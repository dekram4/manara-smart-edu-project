"""Draws the three icons of the kindergarten voice games (general culture).

    py tool/build_kg_game_icons.py

Writes assets/images/kg_colors.png, kg_shapes.png and kg_math.png — 512x512
RGBA, drawn at 4x and scaled down so every edge is smooth. Glossy, rounded
and bright, to sit beside the 3D icons the other home cards use.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'images'
S = 4            # supersampling
W = 512 * S


def canvas():
    return Image.new('RGBA', (W, W), (0, 0, 0, 0))


def shadow(img, offset=(0, 18), blur=26, alpha=90):
    """A soft drop shadow under everything already drawn on [img]."""
    a = img.split()[3]
    sh = Image.new('RGBA', img.size, (15, 23, 42, 0))
    sh.putalpha(a.point(lambda v: v * alpha // 255))
    sh = sh.filter(ImageFilter.GaussianBlur(blur * S))
    base = canvas()
    base.alpha_composite(sh, (offset[0] * S, offset[1] * S))
    base.alpha_composite(img)
    return base


def mix(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def radial_ball(size, color, light=(255, 255, 255)):
    """A shaded sphere: lit top-left, deeper at the rim."""
    ball = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(ball)
    steps = 60
    for i in range(steps):
        t = i / steps
        r = size / 2 * (1 - t)
        cx = size / 2 - size * 0.16 * t
        cy = size / 2 - size * 0.18 * t
        col = mix(mix(color, (0, 0, 0), 0.28), mix(color, light, 0.55), t)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (255,))
    # specular highlight
    hl = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hl)
    hd.ellipse([size * 0.22, size * 0.14, size * 0.48, size * 0.34], fill=(255, 255, 255, 170))
    hl = hl.filter(ImageFilter.GaussianBlur(size * 0.03))
    ball.alpha_composite(hl)
    return ball


def glossy_blob(img, box, color):
    x0, y0, x1, y1 = box
    size = int(x1 - x0)
    ball = radial_ball(size, color)
    img.alpha_composite(ball, (int(x0), int(y0)))


def save(img, name):
    img = img.resize((512, 512), Image.LANCZOS)
    img.save(OUT / name, optimize=True)
    print(name, (OUT / name).stat().st_size // 1024, 'KB')


# ── 1) الألوان: لوحةُ رسّام وعليها كتلُ ألوانٍ لامعة، وفرشاة ────────────────
def colors_icon():
    img = canvas()
    d = ImageDraw.Draw(img)
    # palette body
    body = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.ellipse([40 * S, 90 * S, 472 * S, 440 * S], fill=(246, 214, 160, 255))
    bd.ellipse([60 * S, 104 * S, 462 * S, 420 * S], fill=(252, 228, 186, 255))
    # thumb hole
    bd.ellipse([300 * S, 300 * S, 372 * S, 364 * S], fill=(0, 0, 0, 0))
    # notch
    bd.ellipse([400 * S, 250 * S, 520 * S, 360 * S], fill=(0, 0, 0, 0))
    hole = Image.new('L', (W, W), 255)
    hdraw = ImageDraw.Draw(hole)
    hdraw.ellipse([300 * S, 300 * S, 372 * S, 364 * S], fill=0)
    hdraw.ellipse([410 * S, 262 * S, 530 * S, 372 * S], fill=0)
    alpha = Image.composite(body.split()[3], Image.new('L', (W, W), 0), hole)
    body.putalpha(alpha)
    img.alpha_composite(body)
    blobs = [
        ((232, 30, 46), (92, 170)),
        ((250, 204, 21), (178, 128)),
        ((22, 163, 74), (270, 126)),
        ((29, 78, 216), (352, 170)),
        ((126, 34, 206), (110, 272)),
        ((249, 115, 22), (196, 300)),
    ]
    for color, (x, y) in blobs:
        glossy_blob(img, (x * S, y * S, (x + 78) * S, (y + 78) * S), color)
    # brush
    br = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    bdr = ImageDraw.Draw(br)
    bdr.line([(330 * S, 470 * S), (470 * S, 40 * S)], fill=(146, 64, 14, 255), width=22 * S)
    bdr.line([(330 * S, 470 * S), (470 * S, 40 * S)], fill=(180, 83, 9, 255), width=12 * S)
    bdr.polygon([(452 * S, 90 * S), (488 * S, 100 * S), (482 * S, 40 * S), (470 * S, 20 * S), (452 * S, 36 * S)],
                fill=(203, 213, 225, 255))
    bdr.polygon([(470 * S, 20 * S), (482 * S, 40 * S), (476 * S, 6 * S)], fill=(244, 114, 182, 255))
    img.alpha_composite(br)
    save(shadow(img), 'kg_colors.png')


# ── 2) الأشكال: مكعّبٌ وكرةٌ وهرمٌ وقطعٌ مسطّحة ─────────────────────────────
def shapes_icon():
    img = canvas()
    d = ImageDraw.Draw(img)
    # flat tiles behind
    d.rounded_rectangle([40 * S, 300 * S, 200 * S, 460 * S], radius=26 * S, fill=(56, 189, 248, 255))
    d.rounded_rectangle([52 * S, 312 * S, 188 * S, 448 * S], radius=20 * S, fill=(125, 211, 252, 255))
    d.polygon([(250 * S, 470 * S), (300 * S, 380 * S), (470 * S, 380 * S), (420 * S, 470 * S)],
              fill=(244, 114, 182, 255))
    # cube (isometric)
    cx, cy, a = 150 * S, 190 * S, 95 * S
    top = [(cx, cy - a * 0.55), (cx + a, cy - a * 0.05), (cx, cy + a * 0.45), (cx - a, cy - a * 0.05)]
    left = [(cx - a, cy - a * 0.05), (cx, cy + a * 0.45), (cx, cy + a * 1.45), (cx - a, cy + a * 0.95)]
    right = [(cx + a, cy - a * 0.05), (cx, cy + a * 0.45), (cx, cy + a * 1.45), (cx + a, cy + a * 0.95)]
    d.polygon(top, fill=(253, 224, 71, 255))
    d.polygon(left, fill=(234, 179, 8, 255))
    d.polygon(right, fill=(202, 138, 4, 255))
    # pyramid
    px, py = 380 * S, 120 * S
    d.polygon([(px, py), (px - 110 * S, py + 210 * S), (px + 5 * S, py + 250 * S)], fill=(34, 197, 94, 255))
    d.polygon([(px, py), (px + 5 * S, py + 250 * S), (px + 110 * S, py + 200 * S)], fill=(21, 128, 61, 255))
    # sphere
    ball = radial_ball(150 * S, (225, 29, 72))
    img.alpha_composite(ball, (300 * S, 250 * S))
    save(shadow(img), 'kg_shapes.png')


# ── 3) الحساب: فقاعاتٌ لامعة بعلامات + − × ÷ ───────────────────────────────
def math_icon():
    img = canvas()
    font_path = ROOT / 'assets' / 'fonts' / 'Tajawal-Bold.ttf'
    font = ImageFont.truetype(str(font_path), 150 * S)
    bubbles = [
        ('+', (232, 30, 46), (40, 40)),
        ('−', (29, 78, 216), (272, 40)),
        ('×', (22, 163, 74), (40, 272)),
        ('÷', (249, 115, 22), (272, 272)),
    ]
    for sign, color, (x, y) in bubbles:
        ball = radial_ball(200 * S, color)
        bd = ImageDraw.Draw(ball)
        bbox = bd.textbbox((0, 0), sign, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        pos = ((200 * S - tw) / 2 - bbox[0], (200 * S - th) / 2 - bbox[1])
        bd.text((pos[0] + 4 * S, pos[1] + 6 * S), sign, font=font, fill=(0, 0, 0, 70))
        bd.text(pos, sign, font=font, fill=(255, 255, 255, 255))
        img.alpha_composite(ball, (x * S, y * S))
    save(shadow(img), 'kg_math.png')


if __name__ == '__main__':
    colors_icon()
    shapes_icon()
    math_icon()
