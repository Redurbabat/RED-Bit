"""Local MCP pilot: read-only by default, optional transport. No listener."""
import argparse
from collections import deque
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import time

PROTOCOL = "2025-11-25"
NAMES = ("redbit_read_status", "redbit_read_queue")
TRANSPORT_NAMES = ("redbit_play", "redbit_pause")
NAVIGATION_NAMES = ("redbit_next", "redbit_previous", "redbit_seek")
VOLUME_NAMES = ("redbit_set_volume",)
PREFERENCE_NAMES = ("redbit_set_automix", "redbit_set_equalizer", "redbit_set_quality", "redbit_set_shuffle")
WRITE_NAMES = TRANSPORT_NAMES + NAVIGATION_NAMES + VOLUME_NAMES + PREFERENCE_NAMES
ARGUMENTS = {
    "redbit_seek": {"seconds": {"type": "number", "minimum": 0}},
    "redbit_set_volume": {"percent": {"type": "number", "minimum": 0, "maximum": 100}},
    "redbit_set_automix": {"enabled": {"type": "boolean"}},
    "redbit_set_equalizer": {"enabled": {"type": "boolean"}},
    "redbit_set_quality": {
        "quality": {"type": "string", "enum": ["LOW", "MEDIUM", "HIGH", "LOSSLESS"]},
        "metered": {"type": "boolean"},
    },
    "redbit_set_shuffle": {"enabled": {"type": "boolean"}},
}
COMMANDS = {
    "redbit_set_volume": "setVolume",
    "redbit_set_automix": "setAutomix",
    "redbit_set_equalizer": "setEqualizer",
    "redbit_set_quality": "setStreamQuality",
    "redbit_set_shuffle": "setShuffle",
}


def allowed_names(allow_play_pause=False, allow_navigation=False,
                  allow_volume=False, allow_preferences=False):
    return (NAMES + (TRANSPORT_NAMES if allow_play_pause else ())
            + (NAVIGATION_NAMES if allow_navigation else ())
            + (VOLUME_NAMES if allow_volume else ())
            + (PREFERENCE_NAMES if allow_preferences else ()))


def input_schema(name):
    properties = ARGUMENTS.get(name, {})
    return {"type": "object", "properties": properties,
            "required": sorted(properties), "additionalProperties": False}


def validate_arguments(name, args):
    schema = input_schema(name)["properties"]
    if type(args) is not dict or args.keys() != schema.keys():
        raise ValueError("invalid argument fields")
    for key, field in schema.items():
        value = args[key]
        kind = field["type"]
        if kind == "number":
            if type(value) not in (int, float) or not math.isfinite(value):
                raise ValueError("invalid number")
            if value < field["minimum"] or ("maximum" in field and value > field["maximum"]):
                raise ValueError("out-of-range number")
        elif kind == "boolean":
            if type(value) is not bool:
                raise ValueError("invalid boolean")
        elif kind == "string":
            if type(value) is not str or value not in field["enum"]:
                raise ValueError("invalid enum")
        else:
            raise ValueError("unknown field type")
    return args

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


