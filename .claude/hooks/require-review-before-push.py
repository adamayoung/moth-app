#!/usr/bin/env python3
"""PreToolUse hook on Bash and the GitHub MCP: let a branch other than `main`
reach GitHub only once its commit has been reviewed.

`Scripts/record-review.sh` writes the marker after the review's fixes are
committed, so a commit made after the review needs another review, except a
merge of `origin/main` that git resolved without help. Pushes to `main`,
branch deletions and pull request merges pass. Prose that quotes a push in an
argument is checked too; pass prose through a file.
"""

import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys

MAIN_BRANCH = "main"
MARKER_DIRECTORY = "moth-reviewed"
MAIN_REMOTE_REF = "refs/remotes/origin/main"
GIT_OPTIONS_TAKING_A_VALUE = {
    "-C", "-c", "--git-dir", "--work-tree", "--namespace", "--super-prefix",
    "--config-env",
}
PUSH_OPTIONS_TAKING_A_VALUE = {"-o", "--push-option", "--repo", "--receive-pack", "--exec"}
PUSH_OPTIONS_PUSHING_UNNAMED_REFS = {"--all", "--branches", "--mirror", "--tags", "--follow-tags"}
PUSH_OPTIONS_DELETING = {"-d", "--delete"}
GH_OPTIONS_TAKING_A_VALUE = {"-R", "--repo", "--hostname"}
GH_PR_CREATE_HEAD_OPTIONS = ("-H", "--head")
GH_FIELD_FLAGS = {"-f", "-F", "--field", "--raw-field", "--input"}
PULL_REQUEST_COLLECTION = re.compile(r"(^|/)pulls/?$")
GITHUB_MCP_BRANCH_WRITES = {"push_files", "create_or_update_file", "delete_file"}
SHELL_PUNCTUATION = set(";&|()")
REDIRECTION_CHARACTERS = set("<>&")


class Refusal(Exception):
    pass


