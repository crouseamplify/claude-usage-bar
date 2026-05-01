"""Mac status bar app showing today's Claude Code token usage."""

import rumps

from .reader import DayUsage, read_today

REFRESH_INTERVAL = 30  # seconds


def _fmt(n: int) -> str:
    """Format a token count as a compact string (e.g. 1,234 → 1.2k)."""
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}k"
    return str(n)


def _title(usage: DayUsage) -> str:
    return f"↑{_fmt(usage.input_tokens)} ↓{_fmt(usage.output_tokens)}"


class ClaudeUsageApp(rumps.App):
    def __init__(self):
        super().__init__("Claude", title="…")

        self.today_item = rumps.MenuItem("Today")
        self.input_item = rumps.MenuItem("  Input:   —")
        self.output_item = rumps.MenuItem("  Output:  —")
        self.cache_read_item = rumps.MenuItem("  Cache read: —")
        self.cache_create_item = rumps.MenuItem("  Cache write: —")
        self.messages_item = rumps.MenuItem("  Messages: —")

        self.menu = [
            self.today_item,
            None,
            self.input_item,
            self.output_item,
            self.cache_read_item,
            self.cache_create_item,
            None,
            self.messages_item,
            None,
        ]

        # Disable clicks on informational items
        for item in (
            self.today_item,
            self.input_item,
            self.output_item,
            self.cache_read_item,
            self.cache_create_item,
            self.messages_item,
        ):
            item.set_callback(None)

        self._refresh(None)

    @rumps.timer(REFRESH_INTERVAL)
    def _refresh(self, _):
        usage = read_today()
        self.title = _title(usage)
        self.today_item.title = f"Today  ({usage.message_count} msgs)"
        self.input_item.title = f"  Input:        {_fmt(usage.input_tokens)}"
        self.output_item.title = f"  Output:       {_fmt(usage.output_tokens)}"
        self.cache_read_item.title = f"  Cache read:   {_fmt(usage.cache_read_tokens)}"
        self.cache_create_item.title = f"  Cache write:  {_fmt(usage.cache_creation_tokens)}"
        self.messages_item.title = f"  Messages:     {usage.message_count}"
