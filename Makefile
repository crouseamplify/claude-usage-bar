APP_NAME    = Claude Usage Bar
BUNDLE_ID   = us.chrisrouse.claude-usage-bar
VERSION     = 0.1.0
DMG_NAME    = Claude-Usage-Bar.dmg

BUILD_DIR   = dist
APP_BUNDLE  = $(BUILD_DIR)/$(APP_NAME).app
BINARY_NAME = ClaudeUsageBar

.PHONY: all app dmg clean icon

all: dmg

## Build the .app bundle from Swift sources
app:
	@echo "→ Building Swift release binary…"
	swift build -c release 2>&1
	@echo "→ Assembling .app bundle…"
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp ".build/release/$(BINARY_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp assets/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns" 2>/dev/null || true
	@cp assets/StatusIcon.png "$(APP_BUNDLE)/Contents/Resources/StatusIcon.png" 2>/dev/null || true
	@cp assets/StatusIcon@2x.png "$(APP_BUNDLE)/Contents/Resources/StatusIcon@2x.png" 2>/dev/null || true
	@printf '<?xml version="1.0" encoding="UTF-8"?>\n\
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n\
<plist version="1.0"><dict>\n\
  <key>CFBundleName</key>              <string>$(APP_NAME)</string>\n\
  <key>CFBundleDisplayName</key>       <string>$(APP_NAME)</string>\n\
  <key>CFBundleIdentifier</key>        <string>$(BUNDLE_ID)</string>\n\
  <key>CFBundleVersion</key>           <string>$(VERSION)</string>\n\
  <key>CFBundleShortVersionString</key><string>$(VERSION)</string>\n\
  <key>CFBundleExecutable</key>        <string>$(APP_NAME)</string>\n\
  <key>CFBundleIconFile</key>          <string>AppIcon</string>\n\
  <key>CFBundlePackageType</key>       <string>APPL</string>\n\
  <key>LSMinimumSystemVersion</key>    <string>13.0</string>\n\
  <key>LSUIElement</key>               <true/>\n\
  <key>NSHumanReadableCopyright</key>  <string>© 2026 Chris Rouse</string>\n\
</dict></plist>' > "$(APP_BUNDLE)/Contents/Info.plist"
	@echo "✅  $(APP_BUNDLE)"

## Wrap the .app in a distributable .dmg
dmg: app
	@rm -f "$(BUILD_DIR)/$(DMG_NAME)"
	create-dmg \
		--volname "$(APP_NAME)" \
		--volicon "assets/AppIcon.icns" \
		--background "assets/dmg-background.png" \
		--window-pos 200 120 \
		--window-size 660 400 \
		--icon-size 128 \
		--icon "$(APP_NAME).app" 180 185 \
		--app-drop-link 480 185 \
		--hide-extension "$(APP_NAME).app" \
		"$(BUILD_DIR)/$(DMG_NAME)" \
		"$(BUILD_DIR)/$(APP_NAME).app"
	@echo "✅  $(BUILD_DIR)/$(DMG_NAME)"

icon:
	python3 scripts/make_icon.py

clean:
	rm -rf .build dist build
