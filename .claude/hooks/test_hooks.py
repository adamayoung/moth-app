"""Tests for the project's PreToolUse hooks and Scripts/record-review.sh.

Run with: python3 -m unittest discover -s .claude/hooks -p 'test_*.py'
"""

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest


HOOKS = Path(__file__).parent
REPOSITORY = HOOKS.parent.parent
REVIEW_GATE = HOOKS / "require-review-before-push.py"
XCODE_GUARD = HOOKS / "xcode-worktree-guard.py"
XCODE_RECORDER = HOOKS / "record-xcode-workspaces.py"
RECORD_REVIEW = REPOSITORY / "Scripts" / "record-review.sh"
SETTINGS = REPOSITORY / ".claude" / "settings.json"

DENIED = 2
ALLOWED = 0


def run_hook(script, stdin):
    return subprocess.run(
        [str(script)], input=stdin, capture_output=True, text=True
    ).returncode


def git(*arguments):
    return subprocess.run(
        ["git", "-c", "user.name=Test", "-c", "user.email=test@example.com", *arguments],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()


def bash_payload(command, cwd):
    return json.dumps({"tool_name": "Bash", "tool_input": {"command": command}, "cwd": str(cwd)})


def mcp_payload(tool, tool_input, cwd):
    return json.dumps({"tool_name": tool, "tool_input": tool_input, "cwd": str(cwd)})


class RepositoryTestCase(unittest.TestCase):
    """A main checkout on `main` and a worktree on `feature/x` one commit ahead."""

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name).resolve()
        self.main_checkout = root / "repo"
        git("init", "-q", "-b", "main", str(self.main_checkout))
        git("-C", str(self.main_checkout), "commit", "-q", "--allow-empty", "-m", "initial")
        self.worktree = self.main_checkout / ".claude" / "worktrees" / "issue-1"
        git("-C", str(self.main_checkout), "worktree", "add", "-q", "-b", "feature/x", str(self.worktree))
        self.commit_in_worktree("feature work")
        self.outside_worktree = root / "elsewhere"
        git("-C", str(self.main_checkout), "worktree", "add", "-q", "-b", "elsewhere", str(self.outside_worktree))
        self.not_a_repository = root / "plain"
        self.not_a_repository.mkdir()

    def tearDown(self):
        self.directory.cleanup()

    def commit_in_worktree(self, message):
        git("-C", str(self.worktree), "commit", "-q", "--allow-empty", "-m", message)

    def record_review(self):
        result = subprocess.run([str(RECORD_REVIEW)], cwd=self.worktree, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


class ReviewGateTests(RepositoryTestCase):
    def pushes_from_the_worktree(self):
        return [
            "git push",
            "git push -u origin feature/x",
            "git push origin HEAD",
            "git push origin HEAD:feature/x",
            "git push --force-with-lease origin +feature/x",
            "git push -o ci.skip origin feature/x",
            "git -c core.sshCommand=ssh push",
            "git --no-pager push",
            "/usr/bin/git push",
            "GIT_TRACE=1 git push",
            "cd somewhere && git push",
            "bash -c 'git push'",
            'eval "git push origin feature/x"',
            "gh pr create --fill",
            "gh pr create --base main --head feature/x --body-file body.md",
            "gh -R adamayoung/moth-app pr create --head=feature/x",
            "gh pr create -H adamayoung:feature/x",
        ]

    def pushes_from_the_main_checkout(self):
        return [
            f"git -C {self.worktree} push -u origin feature/x",
            "git push origin feature/x",
            "gh pr create --head feature/x",
        ]

    def gate(self, command, cwd):
        return run_hook(REVIEW_GATE, bash_payload(command, cwd))

    def test_denies_an_unreviewed_branch_in_every_invocation_form(self):
        cases = [(command, self.worktree) for command in self.pushes_from_the_worktree()]
        cases += [(command, self.main_checkout) for command in self.pushes_from_the_main_checkout()]
        for command, cwd in cases:
            with self.subTest(command=command, cwd=cwd):
                self.assertEqual(self.gate(command, cwd), DENIED)

    def test_allows_the_same_commands_once_the_branch_is_reviewed(self):
        self.record_review()
        cases = [(command, self.worktree) for command in self.pushes_from_the_worktree()]
        cases += [(command, self.main_checkout) for command in self.pushes_from_the_main_checkout()]
        for command, cwd in cases:
            with self.subTest(command=command, cwd=cwd):
                self.assertEqual(self.gate(command, cwd), ALLOWED)

    def test_ignores_redirections_after_a_push(self):
        self.record_review()
        cases = [
            ("git push origin feature/x 2>&1 | tail -2", self.worktree),
            ("git push -u origin feature/x > /tmp/push.log 2>&1", self.worktree),
            ("git push origin main 2>&1 | tail -2", self.main_checkout),
            ("git push 2>/dev/null", self.main_checkout),
            ("git push origin main &>/tmp/push.log", self.main_checkout),
        ]
        for command, cwd in cases:
            with self.subTest(command=command):
                self.assertEqual(self.gate(command, cwd), ALLOWED)

    def test_denies_a_commit_made_after_the_review(self):
        self.record_review()
        self.commit_in_worktree("after the review")
        self.assertEqual(self.gate("git push -u origin feature/x", self.worktree), DENIED)

    def test_allows_pushes_to_main_and_deletions(self):
        cases = [
            ("git push", self.main_checkout),
            ("git push origin main", self.main_checkout),
            ("git push origin HEAD", self.main_checkout),
            ("git push origin HEAD:main", self.worktree),
            ("git push origin feature/x:refs/heads/main", self.main_checkout),
            ("git push origin --delete feature/x", self.main_checkout),
            ("git push origin :feature/x", self.main_checkout),
        ]
        for command, cwd in cases:
            with self.subTest(command=command, cwd=cwd):
                self.assertEqual(self.gate(command, cwd), ALLOWED)

    def test_denies_pushes_it_cannot_resolve(self):
        for command in [
            "git push --all origin",
            "git push --tags",
            "git push --mirror origin",
            'git -C "$WT" push',
            "git push origin $BRANCH",
            "git push origin no-such-branch",
            "git send-pack origin HEAD:refs/heads/feature/x",
            "gh pr create --head no-such-branch",
        ]:
            with self.subTest(command=command):
                self.assertEqual(self.gate(command, self.main_checkout), DENIED)

    def merge_main_into_the_branch(self, conflicting):
        (self.worktree / "file.txt").write_text("branch\n")
        git("-C", str(self.worktree), "add", "file.txt")
        self.commit_in_worktree("branch change")
        self.record_review()
        (self.main_checkout / ("file.txt" if conflicting else "other.txt")).write_text("main\n")
        git("-C", str(self.main_checkout), "add", ".")
        git("-C", str(self.main_checkout), "commit", "-q", "-m", "main moves on")
        git("-C", str(self.main_checkout), "update-ref", "refs/remotes/origin/main", "main")
        merge = subprocess.run(
            ["git", "-c", "user.name=Test", "-c", "user.email=test@example.com",
             "-C", str(self.worktree), "merge", "-q", "--no-edit", "origin/main"],
            capture_output=True,
        )
        if conflicting:
            self.assertNotEqual(merge.returncode, 0)
            (self.worktree / "file.txt").write_text("resolved\n")
            git("-C", str(self.worktree), "add", "file.txt")
            git("-C", str(self.worktree), "commit", "-q", "--no-edit")

    def test_allows_a_clean_merge_of_origin_main_into_a_reviewed_branch(self):
        self.merge_main_into_the_branch(conflicting=False)
        self.assertEqual(self.gate("git push origin feature/x", self.worktree), ALLOWED)

    def test_denies_a_merge_whose_conflict_resolution_is_unreviewed(self):
        self.merge_main_into_the_branch(conflicting=True)
        self.assertEqual(self.gate("git push origin feature/x", self.worktree), DENIED)

    def test_allows_git_commands_other_than_push_in_a_variable_directory(self):
        for command in ['git -C "$WT" status --short', "git -C $WT log --oneline -3"]:
            with self.subTest(command=command):
                self.assertEqual(self.gate(command, self.main_checkout), ALLOWED)

    def test_denies_creating_a_pull_request_through_gh_api(self):
        self.record_review()
        for command in [
            "gh api repos/adamayoung/moth-app/pulls -X POST -f head=feature/x",
            "gh api repos/adamayoung/moth-app/pulls -f title=t -f head=feature/x",
            "gh api --method=POST repos/adamayoung/moth-app/pulls/",
            "gh api graphql -f query='mutation { createPullRequest(input: {}) { clientMutationId } }'",
        ]:
            with self.subTest(command=command):
                self.assertEqual(self.gate(command, self.worktree), DENIED)

    def test_allows_everyday_commands_on_an_unreviewed_branch(self):
        for command in [
            "git status --short",
            "git fetch origin",
            "git switch --no-track -c feature/y origin/main",
            "git commit -F /tmp/scratch/commit-message.txt",
            "git stash push -m wip",
            "git log --oneline origin/main..HEAD",
            "gh issue view 42 --json title,body -q .body",
            "gh pr view 12 --json title",
            "gh pr merge 12 --squash",
            "gh pr edit 12 --body-file body.md",
            "gh api repos/adamayoung/moth-app/pulls/12",
            "gh api repos/adamayoung/moth-app/pulls -X GET -f state=open",
            "gh api repos/adamayoung/moth-app/pulls/12/comments -f body=thanks",
            "make test-ui TESTS=GitHubSignInTests UI_ALLOWANCE=short",
            "grep -rn push docs/",
            "git",
        ]:
            with self.subTest(command=command):
                self.assertEqual(self.gate(command, self.worktree), ALLOWED)

    def test_gates_the_github_mcp_tools_that_reach_a_branch(self):
        create = "mcp__github__create_pull_request"
        cases = [
            (create, {"head": "feature/x", "base": "main"}, DENIED),
            (create, {"base": "main"}, DENIED),
            ("mcp__github__push_files", {"branch": "feature/x", "files": []}, DENIED),
            ("mcp__github__create_or_update_file", {"branch": "feature/x"}, DENIED),
            ("mcp__github__delete_file", {}, DENIED),
            ("mcp__github__push_files", {"branch": "main", "files": []}, ALLOWED),
            ("mcp__github__add_issue_comment", {"issue_number": 1}, ALLOWED),
        ]
        for tool, tool_input, expected in cases:
            with self.subTest(tool=tool, tool_input=tool_input):
                self.assertEqual(run_hook(REVIEW_GATE, mcp_payload(tool, tool_input, self.worktree)), expected)
        self.record_review()
        reviewed = mcp_payload(create, {"head": "feature/x", "base": "main"}, self.main_checkout)
        self.assertEqual(run_hook(REVIEW_GATE, reviewed), ALLOWED)

    def test_denies_input_it_cannot_read(self):
        for stdin in [
            "",
            "not json: git push",
            json.dumps({"tool_name": "Bash", "tool_input": {"command": "git status"}}),
            json.dumps({"tool_name": "Bash", "tool_input": {"cmd": "git status"}, "cwd": "/"}),
            json.dumps({"tool_name": "Bash", "tool_input": {"command": ["git", "push"]}, "cwd": "/"}),
            json.dumps(["git push"]),
        ]:
            with self.subTest(stdin=stdin):
                self.assertEqual(run_hook(REVIEW_GATE, stdin), DENIED)

    def test_denies_a_push_when_git_cannot_run(self):
        result = subprocess.run(
            [sys.executable, str(REVIEW_GATE)],
            input=bash_payload("git push", self.worktree),
            capture_output=True,
            text=True,
            env={"PATH": self.directory.name},
        )
        self.assertEqual(result.returncode, DENIED)


class RecordReviewTests(RepositoryTestCase):
    def test_marks_head_in_the_shared_git_directory(self):
        self.record_review()
        head = git("-C", str(self.worktree), "rev-parse", "HEAD")
        self.assertTrue((self.main_checkout / ".git" / "moth-reviewed" / head).is_file())

    def test_refuses_while_tracked_changes_are_uncommitted(self):
        (self.worktree / "file.txt").write_text("one\n")
        git("-C", str(self.worktree), "add", "file.txt")
        result = subprocess.run([str(RECORD_REVIEW)], cwd=self.worktree, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.main_checkout / ".git" / "moth-reviewed").exists())


