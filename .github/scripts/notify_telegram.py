#!/usr/bin/env python3
"""Post a dropweb release announcement to Telegram as a Rich Message.

Bot API 10.1 sendRichMessage, HTML rich mode, brand-styled:
  🆕 dropweb vX.Y.Z 💚 heading (custom emoji from t.me/addemoji/zenbot_cabinet_by_dropwebpay_bot),
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
  VERSION=v0.8.4 python3 notify_telegram.py --print-manifest-notes

Commits are read from the "## Что нового" or "## Коммиты" release.md section.
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

# Custom emoji, fallback char -> custom_emoji_id. Regenerate with the
# "Emoji pack" workflow; keys are ordered longest-first so a variation-selector
# form matches before its bare codepoint.
#
# Primary: t.me/addemoji/zenbot_cabinet_by_dropwebpay_bot (Zenbot Cabinet).
PACK = {
    "ℹ️": "5443024436611556449", "↗": "5442666373778023939", "↩": "5442892482331319813",
    "⌛": "5442949467957405897", "⏰": "5445273083919247768", "⏱": "5443018582571130940",
    "⏳": "5442808751943889341", "◀": "5443115923709929251", "☎": "5442990815607564435",
    "♻": "5443106367407697189", "⚖": "5442601365153030947", "⚙": "5442786632862313635",
    "⚠": "5443033760985555744", "⚡": "5443151331420315824", "⚪": "5442648227541201196",
    "⚫": "5443003193703309824", "⛔": "5442968404468213153", "✅": "5442808215072974818",
    "✉": "5442890274718134160", "✏": "5442682647409108934", "✨": "5442752114210156135",
    "❌": "5445291973185414524", "❓": "5442858075348314906", "❗": "5442978149749009813",
    "➕": "5442722702274112023", "➖": "5442983217810416814", "➡": "5443132497988724070",
    "⬅": "5442891554618388379", "⬆": "5442935934515457459", "⬇": "5443035053770714567",
    "⬛": "5445281270126913852", "⭐": "5442655211158020880", "🆔": "5443076405715838549",
    "🆕": "5444968063931817207", "🌐": "5442942497225483407", "🌗": "5443149845361632405",
    "🌳": "5443153264155599341", "🍎": "5442989381088486787", "🎁": "5443015473014813109",
    "🎉": "5445326874089661638", "🎟": "5442661168277663661", "🎧": "5442886873104032581",
    "🎫": "5442740363179634864", "🎭": "5442798946533553490", "🎯": "5442785696559441899",
    "🎰": "5442731232079163479", "🎲": "5442842798149641383", "🏆": "5442663350121047528",
    "🏠": "5443054239389622955", "🏪": "5443001011859921398", "🏷": "5442756211608953496",
    "🐧": "5445022927844055114", "👀": "5442732559224055987", "👁": "5442918715991567168",
    "👆": "5443113174930861462", "👍": "5442717419464343257", "👑": "5442614885710078777",
    "👤": "5443081001330843309", "👥": "5445132668553436182", "💎": "5442648377865055294",
    "💚": "5442899912624744398", "💡": "5443145636293683308", "💬": "5445354928816037772",
    "💰": "5442931059727577546", "💳": "5445381557613270986", "💵": "5443056734765622293",
    "💸": "5443129504396522346", "💻": "5443038051657885361", "📄": "5443161884154964290",
    "📅": "5443043471906613409", "📈": "5442916431068964817", "📊": "5442704676296370445",
    "📋": "5442891588978130446", "📌": "5442648197476428669", "📎": "5444980987488413110",
    "📜": "5443074159447944631", "📝": "5442613322341980971", "📡": "5442974426012363907",
    "📢": "5442824759286999281", "📣": "5442704358468792901", "📤": "5442708906839157694",
    "📥": "5442932408347305460", "📦": "5442922744670892239", "📨": "5443125046220463368",
    "📱": "5445058344144379708", "📲": "5443047796938679371", "📶": "5442746565112409990",
    "🔀": "5442889170911538178", "🔁": "5445386904847571815", "🔃": "5442918569962678163",
    "🔄": "5442921494835407389", "🔌": "5442654919100244972", "🔍": "5442837334951241781",
    "🔎": "5442862791222406369", "🔐": "5442654949165014985", "🔑": "5444967239298096727",
    "🔒": "5442779932713330401", "🔔": "5442831060004020638", "🔗": "5443085450916964336",
    "🔢": "5442849897730583719", "🔤": "5442907845429339815", "🔥": "5442903739440602089",
    "🔴": "5442828985534818737", "🔵": "5442612519183099783", "🕒": "5442722247007577983",
    "🕓": "5443031862610014850", "🕵": "5442840826759652244", "🕶": "5442989595836849937",
    "🖥": "5442614237170017372", "🗂": "5443112655239815282", "🗄": "5443108935798137700",
    "🗑": "5442895652017185757", "🗒": "5443149969915686387", "🗓": "5442853681596769773",
    "🚀": "5442659755233420198", "🚇": "5442839095887834912", "🚧": "5443074223872454810",
    "🚫": "5442701339106781343", "🛜": "5442756718415095357", "🛠": "5443033078085753205",
    "🛡": "5443007037699042360", "🟡": "5443056313858827865", "🟢": "5445277649469481978",
    "🤖": "5445112263163811861", "🤝": "5443126824336927796", "🥧": "5442962533247921674",
    "🧩": "5443066630370274694", "🧪": "5443152482471551268", "🧱": "5442968279914163432",
    "🧹": "5442916327989749260", "🧾": "5442877406996112507", "🪙": "5442863487007109511",
    "🪟": "5445205906335769874", "🪪": "5443005624654802540",

    # t.me/addemoji/dropwebpackv1 (SimpleG) — only what the new pack lacks.
    # The download heading, "Под капотом" and "Исправления" are structural, and
    # the rest appear in shipped release notes, so dropping them would break
    # re-announcing older tags.
    "🏴‍☠️": "5265145909326419576", "🧑‍💻": "5264951755329805695", "⚠️": "5265226418488385619",
    "❤️": "5264735258913314397", "👁️": "5265016038105324959",
    "🕷️": "5264936838908388851", "🎨": "5264755952065750518", "📟": "5265182931944510281",
    "😂": "5264824937830456755", "🤔": "5264857154380142241", 
    "🧼": "5265159902329871766",
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
        ## 📥 Заголовок секции
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
    """Render sections whose headers start with a PACK emoji."""
    out = []
    for header, prose in sections:
        emoji = next((c for c in PACK if header.startswith(c)), "")
        if not emoji:
            raise ValueError(
                f"release-note section header {header!r} must start with an emoji from "
                "https://t.me/addemoji/zenbot_cabinet_by_dropwebpay_bot"
            )
        title = header[len(emoji):].strip()
        lead = f"{ce(emoji)} "
        if rich:
            out.append(f"<h4>{lead}{esc(title)}</h4><p>{esc(prose)}</p>")
        else:
            out.append(f"{lead}<b>{esc(title)}</b>\n{esc(prose)}")
    return out


def manifest_notes(sections: list[tuple[str, str]]) -> list[str]:
    render_notes_sections(sections, rich=True)
    return [prose for _, prose in sections]


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
            f"<details><summary>{ce('📝')} {summary}</summary>{body}</details>"
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
    downloads = f"────────────────\n{ce('📥')} <b>Скачать:</b>\n" + "\n".join(
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
    ap.add_argument("--print-manifest-notes", action="store_true")
    args = ap.parse_args()

    tag = os.environ.get("VERSION", "").strip()
    version = tag.lstrip("v")

    if not version:
        print("::error::VERSION env is required (e.g. v0.8.4)")
        return 1

    if args.print_manifest_notes:
        _, sections = load_release_notes(tag)
        print(json.dumps(manifest_notes(sections), ensure_ascii=False))
        return 0

    is_stable = os.environ.get("IS_STABLE", "").lower() == "true"
    release_url = os.environ.get("RELEASE_URL") or f"https://github.com/{REPO}/releases/tag/{tag}"

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
         "icon_custom_emoji_id": PACK["📥"]},
        {"text": "dropweb.org", "url": "https://dropweb.org",
         "icon_custom_emoji_id": PACK["💚"]},
    ]]}
    keyboard_plain = {"inline_keyboard": [[
        {"text": "📥 Скачать", "style": "success", "url": release_url},
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
