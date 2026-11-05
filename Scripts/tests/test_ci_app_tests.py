"""Tests for Scripts/ci-app-tests.sh, which runs MothTests only on a runner at
or above the deployment target.

Run with: python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


CI_APP_TESTS = Path(__file__).resolve().parent.parent / "ci-app-tests.sh"


class CIAppTestsTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name)
        self.fake_bin = self.directory / "bin"
        self.fake_bin.mkdir()
        self.ran = self.directory / "ran"
        self.summary = self.directory / "summary"
        self.script = self.directory / "Scripts" / CI_APP_TESTS.name
        self.script.parent.mkdir()
        shutil.copy(CI_APP_TESTS, self.script)
        self.xcconfig = self.directory / "Configs" / "Shared.xcconfig"
        self.xcconfig.parent.mkdir()
        self.set_deployment_target("27.2")

    def set_deployment_target(self, version):
        self.xcconfig.write_text(f"MARKETING_VERSION = 1.0\nMACOSX_DEPLOYMENT_TARGET = {version}\n")

    def run_script(self, host, make_status=0, summary=True):
        fake_sw_vers = self.fake_bin / "sw_vers"
        fake_sw_vers.write_text(f'#!/bin/sh\necho "{host}"\n')
        fake_sw_vers.chmod(0o755)
        fake_make = self.fake_bin / "make"
        fake_make.write_text(f'#!/bin/sh\necho "$@" >> "{self.ran}"\nexit {make_status}\n')
        fake_make.chmod(0o755)
        environment = {**os.environ, "PATH": f"{self.fake_bin}:{os.environ['PATH']}"}
        environment.pop("GITHUB_STEP_SUMMARY", None)
        if summary:
            environment["GITHUB_STEP_SUMMARY"] = str(self.summary)
        return subprocess.run(
            [self.script],
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=30,
        )

    def tests_ran(self):
        return self.ran.exists()

    def test_an_older_host_warns_that_mothtests_did_not_run_and_passes(self):
        result = self.run_script("27.0.1")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertRegex(result.stdout, r"(?m)^::warning[^\n]*::.*MothTests did not run")
        self.assertIn("`MothTests` did not run", self.summary.read_text())
        self.assertFalse(self.tests_ran())

    def test_a_host_at_the_target_runs_the_tests(self):
        result = self.run_script("27.2")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.ran.read_text().split(), ["test-unit-unsigned"])
        self.assertNotIn("::warning", result.stdout)

    def test_a_newer_host_runs_the_tests(self):
        self.assertEqual(self.run_script("28.0").returncode, 0)
        self.assertTrue(self.tests_ran())

    def test_a_minor_version_compares_as_a_number_not_as_text(self):
        self.run_script("27.10")
        self.assertTrue(self.tests_ran())

    def test_a_missing_patch_counts_as_zero(self):
        self.run_script("27.2.0")
        self.assertTrue(self.tests_ran())

    def test_a_host_one_patch_below_a_patch_level_target_is_older(self):
        self.set_deployment_target("27.2.1")
        self.run_script("27.2")
        self.assertFalse(self.tests_ran())

    def test_the_log_shows_the_comparison_on_both_paths(self):
        for host in ("27.0.1", "27.3"):
            with self.subTest(host=host):
                output = self.run_script(host).stdout
                self.assertIn(f"Runner macOS {host}, deployment target 27.2", output)

    def test_an_older_host_passes_without_a_step_summary(self):
        self.assertEqual(self.run_script("27.0.1", summary=False).returncode, 0)

    def test_the_target_comes_from_the_xcconfig(self):
        self.set_deployment_target("28.1")
        output = self.run_script("27.2").stdout
        self.assertIn("deployment target 28.1", output)
        self.assertFalse(self.tests_ran())

    def test_an_unreadable_target_fails_without_running_anything(self):
        self.xcconfig.write_text("MARKETING_VERSION = 1.0\n")
        result = self.run_script("27.2")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error:", result.stdout)
        self.assertFalse(self.tests_ran())

    def test_an_unreadable_host_version_fails_without_running_anything(self):
        result = self.run_script("unknown")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error:", result.stdout)
        self.assertFalse(self.tests_ran())

    def test_a_failing_test_run_fails_the_script(self):
        self.assertEqual(self.run_script("27.2", make_status=65).returncode, 65)


if __name__ == "__main__":
    unittest.main()
