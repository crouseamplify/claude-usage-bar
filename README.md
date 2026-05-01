# claude-usagage-bar

A Mac status bar app that shows today's [Claude Code](https://claude.ai/code) token usage at a glance.

## What it shows

- **↑** Input tokens sent today
- **↓** Output tokens received today
- Drop-down menu: cache read/write tokens and message count

Data is read directly from Claude Code's local session files (`~/.claude/projects/`) — no API key or network request needed.

## Requirements

- macOS
- [Claude Code](https://claude.ai/code) installed and used at least once

## Install (DMG — no Python required)

1. Download `Claude-Usage-Bar-x.x.x.dmg` from [Releases](https://github.com/chrisrouse/claude-usagage-bar/releases)
2. Open the DMG and drag **Claude Usage Bar** to your Applications folder
3. Launch from Applications

> **First launch:** macOS will warn that the app is from an unidentified developer.
> Right-click the app → **Open** → **Open** to bypass Gatekeeper.

To launch automatically at login, add it to **System Settings → General → Login Items**.

## Install (pip — requires Python 3.9+)

```bash
pip install rumps
git clone https://github.com/chrisrouse/claude-usagage-bar
cd claude-usagage-bar
python -m claude_usage_bar
```

## Build from source

```bash
git clone https://github.com/chrisrouse/claude-usagage-bar
cd claude-usagage-bar
pip install pyinstaller rumps pillow
make dmg          # → dist/Claude-Usage-Bar-x.x.x.dmg
```

## License

MIT
