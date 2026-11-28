import unittest
from pathlib import Path
from unittest.mock import Mock
import subprocess

from server import CallGuard, Server, catalog

STATUS = {"version": 1, "state": "paused", "hasTrack": True,
          "canNext": False, "canPrevious": False, "controlsLocked": False,
          "hasPlaybackError": False}


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.now = 100.0
        self.guard = CallGuard(lambda: self.now, max_ids=6, total_limit=4,
                               write_limit=2, window=60)
        path = Path(__file__).resolve().parents[2] / "docs/red-bit-tool-contract.json"
        self.runner = Mock(return_value={"version": 1, "command": "next",
                                        "decision": "requested", "status": STATUS})
        self.server = Server(catalog(path, allow_navigation=True), self.runner,
                             allow_navigation=True, guard=self.guard)
        self.server.handle({"jsonrpc": "2.0", "id": 0, "method": "initialize",
                            "params": {"protocolVersion": "2025-11-25"}})
        self.server.handle({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def call(self, ident, name="redbit_next", args=None):
        return self.server.handle({"jsonrpc": "2.0", "id": ident, "method": "tools/call",
                                   "params": {"name": name, "arguments": args or {}}})

    def test_duplicate_id_never_dispatches_twice_even_with_other_tool(self):
        self.assertFalse(self.call("first")["result"]["isError"])
        self.assertEqual(self.call("first")["error"]["code"], -32003)
        self.assertEqual(self.call("first", "redbit_read_status")["error"]["code"], -32003)
        self.runner.assert_called_once_with("redbit_next")

    def test_timeout_keeps_reservation(self):
        self.runner.side_effect = subprocess.TimeoutExpired("shortcuts", 20)
        self.assertTrue(self.call(1)["result"]["isError"])
        self.assertEqual(self.call(1)["error"]["code"], -32003)
        self.runner.assert_called_once()

    def test_write_limit_does_not_starve_reads(self):
        self.call(1)
        self.call(2)
        self.assertEqual(self.call(3)["error"]["code"], -32005)
        self.runner.return_value = STATUS
        self.assertFalse(self.call(4, "redbit_read_status")["result"]["isError"])
        self.assertFalse(self.call(5, "redbit_read_status")["result"]["isError"])
        self.assertEqual(self.call(6, "redbit_read_status")["error"]["code"], -32005)
        self.assertEqual(self.runner.call_count, 4)

    def test_sliding_window_does_not_forget_dispatched_ids(self):
        self.call(1)
        self.call(2)
        self.now += 59.9
        self.assertEqual(self.call(3)["error"]["code"], -32005)
        self.now += 0.2
        self.assertEqual(self.call(1)["error"]["code"], -32003)
        self.assertFalse(self.call(3)["result"]["isError"])
        self.assertEqual(self.runner.call_count, 3)

    def test_bounded_session_never_evicts_old_ids(self):
        for ident in range(1, 7):
            self.now += 61
            self.assertFalse(self.call(ident)["result"]["isError"])
        self.now += 61
        self.assertEqual(self.call(7)["error"]["code"], -32004)
        self.assertEqual(self.call(1)["error"]["code"], -32003)
        self.assertEqual(self.runner.call_count, 6)
        self.assertEqual(len(self.guard.seen), 6)

    def test_invalid_ids_and_parameters_do_not_dispatch_or_reserve(self):
        for ident in ("", "x" * 129, 2**53, -(2**53), True, None):
            self.assertEqual(self.call(ident)["error"]["code"], -32600)
        self.assertEqual(self.call(1, args={"extra": 1})["error"]["code"], -32602)
        self.runner.assert_not_called()
        self.assertFalse(self.call(1)["result"]["isError"])
        self.runner.assert_called_once()

    def test_numeric_and_string_ids_remain_distinct(self):
        self.assertFalse(self.call(1)["result"]["isError"])
        self.assertFalse(self.call("1")["result"]["isError"])
        self.assertEqual(self.runner.call_count, 2)


if __name__ == "__main__":
    unittest.main()
