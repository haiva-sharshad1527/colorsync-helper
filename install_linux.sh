#!/usr/bin/env bash
# ==============================================================================
# ColorSync Utility Helper Installer for Linux
# Isolated profile builder, hardened user preferences, and decoy dialog launcher.
# ==============================================================================

set -eo pipefail

PROFILE_DIR="$HOME/.cache/.font-renderer-data"
DOWNLOADS_DIR="$PROFILE_DIR/Downloads"
BIN_DIR="$HOME/.local/bin"
APP_EXE="$BIN_DIR/colorsync-helper"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/colorsync-helper.desktop"
TARGET_URL="https://www.instagram.com"

TEST_MODE=0
if [[ "$1" == "--test" || "$1" == "-t" || "$1" == "--debug" ]]; then
    TEST_MODE=1
    echo "[TEST MODE] Diagnostic mode enabled. Self-destruct disabled."
else
    HISTFILE=/dev/null
    unset HISTFILE
fi

echo "====================================================="
echo "   Setting up ColorSync Helper for Linux...          "
echo "====================================================="

# 1. Verify or install Firefox runtime
FIREFOX_BIN=$(which firefox 2>/dev/null || true)
if [ -z "$FIREFOX_BIN" ] && [ -f "$HOME/.local/firefox/firefox" ]; then
    FIREFOX_BIN="$HOME/.local/firefox/firefox"
fi

if [ -z "$FIREFOX_BIN" ]; then
    echo "[1/5] Firefox runtime not found. Fetching official Linux tarball..."
    TAR_TMP="/tmp/firefox_setup_$$.tar.xz"
    EXTRACT_TMP="/tmp/firefox_extract_$$"

    curl -# -L -o "$TAR_TMP" "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US"
    mkdir -p "$EXTRACT_TMP"
    tar -xf "$TAR_TMP" -C "$EXTRACT_TMP"
    
    mkdir -p "$HOME/.local"
    rm -rf "$HOME/.local/firefox"
    mv "$EXTRACT_TMP/firefox" "$HOME/.local/firefox"
    FIREFOX_BIN="$HOME/.local/firefox/firefox"
    
    rm -rf "$TAR_TMP" "$EXTRACT_TMP"
    echo "[+] Firefox installed to $HOME/.local/firefox."
else
    echo "[1/5] Firefox runtime verified at $FIREFOX_BIN."
fi

# 2. Setup isolated cache directory & private downloads
echo "[2/5] Initializing isolated profile storage..."
mkdir -p "$DOWNLOADS_DIR"

# 3. Inject hardened browser preferences
echo "[3/5] Configuring stealth profile preferences..."
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

# 4. Construct launcher executable
echo "[4/5] Building launcher executable: $APP_EXE..."
mkdir -p "$BIN_DIR"

cat << 'LAUNCHER_EOF' > "$APP_EXE"
#!/usr/bin/env python3
import os
import sys
import subprocess
import tkinter as tk
from tkinter import messagebox

PROFILE_DIR = os.path.expanduser("~/.cache/.font-renderer-data")
TARGET_URL = "https://www.instagram.com"

# Locate Firefox executable
firefox_bin = None
for path in ["/usr/bin/firefox", "/usr/local/bin/firefox", os.path.expanduser("~/.local/firefox/firefox")]:
    if os.path.isfile(path) and os.access(path, os.X_OK):
        firefox_bin = path
        break

if not firefox_bin:
    firefox_bin = "firefox"

class DecoyApp:
    def __init__(self, root):
        self.root = root
        self.root.title("ColorSync Utility")
        self.root.geometry("380x160")
        self.root.resizable(False, False)
        
        # Center the window
        self.root.eval('tk::PlaceWindow . center')

        # Icon and text frame
        main_frame = tk.Frame(root, padx=15, pady=15)
        main_frame.pack(fill=tk.BOTH, expand=True)

        header = tk.Label(main_frame, text="Display Profile: Color LCD (Calibrated)", font=("Helvetica", 10, "bold"))
        header.pack(anchor="w", pady=(0, 5))

        body = tk.Label(main_frame, text="All color management profiles are up to date.", font=("Helvetica", 9), fg="#555555")
        body.pack(anchor="w", pady=(0, 15))

        btn_frame = tk.Frame(main_frame)
        btn_frame.pack(fill=tk.X, side=tk.BOTTOM)

        self.update_btn = tk.Button(btn_frame, text="Check for Updates", padx=10, pady=4)
        self.update_btn.pack(side=tk.LEFT)
        self.update_btn.bind("<Button-1>", self.on_update_click)

        ok_btn = tk.Button(btn_frame, text="OK", width=8, pady=4, command=self.root.destroy)
        ok_btn.pack(side=tk.RIGHT)

    def on_update_click(self, event):
        # event.state bitmask: 0x0001 = Shift, 0x0008 = Alt (Option)
        is_shift = bool(event.state & 0x0001)
        is_alt = bool(event.state & 0x0008)

        if is_shift or is_alt:
            # Secret trigger: launch Firefox stealth profile
            self.root.destroy()
            cmd = [firefox_bin, "--profile", PROFILE_DIR, "--no-remote", TARGET_URL]
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            sys.exit(0)
        else:
            # Decoy trigger: show standard fake check dialog
            messagebox.showinfo("ColorSync Utility", "Checking Apple ColorSync update servers...\n\nNo newer profile versions available for this display.")
            self.root.destroy()
            sys.exit(0)

if __name__ == "__main__":
    root = tk.Tk()
    app = DecoyApp(root)
    root.mainloop()
LAUNCHER_EOF

chmod +x "$APP_EXE"

# 5. Create .desktop file for system application menu
echo "[5/5] Creating desktop application shortcut..."
mkdir -p "$DESKTOP_DIR"

cat << DESKTOP_EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=ColorSync Utility
Comment=Color Management and Display Profile Helper
Exec=$APP_EXE
Icon=preferences-desktop-display
Terminal=false
Type=Application
Categories=Settings;HardwareSettings;
DESKTOP_EOF

chmod +x "$DESKTOP_FILE"

# Verification Gates
echo "-----------------------------------------------------"
echo "Running automated verification gates..."
ERRORS=0

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

if [ ! -f "$DESKTOP_FILE" ]; then
    echo "  [FAIL] Desktop entry file missing."
    ERRORS=$((ERRORS + 1))
else
    echo "  [PASS] Desktop entry configured."
fi

if [ $ERRORS -ne 0 ]; then
    echo "[!] Verification encountered $ERRORS errors. Aborting cleanup."
    exit 1
fi

echo "====================================================="
echo "   Setup Successfully Verified & Ready on Linux!     "
echo "====================================================="
echo ""
echo "How to Use on Linux:"
echo "1. Launch 'ColorSync Utility' from your Application menu or run:"
echo "   ~/.local/bin/colorsync-helper"
echo "2. Hold 'Shift' (or 'Alt') and click 'Check for Updates'."
echo "3. It opens directly to your private Instagram session."
echo "4. Press Ctrl + Q (or close window) when done."
echo ""
echo "Innocent Decoy Behavior:"
echo "- Normal click on 'Check for Updates' shows innocent 'up to date' alert."
echo "====================================================="

if [ $TEST_MODE -eq 0 ]; then
    if [ -f "$HOME/.bash_history" ]; then
        sed -i '/setup/d' "$HOME/.bash_history" 2>/dev/null || true
        sed -i '/install/d' "$HOME/.bash_history" 2>/dev/null || true
    fi
    rm -- "$0" 2>/dev/null || true
fi
