SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -ec

-include .env

DERIVED_DATA := $(CURDIR)/DerivedData
RESULT_BUNDLE := $(DERIVED_DATA)/Result.xcresult

XCODEBUILD_FLAGS ?= -scheme Moth -destination 'platform=macOS' -parallelizeTargets -skipMacroValidation -derivedDataPath '$(DERIVED_DATA)'

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

.PHONY: build test test-unit test-ui test-packages test-all lint format clean-spm

build:
	@MOTH_BUILD_LOCK_LABEL="build Moth" Scripts/build-lock.sh xcodebuild build $(XCODEBUILD_FLAGS)

test:
	@MOTH_BUILD_LOCK_LABEL="test UnitTests" Scripts/build-lock.sh Scripts/run-xcode-tests.sh '$(RESULT_BUNDLE)' $(XCODEBUILD_FLAGS) -testPlan UnitTests $(ONLY_TESTING_FLAG)

test-unit:
	@MOTH_BUILD_LOCK_LABEL="test-unit UnitTests" Scripts/build-lock.sh Scripts/run-xcode-tests.sh '$(RESULT_BUNDLE)' $(XCODEBUILD_FLAGS) -testPlan UnitTests $(or $(ONLY_TESTING_FLAG),-only-testing:MothTests)

test-ui: TEST_TARGET = MothUITests
test-ui:
	@Scripts/clear-stale-moth.sh --check-only
	@MOTH_BUILD_LOCK_LABEL="test-ui UITests" Scripts/build-lock.sh Scripts/clear-stale-moth.sh Scripts/run-xcode-tests.sh '$(RESULT_BUNDLE)' $(XCODEBUILD_FLAGS) -testPlan UITests $(ONLY_TESTING_FLAG) $(UI_ALLOWANCE_FLAGS)

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
