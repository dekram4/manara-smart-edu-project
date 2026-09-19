"""RETIRED — do not run. The Arabic clips are now supplied recordings.

The Arabic lines in `assets/audio/voice/` were replaced by recordings produced
the same way as the hub's welcome (`manara-arabic-student-welcome.mp3`), so the
greeting and the cards are one voice. Running this would write edge-tts clips
over them. It therefore stops before doing anything unless given `--allow`,
and even then it never writes any file in `SUPPLIED` below.

The notes that follow describe how the earlier clips were made.

Records the line each portal says when it is opened, in the welcome's voice.

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

The same voice and settings read the English lines: Ava is natively English,
so the two languages now also sound like one speaker.

The second greeting — `manara-arabic-student-welcome.mp3`, spoken on the hub
once the path is chosen — is the same speaker. Transcribed, it is «مرحباً يا
بطل، أهلاً بك في منصة منارة المعرفة، سعداء جداً بانضمامك إلينا، هيا نبدأ رحلة
التعلم والمغامرة», in Modern Standard Arabic, at a median pitch of 250 Hz —
the very pitch Ava reaches at the settings below. Both greetings are formal
Arabic, so these lines are too.

A Saudi-dialect version in `ar-SA-HamedNeural` was tried and dropped: a
different speaker from both greetings, which is the mismatch this whole script
exists to prevent.

**Pronunciation comes from the tashkeel.** Every Arabic line is fully
vowelled — case endings, hamzas and shaddas written out — except the last
letter of a word the voice pauses on, which is left bare so the engine makes
its own natural pause there. Checked by transcribing each render back with
Whisper: a written pausal sukun was what broke words («الصَّعْبَةْ» came back
as «الصعبت», «رَائِعْ» as «رع», «بَطَلْ» as «بط»), and all three read cleanly
once that sukun was dropped («رَائِعٌ» keeps its tanween for the same reason).

The text is read from `lib/src/l10n/student_strings.dart` — every
`portal.<name>.voice` key, `portal.voice.generic`, and `path.voice` for the
path-choosing screen (recorded as `path_<language>.mp3`) — so a reworded line is
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
import sys

import edge_tts

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

STRINGS = os.path.join(ROOT, "lib", "src", "l10n", "student_strings.dart")
OUT_DIR = os.path.join(ROOT, "assets", "audio", "voice")

# The welcome's own voice, as identified in the module docstring, for both
# languages. Keep the file naming in step with
# `StudentSoundService.portalVoiceAsset`.
WELCOME_VOICE = {"voice": "en-US-AvaMultilingualNeural", "pitch": "+18Hz", "rate": "-12%"}
VOICES = {"ar": WELCOME_VOICE, "en": WELCOME_VOICE}

# Supplied recordings. Never written by this script, with or without --allow.
SUPPLIED = {
    "path_ar",
    "lesson_ar",
    "tutor_ar",
    "cinema_ar",
    "games_ar",
    "meeting_ar",
    "chat_ar",
    "challenge_ar",
    "solver_ar",
    "quiz_ar",
}

# `'portal.lesson.voice': 'text',` — the value may wrap onto the next line, and
# may be in either quote style when it contains an apostrophe.
LINE = re.compile(
    r"'(?:portal\.(?:(?P<name>[a-z]+)\.voice|voice\.(?P<generic>generic))"
    r"|(?P<path>path)\.voice)'\s*:\s*"
    r"(?P<quote>['\"])(?P<text>.*?)(?P=quote)\s*,",
    re.DOTALL,
)


def lines_for(block: str) -> dict[str, str]:
    found = {}
    for match in LINE.finditer(block):
        name = match.group("name") or match.group("generic") or match.group("path")
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
    if "--allow" not in sys.argv[1:]:
        raise SystemExit(
            "build_portal_voices.py is retired: the Arabic clips are supplied "
            "recordings. Pass --allow only to re-render a clip that is not one "
            "of them (see SUPPLIED)."
        )
    os.makedirs(OUT_DIR, exist_ok=True)
    for language, lines in read_lines().items():
        if "generic" not in lines:
            raise SystemExit(f"no portal.voice.generic line for {language}")
        for name, text in sorted(lines.items()):
            if f"{name}_{language}" in SUPPLIED:
                continue
            path = os.path.join(OUT_DIR, f"{name}_{language}.mp3")
            await render(text, language, path)
            print(f"wrote {os.path.relpath(path, ROOT)}  {text}")


if __name__ == "__main__":
    asyncio.run(main())
