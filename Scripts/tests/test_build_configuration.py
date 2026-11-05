"""Tests for the build settings the project resolves to, read from xcodebuild, and
for the files under Configs/.

Run with: python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
"""

from functools import lru_cache
import json
from pathlib import Path
import plistlib
import re
import subprocess
import unittest


REPOSITORY = Path(__file__).resolve().parent.parent.parent
CONFIGS = REPOSITORY / "Configs"
PROJECT_FILE = REPOSITORY / "Moth.xcodeproj" / "project.xcproj"
TEST_PLANS = REPOSITORY / "TestPlans"

PACKAGES = ("HTTPKit", "MothCore", "MothImport", "PostmanKit")
TARGETS = ("Moth", "MothTests", "MothUITests")
CONFIGURATIONS = ("Debug", "Release")
EXAMPLE_CONTAINER = "iCloud.example.Moth"


@lru_cache(maxsize=None)
def build_settings(target, configuration, *overrides):
    output = subprocess.run(
        [
            "xcodebuild",
            "-project",
            str(REPOSITORY / "Moth.xcodeproj"),
            "-target",
            target,
            "-configuration",
            configuration,
            "-showBuildSettings",
            *overrides,
        ],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    settings = dict(re.findall(r"^\s+(\w+) = (.*)$", output, re.MULTILINE))
    if not settings:
        raise AssertionError(f"xcodebuild reported no settings for {target} {configuration}")
    return settings


def app_target_section():
    section = re.search(r'"name": "Moth",.*?(?="name": "MothTests")', PROJECT_FILE.read_text(), re.DOTALL)
    if section is None:
        raise AssertionError("found no Moth target before MothTests in the project file")
    return section.group(0)


def app_settings(*overrides):
    return build_settings("Moth", "Debug", *overrides)


class LanguageModeTests(unittest.TestCase):
    def test_every_target_builds_in_swift_6_in_both_configurations(self):
        for target in TARGETS:
            for configuration in CONFIGURATIONS:
                with self.subTest(target=target, configuration=configuration):
                    self.assertEqual(build_settings(target, configuration).get("SWIFT_VERSION"), "6.0")

    def test_warnings_are_errors_in_both_configurations(self):
        for target in TARGETS:
            for configuration in CONFIGURATIONS:
                with self.subTest(target=target, configuration=configuration):
                    settings = build_settings(target, configuration)
                    self.assertEqual(settings.get("SWIFT_TREAT_WARNINGS_AS_ERRORS"), "YES")
                    self.assertEqual(settings.get("GCC_TREAT_WARNINGS_AS_ERRORS"), "YES")

    def test_the_app_target_defaults_to_the_main_actor(self):
        self.assertEqual(app_settings().get("SWIFT_DEFAULT_ACTOR_ISOLATION"), "MainActor")


class ConfigurationFileTests(unittest.TestCase):
    def test_the_project_has_only_debug_and_release_each_from_its_xcconfig(self):
        listing = subprocess.run(
            ["xcodebuild", "-project", str(REPOSITORY / "Moth.xcodeproj"), "-list", "-json"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        self.assertEqual(sorted(json.loads(listing)["project"]["configurations"]), list(CONFIGURATIONS))

        project = PROJECT_FILE.read_text()
        for configuration in CONFIGURATIONS:
            with self.subTest(configuration=configuration):
                self.assertIn(f'{{ "name": "{configuration}", "file": "Configs/{configuration}.xcconfig" }}', project)

    def test_each_configuration_ends_by_optionally_including_the_local_xcconfig(self):
        for configuration in CONFIGURATIONS:
            with self.subTest(configuration=configuration):
                lines = (CONFIGS / f"{configuration}.xcconfig").read_text().strip().splitlines()
                self.assertEqual(lines[-1], '#include? "Local.xcconfig"')

    def test_the_local_xcconfig_is_gitignored(self):
        ignored = subprocess.run(
            ["git", "-C", str(REPOSITORY), "check-ignore", "--no-index", "--quiet", "Configs/Local.xcconfig"]
        )
        self.assertEqual(ignored.returncode, 0)

    def test_the_example_shows_a_team_and_a_container(self):
        example = (CONFIGS / "Local.xcconfig.example").read_text()
        self.assertRegex(example, r"(?m)^DEVELOPMENT_TEAM = \S+$")
        self.assertRegex(example, r"(?m)^MOTH_ICLOUD_CONTAINER = iCloud\.\S+$")

    def test_the_project_holds_no_team(self):
        self.assertNotIn("DEVELOPMENT_TEAM", PROJECT_FILE.read_text())

    def test_configs_is_outside_every_target(self):
        project = PROJECT_FILE.read_text()
        entry = re.search(r'\{\s*"kind": "\w+",\s*"path": "Configs".*?\],\s*\}', project, re.DOTALL)
        self.assertIsNotNone(entry)
        self.assertIn('"kind": "group"', entry.group(0))
        self.assertNotIn("target-membership", entry.group(0))


class PackageIntegrationTests(unittest.TestCase):
    def test_packages_is_a_folder_outside_every_target(self):
        self.assertRegex(PROJECT_FILE.read_text(), r'\{ "kind": "folder", "path": "Packages" \}')

    # With the packages in the project's `packages` array, make test passed and ran none of their tests.
    def test_no_package_is_a_dependency_reference(self):
        self.assertNotIn('"packages"', PROJECT_FILE.read_text())

    def test_the_app_section_stops_before_the_test_targets(self):
        self.assertIn('"id": "66385399309BDC9600B9519C"', app_target_section())
        self.assertNotIn("663853A8309BDC9700B9519C", app_target_section())

    def test_the_app_links_only_the_packages_the_boundaries_table_allows(self):
        linked = re.findall(r'"product-name": "(\w+)"', app_target_section())
        self.assertEqual(sorted(linked), ["HTTPKit", "MothCore", "MothImport"])

    def test_the_unit_plan_runs_every_package_s_tests(self):
        plan = json.loads((TEST_PLANS / "UnitTests.xctestplan").read_text())
        containers = {
            entry["target"]["containerPath"]: entry["target"]["name"] for entry in plan["testTargets"]
        }
        for package in PACKAGES:
            with self.subTest(package=package):
                self.assertEqual(containers.get(f"container:Packages/{package}"), f"{package}Tests")


class EntitlementTests(unittest.TestCase):
    def test_no_container_means_no_entitlements_file(self):
        self.assertEqual(app_settings("MOTH_ICLOUD_CONTAINER=").get("CODE_SIGN_ENTITLEMENTS", ""), "")

    def test_a_container_applies_the_icloud_entitlements(self):
        settings = app_settings(f"MOTH_ICLOUD_CONTAINER={EXAMPLE_CONTAINER}")
        self.assertEqual(settings.get("CODE_SIGN_ENTITLEMENTS"), "Configs/MothICloud.entitlements")

    def test_the_test_targets_never_take_the_icloud_entitlements(self):
        for target in ("MothTests", "MothUITests"):
            with self.subTest(target=target):
                settings = build_settings(target, "Debug", f"MOTH_ICLOUD_CONTAINER={EXAMPLE_CONTAINER}")
                self.assertEqual(settings.get("CODE_SIGN_ENTITLEMENTS", ""), "")

    def test_the_icloud_entitlements_cover_cloudkit_push_and_the_keychain(self):
        with (CONFIGS / "MothICloud.entitlements").open("rb") as file:
            entitlements = plistlib.load(file)

        self.assertEqual(
            entitlements,
            {
                "com.apple.developer.aps-environment": "development",
                "com.apple.developer.icloud-container-identifiers": ["$(MOTH_ICLOUD_CONTAINER)"],
                "com.apple.developer.icloud-services": ["CloudKit"],
                "keychain-access-groups": ["$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)"],
            },
        )

    def test_the_app_is_sandboxed_with_outgoing_connections_only(self):
        settings = app_settings()
        self.assertEqual(settings.get("ENABLE_APP_SANDBOX"), "YES")
        self.assertEqual(settings.get("ENABLE_OUTGOING_NETWORK_CONNECTIONS"), "YES")
        self.assertEqual(settings.get("ENABLE_INCOMING_NETWORK_CONNECTIONS"), "NO")


class LocalisationTests(unittest.TestCase):
    def test_the_development_language_is_british_english(self):
        self.assertEqual(app_settings().get("DEVELOPMENT_LANGUAGE"), "en-GB")


if __name__ == "__main__":
    unittest.main()
