"""Tests for the commands the Makefile builds, read from `make -n`.

Run with: python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
"""

from pathlib import Path
import subprocess
import unittest


REPOSITORY = Path(__file__).resolve().parent.parent.parent


def dry_run(*arguments):
    return subprocess.run(
        ["make", "-C", str(REPOSITORY), "-n", *arguments],
        capture_output=True,
        text=True,
    )


class TestSelectionTests(unittest.TestCase):
    def test_test_runs_the_unit_plan_with_no_filter(self):
        output = dry_run("test").stdout
        self.assertIn("-testPlan UnitTests", output)
        self.assertNotIn("-only-testing", output)

    def test_a_filter_defaults_to_the_app_test_target(self):
        self.assertIn("-only-testing:'MothTests/AppLaunchModeTests'", dry_run("test", "TESTS=AppLaunchModeTests").stdout)

    def test_a_function_filter_keeps_its_parentheses_quoted(self):
        output = dry_run("test", "TESTS=AppLaunchModeTests/noArgumentsIsLive()").stdout
        self.assertIn("-only-testing:'MothTests/AppLaunchModeTests/noArgumentsIsLive()'", output)

    def test_test_target_redirects_a_filter_to_a_package(self):
        output = dry_run("test", "TEST_TARGET=MothCoreTests", "TESTS=VariableResolverTests").stdout
        self.assertIn("-only-testing:'MothCoreTests/VariableResolverTests'", output)

    def test_test_unit_covers_only_the_app_tests(self):
        output = dry_run("test-unit").stdout
        self.assertIn("-testPlan UnitTests", output)
        self.assertIn("-only-testing:MothTests", output)

    def test_test_ui_runs_the_ui_plan(self):
        output = dry_run("test-ui").stdout
        self.assertIn("-testPlan UITests", output)
        self.assertNotIn("-only-testing", output)

    def test_a_ui_filter_uses_the_ui_target(self):
        self.assertIn("-only-testing:'MothUITests/RequestEditorTests'", dry_run("test-ui", "TESTS=RequestEditorTests").stdout)


    def test_test_all_runs_unit_then_packages_then_ui(self):
        output = dry_run("test-all").stdout
        unit = output.index("-testPlan UnitTests")
        packages = output.index("Scripts/test-packages.sh")
        ui = output.index("-testPlan UITests")
        self.assertLess(unit, packages)
        self.assertLess(packages, ui)


class UIAllowanceTests(unittest.TestCase):
    def test_no_allowance_adds_no_flags(self):
        self.assertNotIn("-test-timeouts-enabled", dry_run("test-ui").stdout)

    def test_short_allows_60_and_90_seconds(self):
        output = dry_run("test-ui", "UI_ALLOWANCE=short").stdout
        self.assertIn("-test-timeouts-enabled YES", output)
        self.assertIn("-default-test-execution-time-allowance 60", output)
        self.assertIn("-maximum-test-execution-time-allowance 90", output)

    def test_long_allows_180_and_240_seconds(self):
        output = dry_run("test-ui", "UI_ALLOWANCE=long").stdout
        self.assertIn("-default-test-execution-time-allowance 180", output)
        self.assertIn("-maximum-test-execution-time-allowance 240", output)

    def test_an_unknown_allowance_is_an_error(self):
        result = dry_run("test-ui", "UI_ALLOWANCE=medium")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("UI_ALLOWANCE", result.stderr)


class BuildLockTests(unittest.TestCase):
    def test_every_xcodebuild_recipe_goes_through_the_lock(self):
        for target in ("build", "test", "test-unit", "test-ui"):
            with self.subTest(target=target):
                self.assertIn("Scripts/build-lock.sh", dry_run(target).stdout)

    def test_test_ui_refuses_a_debugged_app_before_it_queues(self):
        lines = dry_run("test-ui").stdout.splitlines()
        self.assertIn("clear-stale-moth.sh --check-only", lines[0])

    def test_test_ui_clears_a_stale_app_while_holding_the_lock(self):
        output = dry_run("test-ui").stdout
        self.assertRegex(output, r"build-lock\.sh Scripts/clear-stale-moth\.sh Scripts/run-xcode-tests\.sh")


class LintTests(unittest.TestCase):
    def test_lint_excludes_worktrees_from_swiftformat_on_the_command_line(self):
        self.assertRegex(dry_run("lint").stdout, r"swiftformat --lint \. --exclude \.claude/worktrees")

    def test_format_excludes_worktrees_from_swiftformat_on_the_command_line(self):
        self.assertRegex(dry_run("format").stdout, r"swiftformat \. --exclude \.claude/worktrees")


if __name__ == "__main__":
    unittest.main()
