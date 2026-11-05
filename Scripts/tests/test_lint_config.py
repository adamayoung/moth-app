"""Tests that .swiftformat and .swiftlint.yml agree, so neither tool moves code
the other then rejects.

Run with: python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
"""

from pathlib import Path
import re
import subprocess
import unittest


REPOSITORY = Path(__file__).resolve().parent.parent.parent


def swiftformat_same_line_attributes():
    match = re.search(r"^--non-complex-attributes (\S+)$", (REPOSITORY / ".swiftformat").read_text(), re.MULTILINE)
    return set(match.group(1).split(","))


def swiftlint_same_line_attributes():
    section = re.search(r"always_on_same_line:\n((?:    - .*\n)+)", (REPOSITORY / ".swiftlint.yml").read_text())
    return set(re.findall(r'"(@\w+)"', section.group(1))) - {"@testable"}


def swiftformat_test_case_name_formats():
    configs = subprocess.run(
        ["git", "ls-files", "*.swiftformat"], cwd=REPOSITORY, capture_output=True, text=True, check=True
    ).stdout.split()
    return {
        value
        for config in configs
        for value in re.findall(r"^--test-case-name-format (\S+)$", (REPOSITORY / config).read_text(), re.MULTILINE)
    }


class AttributePlacementTests(unittest.TestCase):
    def test_both_tools_keep_the_same_attributes_on_the_declaration_line(self):
        self.assertEqual(swiftformat_same_line_attributes(), swiftlint_same_line_attributes())


class TestCaseNameTests(unittest.TestCase):
    def test_every_swiftformat_config_preserves_test_case_names(self):
        self.assertEqual(swiftformat_test_case_name_formats(), {"preserve"})


if __name__ == "__main__":
    unittest.main()
