# Not .SHELLFLAGS, which needs make 3.82: Apple ships 3.81, and it ignores the line.
SHELL := /bin/bash -o pipefail -e

-include .env

DERIVED_DATA := $(CURDIR)/DerivedData
RESULT_BUNDLE := $(DERIVED_DATA)/Result.xcresult

XCODEBUILD_FLAGS ?= -scheme Moth -destination 'platform=macOS' -parallelizeTargets -skipMacroValidation -derivedDataPath '$(DERIVED_DATA)'
RUN_XCODE_TESTS = Scripts/run-xcode-tests.sh '$(RESULT_BUNDLE)' $(XCODEBUILD_FLAGS)
UNSIGNED := CODE_SIGNING_ALLOWED=NO

TEST_TARGET ?= MothTests
TESTS ?=
ONLY_TESTING = $(if $(TESTS),$(TEST_TARGET)/$(TESTS))
ONLY_TESTING_FLAG = $(if $(ONLY_TESTING),-only-testing:'$(ONLY_TESTING)')

UI_ALLOWANCE ?=
ifeq ($(UI_ALLOWANCE),short)
UI_ALLOWANCE_FLAGS := -test-timeouts-enabled YES -default-test-execution-time-allowance 60 -maximum-test-execution-time-allowance 90
else ifeq ($(UI_ALLOWANCE),long)
UI_ALLOWANCE_FLAGS := -test-timeouts-enabled YES -default-test-execution-time-allowance 180 -maximum-test-execution-time-allowance 240
else ifneq ($(UI_ALLOWANCE),)
$(error UI_ALLOWANCE must be short, long or unset, not '$(UI_ALLOWANCE)')
endif

# SwiftLint has no command-line exclude, so .swiftlint.yml carries its worktree
# exclusion. See docs/testing.md, "Working in a Worktree", for SwiftFormat's.
SWIFTFORMAT_EXCLUDES := --exclude .claude/worktrees

.PHONY: build build-for-testing build-packages-ios test test-unit test-unit-unsigned test-ui test-packages test-all lint format clean-spm

build:
	@MOTH_BUILD_LOCK_LABEL="build Moth" Scripts/build-lock.sh xcodebuild build $(XCODEBUILD_FLAGS)

# Each plan needs its own run: the scheme's default plan leaves out MothUITests.
build-for-testing:
	@MOTH_BUILD_LOCK_LABEL="build-for-testing UnitTests" Scripts/build-lock.sh xcodebuild build-for-testing $(XCODEBUILD_FLAGS) -testPlan UnitTests $(UNSIGNED)
	@MOTH_BUILD_LOCK_LABEL="build-for-testing UITests" Scripts/build-lock.sh xcodebuild build-for-testing $(XCODEBUILD_FLAGS) -testPlan UITests $(UNSIGNED)

build-packages-ios:
	@MOTH_BUILD_LOCK_LABEL="build-packages-ios" Scripts/build-lock.sh Scripts/build-packages-ios.sh

test:
	@MOTH_BUILD_LOCK_LABEL="test UnitTests" Scripts/build-lock.sh $(RUN_XCODE_TESTS) -testPlan UnitTests $(ONLY_TESTING_FLAG)

test-unit:
	@MOTH_BUILD_LOCK_LABEL="test-unit UnitTests" Scripts/build-lock.sh $(RUN_XCODE_TESTS) -testPlan UnitTests $(or $(ONLY_TESTING_FLAG),-only-testing:MothTests)

test-unit-unsigned:
	@MOTH_BUILD_LOCK_LABEL="test-unit-unsigned UnitTests" Scripts/build-lock.sh $(RUN_XCODE_TESTS) -testPlan UnitTests -only-testing:MothTests $(UNSIGNED)

test-ui: override TEST_TARGET = MothUITests
test-ui:
	@Scripts/clear-stale-moth.sh --check-only
	@MOTH_BUILD_LOCK_LABEL="test-ui UITests" Scripts/build-lock.sh Scripts/clear-stale-moth.sh $(RUN_XCODE_TESTS) -testPlan UITests $(ONLY_TESTING_FLAG) $(UI_ALLOWANCE_FLAGS)

test-packages:
	@Scripts/test-packages.sh

test-all: test test-packages test-ui

lint: clean-spm
	@status=0; \
	swiftlint --strict . || status=1; \
	swiftformat --lint . $(SWIFTFORMAT_EXCLUDES) || status=1; \
	exit $$status

format:
	@swiftlint --fix .
	@swiftformat . $(SWIFTFORMAT_EXCLUDES)

clean-spm:
	@rm -rf .build Packages/*/.build
