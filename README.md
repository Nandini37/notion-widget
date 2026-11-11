# Notion Widget for macOS 📝

A native, lightweight, and hardened macOS desktop widget application for Notion pages and databases.

Designed to live gracefully on your desktop, with edge-to-edge database optimization, multiple window placement modes, and zero third-party telemetry.

---

## ✨ Features

- **📊 Edge-to-Edge Database Focus**: Automatically removes Notion's bulky navigation bars, covers, hero icons, and default 96px side margins to present a clean, distraction-free database view.
- **☀️ Native Light Mode**: Enforces crisp, high-contrast light mode styling with clean white canvas backgrounds.
- **📌 3 Window Placement Modes**:
  - **Normal (Behind Apps)** *(Recommended)*: Sits quietly behind your active workspace (Chrome, Slack, VSCode). Accessible across all macOS Spaces.
  - **Float (Always on Top)**: Stays pinned above all other windows like a sticky note or picture-in-picture dashboard.
  - **Wall (Wallpaper Layer)**: Anchored directly into your desktop wallpaper. Revealed when you move windows aside or use macOS *Show Desktop*.
- **⚙️ Dedicated Settings & Page Selector (`Cmd+,`)**:
  - Maintain a list of your favorite Notion pages and databases.
  - 1-click database switching.
  - One-click clipboard paste (`📋 Paste`) with automatic URL formatting.
  - Live window placement and clean view toggles.
- **🛡️ Hardened Security**:
  - **Apple Hardened Runtime**: Compiled with memory integrity (`W^X`) and anti-injection protections.
  - **Domain Navigation Jail**: Restricted strictly to verified Notion and OAuth domains (`notion.so`, `notion.com`, `accounts.google.com`, `appleid.apple.com`).
  - **External Link Quarantine**: Clicking external links inside your notes routes them safely to your default external browser (Safari/Chrome), isolating the widget from third-party scripts.
  - **File System Lockdown**: JavaScript is strictly blocked from accessing local file URLs (`file://`).
  - **Strict HTTPS / ATS**: Insecure plaintext HTTP traffic is blocked at the macOS network layer.
  - **One-Click Session Wipe**: Securely remove all cached cookies and credentials on demand.

---

## 🚀 Quick Setup & Installation

### Prerequisites
- macOS 12.0 or later
- Apple Swift compiler (`swiftc`, included with Xcode or Command Line Tools)

### One-Command Setup from Git
Clone the repository and run `./install.sh`:

```bash
git clone https://github.com/Nandini37/notion-widget.git
cd notion-widget
./install.sh
```

The script compiles the application with Apple Hardened Runtime, installs it to `~/Applications/Notion Widget.app`, and launches it immediately.

---

## ⌨️ Controls & Shortcuts

| Action | Shortcut / Location |
| :--- | :--- |
| **Open Settings** | `Cmd + ,` or click `⚙️` on widget header |
| **Toggle Window Mode** | Click mode button on widget (`📌 Desk` / `🔝 Float` / `🖼️ Wall`) |
| **Reload Page** | `Cmd + R` or click `🔄` |
| **Hide Widget** | Click `✕` on widget header |
| **Show Widget** | Click the custom Notion `N` icon in the macOS Menu Bar |
| **Paste Link** | `Cmd + V` or click `📋 Paste` in Settings |

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
