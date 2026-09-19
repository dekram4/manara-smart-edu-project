"""Builds the launcher icon out of the app's own artwork.

The two sources are not new drawings — they are the exact images the student
already meets on the way in, so the thing they tap on the home screen is the
thing that greets them:

  * `assets/images/student_mascot.png` — the pair of reading children from the
    login screen (`StudentInteractiveMascot`).
  * `assets/images/manara-logo-mark-transparent.png` — the Manara mark from the
    welcome screen.

The composition puts the mark *in front of* the pair, centred on the line where
their hands and books already are, and sized to stop short of their outer
hands. Those hands staying visible at the left and right of the disc are what
makes the pair read as holding it; a disc wide enough to cover them would read
as a sticker pasted on top.

Two files come out, because Android needs two:

  * `assets/icon/app_icon.png` — the whole icon, background and all. This is
    what pre-Android-8 launchers and the web/Windows targets use.
  * `assets/icon/app_icon_foreground.png` — the same artwork with no
    background, drawn inside the middle 60% of the canvas. Android 8+ composites
    it over `adaptive_icon_background` and then applies the launcher's own mask
    (circle, squircle, rounded square), which crops everything outside roughly
    that middle. Anything drawn wider gets its edges shaved off by some
    launchers and not others.

`assets/icon/` is deliberately NOT in pubspec.yaml's `assets:` list. These are
build-time inputs that nothing at runtime draws, and a declared directory would
put ~1 MB of unreachable artwork into every APK.

Run with `py tool/build_launcher_icon.py`, then `dart run flutter_launcher_icons`.
Both the sources and the generated `android/app/src/main/res/**` output are
committed, so the APK build never runs this.
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

MASCOT = os.path.join(ROOT, "assets", "images", "student_mascot.png")
LOGO = os.path.join(ROOT, "assets", "images", "manara-logo-mark-transparent.png")
OUT_DIR = os.path.join(ROOT, "assets", "icon")

SIZE = 1024

# A sky that stays in one hue family top to bottom. The mascot is lime and the
# mark is teal; a light blue lets both keep their own colour instead of fighting
# a second one. It also means the flat `adaptive_icon_background` below can sit
# at this gradient's midpoint and produce the same icon on Android 8+.
SKY_TOP = (0x6F, 0xCB, 0xF2)
SKY_BOTTOM = (0xC6, 0xEE, 0xFB)
# Keep in sync with `adaptive_icon_background` in pubspec.yaml.
ADAPTIVE_BG = "#9BDDF7"

CORNER_RADIUS = int(SIZE * 0.23)

# How much of the canvas the artwork fills, for each of the two outputs.
LEGACY_CONTENT = 0.80
FOREGROUND_CONTENT = 0.60

# The mark's diameter as a fraction of the pair's width. Measured, not guessed:
# the girl's outer hand sits at x≈0.20 of the artwork and the boy's at x≈0.89,
# so 0.54 spans 0.23-0.77 and leaves both of them clear of the disc's rim.
LOGO_WIDTH_FRACTION = 0.54
# Where the disc's centre sits down the pair's height. Their open books occupy
# y 314-390 of the 560px source (0.57-0.72 of the traced artwork), and this puts
# the disc's middle on that line.
LOGO_CENTRE_Y_FRACTION = 0.64


def trimmed(path: str) -> Image.Image:
    """Loads an image cropped to its own ink.

    Both sources carry transparent padding — the mark has ~12% on its left edge
    alone. Composing against the raw canvas would place the artwork by where its
    file happens to end rather than by where it is drawn, which is how elements
    end up looking off-centre for no visible reason.
    """
    image = Image.open(path).convert("RGBA")
    box = image.getchannel("A").getbbox()
    return image.crop(box) if box else image


def scaled_to_width(image: Image.Image, width: int) -> Image.Image:
    height = max(1, round(image.height * width / image.width))
    return image.resize((width, height), Image.LANCZOS)


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius, fill=255)
    return mask


def sky(size: int) -> Image.Image:
    """The background: a vertical gradient, drawn a row at a time."""
    band = Image.new("RGB", (1, size))
    pixels = band.load()
    for y in range(size):
        t = y / (size - 1)
        pixels[0, y] = tuple(
            round(SKY_TOP[i] + (SKY_BOTTOM[i] - SKY_TOP[i]) * t) for i in range(3)
        )
    return band.resize((size, size), Image.BICUBIC).convert("RGBA")


def drop_shadow(source: Image.Image, blur: int, offset: int, opacity: int) -> Image.Image:
    """A blurred silhouette of `source`, to sit behind it.

    Built from the alpha channel rather than the colours, so a dark drawing and
    a light one cast the same shadow.
    """
    shadow = Image.new("RGBA", source.size, (0, 0, 0, 0))
    shadow.putalpha(source.getchannel("A").point(lambda a: a * opacity // 255))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    padded = Image.new("RGBA", source.size, (0, 0, 0, 0))
    padded.paste(shadow, (0, offset), shadow)
    return padded


def halo(size: int, centre: tuple[int, int], radius: int) -> Image.Image:
    """A soft white glow, to lift the artwork off the sky.

    Drawn as concentric rings of rising alpha and then blurred — a plain disc
    would leave a visible edge at this scale.
    """
    layer = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(layer)
    steps = 48
    for i in range(steps, 0, -1):
        r = radius * i / steps
        alpha = round(150 * (1 - i / steps) ** 1.6)
        draw.ellipse(
            (centre[0] - r, centre[1] - r, centre[0] + r, centre[1] + r),
            fill=(255, 255, 255, alpha),
        )
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.12))


def compose(content_fraction: float, with_background: bool) -> Image.Image:
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    if with_background:
        canvas = Image.composite(
            sky(SIZE), canvas, rounded_mask(SIZE, CORNER_RADIUS)
        )

    content = round(SIZE * content_fraction)
    pair = scaled_to_width(trimmed(MASCOT), content)
    # The pair is taller than it is wide; if that height overflows the content
    # box, width is not the constraint and the fit has to be taken from height.
    if pair.height > content:
        pair = pair.resize(
            (max(1, round(pair.width * content / pair.height)), content), Image.LANCZOS
        )

    pair_x = (SIZE - pair.width) // 2
    pair_y = (SIZE - pair.height) // 2

    glow = halo(
        SIZE,
        (SIZE // 2, pair_y + pair.height // 2),
        round(max(pair.width, pair.height) * 0.62),
    )
    canvas.alpha_composite(glow)

    pair_layer = _placed(pair, pair_x, pair_y)
    canvas.alpha_composite(
        drop_shadow(
            pair_layer,
            blur=round(SIZE * 0.018),
            offset=round(SIZE * 0.012),
            opacity=70,
        )
    )
    canvas.alpha_composite(pair_layer)

    # The mark, in front, on the line where their hands already are.
    mark = scaled_to_width(trimmed(LOGO), round(pair.width * LOGO_WIDTH_FRACTION))
    mark_x = (SIZE - mark.width) // 2
    mark_y = round(pair_y + pair.height * LOGO_CENTRE_Y_FRACTION) - mark.height // 2

    # A white disc under the mark. The mark's strokes are teal on nothing, and
    # laid straight over the lime sweaters they lose most of their contrast at
    # 48px — which is the size that actually matters here.
    plate_r = round(max(mark.width, mark.height) * 0.56)
    plate_c = (mark_x + mark.width // 2, mark_y + mark.height // 2)
    plate = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(plate).ellipse(
        (
            plate_c[0] - plate_r,
            plate_c[1] - plate_r,
            plate_c[0] + plate_r,
            plate_c[1] + plate_r,
        ),
        fill=(255, 255, 255, 255),
    )
    canvas.alpha_composite(
        drop_shadow(plate, blur=round(SIZE * 0.014), offset=round(SIZE * 0.010), opacity=90)
    )
    canvas.alpha_composite(plate)
    canvas.alpha_composite(_placed(mark, mark_x, mark_y))

    if with_background:
        # Re-apply the rounded mask: the halo and the shadows are drawn on the
        # full square and would otherwise bleed past the corners.
        canvas.putalpha(
            Image.composite(
                canvas.getchannel("A"),
                Image.new("L", (SIZE, SIZE), 0),
                rounded_mask(SIZE, CORNER_RADIUS),
            )
        )

    return canvas


def _placed(image: Image.Image, x: int, y: int) -> Image.Image:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    layer.paste(image, (x, y), image)
    return layer


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)

    full = compose(LEGACY_CONTENT, with_background=True)
    full.save(os.path.join(OUT_DIR, "app_icon.png"))

    foreground = compose(FOREGROUND_CONTENT, with_background=False)
    foreground.save(os.path.join(OUT_DIR, "app_icon_foreground.png"))

    print(f"wrote {OUT_DIR}/app_icon.png             {full.size}")
    print(f"wrote {OUT_DIR}/app_icon_foreground.png  {foreground.size}")
    print(f"adaptive_icon_background should be {ADAPTIVE_BG}")


if __name__ == "__main__":
    main()
