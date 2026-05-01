"""Reads today's token usage from Claude Code session JSONL files."""

import glob
import json
import os
from dataclasses import dataclass, field
from datetime import date


@dataclass
class DayUsage:
    input_tokens: int = 0
    output_tokens: int = 0
    cache_read_tokens: int = 0
    cache_creation_tokens: int = 0
    message_count: int = 0

    @property
    def total_tokens(self) -> int:
        return self.input_tokens + self.output_tokens

    @property
    def cache_savings(self) -> int:
        """Tokens served from cache instead of being re-processed."""
        return self.cache_read_tokens


def read_today() -> DayUsage:
    """Aggregate token usage for today from all Claude Code session files."""
    today = date.today().isoformat()
    usage = DayUsage()

    projects_dir = os.path.expanduser("~/.claude/projects")
    pattern = os.path.join(projects_dir, "**", "*.jsonl")

    for path in glob.glob(pattern, recursive=True):
        _parse_jsonl(path, today, usage)

    return usage


def _parse_jsonl(path: str, today: str, usage: DayUsage) -> None:
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    msg = json.loads(line)
                except json.JSONDecodeError:
                    continue

                ts = msg.get("timestamp", "")
                if not ts.startswith(today):
                    continue

                if msg.get("type") != "assistant":
                    continue

                message = msg.get("message", {})
                u = message.get("usage")
                if not u:
                    continue

                usage.input_tokens += u.get("input_tokens", 0)
                usage.output_tokens += u.get("output_tokens", 0)
                usage.cache_read_tokens += u.get("cache_read_input_tokens", 0)
                usage.cache_creation_tokens += u.get("cache_creation_input_tokens", 0)
                usage.message_count += 1
    except OSError:
        pass
