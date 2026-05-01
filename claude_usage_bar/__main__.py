"""Entry point for `python -m claude_usage_bar` and the installed CLI command."""

from .app import ClaudeUsageApp


def main():
    ClaudeUsageApp().run()


if __name__ == "__main__":
    main()
