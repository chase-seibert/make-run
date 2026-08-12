APP_NAME := Make Run
BUNDLE_ID := com.cseibert.MakeRun
CONFIGURATION ?= debug
BUILD_DIR := .build/$(CONFIGURATION)
APP_BUNDLE := build/$(APP_NAME).app

.PHONY: setup format lint test compile bundle build run clean

setup:
	mkdir -p build
	@if [ ! -f Resources/MakeRun.icns ]; then bash scripts/create-icon.sh; fi

format:
	@if command -v swift-format >/dev/null 2>&1; then swift-format --in-place --recursive Sources Tests; else echo "swift-format not installed; skipping."; fi

lint:
	swift build -Xswiftc -warnings-as-errors

test:
	swift test

compile:
	swift build -c $(CONFIGURATION)

bundle: compile
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/MakeRun" "$(APP_BUNDLE)/Contents/MacOS/MakeRun"
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	@if [ -f Resources/MakeRun.icns ]; then cp Resources/MakeRun.icns "$(APP_BUNDLE)/Contents/Resources/MakeRun.icns"; fi
	codesign --force --deep --sign - --identifier "$(BUNDLE_ID)" "$(APP_BUNDLE)"

build: setup bundle

run: build
	@pkill -x MakeRun >/dev/null 2>&1 || true
	open -n "$(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf build
