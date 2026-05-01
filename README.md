# claude-usagage-bar

A Mac status bar app that shows today's [Claude Code](https://claude.ai/code) token usage at a glance.

![Status bar showing ↑1.2k ↓45.3k](https://img.shields.io/badge/status-alpha-orange)

## What it shows

- **↑** Input tokens sent today
- **↓** Output tokens received today
- Drop-down menu: cache read/write tokens and message count

Data is read directly from Claude Code's local session files (`~/.claude/projects/`) — no API key or network request needed.

## Requirements

- macOS
- Python 3.9+
- [Claude Code](https://claude.ai/code) installed and used at least once

## Install

```bash
pip install claude-usagage-bar
```

## Run

```bash
claude-usage-bar
```

To launch automatically at login, add it to **System Settings → General → Login Items**.

## Development

```bash
git clone https://github.com/chrisrouse/claude-usagage-bar
cd claude-usagage-bar
pip install -e ".[dev]"
python -m claude_usage_bar
```

## License

MIT
