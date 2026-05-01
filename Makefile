APP_NAME       = Claude Usage Bar
BUNDLE_ID      = us.chrisrouse.claude-usage-bar
VERSION        = 1.0.0
DMG_NAME       = Claude-Usage-Bar.dmg
SPARKLE_TOOLS  = .build/artifacts/sparkle/Sparkle/bin
SPARKLE_FW     = .build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework
APPCAST_URL    = https://raw.githubusercontent.com/chrisrouse/claude-usage-bar/main/appcast.xml
PUBLIC_ED_KEY  = E5M8YK8YovgcI9IVtZZOkBXmGGsb08KOqSQ3x51ZiDA=

BUILD_DIR   = dist
APP_BUNDLE  = $(BUILD_DIR)/$(APP_NAME).app
BINARY_NAME = ClaudeUsageBar

.PHONY: all app dmg release clean

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
	@install_name_tool -add_rpath "@executable_path/../Frameworks" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp assets/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns" 2>/dev/null || true
	@cp assets/StatusIcon.png "$(APP_BUNDLE)/Contents/Resources/StatusIcon.png" 2>/dev/null || true
	@cp assets/StatusIcon@2x.png "$(APP_BUNDLE)/Contents/Resources/StatusIcon@2x.png" 2>/dev/null || true
	@mkdir -p "$(APP_BUNDLE)/Contents/Frameworks"
	@cp -R "$(SPARKLE_FW)" "$(APP_BUNDLE)/Contents/Frameworks/"
	@cp -R "$(SPARKLE_FW)/Versions/A/XPCServices" "$(APP_BUNDLE)/Contents/XPCServices" 2>/dev/null || true
	@cp ACKNOWLEDGEMENTS.md "$(APP_BUNDLE)/Contents/Resources/ACKNOWLEDGEMENTS.md" 2>/dev/null || true
	@cp ".build/checkouts/Sparkle/LICENSE" "$(APP_BUNDLE)/Contents/Resources/Sparkle-LICENSE.txt" 2>/dev/null || true
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
  <key>SUFeedURL</key>                 <string>$(APPCAST_URL)</string>\n\
  <key>SUPublicEDKey</key>             <string>$(PUBLIC_ED_KEY)</string>\n\
  <key>SUEnableAutomaticChecks</key>   <true/>\n\
</dict></plist>' > "$(APP_BUNDLE)/Contents/Info.plist"
	@echo "✅  $(APP_BUNDLE)"

## Wrap the .app in a distributable .dmg
dmg: app
	@echo "→ Ad-hoc signing app…"
	@codesign --sign - --force --deep --timestamp=none "$(APP_BUNDLE)"
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

## Build DMG, sign it, and generate appcast.xml for Sparkle
release: dmg
	@echo "→ Generating appcast…"
	"$(SPARKLE_TOOLS)/generate_appcast" "$(BUILD_DIR)"
	@mv "$(BUILD_DIR)/appcast.xml" appcast.xml 2>/dev/null || true
	@echo "✅  appcast.xml — commit and push to publish the update"

clean:
	rm -rf .build dist build
