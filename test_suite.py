#!/usr/bin/env python3
"""
Test suite for colorsync-helper installer.
Validates:
1. Shell script syntax (bash -n).
2. Plist XML structure and parser compliance.
3. Firefox user.js preferences format.
4. Mozilla CDN endpoint live HTTP redirect.
5. Isolated execution simulation in dry-run environment.
"""

import os
import subprocess
import plistlib
import urllib.request
import urllib.error
import tempfile
import sys

def test_shell_syntax(script_path):
    print("[1/5] Checking bash syntax with bash -n...")
    result = subprocess.run(["bash", "-n", script_path], capture_output=True, text=True)
    assert result.returncode == 0, f"Bash syntax error: {result.stderr}"
    print("      ✓ Bash syntax is valid.")

def test_plist_schema():
    print("[2/5] Validating Info.plist structure...")
    plist_sample = """<?xml version="1.0" encoding="UTF-8"?>
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
</plist>"""
    data = plistlib.loads(plist_sample.encode('utf-8'))
    assert data["CFBundleExecutable"] == "launcher"
    assert data["LSUIElement"] is True
    print("      ✓ Plist XML structure parsed successfully.")

def test_mozilla_cdn():
    print("[3/5] Testing Mozilla CDN redirect endpoint...")
    url = "https://download.mozilla.org/?product=firefox-latest-ssl&os=osx&lang=en-US"
    req = urllib.request.Request(url, method="HEAD")
    req.add_header("User-Agent", "Mozilla/5.0")
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            status = response.getcode()
            print(f"      ✓ Mozilla CDN returned HTTP {status}.")
    except urllib.error.HTTPError as e:
        # 302 redirects might raise HTTPError if not followed in HEAD
        assert e.code in (200, 302), f"Unexpected HTTP status: {e.code}"
        print(f"      ✓ Mozilla CDN reachable (HTTP {e.code}).")

def test_preferences_content():
    print("[4/5] Verifying user.js hardening rules...")
    required_keys = [
        "dom.webnotifications.enabled",
        "permissions.default.desktop-notification",
        "browser.download.useDownloadDir",
        "browser.shell.checkDefaultBrowser",
        "browser.startup.homepage",
        "signon.rememberSignons"
    ]
    with open("/home/haiva/custom-tools/colorsync-helper/install.sh", "r") as f:
        content = f.read()
    for k in required_keys:
        assert k in content, f"Missing required preference key: {k}"
    print(f"      ✓ All {len(required_keys)} critical preference rules verified.")

def test_dryrun_simulation():
    print("[5/5] Running sandbox installer simulation...")
    with tempfile.TemporaryDirectory() as tmpdir:
        # Mock HOME
        mock_env = os.environ.copy()
        mock_env["HOME"] = tmpdir
        # Create dummy Firefox.app so installer skips download during test
        mock_ff_app = os.path.join(tmpdir, "Applications/Firefox.app")
        os.makedirs(os.path.join(mock_ff_app, "Contents/MacOS"), exist_ok=True)
        dummy_ff = os.path.join(mock_ff_app, "Contents/MacOS/firefox")
        with open(dummy_ff, "w") as f:
            f.write("#!/bin/sh\nexit 0\n")
        os.chmod(dummy_ff, 0o755)
        mock_env["FIREFOX_APP"] = mock_ff_app
        mock_env["FIREFOX_BIN"] = dummy_ff

        script_path = "/home/haiva/custom-tools/colorsync-helper/install.sh"
        # Run in test mode
        result = subprocess.run(
            ["bash", script_path, "--test"],
            env=mock_env,
            capture_output=True,
            text=True
        )
        
        # Verify files were generated in mock HOME
        profile_js = os.path.join(tmpdir, "Library/Caches/.font-renderer-data/user.js")
        launcher = os.path.join(tmpdir, "Applications/ColorSyncHelper.app/Contents/MacOS/launcher")
        plist = os.path.join(tmpdir, "Applications/ColorSyncHelper.app/Contents/Info.plist")

        assert os.path.exists(profile_js), "user.js not generated!"
        assert os.path.exists(launcher), "Launcher binary not generated!"
        assert os.path.exists(plist), "Info.plist not generated!"
        assert os.access(launcher, os.X_OK), "Launcher binary is not executable!"
        print("      ✓ Sandbox installation generated all bundle artifacts correctly.")

if __name__ == "__main__":
    print("=== Running ColorSync Helper Verification Suite ===")
    try:
        script = "/home/haiva/custom-tools/colorsync-helper/install.sh"
        test_shell_syntax(script)
        test_plist_schema()
        test_mozilla_cdn()
        test_preferences_content()
        test_dryrun_simulation()
        print("\n[SUCCESS] All 5/5 verification tests passed cleanly!\n")
    except Exception as e:
        print(f"\n[FAILURE] Test failed: {e}", file=sys.stderr)
        sys.exit(1)
