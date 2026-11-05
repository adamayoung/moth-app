"""Tests for Scripts/build-packages-ios.sh, which builds every package for iOS.

Run with: python3 -m unittest discover -s Scripts/tests -p 'test_*.py'
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


BUILD_PACKAGES_IOS = Path(__file__).resolve().parent.parent / "build-packages-ios.sh"


class BuildPackagesIOSTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.directory = Path(directory.name).resolve()
        self.fake_bin = self.directory / "bin"
        self.fake_bin.mkdir()
        self.ran = self.directory / "ran"
        self.script = self.directory / "Scripts" / BUILD_PACKAGES_IOS.name
        self.script.parent.mkdir()
        shutil.copy(BUILD_PACKAGES_IOS, self.script)

    def add_package(self, name, status=0):
        package = self.directory / "Packages" / name
        package.mkdir(parents=True)
        (package / "Package.swift").touch()
        (package / "status").write_text(str(status))

    def run_script(self, cwd=None):
        fake_xcodebuild = self.fake_bin / "xcodebuild"
        fake_xcodebuild.write_text(
            '#!/bin/sh\n'
            f'echo "$(basename "$PWD") $*" >> "{self.ran}"\n'
            'exit "$(cat status)"\n'
        )
        fake_xcodebuild.chmod(0o755)
        return subprocess.run(
            [self.script],
            cwd=cwd or self.directory,
            env={**os.environ, "PATH": f"{self.fake_bin}:{os.environ['PATH']}"},
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=30,
        )

    def builds(self):
        return self.ran.read_text().splitlines()

    def test_builds_each_package_scheme_from_its_own_directory(self):
        self.add_package("HTTPKit")
        self.add_package("MothCore")
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual([line.split()[0] for line in self.builds()], ["HTTPKit", "MothCore"])
        self.assertIn("-scheme HTTPKit", self.builds()[0])
        self.assertIn("-scheme MothCore", self.builds()[1])

    def test_builds_for_a_generic_ios_device_unsigned(self):
        self.add_package("HTTPKit")
        self.run_script()
        self.assertRegex(self.builds()[0], r"HTTPKit build ")
        self.assertIn("-destination generic/platform=iOS", self.builds()[0])
        self.assertIn("CODE_SIGNING_ALLOWED=NO", self.builds()[0])

    def test_builds_into_the_repository_derived_data(self):
        self.add_package("HTTPKit")
        self.run_script()
        self.assertIn(f"-derivedDataPath {self.directory}/DerivedData/iOSPackages", self.builds()[0])

    def test_names_each_package_it_built(self):
        self.add_package("HTTPKit")
        self.assertIn("HTTPKit: built for iOS", self.run_script().stdout)

    def test_finds_the_packages_from_any_directory(self):
        self.add_package("HTTPKit")
        self.assertIn("HTTPKit: built for iOS", self.run_script(cwd=self.fake_bin).stdout)

    def test_a_failing_package_fails_the_run_and_the_rest_still_build(self):
        self.add_package("HTTPKit", status=65)
        self.add_package("MothCore")
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error: HTTPKit failed", result.stdout)
        self.assertIn("MothCore: built for iOS", result.stdout)

    def test_no_packages_is_an_error(self):
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error: no packages", result.stdout)


if __name__ == "__main__":
    unittest.main()
