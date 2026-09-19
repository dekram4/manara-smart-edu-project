"""Records the line each portal says when it is opened.

The welcome the student hears first (`assets/audio/welcome.mp3`) is not the
device's speech engine — it is a clip exported from Clipchamp, whose voices are
Microsoft's neural voices. The portal lines used to go through `flutter_tts`
instead, which hands the text to whatever engine the phone ships with. On most
phones that engine has no Arabic voice worth the name, and the result was the
robotic reading that sounded nothing like the greeting before it.

So the lines are now recorded too, from the same family of voices, and played
back exactly the way the welcome is. Nothing about how they sound depends on
the device any more.

The voice was matched by measurement, not by ear alone:

  * `welcome.mp3` has a median pitch of ~254 Hz, 20th-80th percentile 225-291.
  * `ar-SA-ZariyahNeural` — the Saudi voice in that family — sits at ~205 Hz.
  * Raised by 35 Hz it lands on 222-291, the same band as the welcome.

A touch slower than the default, for a young listener.

The English lines use `en-US-AnaNeural`, which is a child's voice already and
needs no adjustment.

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

# Per language: the voice, and how it is adjusted. See the module docstring for
# where the Arabic numbers come from. Keep the file naming in step with
# `StudentSoundService._portalVoiceAsset`.
VOICES = {
    "ar": {"voice": "ar-SA-ZariyahNeural", "pitch": "+35Hz", "rate": "-8%"},
    "en": {"voice": "en-US-AnaNeural", "pitch": "+0Hz", "rate": "-5%"},
}

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
