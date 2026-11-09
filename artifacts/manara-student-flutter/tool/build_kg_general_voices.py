"""Records the questions of the kindergarten quiz («أسئلة الروضة»).

    py tool/build_kg_general_voices.py [--check]

Reads every KgGeneralQuestion('<id>', KgTopic.x, '<text>', ...) from
lib/src/services/kindergarten_voice_quiz.dart — the Dart list is the single
source — and writes assets/audio/kg_games/general/<id>.mp3 in the same
Arabic voice as the numbers and the math words (VOICE_AR in
build_tracing_voices.py). Existing clips are kept; delete one to re-record it.

--check transcribes each clip back with faster-whisper (medium) and prints it
beside the text, to hear-check by eye.
"""

import asyncio
import importlib.util
import re
import sys
from pathlib import Path

import edge_tts

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'audio' / 'kg_games' / 'general'
SOURCE = ROOT / 'lib' / 'src' / 'services' / 'kindergarten_voice_quiz.dart'

spec = importlib.util.spec_from_file_location('tv', ROOT / 'tool' / 'build_tracing_voices.py')
tv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tv)


def questions():
    text = SOURCE.read_text(encoding='utf-8')
    return re.findall(r"KgGeneralQuestion\('(\w+)', KgTopic\.\w+, '([^']+)'", text)


async def record(qid, text):
    path = OUT / f'{qid}.mp3'
    if path.exists():
        return
    voice = tv.VOICE_AR
    for attempt in range(3):
        try:
            await edge_tts.Communicate(text, voice['voice'], pitch=voice['pitch'], rate=voice['rate']).save(str(path))
            print('recorded', path.name)
            return
        except Exception as error:  # noqa: BLE001 — the service drops calls now and then
            print('retry', qid, error)
            await asyncio.sleep(2)
    raise SystemExit(f'could not record {qid}')


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    found = questions()
    for qid, text in found:
        asyncio.run(record(qid, text))
    print(len(found), 'questions')
    if '--check' in sys.argv:
        from faster_whisper import WhisperModel
        model = WhisperModel('medium', device='cpu', compute_type='int8')
        for qid, text in found:
            segs, _ = model.transcribe(str(OUT / f'{qid}.mp3'), language='ar', beam_size=5)
            print(qid, '|', text, '|', ' '.join(s.text for s in segs).strip(), flush=True)


if __name__ == '__main__':
    main()
