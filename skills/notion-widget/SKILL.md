---
name: notion-widget
description: Install, build, configure, and manage the native Notion Widget for macOS directly from git.
---

# Notion Widget Setup & Automation Skill

This skill allows agents to install, build, configure, and manage the native macOS **Notion Widget** directly from git.

## 🚀 One-Command Setup from Git

To install and launch Notion Widget on any Mac running macOS 12+:

```bash
git clone https://github.com/Nandini37/notion-widget.git
cd notion-widget
./install.sh
```

The installer automatically:
1. Compiles the Swift application with Apple Hardened Runtime security.
2. Installs the app bundle into `~/Applications/Notion Widget.app`.
3. Opens the app immediately on the desktop.

---

## ⚙️ Personal Configuration (Git-Ignored)

To pre-configure personal Notion database links without committing them to git:

Create `config.local.json` in the project root:

```json
{
  "defaultURL": "https://www.notion.so/your-database-link",
  "savedPages": [
    {
      "name": "Sprint Board",
      "url": "https://www.notion.so/your-database-link"
    }
  ]
}
```

Run `./build.sh` to compile with your local presets. Git will automatically ignore `config.local.json`.

---

## 🎛️ Automation & Preferences

Preferences can be modified via the built-in Settings window (`Cmd+,`) or via macOS `defaults`:

| Setting | Command | Values |
| :--- | :--- | :--- |
| **Window Mode** | `defaults write com.local.NotionWidget NotionWidgetWindowMode -int <val>` | `0` = Normal, `1` = Float, `2` = Wall |
| **Clean Database View** | `defaults write com.local.NotionWidget NotionWidgetCleanMode -bool <val>` | `true` / `false` |
| **Active URL** | `defaults write com.local.NotionWidget NotionWidgetSavedURL "<url>"` | Valid Notion HTTPS URL |
