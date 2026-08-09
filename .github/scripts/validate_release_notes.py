#!/usr/bin/env python3
"""Fail fast when a release note cannot be rendered into a Telegram post.

The announcement step runs last and carries continue-on-error, so a malformed
note used to ship a green release with no post at all: v0.8.7-pre.3 died on
`ValueError: section header must start with an emoji from the pack` and nobody
noticed until someone asked where the announcement was.

Absent notes are fine — the post falls back to the generated commit list.
"""
import importlib.util
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def load_notifier():
    spec = importlib.util.spec_from_file_location(
        "notify_telegram", os.path.join(HERE, "notify_telegram.py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    tag = (sys.argv[1] if len(sys.argv) > 1 else "").strip()
    if not tag:
        print("no tag given, nothing to validate")
        return 0

    notifier = load_notifier()
    intro, sections = notifier.load_release_notes(tag)
    if not intro and not sections:
        print(f"no hand-written notes for {tag}; the post will use the commit list")
        return 0

    try:
        notifier.render_notes_sections(sections, rich=True)
        notifier.render_notes_sections(sections, rich=False)
    except ValueError as exc:
        print(f"::error file=.github/release_notes/{tag}.md::{exc}")
        print("\nallowed section emoji:")
        print("  " + " ".join(notifier.PACK))
        return 1

    print(f"{tag}: {len(sections)} section(s) render cleanly")
    for header, _ in sections:
        print(f"  {header}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
