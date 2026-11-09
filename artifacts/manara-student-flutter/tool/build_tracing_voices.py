"""Records the names «قلمي السحري» says: numbers 0–100 (Arabic and English)
and the English letters A–Z.

    py tool/build_tracing_voices.py

The Arabic letters already have recordings (assets/audio/ar/). The numbers
and the English letters were spoken by the device's speech engine — and on
the many Android phones without an Arabic voice installed, the Arabic numbers
said nothing at all. These recordings replace the engine for all of them.

Voices — chosen by transcribing every clip back with Whisper:
  * English: `en-US-AvaNeural` at +18 Hz and -12% — Ava, the speaker
    `build_portal_voices.py` matched to the app's welcome, in her English-only
    voice. The multilingual Ava guessed the language of a lone letter and said
    W as French «vous»; the English-only voice cannot.
  * Arabic numbers and the maths game's words: `ar-QA-AmalNeural`, slightly
    slower for children. The multilingual voice blurred several numbers
    (ثلاثة، سبعة، تسعة، تسعة وتسعون); and of seven native Arabic voices read
    the same 20 numbers and transcribed back, Amal came out clearest (18/20,
    against 8/20 for ar-SA-ZariyahNeural) — clarity first, for a child
    learning them.
Arabic numbers are written fully vowelled, the last letter included
(tanween or fatha): transcribed back, «صِفْر» bare came out as «سبعة» and
«ثَلاثَة» as «سنة», while «صِفْرٌ» and «ثَلَاثَةٌ» came out right. English letters are written as they are said («double you», «aitch»):
a bare letter is ambiguous to any speech engine.

Writes:
    assets/audio/numbers_ar/n_<n>.mp3     0..100
    assets/audio/numbers_en/n_<n>.mp3     0..100
    assets/audio/letters_en/letter_<x>.mp3  a..z
    assets/audio/kg_games/op_*.mp3, how_much.mp3   (the maths game's equation)
"""

import asyncio
from pathlib import Path

import edge_tts

ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / 'assets' / 'audio'
VOICE_EN = {'voice': 'en-US-AvaNeural', 'pitch': '+18Hz', 'rate': '-12%'}
VOICE_AR = {'voice': 'ar-QA-AmalNeural', 'pitch': '+0Hz', 'rate': '-10%'}

KG_MATH_WORDS = {
    'op_plus': 'زائِد.',
    'op_minus': 'نَاقِصُ',
    'op_times': 'مَضْرُوبًا فِي',
    'op_divide': 'تَقْسِيمُ',
    'how_much': 'كَمْ يُسَاوِي؟',
}

# ‏أسماءُ الحروف الإنجليزية كما تُنطق.
LETTER_NAMES = [
    'ay', 'bee', 'see', 'dee', 'ee', 'eff', 'jee', 'aitch', 'eye', 'jay', 'kay', 'el', 'em',
    'en', 'oh', 'pee', 'cue', 'ar', 'ess', 'tee', 'you', 'vee', 'double you', 'ex', 'why', 'zee',
]

