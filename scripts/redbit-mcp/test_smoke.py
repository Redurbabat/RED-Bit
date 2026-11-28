import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

from smoke import CONTRACT, check_output, requests, run_check
from server import NAMES, Server, catalog

STATUS = {"version": 1, "state": "paused", "hasTrack": True, "canNext": False,
          "canPrevious": False, "controlsLocked": False, "hasPlaybackError": False}
QUEUE = {"version": 1, "total": 3, "upcoming": 2, "automaticUpcoming": 1,
         "manualUpcoming": 1, "shuffleEnabled": False, "controlsLocked": False}


def fixture_output(unavailable=False):
    def runner(name):
        if unavailable:
            raise OSError("fixture unavailable")
        return STATUS if name == NAMES[0] else QUEUE
    server = Server(catalog(CONTRACT), runner)
    replies = [server.handle(request) for request in requests()]
    return "".join(json.dumps(reply) + "\n" for reply in replies if reply is not None).encode()


class AcceptanceTests(unittest.TestCase):
    def test_read_only_positive_and_private_report(self):
        report = check_output(fixture_output())
        self.assertEqual(report, {"version": 1, "handshake": "passed",
            "readOnlyCatalog": "passed", "readChecks": 2, "result": "passed",
            "writesRequested": 0})
        self.assertNotIn("paused", json.dumps(report))

    def test_unavailable_is_not_success_and_cause_not_inferred(self):
        report = check_output(fixture_output(True), expect_unavailable=True)
        self.assertEqual(report["result"], "unavailable")
        with self.assertRaises(ValueError):
            check_output(fixture_output(True))
        with self.assertRaises(ValueError):
            check_output(fixture_output(), expect_unavailable=True)

    def test_exact_catalog_and_response_ids(self):
        original = [json.loads(line) for line in fixture_output().splitlines()]
        changed = json.loads(json.dumps(original))
        changed[1]["result"]["tools"].append({"name": "redbit_play"})
        with self.assertRaises(ValueError):
            check_output("\n".join(map(json.dumps, changed)).encode())
        changed = json.loads(json.dumps(original))
        changed[2]["id"] = 4
        with self.assertRaises(ValueError):
            check_output("\n".join(map(json.dumps, changed)).encode())

    def test_private_and_missing_fields_fail(self):
        replies = [json.loads(line) for line in fixture_output().splitlines()]
        replies[2]["result"]["content"][0]["text"] = json.dumps(dict(STATUS, title="private"))
        with self.assertRaises(ValueError):
            check_output("\n".join(map(json.dumps, replies)).encode())
        with self.assertRaises(ValueError):
            check_output(b"")
        with self.assertRaises(ValueError):
            check_output(b"x" * 65537)

    def test_launch_has_no_write_flags_and_only_read_requests(self):
        with patch("smoke.subprocess.run", return_value=subprocess.CompletedProcess(
                args=[], returncode=0, stdout=fixture_output(), stderr=b"")) as call:
            self.assertEqual(run_check("RED Bit Local")["result"], "passed")
        argv = call.call_args.args[0]
        self.assertEqual(argv[2:], ["--shortcut", "RED Bit Local"])
        payload = call.call_args.kwargs["input"]
        calls = [json.loads(line) for line in payload.splitlines()]
        self.assertEqual([r["params"]["name"] for r in calls if r["method"] == "tools/call"],
                         list(NAMES))

    def test_actual_stdio_process_fixture(self):
        # Real stdin/stdout pipes and process exit, but simulated app response.
        code = (
            "import sys\n"
            "from pathlib import Path\n"
            "from server import Server, catalog, serve\n"
            f"status={STATUS!r}\nqueue={QUEUE!r}\n"
            f"tools=catalog(Path({str(CONTRACT)!r}))\n"
            "serve(Server(tools, lambda n: status if n=='redbit_read_status' else queue), "
            "sys.stdin.buffer, sys.stdout.buffer)\n"
        )
        payload = "".join(json.dumps(request) + "\n" for request in requests()).encode()
        result = subprocess.run([sys.executable, "-c", code],
            cwd=Path(__file__).resolve().parent, input=payload, capture_output=True,
            timeout=10, check=True)
        self.assertEqual(result.stderr, b"")
        self.assertEqual(check_output(result.stdout)["result"], "passed")


if __name__ == "__main__":
    unittest.main()