def catalog(path, allow_play_pause=False, allow_navigation=False,
            allow_volume=False, allow_preferences=False):
    data = strict_json(path.read_text(encoding="utf-8"))
    if data.get("version") != 1 or data.get("app") != "red-bit" or data.get("remoteAvailable") is not False:
        raise ValueError("unexpected tool contract")
    tools = []
    for name in allowed_names(allow_play_pause, allow_navigation, allow_volume, allow_preferences):
        read_only = name in NAMES
        matches = [t for t in data["tools"] if t["name"] == name]
        if len(matches) != 1:
            raise ValueError("missing tool")
        t = matches[0]
        if t["scope"] != ("status" if read_only else ("preferences" if name in PREFERENCE_NAMES else "transport")) or t["readOnly"] is not read_only or t["inputSchema"] != input_schema(name):
            raise ValueError("unexpected tool")
        tools.append({"name": name, "description": t["description"], "inputSchema": t["inputSchema"],
                      "annotations": {"readOnlyHint": read_only, "destructiveHint": False,
                                      "idempotentHint": name not in NAVIGATION_NAMES, "openWorldHint": False}})
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
    elif name in WRITE_NAMES:
        required = {"version", "command", "decision"}
        if name not in PREFERENCE_NAMES or name == "redbit_set_automix":
            required.add("status")
        optional = {
            "redbit_set_volume": {"volumePercent"},
            "redbit_set_automix": {"automixEnabled"},
            "redbit_set_equalizer": {"equalizerEnabled"},
            "redbit_set_quality": {"requestedQuality", "metered"},
            "redbit_set_shuffle": {"shuffleEnabled"},
        }.get(name, set())
        if not required <= value.keys() <= required | optional:
            raise ValueError("invalid command receipt")
        decisions = ("requested", "unchanged", "locked", "unavailable")
        if name in ARGUMENTS:
            decisions += ("invalidValue",)
        if value["command"] != COMMANDS.get(name, name.removeprefix("redbit_")) or value["decision"] not in decisions:
            raise ValueError("invalid command decision")
        if "status" in required:
            validate_reply(NAMES[0], value["status"])
        if "volumePercent" in value:
            validate_arguments("redbit_set_volume", {"percent": value["volumePercent"]})
        for flag in ("automixEnabled", "equalizerEnabled", "shuffleEnabled", "metered"):
            if flag in value and type(value[flag]) is not bool:
                raise ValueError("invalid command flag")
        if "requestedQuality" in value:
            q = value["requestedQuality"]
            if type(q) is not str or q not in ARGUMENTS["redbit_set_quality"]["quality"]["enum"]:
                raise ValueError("invalid quality receipt")
        if name in PREFERENCE_NAMES and value["decision"] in ("requested", "unchanged"):
            expected = {
                "redbit_set_equalizer": {"equalizerEnabled"},
                "redbit_set_quality": {"requestedQuality", "metered"},
                "redbit_set_shuffle": {"shuffleEnabled"},
                "redbit_set_automix": {"automixEnabled"},
            }[name]
            if not expected <= value.keys():
                raise ValueError("missing preference value")
    else:
        raise ValueError("unknown tool")
    return value


