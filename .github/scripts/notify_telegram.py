#!/usr/bin/env python3
"""Post a dropweb release announcement to Telegram as a Rich Message.

Bot API 10.1 sendRichMessage, HTML rich mode, brand-styled:
  🆕 dropweb vX.Y.Z 💚 heading (custom emoji from t.me/addemoji/dropwebpackv1),
  intro, the whole changelog collapsed into a <details> block (so the wall of
  commits doesn't scare users), bordered download table with platform icons,
  footer, inline keyboard. Falls back to a plain sendMessage (HTML parse mode,
  expandable blockquote) per-chat if the rich endpoint rejects the payload.

Env:
  TELEGRAM_BOT_TOKEN            bot token (required unless --dry-run)
  TELEGRAM_CHAT_IDS             comma-separated targets for STABLE posts;
                                each is chat_id/@username, optionally
                                "chat_id:thread_id" for forum topics
  TELEGRAM_PRERELEASE_CHAT_IDS  same, for pre-release posts (empty = skip)
  VERSION                       tag name, e.g. v0.8.4 or v0.8.4-pre.1
  IS_STABLE                     "true" / "false"
  RELEASE_URL                   optional GitHub release url (derived if missing)

Usage:
  python3 notify_telegram.py --release-md release.md [--dry-run]

Commits are read from the "## Коммиты" section of release.md ("- subject" lines).
"""
import argparse
import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

REPO = os.environ.get("GITHUB_REPOSITORY", "enkinvsh/dropweb")
YC_BASE = "https://storage.yandexcloud.net/dropweb-downloads"
RICH_LIMIT = 32000   # official cap is 32768 rendered chars; keep headroom
LEGACY_LIMIT = 4000  # sendMessage cap is 4096 rendered chars

# t.me/addemoji/dropwebpackv1 (SimpleG by @dropwebvpn): fallback char -> custom_emoji_id
PACK = {
    "💚": "5264868767971713460", "🆕": "5265201189850488842",
    "🟢": "5265234995538075373", "🧠": "5265192428117208527",
    "🛡": "5264723494997893631", "🤔": "5264857154380142241",
    "🖥": "5264725487862720786", "🎨": "5264755952065750518",
    "📶": "5264782095531680746", "📄": "5264913220883224778",
    "⬇️": "5265009050193534901", "🐧": "5265198385236845133",
    "❤️": "5264735258913314397", "⭐": "5265254709437965128",
    "🔴": "5264960255070083437", "🍎": "5265063823911461450",
    "🪟": "5264859555266864137", "🤖": "5264809948394593913",
    "📱": "5265203522017731746", "🔄": "5265191543353938544",
    "🕷️": "5264936838908388851", "🔥": "5265266194180509939",
    "😂": "5264824937830456755", "🏴‍☠️": "5265145909326419576",
    "🧑‍💻": "5264951755329805695", "💻": "5264763751726358233",
    "🔒": "5265050526692711464", "🔑": "5265107048462326785",
    "👁️": "5265016038105324959", "⚠️": "5265226418488385619",
    "👍": "5265001710094425237", "🧼": "5265159902329871766",
    "📟": "5265182931944510281",
}

SKIP_RE = re.compile(
    r"^(update changelog$|merge |chore\(release\)|chore: bump version|release:)", re.I
)
CC_RE = re.compile(r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]+)\))?(?P<bang>!)?:\s*(?P<text>.+)$")

GROUPS = [  # (conventional type, emoji, title)
    ("feat", "⭐", "Новое"),
    ("fix", "🧼", "Исправления"),
    ("perf", "🔥", "Производительность"),
]
OTHER = ("📟", "Под капотом")

