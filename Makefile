.PHONY: build test clean deploy bundle release archive

APP_NAME = Drifter
BUILD_DIR = .build
APP_BUNDLE = $(APP_NAME).app
VERSION ?= $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null || echo "1.1.0")

build:
	swift build -c debug

release:
	swift build -c release

bundle: release
	mkdir -p $(APP_BUNDLE)/Contents/MacOS $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/release/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	if [ -f Info.plist ]; then cp Info.plist $(APP_BUNDLE)/Contents/; fi
	if [ -f AppIcon.icns ]; then cp AppIcon.icns $(APP_BUNDLE)/Contents/Resources/; fi

archive: bundle
	mkdir -p dist
	ditto -c -k --keepParent $(APP_BUNDLE) dist/$(APP_NAME)-$(VERSION).zip
	@echo "Created dist/$(APP_NAME)-$(VERSION).zip"
	@shasum -a 256 dist/$(APP_NAME)-$(VERSION).zip

test:
	swift test

clean:
	rm -rf $(BUILD_DIR) $(APP_BUNDLE) dist

deploy: test build
	-killall $(APP_NAME) 2>/dev/null || true
	sleep 1
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/debug/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	if [ -f Info.plist ]; then cp Info.plist $(APP_BUNDLE)/Contents/; fi
	if [ -f AppIcon.icns ]; then cp AppIcon.icns $(APP_BUNDLE)/Contents/Resources/; fi
	open -n -a "$(shell pwd)/$(APP_BUNDLE)"
	@echo "Deploying and relaunching $(APP_NAME).app complete."
