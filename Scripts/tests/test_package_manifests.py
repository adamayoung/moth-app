"""Tests for the local packages' manifests and imports, against the Module Boundaries
table in docs/architecture.md.

Run with: python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
"""

from functools import lru_cache
import json
from pathlib import Path
import re
import subprocess
import unittest


REPOSITORY = Path(__file__).resolve().parent.parent.parent
PACKAGES = REPOSITORY / "Packages"

ALLOWED_DEPENDENCIES = {
    "HTTPKit": set(),
    "MothCore": {"HTTPKit"},
    "MothImport": {"MothCore", "PostmanKit"},
    "PostmanKit": set(),
}
MAIN_ACTOR_PACKAGES = {"MothCore", "MothImport"}
UPCOMING_FEATURES = {
    "ApproachableConcurrency",
    "InferIsolatedConformances",
    "NonisolatedNonsendingByDefault",
}
APP_DEPENDENCIES = {"HTTPKit", "MothCore", "MothImport"}
UI_MODULES = {"SwiftUI", "AppKit"}
IMPORT = re.compile(
    r"^[ \t]*(?:@\w+[ \t]+)*(?:(?:public|package|internal|fileprivate|private)[ \t]+)?import[ \t]+"
    r"(?:(?:class|enum|func|let|protocol|struct|typealias|var)[ \t]+)?(\w+)",
    re.MULTILINE,
)


@lru_cache(maxsize=None)
def manifest(package):
    output = subprocess.run(
        ["swift", "package", "dump-package", "--package-path", str(PACKAGES / package)],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return json.loads(output)


def declared_dependencies(package):
    return {Path(entry["fileSystem"][0]["path"]).name for entry in manifest(package)["dependencies"]}


def target(package, name):
    return next(entry for entry in manifest(package)["targets"] if entry["name"] == name)


def targets(package):
    return manifest(package)["targets"]


def setting_values(package_target, kind):
    return {
        setting["kind"][kind]["_0"]
        for setting in package_target["settings"]
        if kind in setting["kind"]
    }


class PackageListTests(unittest.TestCase):
    def test_the_four_packages_exist(self):
        found = {path.parent.name for path in PACKAGES.glob("*/Package.swift")}
        self.assertEqual(found, set(ALLOWED_DEPENDENCIES))

    def test_each_package_has_a_library_and_a_test_target(self):
        for package in ALLOWED_DEPENDENCIES:
            with self.subTest(package=package):
                self.assertEqual(
                    {entry["name"]: entry["type"] for entry in targets(package)},
                    {package: "regular", f"{package}Tests": "test"},
                )


class DependencyTests(unittest.TestCase):
    def test_each_package_declares_only_the_table_s_dependencies(self):
        for package, allowed in ALLOWED_DEPENDENCIES.items():
            with self.subTest(package=package):
                self.assertEqual(declared_dependencies(package), allowed)

    def test_each_library_target_uses_only_the_table_s_dependencies(self):
        for package, allowed in ALLOWED_DEPENDENCIES.items():
            with self.subTest(package=package):
                names = {entry["byName"][0] for entry in target(package, package)["dependencies"]}
                self.assertEqual(names, allowed)


class SettingsTests(unittest.TestCase):
    def test_each_package_uses_tools_6_4(self):
        for package in ALLOWED_DEPENDENCIES:
            with self.subTest(package=package):
                self.assertEqual(manifest(package)["toolsVersion"]["_version"], "6.4.0")

    def test_each_package_defaults_to_british_english(self):
        for package in ALLOWED_DEPENDENCIES:
            with self.subTest(package=package):
                self.assertEqual(manifest(package)["defaultLocalization"], "en-GB")

    def test_each_package_declares_macos_and_ios_27_2(self):
        for package in ALLOWED_DEPENDENCIES:
            with self.subTest(package=package):
                platforms = {
                    entry["platformName"]: entry["version"] for entry in manifest(package)["platforms"]
                }
                self.assertEqual(platforms, {"macos": "27.2", "ios": "27.2"})

    def test_every_target_enables_the_upcoming_features(self):
        for package in ALLOWED_DEPENDENCIES:
            for entry in targets(package):
                with self.subTest(target=entry["name"]):
                    self.assertEqual(setting_values(entry, "enableUpcomingFeature"), UPCOMING_FEATURES)

    def test_every_target_treats_warnings_as_errors(self):
        for package in ALLOWED_DEPENDENCIES:
            for entry in targets(package):
                with self.subTest(target=entry["name"]):
                    self.assertEqual(setting_values(entry, "treatAllWarnings"), {"error"})

    def test_only_mothcore_and_mothimport_default_to_the_main_actor(self):
        for package in ALLOWED_DEPENDENCIES:
            expected = {"MainActor"} if package in MAIN_ACTOR_PACKAGES else set()
            for entry in targets(package):
                with self.subTest(target=entry["name"]):
                    self.assertEqual(setting_values(entry, "defaultIsolation"), expected)


def imports(text):
    return set(IMPORT.findall(text))


def swift_files(directory):
    return [path for path in directory.glob("**/*.swift") if ".build" not in path.parts]


class ImportTests(unittest.TestCase):
    def test_the_import_pattern_reads_the_forms_swift_allows(self):
        forms = {
            "import SwiftUI": "SwiftUI",
            "@testable import AppKit": "AppKit",
            "import struct SwiftUI.Color": "SwiftUI",
            "public import HTTPKit": "HTTPKit",
            "@preconcurrency internal import PostmanKit": "PostmanKit",
        }
        for line, module in forms.items():
            with self.subTest(line=line):
                self.assertEqual(imports(line), {module})

    def test_no_package_imports_swiftui_or_appkit(self):
        sources = swift_files(PACKAGES)
        self.assertTrue(sources, "found no package sources to check")
        for path in sources:
            with self.subTest(path=path.relative_to(REPOSITORY)):
                self.assertFalse(imports(path.read_text()) & UI_MODULES)

    # SwiftPM compiles an import of a transitive dependency, even with
    # --explicit-target-dependency-import-check error, so the compiler alone cannot hold the table.
    def test_each_library_imports_only_the_table_s_dependencies(self):
        for package, allowed in ALLOWED_DEPENDENCIES.items():
            for path in swift_files(PACKAGES / package / "Sources"):
                with self.subTest(path=path.relative_to(REPOSITORY)):
                    local = imports(path.read_text()) & set(ALLOWED_DEPENDENCIES)
                    self.assertLessEqual(local, allowed)

    def test_the_app_imports_only_the_table_s_dependencies(self):
        sources = swift_files(REPOSITORY / "Moth")
        self.assertTrue(sources, "found no app sources to check")
        for path in sources:
            with self.subTest(path=path.relative_to(REPOSITORY)):
                local = imports(path.read_text()) & set(ALLOWED_DEPENDENCIES)
                self.assertLessEqual(local, APP_DEPENDENCIES)


if __name__ == "__main__":
    unittest.main()