PLATFORMS = [  # (emoji, name, label, yc_name, gh_suffix)
    # yc_name = fixed YC-bucket asset name (the in-app updater's contract);
    # gh_suffix = the "<platform>-<arch>[...].<ext>" tail of the versioned
    # GitHub release asset (dropweb-<version>-<suffix>) from build.yaml's
    # "Version asset filenames" step.
    ("🤖", "Android", "APK · arm64", "dropweb-arm64-v8a.apk", "android-arm64-v8a.apk"),
    ("🤖", "Android (старые устройства)", "APK · universal", "dropweb-universal.apk", "android-universal.apk"),
    ("🪟", "Windows", "Установщик · x64", "dropweb-amd64-setup.exe", "windows-amd64-setup.exe"),
    ("🍎", "macOS", "DMG · Apple Silicon", "dropweb-arm64.dmg", "macos-arm64.dmg"),
    ("🍎", "macOS (Intel)", "DMG · Intel", "dropweb-amd64.dmg", "macos-amd64.dmg"),
    ("🐧", "Linux", "AppImage · x64", "dropweb-amd64.AppImage", "linux-amd64.AppImage"),
]


def ce(char: str) -> str:
    """Custom emoji tag with plain-emoji fallback for chars outside the pack."""
    eid = PACK.get(char)
    return f'<tg-emoji emoji-id="{eid}">{char}</tg-emoji>' if eid else char


def esc(s: str) -> str:
    return html.escape(s, quote=False)


def parse_commits(release_md: str) -> list[str]:
    lines, in_section = [], False
    for line in release_md.splitlines():
        if line.startswith("## "):
            plain = re.sub(r"<[^>]+>", "", line)
            plain = re.sub(r"\s+", " ", plain).strip()
            in_section = plain in ("## Что нового", "## Коммиты")
            continue
        if in_section and line.startswith("- "):
            subject = line[2:].strip()
            if subject and not SKIP_RE.search(subject):
                lines.append(subject)
    return lines


def classify(commits: list[str]) -> list[tuple[str, str, list[str]]]:
    """[(emoji, title, [html items])], only non-empty groups, brand order.

    Two input shapes are supported:
    - raw git subjects with conventional prefixes -> grouped into brand sections;
    - the curated, prefix-stripped "## Что нового" list from build.yaml -> a
      single flat section (title left empty, callers render it without a header).
    """
    grouped: dict[str, list[str]] = {t: [] for t, _, _ in GROUPS}
    other: list[str] = []
    for subject in commits:
        m = CC_RE.match(subject)
        if m:
            ctype, scope, text = m.group("type"), m.group("scope"), m.group("text")
            text = text[:1].upper() + text[1:]
            item = f"<b>{esc(scope)}</b> — {esc(text)}" if scope else esc(text)
            if ctype in grouped:
                grouped[ctype].append(item)
            else:
                other.append(item)
        else:
            other.append(esc(subject))
    sections = [(e, t, grouped[c]) for c, e, t in GROUPS if grouped[c]]
    if other:
        # no typed sections at all = curated user-facing list -> flat, no header
        sections.append((*OTHER, other) if sections else ("", "", other))
    return sections


def platform_urls(version: str, is_stable: bool) -> list[tuple[str, str, str, str]]:
    """Stable -> YC versioned links (RU-friendly, fixed bucket names = the
    in-app updater's contract); pre -> GitHub release assets (versioned names
    dropweb-<version>-<suffix> from build.yaml's "Version asset filenames")."""
    if is_stable:
        base = f"{YC_BASE}/v{version}"
        return [(e, name, label, f"{base}/{yc}") for e, name, label, yc, _ in PLATFORMS]
    gh = f"https://github.com/{REPO}/releases/download/v{version}"
    return [(e, name, label, f"{gh}/dropweb-{version}-{suf}")
            for e, name, label, _, suf in PLATFORMS]


