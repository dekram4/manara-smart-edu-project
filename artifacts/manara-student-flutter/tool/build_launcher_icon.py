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

**No background, no frame.** The icon used to sit on a rounded sky-blue square
with a white glow behind the pair. On the home screen that read as the
characters shut inside a blue box with a hard edge, so both are gone: the
artwork is cut out on transparency and is itself the icon's shape.

Two files come out, because Android needs two:

  * `assets/icon/app_icon.png` — the whole icon, used by pre-Android-8
    launchers. With nothing to frame, the artwork runs almost edge to edge.
  * `assets/icon/app_icon_foreground.png` — the adaptive icon's foreground.
    Android 8+ composites it over `adaptive_icon_background` (transparent, see
    pubspec.yaml) and clips it with the launcher's own mask — a circle, a
    squircle, a rounded square. Every one of those masks contains the 72dp
    circle at the middle of the 108dp canvas, so the artwork is sized to keep
    its whole silhouette inside that circle, and no launcher shaves a foot or a
    hat off it. `adaptive_icon_foreground_inset` is 0 so this file's own
    margins are the only ones — the generator's default 16% inset on top of
    them is what made the characters so small before.

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

# The pair's height as a fraction of the canvas, for each output.
#
# The legacy icon was 0.80 inside a frame. With the frame gone it is 0.98 —
# 22% larger, just short of the edge so resampling never shaves a pixel off.
LEGACY_CONTENT = 0.98
# The adaptive foreground was 0.60 of an image the generator then inset by 16%
# per side: 0.60 x 0.68 = 0.41 of the launcher's canvas. It is now 0.50 with no
# inset — 22% larger. That is also as large as it can go: the silhouette's
# farthest pixel (the bench's corners) lies 0.62 of the pair's height from its
# centre, so at 0.50 it reaches 0.31 of the canvas, inside the 0.333 radius of
# the 72dp circle every launcher mask contains.
FOREGROUND_CONTENT = 0.50

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


def compose(content_fraction: float) -> Image.Image:
    """The pair holding the mark, centred on a transparent canvas."""
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

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

    # No halo and no shadow behind the pair. Both were there to lift it off the
    # sky, and on a transparent icon they would be a grey smudge on whatever
    # wallpaper the student has — the launcher draws its own shadow.
    canvas.alpha_composite(_placed(pair, pair_x, pair_y))

    # The mark, in front, on the line where their hands already are.
    mark = scaled_to_width(trimmed(LOGO), round(pair.width * LOGO_WIDTH_FRACTION))
    mark_x = (SIZE - mark.width) // 2
    mark_y = round(pair_y + pair.height * LOGO_CENTRE_Y_FRACTION) - mark.height // 2

    # A white disc under the mark. It is part of the mark rather than a
    # background: the mark's strokes are teal on nothing, and laid straight
    # over the lime sweaters they lose most of their contrast at 48px — which
    # is the size that actually matters here. Its shadow falls on the pair, not
    # past it, so it stays.
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

    return canvas


def _placed(image: Image.Image, x: int, y: int) -> Image.Image:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    layer.paste(image, (x, y), image)
    return layer


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)

    full = compose(LEGACY_CONTENT)
    full.save(os.path.join(OUT_DIR, "app_icon.png"))

    foreground = compose(FOREGROUND_CONTENT)
    foreground.save(os.path.join(OUT_DIR, "app_icon_foreground.png"))

    print(f"wrote {OUT_DIR}/app_icon.png             {full.size}")
    print(f"wrote {OUT_DIR}/app_icon_foreground.png  {foreground.size}")


if __name__ == "__main__":
    main()
