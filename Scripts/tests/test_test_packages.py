"""Tests for Scripts/test-packages.sh, which runs `swift test` in every package.

Run with: python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


TEST_PACKAGES = Path(__file__).resolve().parent.parent / "test-packages.sh"

SWIFT_TESTING_SUMMARY = "Test run with {} tests in 1 suite passed after 0.001 seconds."
XCTEST_SUMMARY = "Executed {} tests, with 0 failures (0 unexpected) in 0.003 (0.004) seconds"


class TestPackagesTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        self.fake_bin = self.directory / "bin"
        self.fake_bin.mkdir()
        self.ran = self.directory / "ran"
        self.environment = {**os.environ, "PATH": f"{self.fake_bin}:{os.environ['PATH']}"}
        self.script = self.directory / "Scripts" / TEST_PACKAGES.name
        self.script.parent.mkdir()
        shutil.copy(TEST_PACKAGES, self.script)

    def add_package(self, name, output, status=0):
        package = self.directory / "Packages" / name
        package.mkdir(parents=True)
        (package / "Package.swift").touch()
        (package / "output").write_text(output)
        (package / "status").write_text(str(status))

    def run_script(self, cwd=None):
        fake_swift = self.fake_bin / "swift"
        fake_swift.write_text(
            '#!/bin/sh\n'
            f'basename "$3" >> "{self.ran}"\n'
            'cat "$3/output"\n'
            'exit "$(cat "$3/status")"\n'
        )
        fake_swift.chmod(0o755)
        return subprocess.run(
            [self.script],
            cwd=cwd or self.directory,
            env=self.environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=30,
        )

    def test_succeeds_and_says_so_with_no_packages(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0)
        self.assertIn("no packages", result.stdout)

    def test_finds_the_packages_from_any_directory(self):
        self.add_package("HTTPKit", SWIFT_TESTING_SUMMARY.format(2))
        result = self.run_script(cwd=self.fake_bin)
        self.assertIn("HTTPKit: ran 2 test(s)", result.stdout)

    def test_passes_a_package_with_swift_testing_tests(self):
        self.add_package("HTTPKit", XCTEST_SUMMARY.format(0) + "\n" + SWIFT_TESTING_SUMMARY.format(2))
        result = self.run_script()
        self.assertEqual(result.returncode, 0)
        self.assertIn("HTTPKit: ran 2 test(s)", result.stdout)

    def test_counts_xctest_summaries_once(self):
        output = "\n".join([XCTEST_SUMMARY.format(2)] * 3 + [SWIFT_TESTING_SUMMARY.format(0)])
        self.add_package("HTTPKit", output)
        result = self.run_script()
        self.assertEqual(result.returncode, 0)
        self.assertIn("HTTPKit: ran 2 test(s)", result.stdout)

    def test_adds_the_two_frameworks_together(self):
        self.add_package("HTTPKit", XCTEST_SUMMARY.format(2) + "\n" + SWIFT_TESTING_SUMMARY.format(3))
        self.assertIn("HTTPKit: ran 5 test(s)", self.run_script().stdout)

    def test_fails_a_package_that_ran_no_tests_and_names_it(self):
        self.add_package("HTTPKit", XCTEST_SUMMARY.format(0) + "\n" + SWIFT_TESTING_SUMMARY.format(0))
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error: HTTPKit ran no tests", result.stdout)

    def test_fails_a_package_whose_tests_fail(self):
        self.add_package("HTTPKit", SWIFT_TESTING_SUMMARY.format(2), status=1)
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error: HTTPKit", result.stdout)

    def test_runs_every_package_after_a_failure(self):
        self.add_package("HTTPKit", "", status=1)
        self.add_package("MothCore", SWIFT_TESTING_SUMMARY.format(1))
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.ran.read_text().split(), ["HTTPKit", "MothCore"])

    def test_names_every_package_and_count_in_the_step_summary(self):
        self.add_package("HTTPKit", SWIFT_TESTING_SUMMARY.format(2))
        self.add_package("MothCore", SWIFT_TESTING_SUMMARY.format(3))
        summary = self.directory / "summary"
        self.environment["GITHUB_STEP_SUMMARY"] = str(summary)
        self.run_script()
        self.assertEqual(summary.read_text().splitlines(), ["- HTTPKit: ran 2 test(s)", "- MothCore: ran 3 test(s)"])


if __name__ == "__main__":
    unittest.main()