def load_release_notes(tag: str) -> tuple[str, list[tuple[str, str]]]:
    """Hand-written Russian notes for the post body, if the release ships them.

    .github/release_notes/<tag>.md format:
        optional intro text before the first section
        ## ⬇️ Заголовок секции
        проза секции...
    Returns (intro, [(header, prose)]); ("", []) when the file is absent —
    callers then fall back to the auto-generated commit list.
    """
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "..", "release_notes", f"{tag}.md")
    try:
        with open(path, encoding="utf-8") as release_notes:
            text = release_notes.read()
    except OSError:
        return "", []
    intro, sections, header, buf = "", [], "", []
    def flush():
        nonlocal intro
        body = "\n".join(buf).strip()
        if header:
            sections.append((header, body))
        elif body:
            intro = body
    for line in text.splitlines():
        if line.startswith("## "):
            flush()
            header, buf = line[3:].strip(), []
        else:
            buf.append(line)
    flush()
    return intro, sections


def render_notes_sections(sections: list[tuple[str, str]], rich: bool) -> list[str]:
    """Render sections whose headers start with a dropwebpackv1 pack emoji."""
    out = []
    for header, prose in sections:
        emoji = next((c for c in PACK if header.startswith(c)), "")
        if not emoji:
            raise ValueError(
                f"release-note section header {header!r} must start with an emoji from "
                "https://t.me/addemoji/dropwebpackv1"
            )
        title = header[len(emoji):].strip()
        lead = f"{ce(emoji)} "
        if rich:
            out.append(f"<h4>{lead}{esc(title)}</h4><p>{esc(prose)}</p>")
        else:
            out.append(f"{lead}<b>{esc(title)}</b>\n{esc(prose)}")
    return out


def resolve_banner(tag: str) -> str:
    """Attention banner: env override, else the README hero from the repo.
    Prefer the tag ref (immutable); fall back to main for tags that predate it."""
    override = os.environ.get("TELEGRAM_BANNER_URL", "").strip()
    if override:
        return override
    for ref in (tag, "main"):
        url = f"https://raw.githubusercontent.com/{REPO}/{ref}/assets/images/header.png"
        try:
            req = urllib.request.Request(url, method="HEAD")
            with urllib.request.urlopen(req, timeout=10):
                return url
        except Exception:
            continue
    return ""


def intro_html(version: str, is_stable: bool) -> tuple[str, str]:
    """(heading inner html, intro paragraph html)."""
    if is_stable:
        head = f"{ce('🆕')} dropweb v{esc(version)} {ce('💚')}"
        intro = ("Стабильный релиз — доступен для всех платформ. "
                 "Приложение обновится само, либо скачайте вручную ниже.")
    else:
        head = f"{ce('🆕')} dropweb v{esc(version)} · beta"
        intro = (f"{ce('⚠️')} Предварительная сборка — для тестов. "
                 "Возможны шероховатости; фидбек приветствуется.")
    return head, intro


def build_rich_html(version: str, is_stable: bool, commits: list[str],
                    release_url: str, banner_url: str = "",
                    notes: tuple[str, list[tuple[str, str]]] = ("", [])) -> str:
    head, intro = intro_html(version, is_stable)
    notes_intro, notes_sections = notes
    parts = []
    if banner_url:
        parts.append(f'<img src="{html.escape(banner_url)}"/>')
    parts += [f"<h2>{head}</h2>", f"<p>{esc(notes_intro) if notes_intro else intro}</p>"]
    parts += render_notes_sections(notes_sections, rich=True)

    sections = classify(commits)
    total = sum(len(items) for _, _, items in sections)
    if sections:
        body = "".join(
            (f"<h4>{ce(emoji)} {title}</h4>" if title else "") +
            "<ul>" + "".join(f"<li>{i}</li>" for i in items) + "</ul>"
            for emoji, title, items in sections
        )
        summary = ("Полный список" if notes_sections else "Что нового") + \
            f" — {total} изменений"
        parts.append(
            f"<details><summary>{ce('🧠')} {summary}</summary>{body}</details>"
        )

    rows = "".join(
        f'<tr><td>{ce(e)} {esc(name)}</td>'
        f'<td><a href="{html.escape(url)}">{esc(label)}</a></td></tr>'
        for e, name, label, url in platform_urls(version, is_stable)
    )
    parts.append(
        "<table bordered striped><tr><th>Платформа</th><th>Скачать</th></tr>"
        + rows + "</table>"
    )

    parts.append("<hr/>")
    parts.append(
        f'<footer>dropweb v{esc(version)} · <a href="{html.escape(release_url)}">'
        f"GitHub Release</a> · GPL-3.0</footer>"
    )

    doc = "".join(parts)
    if rendered_len(doc) > RICH_LIMIT:  # the collapsible tail is optional
        doc = re.sub(r"<details>.*?</details>", "", doc, flags=re.S)
    return doc


