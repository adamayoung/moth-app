"""Tests for Scripts/clear-stale-moth.sh, which clears the way for a UI run.

Run with: python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
"""

import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import unittest


CLEAR_STALE_MOTH = Path(__file__).resolve().parent.parent / "clear-stale-moth.sh"


class ClearStaleMothTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        self.process_name = f"MothTest{os.getpid()}"
        self.sleeper = self.directory / self.process_name
        shutil.copy("/bin/sleep", self.sleeper)
        # The kernel kills a copy of a platform binary on launch unless it is re-signed.
        subprocess.run(["codesign", "--force", "--sign", "-", self.sleeper], check=True, capture_output=True)
        self.fake_bin = self.directory / "bin"
        self.fake_bin.mkdir()
        self.marker = self.directory / "ran"
        self.environment = {**os.environ, "MOTH_APP_PROCESS": self.process_name}

    def start_app(self):
        process = subprocess.Popen([self.sleeper, "60"])
        self.addCleanup(process.wait)
        self.addCleanup(process.kill)
        return process

    def report_as_debugged(self, *processes):
        pids = " ".join(str(process.pid) for process in processes)
        fake_ps = self.fake_bin / "ps"
        fake_ps.write_text(f'#!/bin/sh\nfor pid in {pids}; do [ "$pid" = "$4" ] && echo SX && exit 0; done\necho S\n')
        fake_ps.chmod(0o755)
        self.environment["PATH"] = f"{self.fake_bin}:{os.environ['PATH']}"

    def run_script(self, *arguments):
        return subprocess.run(
            [CLEAR_STALE_MOTH, *arguments],
            env=self.environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=30,
        )

    def run_with_follow_on(self):
        return self.run_script("touch", str(self.marker))

    def test_runs_the_command_when_nothing_is_running(self):
        result = self.run_with_follow_on()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertTrue(self.marker.exists())

    def test_returns_the_status_of_the_command(self):
        self.assertEqual(self.run_script("sh", "-c", "exit 7").returncode, 7)

    def test_kills_a_stale_copy_and_reports_it_before_the_command(self):
        app = self.start_app()
        result = self.run_with_follow_on()
        self.assertEqual(result.returncode, 0)
        self.assertIn(f"killed stale {self.process_name} (pid {app.pid}) before the UI run", result.stdout)
        self.assertEqual(app.wait(timeout=10), -signal.SIGTERM)
        self.assertTrue(self.marker.exists())

    def test_refuses_a_copy_under_the_debugger_without_signalling_it(self):
        app = self.start_app()
        self.report_as_debugged(app)
        result = self.run_with_follow_on()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(f"error: {self.process_name} (pid {app.pid}) is running under the Xcode debugger", result.stdout)
        self.assertIsNone(app.poll())
        self.assertFalse(self.marker.exists())

    def test_signals_nothing_when_one_of_two_copies_is_under_the_debugger(self):
        debugged = self.start_app()
        stale = self.start_app()
        self.report_as_debugged(debugged)
        result = self.run_with_follow_on()
        self.assertNotEqual(result.returncode, 0)
        self.assertIsNone(debugged.poll())
        self.assertIsNone(stale.poll())

    def test_check_only_leaves_a_stale_copy_running(self):
        app = self.start_app()
        result = self.run_script("--check-only")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")
        self.assertIsNone(app.poll())

    def test_check_only_refuses_a_copy_under_the_debugger(self):
        app = self.start_app()
        self.report_as_debugged(app)
        result = self.run_script("--check-only")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("is running under the Xcode debugger", result.stdout)


if __name__ == "__main__":
    unittest.main()
