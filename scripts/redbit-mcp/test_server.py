import io
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

from server import NAMES, TRANSPORT_NAMES, Server, ShortcutRunner, catalog, serve, strict_json, validate_reply

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

    def enable_transport(self):
        tools = catalog(Path(__file__).resolve().parents[2] / "docs/red-bit-tool-contract.json", True)
        self.server = Server(tools, self.run_fixture, allow_play_pause=True)
        self.ready()
        return tools

    def test_transport_requires_explicit_host_opt_in(self):
        tools = catalog(Path(__file__).resolve().parents[2] / "docs/red-bit-tool-contract.json", True)
        with self.assertRaises(ValueError):
            Server(tools, self.run_fixture)
        with patch("server.subprocess.run") as run:
            with self.assertRaises(ValueError):
                ShortcutRunner("RED Bit Local")("redbit_play")
            run.assert_not_called()
        self.ready()
        self.assertIn("error", self.request("tools/call", {"name": "redbit_pause"}))
        self.assertEqual(self.calls, [])

    def test_transport_catalog_and_receipts(self):
        tools = self.enable_transport()
        self.assertEqual([t["name"] for t in tools], list(NAMES + TRANSPORT_NAMES))
        self.assertTrue(all(not t["annotations"]["readOnlyHint"] for t in tools[2:]))
        def receipt(name):
            self.calls.append(name)
            return {"version": 1, "command": name.removeprefix("redbit_"),
                    "decision": "requested", "status": STATUS}
        self.server.runner = receipt
        for name in TRANSPORT_NAMES:
            result = self.request("tools/call", {"name": name})["result"]
            self.assertFalse(result["isError"])
            self.assertEqual(json.loads(result["content"][0]["text"])["decision"], "requested")
        for name in ("redbit_next", "redbit_previous", "redbit_set_volume", "redbit_set_quality"):
            self.assertIn("error", self.request("tools/call", {"name": name}))
        self.assertIn("error", self.request("tools/call", {"name": "redbit_play", "arguments": {"extra": 1}}))
        self.assertEqual(self.calls, list(TRANSPORT_NAMES))

    def test_transport_rejected_and_private_receipts(self):
        self.enable_transport()
        for decision in ("locked", "unavailable", "unchanged"):
            self.server.runner = lambda _: {"version": 1, "command": "pause",
                                            "decision": decision, "status": STATUS}
            result = self.request("tools/call", {"name": "redbit_pause"})["result"]
            self.assertEqual(result["isError"], decision != "unchanged")
        for receipt in (
            {"version": 1, "command": "play", "decision": "requested", "status": STATUS},
            {"version": 1, "command": "pause", "decision": "private", "status": STATUS},
            {"version": 1, "command": "pause", "decision": "requested", "status": dict(STATUS, token="private")},
        ):
            self.server.runner = lambda _: receipt
            result = self.request("tools/call", {"name": "redbit_pause"})["result"]
            self.assertTrue(result["isError"])
            self.assertNotIn("private", json.dumps(result))

    def test_transport_timeout_unknown_outcome_and_no_retry(self):
        self.enable_transport()
        self.server.runner = ShortcutRunner("RED Bit Local", allow_play_pause=True)
        with patch("server.subprocess.run", side_effect=subprocess.TimeoutExpired("shortcuts", 20)) as run:
            result = self.request("tools/call", {"name": "redbit_play"})["result"]
            self.assertTrue(result["isError"])
            self.assertIn("outcome unknown", result["content"][0]["text"])
            run.assert_called_once()

    def test_transport_file_bridge(self):
        def fake_run(args, **kwargs):
            self.assertEqual(json.loads(Path(args[4]).read_text()), {"tool": "redbit_pause", "arguments": "{}"})
            Path(args[6]).write_text(json.dumps({"version": 1, "command": "pause",
                "decision": "requested", "status": STATUS}))
        with patch("server.subprocess.run", side_effect=fake_run):
            reply = ShortcutRunner("RED Bit Local", allow_play_pause=True)("redbit_pause")
            self.assertEqual(validate_reply("redbit_pause", reply)["command"], "pause")

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
