"""Local, read-only MCP pilot. Never starts a network listener."""
import argparse
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile

PROTOCOL = "2025-11-25"
NAMES = ("redbit_read_status", "redbit_read_queue")
MAX_LINE = 16384
MAX_REPLY = 8192


def strict_json(text):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("duplicate field")
            result[key] = value
        return result

    def constant(_):
        raise ValueError("non-finite JSON")

    return json.loads(text, object_pairs_hook=pairs, parse_constant=constant)


def catalog(path):
    data = strict_json(path.read_text(encoding="utf-8"))
    if data.get("version") != 1 or data.get("app") != "red-bit" or data.get("remoteAvailable") is not False:
        raise ValueError("unexpected tool contract")
    tools = []
    for name in NAMES:
        matches = [t for t in data["tools"] if t["name"] == name]
        if len(matches) != 1:
            raise ValueError("missing read tool")
        t = matches[0]
        if t["scope"] != "status" or t["readOnly"] is not True or t["inputSchema"] != {
            "type": "object", "properties": {}, "required": [], "additionalProperties": False
        }:
            raise ValueError("unexpected read tool")
        tools.append({"name": name, "description": t["description"], "inputSchema": t["inputSchema"],
                      "annotations": {"readOnlyHint": True, "openWorldHint": False}})
    return tools


def validate_reply(name, value):
    if type(value) is not dict or type(value.get("version")) is not int or value["version"] != 1:
        raise ValueError("invalid reply")
    if name == NAMES[0]:
        flags = {"hasTrack", "canNext", "canPrevious", "controlsLocked", "hasPlaybackError"}
        required = flags | {"version", "state"}
        optional = {"positionSeconds", "durationSeconds"}
        if not required <= value.keys() <= required | optional or value["state"] not in (
            "stopped", "buffering", "playing", "paused"
        ) or any(type(value[k]) is not bool for k in flags):
            raise ValueError("invalid status")
        for key in optional & value.keys():
            n = value[key]
            if type(n) not in (float, int) or not math.isfinite(n) or n < 0:
                raise ValueError("invalid time")
    elif name == NAMES[1]:
        counts = {"total", "upcoming", "automaticUpcoming", "manualUpcoming"}
        flags = {"shuffleEnabled", "controlsLocked"}
        if value.keys() != counts | flags | {"version"} or any(
            type(value[k]) is not int or value[k] < 0 for k in counts
        ) or any(type(value[k]) is not bool for k in flags):
            raise ValueError("invalid queue")
        if value["upcoming"] > value["total"] or value["automaticUpcoming"] + value["manualUpcoming"] != value["upcoming"]:
            raise ValueError("invalid queue counts")
    else:
        raise ValueError("unknown read tool")
    return value


class ShortcutRunner:
    def __init__(self, shortcut):
        if not shortcut.strip() or shortcut.startswith("-") or len(shortcut) > 200:
            raise ValueError("invalid shortcut name")
        self.shortcut = shortcut

    def __call__(self, name):
        if name not in NAMES:
            raise ValueError("not a read tool")
        with tempfile.TemporaryDirectory(prefix="redbit-mcp-") as temp:
            source, target = Path(temp) / "request.json", Path(temp) / "reply.txt"
            source.write_text(json.dumps({"tool": name, "arguments": "{}"}), encoding="utf-8")
            subprocess.run(["/usr/bin/shortcuts", "run", self.shortcut, "-i", str(source), "-o", str(target)],
                           check=True, timeout=20, stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            with target.open("rb") as stream:
                raw = stream.read(MAX_REPLY + 1)
            if len(raw) > MAX_REPLY:
                raise ValueError("oversized reply")
            return strict_json(raw.decode("utf-8"))


class Server:
    def __init__(self, tools, runner):
        self.tools = tools
        self.runner = runner
        self.phase = "new"

    def handle(self, request):
        if type(request) is not dict or request.get("jsonrpc") != "2.0" or not isinstance(request.get("method"), str):
            return self.error(None, -32600, "Invalid request")
        method = request["method"]
        ident = request.get("id")
        if "id" not in request:
            if method == "notifications/initialized" and self.phase == "initializing":
                self.phase = "ready"
            return None  # Notifications never execute tools or get responses.
        if type(ident) not in (str, int):
            return self.error(None, -32600, "Invalid request id")
        params = request.get("params", {})
        if type(params) is not dict:
            return self.error(ident, -32602, "Invalid params")
        if method == "initialize" and self.phase == "new":
            if not isinstance(params.get("protocolVersion"), str):
                return self.error(ident, -32602, "Invalid protocol version")
            self.phase = "initializing"
            result = {"protocolVersion": PROTOCOL, "capabilities": {"tools": {}},
                      "serverInfo": {"name": "red-bit-local-read", "version": "0.1.0"}}
        elif method == "ping":
            result = {}
        elif self.phase != "ready":
            return self.error(ident, -32002, "Not initialized")
        elif method == "tools/list":
            result = {"tools": self.tools}
        elif method == "tools/call":
            name = params.get("name")
            args = params.get("arguments", {})
            if name not in NAMES or type(args) is not dict or args:
                return self.error(ident, -32602, "Unsupported read tool or arguments")
            try:
                value = validate_reply(name, self.runner(name))
                result = {"content": [{"type": "text", "text": json.dumps(value, allow_nan=False, sort_keys=True)}], "isError": False}
            except (OSError, ValueError, OverflowError, subprocess.SubprocessError):
                result = {"content": [{"type": "text", "text": "RED Bit read unavailable. Check local permission, authentication and shortcut."}], "isError": True}
        else:
            return self.error(ident, -32601, "Method not found")
        return {"jsonrpc": "2.0", "id": ident, "result": result}

    @staticmethod
    def error(ident, code, message):
        return {"jsonrpc": "2.0", "id": ident, "error": {"code": code, "message": message}}


def serve(server, input_stream, output_stream):
    while raw := input_stream.readline(MAX_LINE + 1):
        if len(raw) > MAX_LINE:
            return  # Bounded framing: close instead of draining unbounded input.
        try:
            result = server.handle(strict_json(raw.decode("utf-8")))
        except (ValueError, RecursionError):
            result = server.error(None, -32700, "Parse error")
        if result is not None:
            output_stream.write((json.dumps(result, allow_nan=False) + "\n").encode("utf-8"))
            output_stream.flush()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shortcut", required=True, help="Name of your trusted local RED Bit shortcut")
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("The Apple Shortcuts bridge requires macOS")
    path = Path(__file__).resolve().parents[2] / "docs/red-bit-tool-contract.json"
    serve(Server(catalog(path), ShortcutRunner(args.shortcut)), sys.stdin.buffer, sys.stdout.buffer)


if __name__ == "__main__":
    main()
