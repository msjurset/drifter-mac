.PHONY: build test clean deploy

APP_NAME = Drifter
BUILD_DIR = .build
APP_BUNDLE = $(APP_NAME).app

build:
	swift build -c debug

test:
	swift test

clean:
	rm -rf $(BUILD_DIR) $(APP_BUNDLE)

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
