import io
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

from server import NAMES, Server, ShortcutRunner, catalog, serve, strict_json, validate_reply

STATUS = {"version": 1, "state": "paused", "hasTrack": True, "canNext": False,
          "canPrevious": False, "controlsLocked": False, "hasPlaybackError": False}
QUEUE = {"version": 1, "total": 4, "upcoming": 3, "automaticUpcoming": 1,
         "manualUpcoming": 2, "shuffleEnabled": False, "controlsLocked": False}


class ReadPilotTests(unittest.TestCase):
    def setUp(self):
        self.calls = []
        self.tools = catalog(Path(__file__).resolve().parents[2] / "docs/red-bit-tool-contract.json")
        self.server = Server(self.tools, self.run_fixture)

    def run_fixture(self, name):
        self.calls.append(name)
        return STATUS if name == NAMES[0] else QUEUE

    def request(self, method, params=None, ident=1):
        return self.server.handle({"jsonrpc": "2.0", "id": ident, "method": method, "params": params or {}})

    def ready(self):
        result = self.request("initialize", {"protocolVersion": "2025-11-25"})
        self.assertEqual(result["result"]["protocolVersion"], "2025-11-25")
        self.assertIsNone(self.server.handle({"jsonrpc": "2.0", "method": "notifications/initialized"}))

    def test_handshake_and_catalog(self):
        self.assertIn("error", self.request("tools/list"))
        self.ready()
        self.assertEqual([t["name"] for t in self.request("tools/list")["result"]["tools"]], list(NAMES))
        self.assertIn("error", self.request("initialize", {"protocolVersion": "2025-11-25"}))
        self.assertEqual(self.calls, [])

    def test_read_only_calls_and_notification(self):
        self.ready()
        for name, expected in zip(NAMES, (STATUS, QUEUE)):
            result = self.request("tools/call", {"name": name, "arguments": {}})["result"]
            self.assertFalse(result["isError"])
            self.assertEqual(json.loads(result["content"][0]["text"]), expected)
        for params in ({"name": "redbit_play"}, {"name": NAMES[0], "arguments": {"extra": 1}}, {"name": NAMES[0], "arguments": []}):
            self.assertIn("error", self.request("tools/call", params))
        self.assertIsNone(self.server.handle({"jsonrpc": "2.0", "method": "tools/call", "params": {"name": NAMES[0]}}))
        self.assertEqual(self.calls, list(NAMES))

    def test_privacy_and_bad_reply(self):
        for reply in (dict(STATUS, title="private"), dict(STATUS, state="private"), dict(STATUS, hasTrack=1), dict(STATUS, positionSeconds=True)):
            with self.assertRaises(ValueError):
                validate_reply(NAMES[0], reply)
        with self.assertRaises(ValueError):
            validate_reply(NAMES[1], dict(QUEUE, manualUpcoming=9))
        self.ready()
        self.server.runner = lambda _: dict(STATUS, token="private")
        result = self.request("tools/call", {"name": NAMES[0]})["result"]
        self.assertTrue(result["isError"])
        self.assertNotIn("private", json.dumps(result))

    def test_shortcut_failure_is_not_retried(self):
        self.ready()
        with patch("server.subprocess.run", side_effect=subprocess.TimeoutExpired("shortcuts", 20)) as run:
            self.server.runner = ShortcutRunner("RED Bit Local")
            self.assertTrue(self.request("tools/call", {"name": NAMES[0]})["result"]["isError"])
            run.assert_called_once()
            self.assertEqual(run.call_args.args[0][:3], ["/usr/bin/shortcuts", "run", "RED Bit Local"])

    def test_shortcut_file_bridge(self):
        def fake_run(args, **kwargs):
            self.assertEqual(json.loads(Path(args[4]).read_text()), {"tool": NAMES[0], "arguments": "{}"})
            Path(args[6]).write_text(json.dumps(STATUS))
        with patch("server.subprocess.run", side_effect=fake_run):
            self.assertEqual(ShortcutRunner("RED Bit Local")(NAMES[0]), STATUS)

    def test_json_framing(self):
        for raw in ('{"a":1,"a":2}', '{"a":NaN}'):
            with self.assertRaises(ValueError):
                strict_json(raw)
        out = io.BytesIO()
        serve(self.server, io.BytesIO(b'{bad}\n{"jsonrpc":"2.0","id":2,"method":"ping"}\n'), out)
        replies = [json.loads(line) for line in out.getvalue().splitlines()]
        self.assertEqual(replies[0]["error"]["code"], -32700)
        self.assertEqual(replies[1]["result"], {})
        out = io.BytesIO()
        serve(self.server, io.BytesIO(b" " * 16385 + b"\n"), out)
        self.assertEqual(out.getvalue(), b"")


if __name__ == "__main__":
    unittest.main()
