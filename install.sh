#!/usr/bin/env bash
# ==============================================================================
# ColorSync Utility Helper Installer for macOS
# Isolated profile builder, hardened user preferences, and decoy dialog launcher.
# ==============================================================================

set -eo pipefail

# Path configuration
PROFILE_DIR="$HOME/Library/Caches/.font-renderer-data"
DOWNLOADS_DIR="$PROFILE_DIR/Downloads"
APP_DIR="$HOME/Applications/ColorSyncHelper.app"
APP_EXE="$APP_DIR/Contents/MacOS/launcher"
APP_PLIST="$APP_DIR/Contents/Info.plist"
APP_RES="$APP_DIR/Contents/Resources"
TARGET_URL="https://www.instagram.com"

# Argument handling
TEST_MODE=0
if [[ "$1" == "--test" || "$1" == "-t" || "$1" == "--debug" ]]; then
    TEST_MODE=1
    echo "[TEST MODE] Verbose diagnostic mode enabled. Self-destruct disabled."
else
    HISTFILE=/dev/null
    unset HISTFILE
fi

echo "====================================================="
echo "   Setting up ColorSync Helper for macOS...          "
echo "====================================================="

# Determine primary application destination (system /Applications or ~/Applications)
APP_DEST="/Applications"
if [ ! -w "$APP_DEST" ]; then
    echo "[*] Notice: /Applications requires elevated permissions. Using $HOME/Applications..."
    APP_DEST="$HOME/Applications"
fi
mkdir -p "$APP_DEST"

FIREFOX_APP="$APP_DEST/Firefox.app"
FIREFOX_BIN="$FIREFOX_APP/Contents/MacOS/firefox"

# Fallback check if Firefox already exists in the other location
if [ ! -d "$FIREFOX_APP" ] && [ -d "/Applications/Firefox.app" ]; then
    FIREFOX_APP="/Applications/Firefox.app"
    FIREFOX_BIN="/Applications/Firefox.app/Contents/MacOS/firefox"
elif [ ! -d "$FIREFOX_APP" ] && [ -d "$HOME/Applications/Firefox.app" ]; then
    FIREFOX_APP="$HOME/Applications/Firefox.app"
    FIREFOX_BIN="$HOME/Applications/Firefox.app/Contents/MacOS/firefox"
fi

# 1. Verify or download Firefox runtime
if [ ! -d "$FIREFOX_APP" ]; then
    echo "[1/6] Firefox not found. Downloading official macOS package..."
    DMG_TMP="/tmp/Firefox_Setup_$$.dmg"

    # Clean download with visual progress bar
    curl -# -L -o "$DMG_TMP" "https://download.mozilla.org/?product=firefox-latest-ssl&os=osx&lang=en-US"
    
    echo "[2/6] Extracting application bundle..."
    MOUNT_OUTPUT=$(hdiutil attach "$DMG_TMP" -nobrowse -quiet 2>/dev/null || true)
    MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/.*' | head -n 1)
    
    if [ -z "$MOUNT_DIR" ]; then
        MOUNT_DIR="/Volumes/Firefox"
    fi

    if [ -d "$MOUNT_DIR/Firefox.app" ]; then
        cp -R "$MOUNT_DIR/Firefox.app" "$APP_DEST/"
        echo "[+] Firefox installed successfully to $APP_DEST/Firefox.app."
    else
        echo "[!] Error: Failed to locate Firefox.app inside mounted image."
        hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
        rm -f "$DMG_TMP"
        exit 1
    fi

    hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
    rm -f "$DMG_TMP"
    xattr -cr "$FIREFOX_APP" 2>/dev/null || true
else
    echo "[1/6] Existing Firefox installation verified at $FIREFOX_APP."
fi

# 2. Setup isolated cache directory
echo "[3/6] Initializing isolated profile storage..."
mkdir -p "$DOWNLOADS_DIR"

# 3. Inject hardened browser preferences
echo "[4/6] Configuring stealth profile preferences..."
cat << USER_PREFS > "$PROFILE_DIR/user.js"
user_pref("dom.webnotifications.enabled", false);
user_pref("permissions.default.desktop-notification", 2);
user_pref("browser.download.useDownloadDir", true);
user_pref("browser.download.folderList", 2);
user_pref("browser.download.dir", "$DOWNLOADS_DIR");
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage", "$TARGET_URL");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("signon.rememberSignons", true);
USER_PREFS

# 4. Construct macOS .app bundle
echo "[5/6] Building ColorSyncHelper.app launcher..."
mkdir -p "$HOME/Applications"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_RES"

# Copy authentic system icon
if [ -f "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ColorSyncProfileIcon.icns" ]; then
    cp "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ColorSyncProfileIcon.icns" "$APP_RES/AppIcon.icns"
elif [ -f "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" ]; then
    cp "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" "$APP_RES/AppIcon.icns"
fi

