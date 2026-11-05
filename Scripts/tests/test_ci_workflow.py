"""Tests for .github/workflows, read as text: the scripts run on a Mac whose
system Python has no YAML parser. GitHub proves the rest on a pull request.

Run with: python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
"""

from pathlib import Path
import re
import unittest


REPOSITORY = Path(__file__).resolve().parent.parent.parent
WORKFLOW_DIRECTORY = REPOSITORY / ".github" / "workflows"
WORKFLOW = WORKFLOW_DIRECTORY / "ci.yml"


def workflow_text():
    return WORKFLOW.read_text()


def job_blocks():
    jobs = workflow_text().split("\njobs:\n", 1)[1]
    pieces = re.split(r"(?m)^  ([a-z-]+):\n", jobs)
    return dict(zip(pieces[1::2], pieces[2::2]))


def deployment_target():
    shared = (REPOSITORY / "Configs" / "Shared.xcconfig").read_text()
    return re.search(r"^MACOSX_DEPLOYMENT_TARGET = (\S+)$", shared, re.MULTILINE).group(1)


class TriggerTests(unittest.TestCase):
    def test_runs_on_pull_requests_to_main(self):
        self.assertRegex(workflow_text(), r"(?m)^on:\n  pull_request:\n    branches: \[main\]$")

    def test_never_runs_a_fork_with_the_base_repository_token(self):
        self.assertNotIn("pull_request_target", workflow_text())

    def test_the_token_can_only_read(self):
        self.assertRegex(workflow_text(), r"(?m)^permissions:\n  contents: read$")


class RunnerTests(unittest.TestCase):
    def test_has_the_five_jobs(self):
        self.assertEqual(set(job_blocks()), {"lint", "package-tests", "app-build", "ios-packages", "app-tests"})

    def test_every_job_uses_the_hosted_image(self):
        for name, block in job_blocks().items():
            with self.subTest(job=name):
                self.assertIn("runs-on: xcode-27\n", block)

    def test_every_job_has_a_timeout(self):
        for name, block in job_blocks().items():
            with self.subTest(job=name):
                self.assertRegex(block, r"timeout-minutes: \d+")

    def test_xcode_is_pinned_for_the_whole_workflow(self):
        self.assertRegex(
            workflow_text(),
            r"(?m)^env:\n  DEVELOPER_DIR: /Applications/Xcode_27\.2\.app/Contents/Developer$",
        )

    def test_no_workflow_needs_a_secret_or_a_self_hosted_runner(self):
        for workflow in WORKFLOW_DIRECTORY.glob("*.y*ml"):
            with self.subTest(workflow=workflow.name):
                text = workflow.read_text()
                self.assertNotIn("self-hosted", text)
                self.assertNotIn("secrets.", text)


class JobCommandTests(unittest.TestCase):
    def test_each_job_runs_its_target(self):
        expected = {
            "lint": "make lint",
            "package-tests": "make test-packages",
            "app-build": "make build-for-testing",
            "ios-packages": "make build-packages-ios",
            "app-tests": "Scripts/ci-app-tests.sh",
        }
        for name, command in expected.items():
            with self.subTest(job=name):
                self.assertRegex(job_blocks()[name], rf"run: {re.escape(command)}\n")

    def test_ui_tests_never_run(self):
        self.assertNotIn("test-ui", workflow_text())
        self.assertNotIn("test-all", workflow_text())

    def test_the_app_tests_job_name_carries_the_deployment_target(self):
        self.assertIn(f"name: App tests (not run below macOS {deployment_target()})\n", job_blocks()["app-tests"])

    def test_every_action_is_pinned_to_a_commit(self):
        uses = re.findall(r"uses: (\S+)", workflow_text())
        self.assertTrue(uses)
        for action in uses:
            with self.subTest(action=action):
                self.assertRegex(action, r"@[0-9a-f]{40}$")


class LintToolTests(unittest.TestCase):
    def test_both_tools_are_pinned_to_a_version_and_a_checksum(self):
        for tool in ("SWIFTLINT", "SWIFTFORMAT"):
            with self.subTest(tool=tool):
                self.assertRegex(workflow_text(), rf"(?m)^  {tool}_VERSION: \d+\.\d+\.\d+$")
                self.assertRegex(workflow_text(), rf"(?m)^  {tool}_SHA256: [0-9a-f]{{64}}$")

    def test_the_download_is_verified_before_it_is_unpacked(self):
        lint = job_blocks()["lint"]
        self.assertLess(lint.index("shasum -a 256 -c"), lint.index("unzip"))

    def test_the_pinned_tools_go_ahead_of_the_images_own(self):
        self.assertIn('>> "$GITHUB_PATH"', job_blocks()["lint"])


if __name__ == "__main__":
    unittest.main()