def xcode_payload(cwd, tool="XcodeWrite", **tool_input):
    return json.dumps({"tool_name": f"mcp__xcode__{tool}", "tool_input": tool_input, "cwd": str(cwd)})


def recorder_payload(cwd, tool, tool_response):
    return json.dumps({
        "tool_name": f"mcp__xcode__{tool}",
        "tool_input": {},
        "tool_response": tool_response,
        "cwd": str(cwd),
    })


class XcodeWorkspaceTestCase(RepositoryTestCase):
    def record(self, tool, tool_response, cwd=None):
        result = subprocess.run(
            [str(XCODE_RECORDER)],
            input=recorder_payload(cwd or self.worktree, tool, tool_response),
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def open_workspace(self, identifier, project_directory):
        response = {"workspaceIdentifier": identifier, "workspacePath": str(project_directory / "Moth.xcodeproj")}
        self.record("XcodeOpenWorkspace", json.dumps(response))

    def guard(self, cwd, tool="RenderPreview", **tool_input):
        return run_hook(XCODE_GUARD, xcode_payload(cwd, tool, **tool_input))


class XcodeGuardTests(XcodeWorkspaceTestCase):
    def test_allows_every_call_from_a_main_checkout_or_outside_any_repository(self):
        for cwd in [self.main_checkout, self.not_a_repository]:
            for tool_input in [{}, {"workspaceIdentifier": "windowtab-main"}]:
                with self.subTest(cwd=cwd, tool_input=tool_input):
                    self.assertEqual(self.guard(cwd, **tool_input), ALLOWED)

    def test_allows_a_worktree_its_own_workspace(self):
        self.open_workspace("workspace-mine", self.worktree)
        for cwd in [self.worktree, self.worktree / "sub"]:
            cwd.mkdir(exist_ok=True)
            for tool in ["RenderPreview", "XcodeWrite", "XcodeCloseWorkspace"]:
                with self.subTest(cwd=cwd, tool=tool):
                    self.assertEqual(self.guard(cwd, tool, workspaceIdentifier="workspace-mine"), ALLOWED)

    def test_denies_a_worktree_any_other_workspace(self):
        self.open_workspace("workspace-theirs", self.outside_worktree)
        self.record("XcodeListWorkspaces", json.dumps({"message": (
            f"* workspaceIdentifier: windowtab-main, workspacePath: {self.main_checkout}/Moth.xcodeproj"
        )}))
        for tool_input in [
            {},
            {"workspaceIdentifier": "windowtab-main"},
            {"workspaceIdentifier": "windowtab-never-listed"},
            {"workspaceIdentifier": "workspace-theirs"},
            {"workspaceIdentifier": "workspace-never-recorded"},
            {"workspaceIdentifier": str(self.worktree / "Moth.xcodeproj")},
        ]:
            with self.subTest(tool_input=tool_input):
                self.assertEqual(self.guard(self.worktree, **tool_input), DENIED)

    def test_opening_a_project_is_allowed_only_inside_the_worktree(self):
        cases = [
            (self.worktree / "Moth.xcodeproj", ALLOWED),
            (self.main_checkout / "Moth.xcodeproj", DENIED),
            (self.outside_worktree / "Moth.xcodeproj", DENIED),
            (self.worktree / ".." / ".." / ".." / "Moth.xcodeproj", DENIED),
        ]
        for path, expected in cases:
            with self.subTest(path=path):
                self.assertEqual(self.guard(self.worktree, "XcodeOpenWorkspace", path=str(path)), expected)
        self.assertEqual(self.guard(self.worktree, "XcodeOpenWorkspace"), DENIED)

    def test_allows_the_calls_that_name_no_workspace(self):
        for tool in ["XcodeListWorkspaces", "DocumentationSearch"]:
            with self.subTest(tool=tool):
                self.assertEqual(self.guard(self.worktree, tool), ALLOWED)

    def test_denies_input_it_cannot_read(self):
        for stdin in [
            "",
            "{oops",
            json.dumps({"tool_input": {}, "working_directory": str(self.main_checkout)}),
            json.dumps({"cwd": None}),
        ]:
            with self.subTest(stdin=stdin):
                self.assertEqual(run_hook(XCODE_GUARD, stdin), DENIED)

    def test_denies_when_git_cannot_run(self):
        result = subprocess.run(
            [sys.executable, str(XCODE_GUARD)],
            input=xcode_payload(self.main_checkout),
            capture_output=True,
            text=True,
            env={"PATH": self.directory.name},
        )
        self.assertEqual(result.returncode, DENIED)


class XcodeRecorderTests(XcodeWorkspaceTestCase):
    def test_records_every_response_shape_the_xcode_tools_return(self):
        listed = (
            f"* workspaceIdentifier: workspace-listed, workspacePath: {self.worktree}/Moth.xcodeproj\n"
            f"* workspaceIdentifier: windowtab-main, workspacePath: {self.main_checkout}/Moth.xcodeproj"
        )
        opened = {"activeScheme": "Moth", "workspaceIdentifier": "workspace-opened",
                  "workspacePath": f"{self.worktree}/Moth.xcodeproj"}
        self.record("XcodeListWorkspaces", json.dumps({"message": listed}))
        self.record("XcodeOpenWorkspace", [{"type": "text", "text": json.dumps(opened)}])
        for identifier in ["workspace-listed", "workspace-opened"]:
            with self.subTest(identifier=identifier):
                self.assertEqual(self.guard(self.worktree, workspaceIdentifier=identifier), ALLOWED)
        self.assertEqual(self.guard(self.worktree, workspaceIdentifier="windowtab-main"), DENIED)

    def test_never_fails_the_tool_call(self):
        for stdin in ["", "{oops", recorder_payload(self.not_a_repository, "XcodeOpenWorkspace", "{}")]:
            with self.subTest(stdin=stdin):
                result = subprocess.run([str(XCODE_RECORDER)], input=stdin, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0)


def settings_hooks(event):
    """(matcher, command) pairs from the project settings, in order."""
    entries = json.loads(SETTINGS.read_text())["hooks"][event]
    return [(entry["matcher"], hook["command"]) for entry in entries for hook in entry["hooks"]]


def pre_tool_use_hooks():
    return settings_hooks("PreToolUse")


def hook_command(script_name, event="PreToolUse"):
    return next((matcher, command) for matcher, command in settings_hooks(event) if script_name in command)


def run_settings_command(command, stdin, project_dir):
    return subprocess.run(
        ["/bin/sh", "-c", command],
        input=stdin,
        capture_output=True,
        text=True,
        env={"PATH": "/usr/bin:/bin", "CLAUDE_PROJECT_DIR": str(project_dir)},
    ).returncode


def matching_tools(script_name, tools, event="PreToolUse"):
    matcher = hook_command(script_name, event)[0]
    return [tool for tool in tools if re.search(matcher, tool)]


class SettingsTests(RepositoryTestCase):
    def test_review_gate_sees_bash_and_the_github_tools_that_reach_a_branch(self):
        gated = [
            "Bash",
            "mcp__github__create_pull_request",
            "mcp__github__push_files",
            "mcp__github__create_or_update_file",
            "mcp__github__delete_file",
            "mcp__plugin_engineering_github__create_pull_request",
        ]
        ungated = [
            "mcp__github__merge_pull_request",
            "mcp__github__add_issue_comment",
            "mcp__github__pull_request_read",
            "mcp__xcode__XcodeWrite",
            "Read",
        ]
        self.assertEqual(matching_tools("require-review-before-push", gated + ungated), gated)

    def test_xcode_guard_sees_only_the_xcode_tools(self):
        tools = ["mcp__xcode__XcodeWrite", "mcp__xcode-tools__RenderPreview", "Bash", "mcp__github__push_files"]
        self.assertEqual(matching_tools("xcode-worktree-guard", tools), tools[:2])

    def test_recorder_sees_the_tools_that_report_workspace_identifiers(self):
        tools = [
            "mcp__xcode__XcodeOpenWorkspace",
            "mcp__xcode__XcodeListWorkspaces",
            "mcp__xcode-tools__XcodeOpenWorkspace",
            "mcp__xcode__XcodeWrite",
            "Write",
        ]
        self.assertEqual(matching_tools("record-xcode-workspaces", tools, "PostToolUse"), tools[:3])

    def test_review_gate_command_runs_the_script_and_refuses_when_it_is_missing(self):
        command = hook_command("require-review-before-push")[1]
        with tempfile.TemporaryDirectory() as empty:
            cases = [
                (bash_payload("git push", self.worktree), REPOSITORY, DENIED),
                (bash_payload("git status", self.worktree), REPOSITORY, ALLOWED),
                (bash_payload("git status", self.worktree), empty, DENIED),
            ]
            for stdin, project_dir, expected in cases:
                with self.subTest(stdin=stdin, project_dir=project_dir):
                    self.assertEqual(run_settings_command(command, stdin, project_dir), expected)

    def test_xcode_guard_command_runs_the_script_and_refuses_when_it_is_missing(self):
        command = hook_command("xcode-worktree-guard")[1]
        with tempfile.TemporaryDirectory() as empty:
            cases = [
                (xcode_payload(self.worktree, workspaceIdentifier="windowtab-main"), REPOSITORY, DENIED),
                (xcode_payload(self.main_checkout), REPOSITORY, ALLOWED),
                (xcode_payload(self.main_checkout), empty, DENIED),
            ]
            for stdin, project_dir, expected in cases:
                with self.subTest(stdin=stdin, project_dir=project_dir):
                    self.assertEqual(run_settings_command(command, stdin, project_dir), expected)


if __name__ == "__main__":
    unittest.main()