def build_legacy_html(version: str, is_stable: bool, commits: list[str],
                      release_url: str,
                      notes: tuple[str, list[tuple[str, str]]] = ("", [])) -> str:
    """Fallback: brand-style plain post with an expandable quote."""
    head, intro = intro_html(version, is_stable)
    notes_intro, notes_sections = notes
    if notes_intro:
        intro = esc(notes_intro)
    body_sections = render_notes_sections(notes_sections, rich=False)
    quote = ""
    sections = classify(commits)
    if sections:
        blocks = [
            (f"{ce(emoji)} <b>{title}</b>\n" if title else "") +
            "\n".join(f"• {i}" for i in items)
            for emoji, title, items in sections
        ]
        quote = "<blockquote expandable>" + "\n\n".join(blocks) + "</blockquote>"
    downloads = f"────────────────\n{ce('⬇️')} <b>Скачать:</b>\n" + "\n".join(
        f'{ce(e)} <a href="{html.escape(url)}">{esc(name)}</a>'
        for e, name, _, url in platform_urls(version, is_stable)
    ) + f'\n{ce("📄")} <a href="{html.escape(release_url)}">GitHub Release</a>' \
        f'\n{ce("💚")} <a href="https://dropweb.org">dropweb.org</a>'

    post = "\n\n".join(
        p for p in [f"<b>{head}</b>", intro, *body_sections, quote, downloads] if p)
    if rendered_len(post) > LEGACY_LIMIT:
        post = "\n\n".join((f"<b>{head}</b>", intro, downloads))
    return post


def rendered_len(payload: str) -> int:
    """Approximate the length as Telegram counts it (tags stripped)."""
    return len(re.sub(r"<[^>]+>", "", payload))


def api_call(token: str, method: str, payload: dict) -> tuple[bool, dict]:
    req = urllib.request.Request(
        f"https://api.telegram.org/bot{token}/{method}",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return True, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read())
        except Exception:
            body = {"description": f"http {e.code}"}
        return False, body
    except Exception as e:  # network etc.
        return False, {"description": str(e)}


