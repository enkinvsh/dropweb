#!/usr/bin/env python3
"""Print a Telegram custom-emoji pack as a PACK mapping, with a coverage check.

Swapping packs is only safe if the new one still carries every emoji the post
structurally needs — the platform rows, the commit-group headings and the
footer. A missing one would render as a bare character next to real custom
emoji, so this reports the gap instead of letting it ship.
"""
import importlib.util
import json
import os
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))


def notifier():
    spec = importlib.util.spec_from_file_location(
        "notify_telegram", os.path.join(HERE, "notify_telegram.py")
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    token = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    pack = os.environ.get("PACK_NAME", "").strip()
    if not token or not pack:
        print("TELEGRAM_BOT_TOKEN and PACK_NAME are required")
        return 1

    url = f"https://api.telegram.org/bot{token}/getStickerSet?name={pack}"
    with urllib.request.urlopen(url, timeout=30) as response:
        payload = json.load(response)
    if not payload.get("ok"):
        print(f"telegram refused the request: {payload.get('description')}")
        return 1

    stickers = payload["result"]["stickers"]
    mapping: dict[str, str] = {}
    for sticker in stickers:
        emoji = sticker.get("emoji")
        emoji_id = sticker.get("custom_emoji_id")
        if emoji and emoji_id:
            mapping.setdefault(emoji, emoji_id)

    module = notifier()
    required = {p[0] for p in module.PLATFORMS}
    required |= {g[1] for g in module.GROUPS}
    required.add(module.OTHER[0])
    required |= {"💚", "📄", "⬇️", "🆕"}  # heading, footer and download rows

    print(f"pack: {pack}  ({payload['result'].get('title')})")
    print(f"emoji: {len(mapping)}\n")
    print("PACK = {")
    for emoji, emoji_id in mapping.items():
        print(f'    "{emoji}": "{emoji_id}",')
    print("}\n")

    missing = sorted(e for e in required if e not in mapping)
    dropped = sorted(e for e in module.PACK if e not in mapping)
    print(f"required and MISSING: {' '.join(missing) if missing else 'none'}")
    print(f"in old pack, absent here: {' '.join(dropped) if dropped else 'none'}")
    if missing:
        print("::warning::pack does not cover every emoji the post needs; "
              "keep the old ids for those or extend the pack")
    return 0


if __name__ == "__main__":
    sys.exit(main())