def shell_words(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        words = list(lexer)
    except ValueError:
        words = command.split()
    words = [word.strip("`") for word in words]
    # A quoted argument can itself be a command: `bash -c 'git push'`.
    nested = [inner for word in words if " " in word for inner in shell_words(word)]
    return words + nested


def is_redirection(word):
    return set(word) <= REDIRECTION_CHARACTERS and bool(set(word) & set("<>"))


def arguments_of(words, command_index):
    arguments, index = [], command_index + 1
    while index < len(words):
        word = words[index]
        following = words[index + 1] if index + 1 < len(words) else ""
        if is_redirection(word):
            index += 2
        elif set(word) <= SHELL_PUNCTUATION:
            break
        elif word.isdigit() and is_redirection(following):
            index += 1
        else:
            arguments.append(word)
            index += 1
    return arguments


def option_value(arguments, index):
    name, equals, value = arguments[index].partition("=")
    if equals:
        return value, index + 1
    following = arguments[index + 1] if index + 1 < len(arguments) else ""
    return following, index + 2


def git(directory, *arguments):
    try:
        result = subprocess.run(["git", "-C", directory, *arguments], capture_output=True, text=True)
    except OSError:
        raise Refusal("git could not be run to check the review marker")
    return result.stdout.strip() if result.returncode == 0 else None


def resolvable(text, what):
    if "$" in text or "`" in text:
        raise Refusal(f"the {what} {text!r} is only known at run time; spell it out")
    return text


def is_clean_merge_of_main(directory, commit):
    parents = (git(directory, "rev-list", "--parents", "-n", "1", commit) or "").split()[1:]
    if len(parents) != 2:
        return None
    merged_from_main = git(directory, "merge-base", "--is-ancestor", parents[1], MAIN_REMOTE_REF) is not None
    # --cc prints a hunk only where the result differs from every parent,
    # which is what a hand-resolved conflict is.
    resolution = git(directory, "diff-tree", "--cc", "--no-commit-id", commit)
    return parents[0] if merged_from_main and resolution == "" else None


def has_marker(directory, commit, markers):
    while not (markers / commit).is_file():
        commit = is_clean_merge_of_main(directory, commit)
        if commit is None:
            return False
    return True


def reviewed(directory, revision):
    commit = git(directory, "rev-parse", "--verify", "--quiet", f"{revision}^{{commit}}")
    if commit is None:
        raise Refusal(f"{revision!r} is not a commit in {directory}")
    common = git(directory, "rev-parse", "--path-format=absolute", "--git-common-dir")
    if common is None:
        raise Refusal(f"{directory} is not a git repository")
    if not has_marker(directory, commit, Path(common) / MARKER_DIRECTORY):
        raise Refusal(f"{revision} ({commit[:12]}) has no review marker")


def current_branch(directory):
    return git(directory, "symbolic-ref", "--quiet", "--short", "HEAD")


def branch_name(reference):
    return reference.removeprefix("refs/heads/")


def check_git_push(arguments, cwd):
    """`arguments` follow the `git` word: global options, then the subcommand."""
    directories, index = [], 0
    while index < len(arguments) and arguments[index].startswith("-"):
        name = arguments[index].partition("=")[0]
        if name in GIT_OPTIONS_TAKING_A_VALUE:
            value, index = option_value(arguments, index)
            if name == "-C":
                directories.append(value)
        else:
            index += 1
    if index >= len(arguments):
        return
    subcommand = arguments[index]
    if subcommand == "send-pack":
        raise Refusal("git send-pack bypasses the review gate; use git push")
    if subcommand != "push":
        return
    directory = cwd
    for value in directories:
        directory = os.path.join(directory, resolvable(value, "directory"))
    push_arguments, positional, index = arguments[index + 1:], [], 0
    while index < len(push_arguments):
        argument = push_arguments[index]
        name = argument.partition("=")[0]
        if name in PUSH_OPTIONS_DELETING:
            return
        if name in PUSH_OPTIONS_PUSHING_UNNAMED_REFS:
            raise Refusal(f"git push {name} pushes refs the gate cannot name")
        if argument.startswith("-"):
            index += 2 if argument in PUSH_OPTIONS_TAKING_A_VALUE else 1
            continue
        positional.append(argument)
        index += 1
    refspecs = positional[1:]
    if not refspecs:
        branch = current_branch(directory)
        if branch != MAIN_BRANCH:
            reviewed(directory, "HEAD")
        return
    for refspec in refspecs:
        source, colon, destination = resolvable(refspec.lstrip("+"), "refspec").partition(":")
        if colon and not source:
            continue
        target = branch_name(destination or source)
        if target == "HEAD":
            target = current_branch(directory)
        if target != MAIN_BRANCH:
            reviewed(directory, source)


def gh_subcommand(arguments):
    found, index = [], 0
    while index < len(arguments) and len(found) < 2:
        if arguments[index].startswith("-"):
            index += 2 if arguments[index] in GH_OPTIONS_TAKING_A_VALUE else 1
        else:
            found.append(arguments[index])
            index += 1
    return found


def creates_a_pull_request_through_the_api(arguments):
    if any("createPullRequest" in argument for argument in arguments):
        return True
    method, has_fields = None, False
    for index, argument in enumerate(arguments):
        name = argument.partition("=")[0]
        if name in ("-X", "--method"):
            method = option_value(arguments, index)[0].upper()
        elif argument.startswith("-X") and len(argument) > 2:
            method = argument[2:].upper()
        has_fields = has_fields or name in GH_FIELD_FLAGS
    # gh api switches to POST when given fields and no explicit method.
    method = method or ("POST" if has_fields else "GET")
    return method == "POST" and any(PULL_REQUEST_COLLECTION.search(argument) for argument in arguments)


def check_pull_request_head(head, cwd):
    branch = branch_name(head.rpartition(":")[2]) if head else current_branch(cwd)
    if branch is None:
        raise Refusal("the pull request's head branch could not be found")
    if branch != MAIN_BRANCH:
        reviewed(cwd, f"refs/heads/{resolvable(branch, 'branch')}")


def check_gh(arguments, cwd):
    subcommand = gh_subcommand(arguments)
    if subcommand[:1] == ["api"] and creates_a_pull_request_through_the_api(arguments):
        raise Refusal("open pull requests with gh pr create, which the gate can check")
    if subcommand == ["pr", "create"]:
        head = None
        for index, argument in enumerate(arguments):
            if argument.partition("=")[0] in GH_PR_CREATE_HEAD_OPTIONS:
                head = option_value(arguments, index)[0]
        check_pull_request_head(head, cwd)


def check_bash(command, cwd):
    words = shell_words(command)
    for index, word in enumerate(words):
        program = os.path.basename(word)
        if program == "git":
            check_git_push(arguments_of(words, index), cwd)
        elif program == "gh":
            check_gh(arguments_of(words, index), cwd)


def check_github_mcp(tool, tool_input, cwd):
    action = tool.rpartition("__")[2]
    if action == "create_pull_request":
        head = tool_input.get("head")
        if not isinstance(head, str) or not head:
            raise Refusal("create_pull_request has no head branch")
        check_pull_request_head(head, cwd)
    elif action in GITHUB_MCP_BRANCH_WRITES and tool_input.get("branch") != MAIN_BRANCH:
        raise Refusal(f"{action} commits to a branch on GitHub; commit locally and push with git")


def read_payload():
    try:
        payload = json.load(sys.stdin)
        tool, tool_input, cwd = payload["tool_name"], payload["tool_input"], payload["cwd"]
    except (ValueError, KeyError, TypeError):
        return None
    if not (isinstance(tool, str) and isinstance(tool_input, dict) and isinstance(cwd, str)):
        return None
    return tool, tool_input, cwd


def check(payload):
    tool, tool_input, cwd = payload
    if tool == "Bash":
        command = tool_input.get("command")
        if not isinstance(command, str):
            raise Refusal("tool_input.command is not a string")
        check_bash(command, cwd)
    elif tool.startswith("mcp__"):
        check_github_mcp(tool, tool_input, cwd)


def main():
    payload = read_payload()
    try:
        if payload is None:
            # Claude Code lets a call through on any exit but 2, so a hook
            # that cannot read its input must refuse rather than crash.
            raise Refusal("the hook input could not be read")
        check(payload)
    except Refusal as refusal:
        print(
            f"Review gate: {refusal}. A branch other than main reaches GitHub "
            "only after its review: commit the review's fixes, run "
            "Scripts/record-review.sh, then push. Quote a push in prose "
            "through a file, not an argument.",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