class ShortcutRunner:
    def __init__(self, shortcut, allow_play_pause=False, allow_navigation=False,
                 allow_volume=False, allow_preferences=False):
        self.allowed = allowed_names(allow_play_pause, allow_navigation, allow_volume, allow_preferences)
        if not shortcut.strip() or shortcut.startswith("-") or len(shortcut) > 200:
            raise ValueError("invalid shortcut name")
        self.shortcut = shortcut

    def __call__(self, name, arguments=None):
        if name not in self.allowed:
            raise ValueError("tool not enabled")
        args = validate_arguments(name, {} if arguments is None else arguments)
        with tempfile.TemporaryDirectory(prefix="redbit-mcp-") as temp:
            source, target = Path(temp) / "request.json", Path(temp) / "reply.txt"
            source.write_text(json.dumps({"tool": name, "arguments": json.dumps(args, allow_nan=False, separators=(",", ":"))}), encoding="utf-8")
            subprocess.run(["/usr/bin/shortcuts", "run", self.shortcut, "-i", str(source), "-o", str(target)],
                           check=True, timeout=20, stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            with target.open("rb") as stream:
                raw = stream.read(MAX_REPLY + 1)
            if len(raw) > MAX_REPLY:
                raise ValueError("oversized reply")
            return strict_json(raw.decode("utf-8"))


class CallGuard:
    """Per-process dispatch guard; no persistent IDs, payloads or receipts.

    MCP request IDs identify a request within its session. A dispatched call
    consumes its ID even if the shortcut times out or returns invalid data.
    No cache eviction: a full session requires reconnecting, not replaying.
    This is not remote authentication or durable cross-session idempotency.
    """
    def __init__(self, clock=time.monotonic, *, max_ids=4096,
                 total_limit=60, write_limit=20, window=60):
        self.clock = clock
        self.max_ids = max_ids
        self.total_limit = total_limit
        self.write_limit = write_limit
        self.window = window
        self.seen = set()
        self.total = deque()
        self.writes = deque()

    def admit(self, ident, write):
        if type(ident) is str:
            if not ident or len(ident.encode("utf-8", errors="surrogatepass")) > 128:
                return "invalid_id"
        elif type(ident) is not int or not -(2**53 - 1) <= ident <= 2**53 - 1:
            return "invalid_id"
        if ident in self.seen:
            return "duplicate"
        if len(self.seen) >= self.max_ids:
            return "session_full"
        now = self.clock()
        for events in (self.total, self.writes):
            while events and now - events[0] >= self.window:
                events.popleft()
        if len(self.total) >= self.total_limit or (write and len(self.writes) >= self.write_limit):
            return "rate_limit"
        # Reserve before dispatch, including calls that fail or time out.
        self.seen.add(ident)
        self.total.append(now)
        if write:
            self.writes.append(now)
        return None


class Server:
    def __init__(self, tools, runner, allow_play_pause=False, allow_navigation=False,
                 allow_volume=False, allow_preferences=False, *, guard=None):
        self.allowed = allowed_names(allow_play_pause, allow_navigation, allow_volume, allow_preferences)
        if tuple(t["name"] for t in tools) != self.allowed:
            raise ValueError("catalog does not match local permissions")
        self.tools = tools
        self.runner = runner
        self.guard = guard if guard is not None else CallGuard()
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
                      "serverInfo": {"name": "red-bit-local", "version": "0.5.0"}}
        elif method == "ping":
            result = {}
        elif self.phase != "ready":
            return self.error(ident, -32002, "Not initialized")
        elif method == "tools/list":
            result = {"tools": self.tools}
        elif method == "tools/call":
            name = params.get("name")
            args = params.get("arguments", {})
            if name not in self.allowed or set(params) - {"name", "arguments", "_meta"}:
                return self.error(ident, -32602, "Unsupported tool or arguments")
            try:
                validate_arguments(name, args)
            except (ValueError, OverflowError):
                return self.error(ident, -32602, "Unsupported tool or arguments")
            blocked = self.guard.admit(ident, name in WRITE_NAMES)
            if blocked:
                code, message = {
                    "invalid_id": (-32600, "Invalid tool request id"),
                    "duplicate": (-32003, "Tool request id already dispatched; not repeated"),
                    "session_full": (-32004, "Tool session limit reached; reconnect required"),
                    "rate_limit": (-32005, "Tool rate limit reached; wait before a new request"),
                }[blocked]
                return self.error(ident, code, message)
            try:
                value = validate_reply(name, self.runner(name, args) if args else self.runner(name))
                rejected = name in WRITE_NAMES and value["decision"] in ("locked", "unavailable", "invalidValue")
                result = {"content": [{"type": "text", "text": json.dumps(value, allow_nan=False, sort_keys=True)}], "isError": rejected}
            except (OSError, ValueError, OverflowError, subprocess.SubprocessError, RecursionError):
                # A timed-out write may already have reached the app. Never retry
                # or report that the requested state was actually reached.
                message = ("RED Bit command outcome unknown. Read status before another request."
                           if name in WRITE_NAMES else
                           "RED Bit read unavailable. Check local permission, authentication and shortcut.")
                result = {"content": [{"type": "text", "text": message}], "isError": True}
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
    parser.add_argument("--allow-play-pause", action="store_true",
                        help="Opt in to Play/Pause only; RED Bit transport permission is also required")
    parser.add_argument("--allow-navigation", action="store_true",
                        help="Opt in to Next/Previous/Seek; separate RED Bit transport permission required")
    parser.add_argument("--allow-volume", action="store_true",
                        help="Opt in to app volume; separate RED Bit transport permission required")
    parser.add_argument("--allow-preferences", action="store_true",
                        help="Opt in to Automix, equalizer, streaming quality and shuffle; app permission required")
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("The Apple Shortcuts bridge requires macOS")
    path = Path(__file__).resolve().parents[2] / "docs/red-bit-tool-contract.json"
    permissions = (args.allow_play_pause, args.allow_navigation, args.allow_volume, args.allow_preferences)
    serve(Server(catalog(path, *permissions),
                 ShortcutRunner(args.shortcut, *permissions),
                 *permissions), sys.stdin.buffer, sys.stdout.buffer)


if __name__ == "__main__":
    main()
