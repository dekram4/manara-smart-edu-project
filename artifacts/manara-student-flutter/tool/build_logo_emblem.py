"""Cuts the Manara emblem — the lighthouse on the open book, inside its arch —
out of the platform's approved logo, on a transparent ground.

Source: `assets/icon/manara_logo_source.png`, the approved logo as supplied
(2000×2000, emblem above the name and the «تعلم بذكاء» line, on white).
Output: `assets/images/manara-logo-emblem.png`, 512×512.

The emblem alone, without the lettering: every place the app shows it already
sets the platform's name beside it in live text, so the logo's own lettering
there would say the name twice. The welcome film carries the complete logo.

── Why not just make white transparent ──
The emblem is white inside its arch — the lamp's light, the star, the ground
behind the tower. Keying out white would hollow it, and the arch is open at
its feet, so even a flood fill from the edge leaks in through those gaps. So
the emblem's silhouette is taken whole instead: its ink, closed across those
gaps and with its holes filled. Everything inside stays as drawn; only the
paper around it goes.

Run with `py tool/build_logo_emblem.py`, then `py tool/build_launcher_icon.py`
and `dart run flutter_launcher_icons`, since the launcher icon carries it too.
"""

from __future__ import annotations

import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

SOURCE = os.path.join(ROOT, "assets", "icon", "manara_logo_source.png")
OUT = os.path.join(ROOT, "assets", "images", "manara-logo-emblem.png")

# The book's lowest point is at y≈1405 of the 2000px source and the name
# starts below 1435; the cut falls in that empty band.
EMBLEM_BOTTOM = 1412
# White added below the cut, so the closing below does not meet the image
# edge — where it cannot erode back and leaves a white tab under the book.
PAD = 120
SIZE = 512


def main() -> None:
    src = Image.open(SOURCE).convert("RGB")
    width = src.width
    emblem = Image.new("RGB", (width, EMBLEM_BOTTOM + PAD), (255, 255, 255))
    emblem.paste(src.crop((0, 0, width, EMBLEM_BOTTOM)), (0, 0))

    ink = emblem.convert("L").point(lambda v: 255 if v < 215 else 0)

    # Closed at quarter size: the gaps are ~40px at full size, and a filter
    # that wide at full size is slow for no visible gain.
    small = ink.resize((width // 4, emblem.height // 4), Image.BILINEAR)
    small = small.point(lambda v: 255 if v > 40 else 0)
    closed = small.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.MinFilter(15))
    marked = closed.convert("RGB")
    ImageDraw.floodfill(marked, (0, 0), (255, 0, 0), thresh=10)
    r, g, _ = marked.split()
    outside = ImageChops.logical_and(
        r.point(lambda v: 255 if v == 255 else 0).convert("1"),
        g.point(lambda v: 255 if v == 0 else 0).convert("1"),
    )
    silhouette = ImageChops.invert(outside.convert("L"))
    silhouette = silhouette.resize(emblem.size, Image.BILINEAR)
    silhouette = silhouette.point(lambda v: 255 if v > 127 else 0)

    # The outer edge follows the ink itself; the closing only fills inside.
    alpha = ImageChops.lighter(
        ImageChops.multiply(silhouette, ink.filter(ImageFilter.MaxFilter(3))),
        silhouette.filter(ImageFilter.MinFilter(9)),
    ).filter(ImageFilter.GaussianBlur(1.0))

    cut = emblem.convert("RGBA")
    cut.putalpha(alpha)
    cut = cut.crop(alpha.point(lambda a: 255 if a > 8 else 0).getbbox())

    side = max(cut.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(cut, ((side - cut.width) // 2, (side - cut.height) // 2), cut)
    square.resize((SIZE, SIZE), Image.LANCZOS).save(OUT, optimize=True)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
