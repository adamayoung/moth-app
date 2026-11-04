"""Tests for Scripts/run-xcode-tests.sh, which stops a run that matched nothing
from passing.

Run with: python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
"""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


RUN_XCODE_TESTS = Path(__file__).resolve().parent.parent / "run-xcode-tests.sh"


class RunXcodeTestsTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        self.bundle = self.directory / "Result.xcresult"
        self.arguments_file = self.directory / "xcodebuild-arguments"
        self.fake_bin = self.directory / "bin"
        self.fake_bin.mkdir()
        self.environment = {**os.environ, "PATH": f"{self.fake_bin}:{os.environ['PATH']}"}

    def fake(self, name, body):
        path = self.fake_bin / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def fake_xcodebuild(self, status=0, writes_bundle=True):
        creates = f'mkdir -p "{self.bundle}"' if writes_bundle else ":"
        self.fake("xcodebuild", f'echo "$@" > "{self.arguments_file}"\n{creates}\nexit {status}')

    def fake_summary(self, total, skipped=0):
        self.fake_summary_output(f'{{"totalTestCount": {total}, "skippedTests": {skipped}}}')

    def fake_summary_output(self, output):
        self.fake("xcrun", f'[ "$3 $4" = "test-results summary" ] && echo \'{output}\'')

    def run_script(self, *arguments):
        return subprocess.run(
            [RUN_XCODE_TESTS, str(self.bundle), *arguments],
            env=self.environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=30,
        )

    def test_reports_the_number_of_tests_that_ran(self):
        self.fake_xcodebuild()
        self.fake_summary(3)
        result = self.run_script()
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.splitlines()[-1], "Ran 3 test(s).")

    def test_passes_its_arguments_and_the_bundle_to_xcodebuild(self):
        self.fake_xcodebuild()
        self.fake_summary(1)
        self.run_script("-scheme", "Moth")
        self.assertEqual(
            self.arguments_file.read_text().strip(),
            f"test -scheme Moth -resultBundlePath {self.bundle}",
        )

    def test_fails_a_run_that_matched_no_tests(self):
        self.fake_xcodebuild()
        self.fake_summary(0)
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Ran 0 test(s).", result.stdout)

    def test_does_not_count_skipped_tests(self):
        self.fake_xcodebuild()
        self.fake_summary(3, skipped=1)
        self.assertIn("Ran 2 test(s).", self.run_script().stdout)

    def test_fails_a_run_whose_tests_were_all_skipped(self):
        self.fake_xcodebuild()
        self.fake_summary(2, skipped=2)
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Ran 0 test(s).", result.stdout)

    def test_fails_when_the_summary_is_empty(self):
        self.fake_xcodebuild()
        self.fake("xcrun", "exit 1")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Ran ", result.stdout)

    def test_fails_when_the_summary_has_no_count(self):
        self.fake_xcodebuild()
        self.fake_summary_output("{}")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Ran ", result.stdout)

    def test_keeps_the_status_of_a_failed_run_when_the_summary_is_unreadable(self):
        self.fake_xcodebuild(status=65)
        self.fake("xcrun", "exit 1")
        self.assertEqual(self.run_script().returncode, 65)

    def test_keeps_the_status_of_a_failed_run_and_still_reports(self):
        self.fake_xcodebuild(status=65)
        self.fake_summary(3)
        result = self.run_script()
        self.assertEqual(result.returncode, 65)
        self.assertIn("Ran 3 test(s).", result.stdout)

    def test_deletes_the_previous_bundle_before_the_run(self):
        self.bundle.mkdir()
        leftover = self.bundle / "leftover"
        leftover.touch()
        self.fake("xcodebuild", f'[ ! -e "{self.bundle}" ] && mkdir "{self.bundle}" && exit 0\nexit 1')
        self.fake_summary(1)
        self.assertEqual(self.run_script().returncode, 0)

    def test_fails_without_a_count_when_there_is_no_bundle(self):
        self.fake_xcodebuild(writes_bundle=False)
        self.fake_summary(3)
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("Ran ", result.stdout)


if __name__ == "__main__":
    unittest.main()