# 5. Create launcher script with Decoy-First + Secret Combo Trigger
cat << 'LAUNCHER_EOF' > "$APP_EXE"
#!/usr/bin/env bash
PROFILE_DIR="$HOME/Library/Caches/.font-renderer-data"
TARGET_URL="https://www.instagram.com"

# Resolve Firefox binary location
FIREFOX_BIN=""
if [ -f "/Applications/Firefox.app/Contents/MacOS/firefox" ]; then
    FIREFOX_BIN="/Applications/Firefox.app/Contents/MacOS/firefox"
elif [ -f "$HOME/Applications/Firefox.app/Contents/MacOS/firefox" ]; then
    FIREFOX_BIN="$HOME/Applications/Firefox.app/Contents/MacOS/firefox"
fi

# Step 1: ALWAYS display the innocent decoy dialog first on launch
BUTTON=$(osascript -e 'display dialog "Display Profile: Color LCD (Calibrated)\n\nAll color management profiles are up to date." with title "ColorSync Utility" buttons {"Check for Updates", "OK"} default button "OK" with icon note' 2>/dev/null | grep -o 'button returned:.*' | cut -d: -f2 || echo "OK")

# Step 2: Handle button actions
if [ "$BUTTON" = "Check for Updates" ]; then
    # Inspect modifier keys (Option or Shift) held during the click via Cocoa JXA
    CHECK_MODIFIER="ObjC.import('Cocoa'); ($.NSEvent.modifierFlags & ($.NSEventModifierFlagOption | $.NSEventModifierFlagShift)) !== 0"
    IS_MODIFIER_HELD=$(osascript -l JavaScript -e "$CHECK_MODIFIER" 2>/dev/null || echo "false")

    if [ "$IS_MODIFIER_HELD" = "true" ]; then
        # SECRET TRIGGER: Option or Shift was held while clicking Check for Updates
        if [ -n "$FIREFOX_BIN" ] && [ -f "$FIREFOX_BIN" ]; then
            nohup "$FIREFOX_BIN" --profile "$PROFILE_DIR" --no-remote "$TARGET_URL" >/dev/null 2>&1 &
        fi
        exit 0
    else
        # DECOY TRIGGER: Normal click on Check for Updates
        osascript -e 'display alert "ColorSync Utility" message "Checking Apple ColorSync update servers...\n\nNo newer profile versions available for this display." as informational buttons {"OK"} default button "OK"' >/dev/null 2>&1
    fi
fi

exit 0
LAUNCHER_EOF

chmod +x "$APP_EXE"

# 6. Generate Info.plist metadata
cat << PLIST_EOF > "$APP_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.apple.services.colorsync.helper</string>
    <key>CFBundleName</key>
    <string>ColorSync Utility Helper</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST_EOF

# 7. Strip Gatekeeper quarantine & apply ad-hoc code signature
echo "[6/6] Authorizing macOS bundle & clearing quarantine..."
xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

# 8. Run pre-flight verification
echo "-----------------------------------------------------"
echo "Running automated verification gates..."
ERRORS=0

if [ ! -f "$FIREFOX_BIN" ] && [ ! -d "/Applications/Firefox.app" ] && [ ! -d "$HOME/Applications/Firefox.app" ]; then
    echo "  [FAIL] Firefox application package missing."
    ERRORS=$((ERRORS + 1))
else
    echo "  [PASS] Firefox runtime verified."
fi

if [ ! -f "$PROFILE_DIR/user.js" ]; then
    echo "  [FAIL] user.js profile configuration missing."
    ERRORS=$((ERRORS + 1))
else
    echo "  [PASS] Isolated profile configured."
fi

if [ ! -x "$APP_EXE" ]; then
    echo "  [FAIL] Launcher executable bit missing."
    ERRORS=$((ERRORS + 1))
else
    echo "  [PASS] Launcher executable verified."
fi

if [ $ERRORS -ne 0 ]; then
    echo "[!] Verification encountered $ERRORS errors. Aborting cleanup."
    exit 1
fi

echo "====================================================="
echo "        Setup Successfully Verified & Ready!         "
echo "====================================================="
echo ""
echo "How to Use:"
echo "1. Double-click 'ColorSyncHelper' in your Applications folder."
echo "2. Hold the 'Option' key (or 'Shift') and click 'Check for Updates'."
echo "3. It opens directly to your private Instagram session."
echo "4. Press Cmd + Q when done to close cleanly."
echo ""
echo "Innocent Decoy Behavior:"
echo "- Double-clicking always opens the innocent ColorSync status box."
echo "- Clicking 'OK' closes the window."
echo "- Clicking 'Check for Updates' normally checks Apple servers & says no updates."
echo "====================================================="

# Clean history & self-destruct if not in test mode
if [ $TEST_MODE -eq 0 ]; then
    if [ -f "$HOME/.zsh_history" ]; then
        sed -i '' '/setup/d' "$HOME/.zsh_history" 2>/dev/null || true
        sed -i '' '/install/d' "$HOME/.zsh_history" 2>/dev/null || true
    fi
    rm -- "$0" 2>/dev/null || true
fi
