"""مكعّباتُ الأرقام والحروف العربية لخريطة المغامرة.

صورُ المواد المورَّدة ليس فيها أرقامٌ عربية (١٢٣): «تحويل الى ارقام عربية» نفسُها
مكعّباتٌ عليها 1 2 3. فتُرسم هنا مكعّباتٌ بالأسلوب نفسه — ثلاثةٌ متراكبة، ملوّنة،
بوجهٍ وأعلى وجانب — عليها الأرقامُ والحروفُ العربية بخطّ التطبيق (Tajawal).

التشغيل من جذر تطبيق فلاتر:
    py tool/build_route_blocks.py

يكتب assets/images/subjects/ar_digits_*.png و ar_letters_*.png (512x512، خلفيةٌ شفّافة).
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / 'assets' / 'fonts' / 'Tajawal-Bold.ttf'
OUT = ROOT / 'assets' / 'images' / 'subjects'

SCALE = 2  # يُرسم بضعف المقاس ثم يُصغَّر: حوافّ ناعمة.
SIZE = 512 * SCALE

PALETTE = [
    (167, 139, 250),  # بنفسجيّ
    (110, 207, 151),  # أخضر
    (255, 167, 112),  # برتقاليّ
    (96, 165, 250),  # أزرق
    (244, 114, 182),  # ورديّ
    (250, 204, 21),  # أصفر
]

SETS = {
    'ar_digits_1': ['١', '٢', '٣'],
    'ar_digits_2': ['٤', '٥', '٦'],
    'ar_digits_3': ['٧', '٨', '٩'],
    'ar_digits_4': ['٠', '١٠', '٥'],
    'ar_letters_1': ['أ', 'ب', 'ت'],
    'ar_letters_2': ['ث', 'ج', 'ح'],
    'ar_letters_3': ['خ', 'د', 'ذ'],
    'ar_letters_4': ['ر', 'ز', 'س'],
}


def shade(color, factor):
    return tuple(max(0, min(255, int(c * factor))) for c in color)


def cube(draw, glyph_layer, x, y, edge, color, glyph, font):
    """مكعّبٌ وجهُه مربّعٌ عند (x, y) بضلع [edge]، وأعلاه وجانبُه بمنظورٍ مائل."""
    depth = edge * 0.28
    top = [(x, y), (x + depth, y - depth), (x + edge + depth, y - depth), (x + edge, y)]
    side = [(x + edge, y), (x + edge + depth, y - depth), (x + edge + depth, y + edge - depth), (x + edge, y + edge)]
    draw.polygon(top, fill=shade(color, 1.18) + (255,))
    draw.polygon(side, fill=shade(color, 0.72) + (255,))
    radius = int(edge * 0.14)
    draw.rounded_rectangle([x, y, x + edge, y + edge], radius=radius, fill=color + (255,))
    # الرمزُ في وسط الوجه، أبيض بظلٍّ ناعم.
    gd = ImageDraw.Draw(glyph_layer)
    box = gd.textbbox((0, 0), glyph, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    cx, cy = x + edge / 2 - w / 2 - box[0], y + edge / 2 - h / 2 - box[1]
    gd.text((cx + edge * 0.025, cy + edge * 0.035), glyph, font=font, fill=(0, 0, 0, 70))
    gd.text((cx, cy), glyph, font=font, fill=(255, 255, 255, 255))


def build(name, glyphs, offset):
    image = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    glyphs_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    edge = SIZE * 0.34
    # اثنان أسفلَ وواحدٌ فوقهما، كما في صورة المكعّبات المورَّدة.
    spots = [
        (SIZE * 0.10, SIZE * 0.55),
        (SIZE * 0.50, SIZE * 0.55),
        (SIZE * 0.30, SIZE * 0.17),
    ]
    # ‏يُقرأ من اليمين: الأوّلُ على المكعّب الأيمن، والثاني على الأيسر، والثالثُ
    # ‏فوقهما. وترتيبُ الرسم يبقى من اليسار: جانبُ المكعّب الأيسر لا يعلو وجهَ
    # ‏الأيمن.
    ordered = [glyphs[1], glyphs[0], glyphs[2]]
    for i, ((x, y), glyph) in enumerate(zip(spots, ordered)):
        font = ImageFont.truetype(str(FONT), int(edge * (0.62 if len(glyph) > 1 else 0.78)))
        cube(draw, glyphs_layer, x, y, edge, PALETTE[(offset + i) % len(PALETTE)], glyph, font)
        # الرمزُ يُطبع على مكعّبه قبل أن يُرسم المكعّبُ التالي فوقه.
        image.alpha_composite(glyphs_layer)
        glyphs_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    # ظلٌّ ناعمٌ تحت الكومة.
    shadow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([SIZE * 0.08, SIZE * 0.92, SIZE * 0.98, SIZE * 0.99], fill=(0, 0, 0, 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(SIZE * 0.015))
    final = Image.alpha_composite(shadow, image).resize((512, 512), Image.LANCZOS)
    final.save(OUT / f'{name}.png', optimize=True)


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    for index, (name, glyphs) in enumerate(SETS.items()):
        build(name, glyphs, index)
        print('wrote', name)
