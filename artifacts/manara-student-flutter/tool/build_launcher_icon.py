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

**No background at all.** The icon is the two characters and the mark, cut
out, with every other pixel at alpha 0 — no colour, no square, no frame.

That is why there is only one output and no Android adaptive icon. An adaptive
icon always has a background layer, and when that layer is transparent some
launchers (tablets, Samsung One UI) fill it with black, which is what the
previous attempt at a frameless icon showed. So `pubspec.yaml` asks for the
plain `image_path` icon only, and the adaptive resources are removed.

The one thing Android may still add is outside the app's control: on Android
8+, a launcher is free to put a legacy icon inside its own shape (Pixel's white
circle, Samsung's "icon frames" setting). Where the launcher shows icons as
they are, this one appears with nothing behind it.

The characters stand out in 3D from a tight shadow dropped just below them. It
hugs the silhouette closely, so it reads as depth rather than as a smudge
behind the artwork.

Output: `assets/icon/app_icon.png`. `assets/icon/` is deliberately NOT in
pubspec.yaml's `assets:` list — it is a build-time input nothing at runtime
draws.

Run with `py tool/build_launcher_icon.py`, then `dart run flutter_launcher_icons`.
Both the source and the generated `android/app/src/main/res/**` output are
committed, so the APK build never runs this.
"""

from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

MASCOT = os.path.join(ROOT, "assets", "images", "student_mascot.png")
LOGO = os.path.join(ROOT, "assets", "images", "manara-logo-mark-transparent.png")
OUT = os.path.join(ROOT, "assets", "icon", "app_icon.png")

SIZE = 1024

# The pair's height as a fraction of the canvas: as large as it can be while
# the shadow below the bench still fits inside the image.
CONTENT = 0.94

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


def _placed(image: Image.Image, x: int, y: int) -> Image.Image:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    layer.paste(image, (x, y), image)
    return layer


def compose() -> Image.Image:
    """The pair holding the mark, with its shadow, on a fully transparent canvas."""
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    content = round(SIZE * CONTENT)
    pair = scaled_to_width(trimmed(MASCOT), content)
    # The pair is taller than it is wide; if that height overflows the content
    # box, width is not the constraint and the fit has to be taken from height.
    if pair.height > content:
        pair = pair.resize(
            (max(1, round(pair.width * content / pair.height)), content), Image.LANCZOS
        )

    shadow_offset = round(pair.height * 0.022)
    pair_x = (SIZE - pair.width) // 2
    # Lifted by half the shadow's drop, so artwork and shadow together are
    # centred rather than the shadow hanging off the bottom edge.
    pair_y = (SIZE - pair.height) // 2 - shadow_offset // 2

    pair_layer = _placed(pair, pair_x, pair_y)
    canvas.alpha_composite(
        drop_shadow(
            pair_layer,
            blur=round(pair.height * 0.012),
            offset=shadow_offset,
            opacity=110,
        )
    )
    canvas.alpha_composite(pair_layer)

    # The mark, in front, on the line where their hands already are.
    mark = scaled_to_width(trimmed(LOGO), round(pair.width * LOGO_WIDTH_FRACTION))
    mark_x = (SIZE - mark.width) // 2
    mark_y = round(pair_y + pair.height * LOGO_CENTRE_Y_FRACTION) - mark.height // 2

    # A white disc under the mark. It is part of the mark, not a background:
    # the mark's strokes are teal on nothing, and laid straight over the lime
    # sweaters they lose most of their contrast at 48px — the size that
    # matters here. It sits entirely on the pair, never past it.
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
        drop_shadow(plate, blur=round(SIZE * 0.012), offset=round(SIZE * 0.010), opacity=90)
    )
    canvas.alpha_composite(plate)
    canvas.alpha_composite(_placed(mark, mark_x, mark_y))

    return canvas


def main() -> None:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    compose().save(OUT)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
