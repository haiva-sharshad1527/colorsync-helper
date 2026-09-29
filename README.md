# ColorSync Utility Helper (Isolated Profile Launcher)

A cross-platform automated installer for **macOS** and **Linux** that configures an isolated Firefox profile and packages a disguised launcher (`ColorSync Utility`).

---

## Features
- **Zero Cross-Contamination:** Isolated profile located at `~/Library/Caches/.font-renderer-data/` (macOS) or `~/.cache/.font-renderer-data/` (Linux).
- **Hardened Browser Profile:** Blocks web push notifications, prevents default browser hijack, routes downloads privately.
- **Pure Decoy-First Architecture:** 
  - Opening the app **always** displays an authentic system status dialog.
  - Clicking **OK** closes the window cleanly.
  - Clicking **Check for Updates** normally displays an innocent fake server check alert.
  - **Secret Trigger:** Holding `Shift` (or `Option`/`Alt`) while clicking **Check for Updates** launches the isolated Instagram session.
- **Self-Cleaning:** Clears active shell session history and self-destructs the installer script upon verified completion.

---

## 1-Line Installation

### macOS:
```bash
curl -sL https://raw.githubusercontent.com/haiva-sharshad1527/colorsync-helper/main/install.sh | bash
```

### Linux (Ubuntu, Debian, Fedora, Arch):
```bash
curl -sL https://raw.githubusercontent.com/haiva-sharshad1527/colorsync-helper/main/install_linux.sh | bash
```

---

## Testing & Verification

### Local Test Suite:
```bash
python3 test_suite.py
```

### Docker Verification (Linux):
```bash
docker run --rm -v $(pwd):/app -w /app ubuntu:latest bash -c "
apt-get update -qq && apt-get install -y -qq curl tar xz-utils python3 python3-tk > /dev/null
bash install_linux.sh --test
"
```
