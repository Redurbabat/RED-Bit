import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

from server import (
    NAMES, PREFERENCE_NAMES, Server, ShortcutRunner, catalog,
    validate_arguments, validate_reply,
)

STATUS = {
    "version": 1, "state": "paused", "hasTrack": True,
    "canNext": False, "canPrevious": False,
    "controlsLocked": False, "hasPlaybackError": False,
}

RECEIPTS = {
    "redbit_set_automix": {
        "version": 1, "command": "setAutomix", "decision": "requested",
        "status": STATUS, "automixEnabled": True,
    },
    "redbit_set_equalizer": {
        "version": 1, "command": "setEqualizer", "decision": "requested",
        "equalizerEnabled": False,
    },
    "redbit_set_quality": {
        "version": 1, "command": "setStreamQuality", "decision": "requested",
        "requestedQuality": "HIGH", "metered": True,
    },
    "redbit_set_shuffle": {
        "version": 1, "command": "setShuffle", "decision": "requested",
        "shuffleEnabled": True,
    },
}
INPUTS = {
    "redbit_set_automix": {"enabled": True},
    "redbit_set_equalizer": {"enabled": False},
    "redbit_set_quality": {"quality": "HIGH", "metered": True},
    "redbit_set_shuffle": {"enabled": True},
}