# ‏كلُّ عددٍ بحركة آخره كاملةً (تنوينٌ أو فتحة): بها ينطقه الصوتُ واضحاً.
# ‏«صِفْر» بلا حركة سُمع «سبعة» و«ثَلاثَة» سُمع «سنة» عند التفريغ بـWhisper،
# ‏و«صِفْرٌ» و«ثَلَاثَةٌ» سُمعا صحيحين.
_AR_UNITS = [
    'صِفْرٌ', 'وَاحِدٌ', 'اِثْنَانِ', 'ثَلَاثَةٌ', 'أَرْبَعَةٌ', 'خَمْسَةٌ', 'سِتَّةٌ', 'سَبْعَةٌ', 'ثَمَانِيَةٌ',
    # ‏وتسعةٌ وعشرةٌ وحدهما بلا تنوين: بصوت Amal سُمعتا منوّنتين «تساطر» و«آشرة»،
    # ‏وبلا تنوين «تسع» و«10» (كلُّ عددٍ جُرّب بالصيغتين وأُخذت أوضحُهما).
    'تِسْعَة',
    'عَشَرَة', 'أَحَدَ عَشَرَ', 'اِثْنَا عَشَرَ', 'ثَلَاثَةَ عَشَرَ', 'أَرْبَعَةَ عَشَرَ', 'خَمْسَةَ عَشَرَ',
    'سِتَّةَ عَشَرَ', 'سَبْعَةَ عَشَرَ', 'ثَمَانِيَةَ عَشَرَ', 'تِسْعَةَ عَشَرَ',
]
# ‏الآحادُ قبل العشرات مرفوعةٌ منوّنة: «وَاحِدٌ وَعِشْرُونَ».
_AR_UNITS_JOINED = [
    '', 'وَاحِدٌ', 'اِثْنَانِ', 'ثَلَاثَةٌ', 'أَرْبَعَةٌ', 'خَمْسَةٌ', 'سِتَّةٌ', 'سَبْعَةٌ', 'ثَمَانِيَةٌ', 'تِسْعَةٌ',
]
_AR_TENS = ['', '', 'عِشْرُونَ', 'ثَلَاثُونَ', 'أَرْبَعُونَ', 'خَمْسُونَ', 'سِتُّونَ', 'سَبْعُونَ', 'ثَمَانُونَ', 'تِسْعُونَ']

_EN_UNITS = [
    'zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven',
    'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen',
]
_EN_TENS = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety']


def arabic_words(n):
    if n == 100:
        return 'مِئَةٌ'
    if n < 20:
        return _AR_UNITS[n]
    unit, tens = n % 10, n // 10
    return _AR_TENS[tens] if unit == 0 else f'{_AR_UNITS_JOINED[unit]} وَ{_AR_TENS[tens]}'


def english_words(n):
    if n == 100:
        return 'one hundred'
    if n < 20:
        return _EN_UNITS[n]
    unit, tens = n % 10, n // 10
    return _EN_TENS[tens] if unit == 0 else f'{_EN_TENS[tens]}-{_EN_UNITS[unit]}'


def jobs():
    for n in range(101):
        yield AUDIO / 'numbers_ar' / f'n_{n}.mp3', arabic_words(n) + '.', VOICE_AR
        yield AUDIO / 'numbers_en' / f'n_{n}.mp3', english_words(n).capitalize() + '.', VOICE_EN
    for i in range(26):
        yield AUDIO / 'letters_en' / f'letter_{chr(97 + i)}.mp3', LETTER_NAMES[i].capitalize() + '.', VOICE_EN
    # ‏كلماتُ المعادلة في «لعبة الحساب» بصوت الأعداد العربية نفسه، فتُقرأ
    # ‏المسألةُ كاملة: «ثلاثة زائد اثنين، كم يساوي؟». وكلٌّ منها بالصيغة التي
    # ‏فُرِّغت صحيحةً: «ضَرْب» وحدها سُمعت «داربو» في كل صيغها، فصارت
    # ‏«مَضْرُوبًا فِي»؛ و«زائِد» تحتاج نقطتها.
    for name, text in KG_MATH_WORDS.items():
        yield AUDIO / 'kg_games' / f'{name}.mp3', text, VOICE_AR


async def record(path, text, voice, gate):
    async with gate:
        path.parent.mkdir(parents=True, exist_ok=True)
        for attempt in range(4):
            try:
                await edge_tts.Communicate(text, voice['voice'], pitch=voice['pitch'], rate=voice['rate']).save(str(path))
                return
            except Exception as error:  # الشبكةُ تنقطع أحياناً: تُعاد المحاولة.
                if attempt == 3:
                    raise
                print('retry', path.name, error)
                await asyncio.sleep(2)


async def main():
    gate = asyncio.Semaphore(6)
    work = list(jobs())
    await asyncio.gather(*(record(path, text, voice, gate) for path, text, voice in work))
    total = sum(path.stat().st_size for path, _, _ in work)
    print(f'{len(work)} clips, {total // 1024} KB')


if __name__ == '__main__':
    asyncio.run(main())
