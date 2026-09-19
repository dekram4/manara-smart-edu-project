"""Records the line each portal says when it is opened, in the welcome's voice.

The welcome the student hears first is `assets/audio/welcome.mp3`, played by
`student_startup_screen.dart`: «منارة المعرفة التعليمية ترحب بكم». It carries a
Clipchamp export tag, and its voice was identified by measurement:

  1. Transcribed offline with Whisper, so candidate voices could be made to say
     the very same sentence.
  2. That sentence rendered in every Microsoft Arabic and multilingual neural
     voice, across pitch and speed settings, and each compared with the
     original using a speaker-verification model (Resemblyzer). Calibration:
     one voice saying two different sentences scores ~0.88; two different
     voices ~0.77.
  3. `en-US-AvaMultilingualNeural` took every top place — up to 0.90 — and no
     other voice came close. At +18 Hz and -12% speed it also matches the
     original's length (2.93s against 2.88s) and median pitch (250 Hz, exactly).

The first version of these clips used `ar-SA-ZariyahNeural` raised by 35 Hz,
chosen on pitch alone. Its similarity to the welcome was 0.69 — a different
voice, which is exactly what the student heard.

The Arabic lines have since moved to a Saudi voice, `ar-SA-HamedNeural`. Ava
read them correctly but in stiff Modern Standard Arabic, which is not how
anyone speaks to a Saudi child. The lines themselves are now written in white
Saudi dialect and fully vowelled — the tashkeel is what makes the voice say
«خَلِّك» and «شُوف» as spoken dialect rather than guessing at a formal reading.
+2 Hz keeps the tone warm without the synthetic lift of a larger shift, and
-5% gives a child time to follow every word.

English still uses Ava at the welcome's settings, as before.

The text is read from `lib/src/l10n/student_strings.dart` — every
`portal.<name>.voice` key and `portal.voice.generic` — so a reworded line is
re-recorded by running this again, not by editing a second copy here.

Run with:

    py -m pip install edge-tts
    py tool/build_portal_voices.py

and commit what it writes to `assets/audio/voice/`. The app build never runs it.
"""

from __future__ import annotations

import asyncio
import os
import re

import edge_tts

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

STRINGS = os.path.join(ROOT, "lib", "src", "l10n", "student_strings.dart")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "voice")

# The welcome's own voice, as identified in the module docstring, for English;
# a native Saudi voice for Arabic (`ar-SA-ZariyahNeural` is the female
# alternative at the same settings). Keep the file naming in step with
# `StudentSoundService.portalVoiceAsset`.
WELCOME_VOICE = {"voice": "en-US-AvaMultilingualNeural", "pitch": "+18Hz", "rate": "-12%"}
SAUDI_VOICE = {"voice": "ar-SA-HamedNeural", "pitch": "+2Hz", "rate": "-5%"}
VOICES = {"ar": SAUDI_VOICE, "en": WELCOME_VOICE}

# `'portal.lesson.voice': 'text',` — the value may wrap onto the next line, and
# may be in either quote style when it contains an apostrophe.
LINE = re.compile(
    r"'portal\.(?:(?P<name>[a-z]+)\.voice|voice\.(?P<generic>generic))'\s*:\s*"
    r"(?P<quote>['\"])(?P<text>.*?)(?P=quote)\s*,",
    re.DOTALL,
)


def lines_for(block: str) -> dict[str, str]:
    found = {}
    for match in LINE.finditer(block):
        name = match.group("name") or match.group("generic")
        found[name] = match.group("text")
    return found


def read_lines() -> dict[str, dict[str, str]]:
    """The spoken lines, per language, keyed by portal name."""
    with open(STRINGS, encoding="utf-8-sig") as handle:
        source = handle.read()
    ar_start = source.index("static const _ar = ")
    en_start = source.index("static const _en = ")
    return {
        "ar": lines_for(source[ar_start:en_start]),
        "en": lines_for(source[en_start:]),
    }


async def render(text: str, language: str, path: str) -> None:
    settings = VOICES[language]
    speech = edge_tts.Communicate(
        text,
        settings["voice"],
        pitch=settings["pitch"],
        rate=settings["rate"],
    )
    await speech.save(path)


async def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    for language, lines in read_lines().items():
        if "generic" not in lines:
            raise SystemExit(f"no portal.voice.generic line for {language}")
        for name, text in sorted(lines.items()):
            path = os.path.join(OUT_DIR, f"{name}_{language}.mp3")
            await render(text, language, path)
            print(f"wrote {os.path.relpath(path, ROOT)}  {text}")


if __name__ == "__main__":
    asyncio.run(main())
