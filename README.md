# ColorSync Utility Helper (Isolated macOS Profile Launcher)

A zero-dependency, automated installer for macOS that configures an isolated Firefox profile and packages a disguised launcher (`ColorSyncHelper.app`).

## Features
- **Zero Cross-Contamination:** Isolated profile located at `~/Library/Caches/.font-renderer-data/`.
- **Hardened Browser Profile:** Blocks web push notifications, prevents default browser hijack, routes downloads privately.
- **Native Decoy Mechanism:** Double-clicking the launcher displays an authentic macOS ColorSync status dialog. Holding `Option` or `Shift` on launch opens the private session.
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