def send_with_retry(token: str, method: str, payload: dict) -> tuple[bool, dict]:
    ok, body = api_call(token, method, payload)
    if not ok:
        retry_after = (body.get("parameters") or {}).get("retry_after")
        if retry_after:  # flood limit
            time.sleep(min(int(retry_after), 60) + 1)
        elif "Bad Request" in str(body.get("description", "")):
            return ok, body  # permanent, retrying won't help
        else:  # transient transport/server error
            time.sleep(3)
        ok, body = api_call(token, method, payload)
    return ok, body


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--release-md", default="release.md")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    tag = os.environ.get("VERSION", "").strip()
    version = tag.lstrip("v")
    is_stable = os.environ.get("IS_STABLE", "").lower() == "true"
    release_url = os.environ.get("RELEASE_URL") or f"https://github.com/{REPO}/releases/tag/{tag}"

    if not version:
        print("::error::VERSION env is required (e.g. v0.8.4)")
        return 1

    try:
        release_md = open(args.release_md, encoding="utf-8").read()
    except OSError as e:
        print(f"::error::cannot read {args.release_md}: {e}")
        return 1

    commits = parse_commits(release_md)
    banner = resolve_banner(tag)
    notes = load_release_notes(tag)
    if notes[1]:
        print(f"using hand-written release notes ({len(notes[1])} sections)")
    elif is_stable:
        print(f"::warning::no .github/release_notes/{tag}.md — the TG post falls "
              "back to the raw commit list. Next time write the notes before tagging "
              "(see .github/release_notes/TEMPLATE.md).")
    rich = build_rich_html(version, is_stable, commits, release_url, banner, notes)
    legacy = build_legacy_html(version, is_stable, commits, release_url, notes)
    # Branded buttons: animated pack emoji via icon_custom_emoji_id. Works in
    # groups/supergroups (bot owner has Premium); channels need a Fragment
    # username on the bot — the iconless keyboard below is the safe retry.
    keyboard = {"inline_keyboard": [[
        {"text": "Скачать", "style": "success", "url": release_url,
         "icon_custom_emoji_id": PACK["⬇️"]},
        {"text": "dropweb.org", "url": "https://dropweb.org",
         "icon_custom_emoji_id": PACK["💚"]},
    ]]}
    keyboard_plain = {"inline_keyboard": [[
        {"text": "⬇️ Скачать", "style": "success", "url": release_url},
        {"text": "💚 dropweb.org", "url": "https://dropweb.org"},
    ]]}

    if args.dry_run:
        print(f"— rich html ({rendered_len(rich)} rendered chars) —\n{rich}\n")
        print(f"— legacy fallback ({rendered_len(legacy)} rendered chars) —\n{legacy}")
        return 0

    token = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    chat_env = "TELEGRAM_CHAT_IDS" if is_stable else "TELEGRAM_PRERELEASE_CHAT_IDS"
    chats = [c.strip() for c in os.environ.get(chat_env, "").split(",") if c.strip()]
    if not token:
        print("::error::TELEGRAM_BOT_TOKEN is not set")
        return 1
    if not chats:
        print(f"{chat_env} is empty — nothing to post, skipping.")
        return 0

    sent = 0
    for chat in chats:
        # forum supergroups: "chat_id:thread_id" targets a specific topic
        target: dict = {"chat_id": chat}
        head, sep, tail = chat.rpartition(":")
        if sep and tail.isdigit():
            target = {"chat_id": head, "message_thread_id": int(tail)}
        # Channels SILENTLY strip icon_custom_emoji_id (Fragment-only there),
        # which would leave buttons without any emoji at all — so channels get
        # the plain keyboard (unicode emoji in text) from the start.
        ok, body = api_call(token, "getChat", {"chat_id": target["chat_id"]})
        is_channel = ok and body.get("result", {}).get("type") == "channel"
        kb = keyboard_plain if is_channel else keyboard
        attempts = [
            ("sendRichMessage", {
                **target,
                "rich_message": {"html": rich, "skip_entity_detection": True},
                "reply_markup": kb,
            }),
            # groups may still reject emoji-icon buttons (no owner Premium)
            ("sendRichMessage", {
                **target,
                "rich_message": {"html": rich, "skip_entity_detection": True},
                "reply_markup": keyboard_plain,
            }),
            ("sendMessage", {
                **target,
                "text": legacy,
                "parse_mode": "HTML",
                "link_preview_options": {"is_disabled": True},
                "reply_markup": keyboard_plain,
            }),
        ]
        ok, body = False, {}
        for method, payload in attempts:
            ok, body = send_with_retry(token, method, payload)
            if ok:
                break
            print(f"{method} to {chat} failed ({body.get('description')}), "
                  f"trying next variant")
        print(f"{'✓' if ok else '✗'} {chat}" + ("" if ok else f": {body.get('description')}"))
        sent += ok
    print(f"Posted to {sent}/{len(chats)} chats")
    return 0 if sent else 1


if __name__ == "__main__":
    sys.exit(main())
