APP_NAME := KeyType
PROJECT := KeyType.xcodeproj
SCHEME := KeyType
CONFIGURATION ?= Release
BUILD_DIR ?= build
INSTALL_DIR ?= $(HOME)/Applications
DEVELOPER_DIR ?= $(shell xcode-select -p 2>/dev/null)
CODE_SIGN_IDENTITY ?= -
MODULE_CACHE_DIR ?= /private/tmp/keytype-clang-cache
SWIFT_MODULE_CACHE_DIR ?= /private/tmp/keytype-swift-cache
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
XCODE_APP_BUNDLE := $(BUILD_DIR)/XcodeDerivedData/Build/Products/$(CONFIGURATION)/$(APP_NAME).app
XCODEBUILD := $(DEVELOPER_DIR)/usr/bin/xcodebuild

.PHONY: build install run test clean

build:
	@set -eu; \
	if [ -n "$(DEVELOPER_DIR)" ] && [ -x "$(XCODEBUILD)" ]; then \
		echo "Building with Xcode"; \
		DEVELOPER_DIR="$(DEVELOPER_DIR)" "$(XCODEBUILD)" \
			-project "$(PROJECT)" \
			-scheme "$(SCHEME)" \
			-configuration "$(CONFIGURATION)" \
			-derivedDataPath "$(BUILD_DIR)/XcodeDerivedData" \
			CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
			build; \
		rm -rf "$(APP_BUNDLE)"; \
		ditto "$(XCODE_APP_BUNDLE)" "$(APP_BUNDLE)"; \
	else \
		echo "Full Xcode not found; building a local ad-hoc app with SwiftPM"; \
		CLANG_MODULE_CACHE_PATH="$(MODULE_CACHE_DIR)" \
		SWIFTPM_MODULECACHE_OVERRIDE="$(SWIFT_MODULE_CACHE_DIR)" \
			swift build --configuration release --product "$(APP_NAME)" --disable-sandbox; \
		bin_dir="$$(CLANG_MODULE_CACHE_PATH="$(MODULE_CACHE_DIR)" SWIFTPM_MODULECACHE_OVERRIDE="$(SWIFT_MODULE_CACHE_DIR)" swift build --configuration release --show-bin-path --disable-sandbox)"; \
		rm -rf "$(APP_BUNDLE)"; \
		mkdir -p "$(APP_BUNDLE)/Contents/MacOS"; \
		mkdir -p "$(APP_BUNDLE)/Contents/Resources"; \
		cp "$$bin_dir/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"; \
		cp "KeyType/Support/Info.plist" "$(APP_BUNDLE)/Contents/Info.plist"; \
		cp "KeyType/Support/KeyType.icns" "$(APP_BUNDLE)/Contents/Resources/KeyType.icns"; \
		codesign --force --deep --sign - --entitlements "KeyType/Support/KeyType.entitlements" "$(APP_BUNDLE)"; \
	fi

install: build
	@mkdir -p "$(INSTALL_DIR)"
	@ditto "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed $(INSTALL_DIR)/$(APP_NAME).app"

run: install
	@open "$(INSTALL_DIR)/$(APP_NAME).app"

test:
	@if [ -z "$(DEVELOPER_DIR)" ] || [ ! -x "$(XCODEBUILD)" ]; then \
		echo "Full Xcode is required to run XCTest."; \
		exit 1; \
	fi
	DEVELOPER_DIR="$(DEVELOPER_DIR)" "$(XCODEBUILD)" \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-destination 'platform=macOS' \
		CODE_SIGN_IDENTITY="$(CODE_SIGN_IDENTITY)" \
		test

clean:
	@rm -rf "$(BUILD_DIR)"
