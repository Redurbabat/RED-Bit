"""Read-only acceptance check for the installed RED Bit macOS shortcut."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

from server import NAMES, PROTOCOL, catalog, strict_json, validate_reply

HERE = Path(__file__).resolve().parent
CONTRACT = HERE.parents[1] / "docs/red-bit-tool-contract.json"


def requests():
    return [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize",
         "params": {"protocolVersion": PROTOCOL, "capabilities": {},
                    "clientInfo": {"name": "red-bit-acceptance", "version": "1"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized"},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
        *({"jsonrpc": "2.0", "id": ident, "method": "tools/call",
           "params": {"name": name, "arguments": {}}}
          for ident, name in enumerate(NAMES, 3)),
    ]


def check_output(output, expect_unavailable=False):
    if len(output) > 65536:
        raise ValueError("oversized protocol response")
    lines = output.splitlines()
    if len(lines) != 4:
        raise ValueError("unexpected response count")
    responses = [strict_json(line.decode("utf-8")) for line in lines]
    results = []
    for ident, reply in enumerate(responses, 1):
        if (type(reply) is not dict or reply.keys() != {"jsonrpc", "id", "result"}
                or reply["jsonrpc"] != "2.0" or type(reply["id"]) is not int
                or reply["id"] != ident or type(reply["result"]) is not dict):
            raise ValueError("invalid protocol response")
        results.append(reply["result"])
    if results[0].get("protocolVersion") != PROTOCOL:
        raise ValueError("protocol version mismatch")
    if results[1] != {"tools": catalog(CONTRACT)}:
        raise ValueError("not an exact read-only catalog")
    for name, result in zip(NAMES, results[2:]):
        if result.keys() != {"content", "isError"} or type(result["isError"]) is not bool:
            raise ValueError("invalid tool response")
        content = result["content"]
        if (type(content) is not list or len(content) != 1 or type(content[0]) is not dict
                or content[0].keys() != {"type", "text"} or content[0]["type"] != "text"
                or type(content[0]["text"]) is not str):
            raise ValueError("invalid tool content")
        if expect_unavailable:
            if not result["isError"]:
                raise ValueError("read unexpectedly available")
        else:
            if result["isError"]:
                raise ValueError("read failed")
            validate_reply(name, strict_json(content[0]["text"]))
    return {"version": 1, "handshake": "passed", "readOnlyCatalog": "passed",
            "readChecks": 2, "result": "unavailable" if expect_unavailable else "passed",
            "writesRequested": 0}


def run_check(shortcut, expect_unavailable=False):
    # Start the real adapter, without ANY optional write flags.
    payload = "".join(json.dumps(request) + "\n" for request in requests()).encode("utf-8")
    completed = subprocess.run(
        [sys.executable, str(HERE / "server.py"), "--shortcut", shortcut],
        input=payload, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        timeout=65, check=True,
    )
    return check_output(completed.stdout, expect_unavailable)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shortcut", required=True)
    parser.add_argument("--expect-unavailable", action="store_true",
                        help="Require both reads to fail; does not establish the cause")
    args = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("Requires the installed RED Bit app and Apple Shortcuts on macOS")
    try:
        report = run_check(args.shortcut, args.expect_unavailable)
    except (OSError, ValueError, OverflowError, RecursionError, subprocess.SubprocessError):
        # No raw replies, filenames, stderr, account details or shortcut names.
        print(json.dumps({"version": 1, "result": "failed", "writesRequested": 0}))
        return 1
    print(json.dumps(report, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
