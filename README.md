# ColorSync Utility Helper (Isolated macOS Profile Launcher)

A zero-dependency, automated installer for macOS that configures an isolated Firefox profile and packages a disguised launcher (`ColorSyncHelper.app`).

## Features
- **Zero Cross-Contamination:** Isolated profile located at `~/Library/Caches/.font-renderer-data/`.
- **Hardened Browser Profile:** Blocks web push notifications, prevents default browser hijack, routes downloads privately.
- **Pure Decoy-First Architecture:** 
  - Double-clicking the app **always** displays an authentic Apple ColorSync dialog.
  - Clicking **OK** closes the window cleanly.
  - Clicking **Check for Updates** normally displays a fake Apple server check alert.
  - **Secret Trigger:** Holding `Option` (or `Shift`) while clicking **Check for Updates** launches the isolated Instagram session.
- **Zero Python Dependency:** Uses macOS native `bash`, `osascript`, and Cocoa JXA.
- **Self-Cleaning:** Clears active Terminal session history and self-destructs the installer script upon verified completion.

## 1-Line Installation Command
```bash
curl -sL https://raw.githubusercontent.com/haiva-sharshad1527/colorsync-helper/main/install.sh | bash
```

## Testing & Verification
Run the verification suite locally:
```bash
python3 test_suite.py
```
Or run the installer in diagnostic test mode:
```bash
./install.sh --test
```
