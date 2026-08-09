import importlib.util
import os
import subprocess
import unicodedata
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("notify_telegram.py")
RELEASE_NOTES_PATH = SCRIPT_PATH.parent.parent / "release_notes" / "v0.8.6.md"
SPEC = importlib.util.spec_from_file_location("notify_telegram", SCRIPT_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"cannot load {SCRIPT_PATH}")
notify_telegram = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(notify_telegram)

# Derived from PACK rather than written out: the pack is swapped wholesale now
# and then, and literals here turn that into a red suite instead of a no-op.
IN_PACK = "🔄" if "🔄" in notify_telegram.PACK else next(iter(notify_telegram.PACK))
IN_PACK_2 = next(e for e in notify_telegram.PACK if e != IN_PACK)
OUTSIDE_PACK = next(
    c for c in ("🦄", "🦖", "🫠", "🧿", "🪬", "🛞") if c not in notify_telegram.PACK
)


class RenderNotesSectionsTest(unittest.TestCase):
    def test_rejects_section_headers_without_pack_prefix(self) -> None:
        for header in (
            f"{OUTSIDE_PACK} Заголовок вне пака",
            "Заголовок без эмодзи",
        ):
            with self.subTest(header=header):
                with self.assertRaisesRegex(
                    ValueError,
                    rf"{header}.*must start with an emoji",
                ):
                    notify_telegram.render_notes_sections(
                        [(header, "Текст секции")],
                        rich=True,
                    )

    def test_renders_pack_heading_as_custom_emoji_in_rich_mode(self) -> None:
        rendered = notify_telegram.render_notes_sections(
            [("🔄 Ядро mihomo 1.19.29", "Текст секции")],
            rich=True,
        )

        # Read the id from PACK rather than pinning it: the pack gets swapped
        # wholesale now and then, and a hardcoded id turns that into a red test
        # instead of the no-op it should be.
        self.assertIn(
            f'<tg-emoji emoji-id="{notify_telegram.PACK["🔄"]}">🔄</tg-emoji>',
            rendered[0],
        )
        self.assertIn("<p>Текст секции</p>", rendered[0])


class StableReleaseNotesTest(unittest.TestCase):
    def test_v086_digest_has_nine_pack_sections(self) -> None:
        _, sections = notify_telegram.load_release_notes("v0.8.6-digest")

        self.assertEqual(9, len(sections))
        self.assertEqual(
            9,
            len(notify_telegram.render_notes_sections(sections, rich=True)),
        )

    def test_manifest_notes_use_only_section_prose(self) -> None:
        notes = notify_telegram.manifest_notes(
            [
                (f"{IN_PACK} Первая секция", "Первая строка.\nВторая строка."),
                (f"{IN_PACK_2} Вторая секция", "Авторская формулировка."),
            ]
        )

        self.assertEqual(
            ["Первая строка.\nВторая строка.", "Авторская формулировка."],
            notes,
        )

    def test_v086_manifest_notes_match_curated_wording(self) -> None:
        _, sections = notify_telegram.load_release_notes("v0.8.6")

        self.assertEqual(
            ["Обновили встроенное VPN-ядро mihomo до версии 1.19.29."],
            notify_telegram.manifest_notes(sections),
        )

    def test_manifest_notes_reject_section_heading_outside_pack(self) -> None:
        with self.assertRaisesRegex(ValueError, "must start with an emoji"):
            notify_telegram.manifest_notes(
                [(f"{OUTSIDE_PACK} Заголовок вне пака", "Текст секции")]
            )

    def test_every_section_heading_starts_with_pack_emoji(self) -> None:
        _, sections = notify_telegram.load_release_notes("v0.8.6")

        self.assertEqual(1, len(sections))
        for header, _ in sections:
            self.assertTrue(
                any(header.startswith(emoji) for emoji in notify_telegram.PACK),
                header,
            )

    def test_contains_no_symbol_outside_pack(self) -> None:
        text = RELEASE_NOTES_PATH.read_text(encoding="utf-8")
        allowed_symbols = {
            char
            for emoji in notify_telegram.PACK
            for char in emoji
            if unicodedata.category(char) == "So"
        }

        self.assertEqual(
            [],
            [
                char
                for char in text
                if unicodedata.category(char) == "So" and char not in allowed_symbols
            ],
        )


class ManifestNotesCliTest(unittest.TestCase):
    def test_prints_only_utf8_json_without_reading_release_md(self) -> None:
        env = os.environ.copy()
        env["VERSION"] = "v0.8.6"

        result = subprocess.run(
            [
                "python3",
                str(SCRIPT_PATH),
                "--print-manifest-notes",
                "--release-md",
                "does-not-exist.md",
            ],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )

        self.assertEqual(0, result.returncode)
        self.assertEqual(
            '["Обновили встроенное VPN-ядро mihomo до версии 1.19.29."]\n',
            result.stdout,
        )
        self.assertEqual("", result.stderr)

    def test_requires_version(self) -> None:
        env = os.environ.copy()
        env.pop("VERSION", None)

        result = subprocess.run(
            ["python3", str(SCRIPT_PATH), "--print-manifest-notes"],
            check=False,
            capture_output=True,
            text=True,
            env=env,
        )

        self.assertNotEqual(0, result.returncode)
        self.assertIn("VERSION env is required", result.stdout)


if __name__ == "__main__":
    unittest.main()
