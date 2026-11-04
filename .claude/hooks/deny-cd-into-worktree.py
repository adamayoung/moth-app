#!/usr/bin/env python3
"""PreToolUse hook on Bash: refuse a top-level `cd`/`pushd` into a worktree.

The Bash tool's working directory persists, so one `cd "$WT" && …` from a
session in the main checkout moves that whole session into the worktree.
A session already inside a worktree, a `( cd … )` or `$( cd … )` subshell,
and text that only mentions `cd` (quoted strings, heredoc bodies) are allowed.
"""

import json
import re
import shlex
import sys

# `<<<` is a here-string and `$((1<<2))` a shift; neither starts a body.
HEREDOC = re.compile(r"(?<!<)<<(?!<)-?\s*(['\"]?)([A-Za-z_]\w*)\1")
ARITHMETIC = re.compile(r"\$\(\(.*?\)\)")
# A variable or substitution target is resolved only at run time, so a name
# that reads as a worktree ($WT, $wt, $WORKTREE, $(git worktree …)) counts.
WORKTREE_NAME = re.compile(r"wt|worktree", re.IGNORECASE)
PUNCTUATION = set(";&|()<>")
SEPARATORS = set(";&|(")
COMMAND_PREFIXES = {
    "{", "!", "if", "then", "do", "else", "elif", "while", "until", "time",
    "builtin", "command",
}


def strip_heredoc_bodies(command):
    kept, delimiter = [], None
    for line in ARITHMETIC.sub("0", command).split("\n"):
        if delimiter is not None:
            if line.strip() == delimiter:
                delimiter = None
            continue
        kept.append(line)
        match = HEREDOC.search(line)
        if match:
            delimiter = match.group(2)
    return " ; ".join(kept)


def tokens(command):
    lexer = shlex.shlex(command, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    lexer.commenters = ""
    try:
        return list(lexer)
    except ValueError:
        return command.split()


def is_punctuation(word):
    return bool(word) and set(word) <= PUNCTUATION


def cd_target(words):
    """The target of a cd, ending where its command ends; an unquoted
    `$( … )` runs on to its closing parenthesis."""
    for index, word in enumerate(words):
        if is_punctuation(word):
            return ""
        if word.startswith("-"):
            continue
        rest = words[index + 1:]
        if not (word.endswith("$") and rest and rest[0].startswith("(")):
            return word
        target, depth = [word], 0
        for part in rest:
            target.append(part)
            depth += part.count("(") - part.count(")")
            if depth <= 0:
                break
        return " ".join(target)
    return ""


def targets_worktree(target):
    if ".claude/worktrees" in target:
        return True
    return "$" in target and bool(WORKTREE_NAME.search(target))


def top_level_cd_into_worktree(command):
    words = tokens(strip_heredoc_bodies(command))
    depth, at_command_start = 0, True
    # The depth each open `case` started at: its `pattern)` closes nothing.
    case_depths = []
    for index, word in enumerate(words):
        if is_punctuation(word):
            at_command_start = bool(set(word) & SEPARATORS)
            for character in word:
                if character == "(":
                    depth += 1
                elif character == ")" and case_depths and depth == case_depths[-1]:
                    at_command_start = True
                elif character == ")":
                    depth -= 1
            continue
        if at_command_start and word == "case":
            case_depths.append(depth)
        elif at_command_start and word == "esac" and case_depths:
            case_depths.pop()
        if at_command_start and word in COMMAND_PREFIXES:
            continue
        if at_command_start and depth == 0 and word in ("cd", "pushd"):
            if targets_worktree(cd_target(words[index + 1:])):
                return True
        at_command_start = False
    return False


def main():
    payload = json.load(sys.stdin)
    if "/.claude/worktrees/" in payload.get("cwd", ""):
        return 0
    command = payload.get("tool_input", {}).get("command", "")
    if top_level_cd_into_worktree(command):
        print(
            "Do not cd into a worktree from this session: the Bash working "
            "directory persists, so the whole session moves there. Use git -C, "
            'make -C, absolute paths, or a ( cd "$WT" && … ) subshell.',
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
