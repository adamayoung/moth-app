"""Tests for Scripts/build-lock.sh, the machine-wide xcodebuild lock.

Run with: python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
"""

import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


BUILD_LOCK = Path(__file__).resolve().parent.parent / "build-lock.sh"


def dead_pid():
    process = subprocess.Popen(["true"])
    process.wait()
    return process.pid


class BuildLockTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        self.lock = self.directory / "build.lock"
        self.environment = {**os.environ, "MOTH_BUILD_LOCK": str(self.lock)}

    def start(self, *command, label="test-ui UITests"):
        return subprocess.Popen(
            [BUILD_LOCK, *command],
            cwd=self.directory,
            env={**self.environment, "MOTH_BUILD_LOCK_LABEL": label},
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

    def run_to_completion(self, *command):
        process = self.start(*command)
        output, _ = process.communicate(timeout=30)
        return process.returncode, output

    def wait_for_lock(self):
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if self.lock.exists():
                return
            time.sleep(0.02)
        self.fail("the first run never took the lock")

    def test_returns_the_status_of_the_command(self):
        status, _ = self.run_to_completion("sh", "-c", "exit 7")
        self.assertEqual(status, 7)

    def test_releases_the_lock_after_success(self):
        self.run_to_completion("true")
        self.assertFalse(self.lock.exists())

    def test_releases_the_lock_after_failure(self):
        self.run_to_completion("false")
        self.assertFalse(self.lock.exists())

    def test_holds_the_lock_while_the_command_runs(self):
        status, output = self.run_to_completion("cat", str(self.lock))
        self.assertEqual(status, 0)
        self.assertRegex(output, r"^\d+$")

    def test_a_second_run_waits_behind_the_first_and_names_it(self):
        release = self.directory / "release"
        first = self.start("sh", "-c", f"while [ ! -e {release} ]; do sleep 0.05; done")
        self.addCleanup(first.communicate)
        self.addCleanup(release.touch)
        self.wait_for_lock()
        marker = self.directory / "second-ran"

        second = self.start("touch", str(marker), label="test UnitTests")
        time.sleep(1.5)
        self.assertFalse(marker.exists())

        release.touch()
        output, _ = second.communicate(timeout=30)
        self.assertEqual(second.returncode, 0)
        self.assertTrue(marker.exists())
        checkout = self.directory.resolve()
        self.assertRegex(
            output,
            rf"waiting for the xcodebuild lock \(held by pid {first.pid}: test-ui UITests in .*{checkout.name}\)\.\.\.",
        )

    def test_takes_over_a_lock_left_by_a_killed_run(self):
        self.lock.write_text(f"{dead_pid()}\n")
        status, _ = self.run_to_completion("true")
        self.assertEqual(status, 0)
        self.assertFalse(self.lock.exists())

    def test_fails_instead_of_waiting_when_the_lock_cannot_be_created(self):
        self.environment["MOTH_BUILD_LOCK"] = str(self.directory / "missing" / "build.lock")
        status, output = self.run_to_completion("true")
        self.assertNotEqual(status, 0)
        self.assertIn("error:", output)

    def test_labels_a_run_with_its_command_when_no_label_is_given(self):
        holder = self.directory / "build.lock.holder"
        process = subprocess.Popen(
            [BUILD_LOCK, "cat", str(holder)],
            cwd=self.directory,
            env=self.environment,
            stdout=subprocess.PIPE,
            text=True,
        )
        output, _ = process.communicate(timeout=30)
        self.assertTrue(output.startswith(f"cat {holder} in "), output)


if __name__ == "__main__":
    unittest.main()