class PreferencePilotTests(unittest.TestCase):
    def setUp(self):
        self.path = Path(__file__).resolve().parents[2] / "docs/red-bit-tool-contract.json"
        self.invocations = []
        self.next_id = 1

    def run_fixture(self, name, arguments=None):
        self.invocations.append((name, arguments))
        return RECEIPTS[name]

    def server(self, enabled):
        tools = catalog(self.path, allow_preferences=enabled)
        server = Server(tools, self.run_fixture, allow_preferences=enabled)
        initialized = server.handle({
            "jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": {"protocolVersion": "2025-11-25"},
        })
        self.assertEqual(initialized["result"]["protocolVersion"], "2025-11-25")
        server.handle({"jsonrpc": "2.0", "method": "notifications/initialized"})
        return server

    def call(self, server, name, arguments):
        self.next_id += 1
        return server.handle({
            "jsonrpc": "2.0", "id": self.next_id, "method": "tools/call",
            "params": {"name": name, "arguments": arguments},
        })

    def test_default_denies_all_four_and_never_calls_runner(self):
        server = self.server(False)
        self.assertEqual(tuple(t["name"] for t in server.tools), NAMES)
        for name in PREFERENCE_NAMES:
            self.assertIn("error", self.call(server, name, INPUTS[name]))
            with self.assertRaises(ValueError):
                ShortcutRunner("RED Bit Local")(name, INPUTS[name])
        self.assertEqual(self.invocations, [])

    def test_opt_in_contract_matches_all_four_declared_schemas(self):
        server = self.server(True)
        self.assertEqual(tuple(t["name"] for t in server.tools), NAMES + PREFERENCE_NAMES)
        recorded = json.loads(self.path.read_text())
        declared = {t["name"]: t for t in recorded["tools"]}
        for tool in server.tools[2:]:
            name = tool["name"]
            self.assertEqual(tool["inputSchema"], declared[name]["inputSchema"])
            self.assertFalse(tool["annotations"]["readOnlyHint"])
            self.assertTrue(tool["annotations"]["idempotentHint"])
            self.assertEqual(declared[name]["scope"], "preferences")

    def test_four_valid_commands_return_private_receipts(self):
        server = self.server(True)
        for name in PREFERENCE_NAMES:
            result = self.call(server, name, INPUTS[name])["result"]
            self.assertFalse(result["isError"])
            reply = json.loads(result["content"][0]["text"])
            self.assertEqual(reply, RECEIPTS[name])
        self.assertEqual(self.invocations, [(name, INPUTS[name]) for name in PREFERENCE_NAMES])

    def test_invalid_arguments_are_rejected_before_any_side_effect(self):
        server = self.server(True)
        wrong = [
            ("redbit_set_automix", {"enabled": 1}),
            ("redbit_set_equalizer", {"enabled": "true"}),
            ("redbit_set_shuffle", {"enabled": False, "extra": 1}),
            ("redbit_set_quality", {"quality": "lossless", "metered": True}),
            ("redbit_set_quality", {"quality": "HIGH", "metered": 1}),
            ("redbit_set_quality", {"quality": "HIGH"}),
            ("redbit_set_quality", {"quality": "HIGH", "metered": True, "token": "secret"}),
            ("redbit_set_quality", {"quality": ["HIGH"], "metered": False}),
            ("redbit_set_quality", {"quality": "LOSSLESS", "metered": None}),
        ]
        for name, arguments in wrong:
            with self.subTest(name=name, arguments=arguments):
                self.assertIn("error", self.call(server, name, arguments))
        self.assertEqual(self.invocations, [])

    def test_receipt_rejects_private_or_wrongly_typed_fields(self):
        server = self.server(True)
        for name, additions in (
            ("redbit_set_equalizer", {"token": "private"}),
            ("redbit_set_equalizer", {"equalizerEnabled": 0}),
            ("redbit_set_shuffle", {"shuffleEnabled": "true"}),
            ("redbit_set_quality", {"requestedQuality": "CUSTOM"}),
            ("redbit_set_quality", {"metered": 1}),
            ("redbit_set_automix", {"automixEnabled": 0}),
            ("redbit_set_automix", {"status": dict(STATUS, title="private")}),
        ):
            with self.subTest(name=name, additions=additions):
                self.invocations.clear()
                server.runner = lambda _name, _args, n=name, extra=additions: dict(RECEIPTS[n], **extra)
                result = self.call(server, name, INPUTS[name])["result"]
                self.assertTrue(result["isError"])
                self.assertNotIn("private", json.dumps(result))
        for name in PREFERENCE_NAMES:
            missing = dict(RECEIPTS[name])
            missing.pop({"redbit_set_automix": "automixEnabled",
                         "redbit_set_equalizer": "equalizerEnabled",
                         "redbit_set_quality": "requestedQuality",
                         "redbit_set_shuffle": "shuffleEnabled"}[name])
            with self.assertRaises(ValueError):
                validate_reply(name, missing)

    def test_shortcut_receives_json_encoded_quality(self):
        def fake_run(args, **_kwargs):
            self.assertEqual(args[:3], ["/usr/bin/shortcuts", "run", "RED Bit Local"])
            request = json.loads(Path(args[4]).read_text())
            self.assertEqual(request["tool"], "redbit_set_quality")
            self.assertEqual(json.loads(request["arguments"]), INPUTS["redbit_set_quality"])
            Path(args[6]).write_text(json.dumps(RECEIPTS["redbit_set_quality"]))
        with patch("server.subprocess.run", side_effect=fake_run) as call:
            runner = ShortcutRunner("RED Bit Local", allow_preferences=True)
            self.assertEqual(runner("redbit_set_quality", INPUTS["redbit_set_quality"]),
                             RECEIPTS["redbit_set_quality"])
            with self.assertRaises(ValueError):
                runner("redbit_set_quality", {"quality": "HIGH", "metered": 1})
            call.assert_called_once()

    def test_timeout_is_unknown_and_not_retried(self):
        server = self.server(True)
        server.runner = ShortcutRunner("RED Bit Local", allow_preferences=True)
        with patch("server.subprocess.run", side_effect=subprocess.TimeoutExpired("shortcuts", 20)) as call:
            result = self.call(server, "redbit_set_shuffle", {"enabled": True})["result"]
            self.assertTrue(result["isError"])
            self.assertIn("outcome unknown", result["content"][0]["text"])
            call.assert_called_once()

    def test_non_finite_number_rejection_still_preserved(self):
        for value in (float("nan"), float("inf"), float("-inf"), True):
            with self.assertRaises(ValueError):
                validate_arguments("redbit_set_volume", {"percent": value})


if __name__ == "__main__":
    unittest.main()
