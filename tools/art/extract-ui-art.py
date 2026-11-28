#!/usr/bin/env python3
"""
extract-ui-art: cuts the UI art out of the style sheet (assets/concept/style-sheet.png), with
free local AI models, and packs it into atlases Roblox can show with ImageRectOffset/Size.

  1. crop each element (boxes below), whiten neighbours touching the crop edge
  2. upscale x4 with Real-ESRGAN (realesrgan-x4plus-anime)
  3. remove the white background: rembg isnet-anime (logo) or a border flood "colour to alpha"
     that keeps enclosed whites (white letters, the gear) and turns glows into transparency
  4. pack into assets/ui/{logo,ui-atlas,creatures-atlas}.png (1024 px max: Roblox's limit)
  5. write src/client/UI/ArtSprites.luau (sprite rectangles, generated)

Setup once: tools/art/setup.sh. Run: make ui-art (then make format).
The three PNGs must be uploaded to Roblox by the owner (Studio > Asset Manager > Import);
their image ids go in src/client/UI/Art.luau.
"""
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.environ.get("COMET_ART_TOOLS", os.path.expanduser("~/.cache/comet-raiders-art"))
SHEET = os.path.join(REPO, "assets", "concept", "style-sheet.png")
OUT = os.path.join(REPO, "assets", "ui")
WORK = os.path.join(REPO, "build", "ui-art")
LUAU = os.path.join(REPO, "src", "client", "UI", "ArtSprites.luau")
ATLAS_SIZE = 1024
PADDING = 4

# Which atlas each sprite goes to (the logo is alone: it needs the full resolution).
def atlas_of(name: str) -> str:
    if name == "logo":
        return "Logo"
    if name.startswith("starling-") or name.startswith("shard-"):
        return "Creatures"
    return "Ui"

ITEMS = {
    "logo": ((24, 8, 456, 302), "rembg", 1024),
    "play": ((16, 706, 238, 800), "flood", 500),
    "shop": ((15, 798, 240, 895), "flood", 500),
    "icon-settings": ((254, 705, 336, 789), "flood", 256),
    "icon-stats": ((336, 705, 415, 789), "flood", 256),
    "icon-gifts": ((416, 702, 499, 790), "flood", 256),
    "icon-index": ((255, 804, 338, 891), "flood", 256),
    "icon-top": ((337, 804, 418, 891), "flood", 256),
    "icon-events": ((417, 801, 504, 893), "flood", 256),
    "coin": ((541, 683, 632, 784), "circle", 192),
    "plus": ((800, 683, 884, 784), "circle", 192),
    "starling-1": ((13, 337, 229, 561), "flood", 330),
    "starling-2": ((223, 359, 423, 561), "flood", 330),
    "starling-3": ((421, 362, 626, 561), "flood", 330),
    "starling-4": ((622, 342, 829, 561), "flood", 330),
    "starling-5": ((822, 356, 1032, 561), "flood", 330),
    "starling-6": ((1027, 355, 1272, 561), "flood", 330),
    "shard-1": ((1299, 354, 1431, 443), "flood", 168),
    "shard-2": ((1419, 336, 1531, 443), "flood", 168),
    "shard-3": ((1538, 336, 1644, 443), "flood", 168),
    "shard-4": ((1297, 490, 1431, 619), "flood", 168),
    "shard-5": ((1419, 494, 1537, 619), "flood", 168),
    "shard-6": ((1529, 498, 1659, 619), "flood", 168),
}

def flood_cutout(rgb: np.ndarray, light: float = 120.0) -> np.ndarray:
    """White background -> alpha, only where connected to the border (enclosed whites stay)."""
    a = rgb.astype(np.float64)
    d = (255.0 - a).max(axis=2)
    lab, _ = ndimage.label(d < light)
    border = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    outer = np.isin(lab, border[border != 0])
    alpha = np.ones(d.shape)
    alpha[outer] = np.clip(d[outer] / light, 0, 1) ** 0.85
    safe = np.maximum(alpha, 1e-3)[..., None]
    fg = np.where(outer[..., None], 255.0 - (255.0 - a) / safe, a)
    fg = np.clip(fg, 0, 255)
    alpha[alpha < 0.03] = 0
    return np.dstack([fg, alpha * 255]).astype(np.uint8)

def isolate(crop: Image.Image) -> Image.Image:
    """Whitens shapes that touch the crop edge (neighbours, section titles, labels), except the
    main (largest) shape, which may legitimately touch it with its glow."""
    a = np.asarray(crop).astype(np.int32)
    ink = (255 - a).max(axis=2) > 18
    lab, n = ndimage.label(ndimage.binary_dilation(ink, iterations=1))
    if n == 0:
        return crop
    sizes = ndimage.sum(ink, lab, range(1, n + 1))
    main = int(np.argmax(sizes)) + 1
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    drop = [int(v) for v in edge if v not in (0, main)]
    out = a.copy()
    out[np.isin(lab, drop)] = 255
    return Image.fromarray(out.astype(np.uint8), "RGB")

def circle_only(crop: Image.Image) -> Image.Image:
    """Round gold buttons overlapping a bar: keep the disc around the gold pixels (plus its outline)."""
    a = np.asarray(crop).astype(np.int32)
    gold = (a[..., 0] > 200) & (a[..., 1] > 120) & (a[..., 2] < 110)
    lab, n = ndimage.label(gold)
    sizes = ndimage.sum(gold, lab, range(1, n + 1))
    ys, xs = np.nonzero(lab == int(np.argmax(sizes)) + 1)
    cy, cx = (ys.min() + ys.max()) / 2, (xs.min() + xs.max()) / 2
    radius = max(ys.max() - ys.min(), xs.max() - xs.min()) / 2 + 3.5
    yy, xx = np.mgrid[0 : a.shape[0], 0 : a.shape[1]]
    out = a.copy()
    out[(yy - cy) ** 2 + (xx - cx) ** 2 > radius**2] = 255
    return Image.fromarray(out.astype(np.uint8), "RGB")

def trim(im: Image.Image, pad: int = 6) -> Image.Image:
    bb = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if not bb:
        return im
    x0, y0, x1, y1 = bb
    return im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)))


def cut_all() -> dict:
    shutil.rmtree(WORK, ignore_errors=True)
    os.makedirs(os.path.join(WORK, "in"))
    os.makedirs(os.path.join(WORK, "up"))
    sheet = Image.open(SHEET).convert("RGB")
    for name, (box, method, _) in ITEMS.items():
        crop = isolate(sheet.crop(box))
        if method == "circle":
            crop = circle_only(crop)
        # White margin so the upscaler and the flood fill see background all around.
        framed = Image.new("RGB", (crop.width + 16, crop.height + 16), (255, 255, 255))
        framed.paste(crop, (8, 8))
        framed.save(os.path.join(WORK, "in", name + ".png"))
    esrgan = os.path.join(ART, "esrgan")
    subprocess.run(
        [os.path.join(esrgan, "realesrgan-ncnn-vulkan"), "-i", os.path.join(WORK, "in"),
         "-o", os.path.join(WORK, "up"), "-n", "realesrgan-x4plus-anime", "-s", "4", "-f", "png"],
        cwd=esrgan, check=True, capture_output=True,
    )
    session = None
    sprites = {}
    for name, (_, method, size) in ITEMS.items():
        up = Image.open(os.path.join(WORK, "up", name + ".png")).convert("RGB")
        if method == "rembg":
            from rembg import new_session, remove

            session = session or new_session("isnet-anime")
            cut = remove(up, session=session, post_process_mask=True).convert("RGBA")
        else:  # "flood" and "circle" (already isolated on white)
            cut = Image.fromarray(flood_cutout(np.asarray(up)), "RGBA")
        cut = trim(cut)
        cut.thumbnail((size, size), Image.LANCZOS)
        cut.save(os.path.join(WORK, name + ".png"))
        sprites[name] = cut
    return sprites


def pack(sprites: dict) -> dict:
    """Shelf packing, tallest first. Returns {name: (atlas, x, y, w, h)}."""
    rects = {}
    for atlas in ("Logo", "Ui", "Creatures"):
        names = sorted((n for n in sprites if atlas_of(n) == atlas), key=lambda n: -sprites[n].height)
        x = y = shelf = 0
        placed = []
        for name in names:
            im = sprites[name]
            if x + im.width > ATLAS_SIZE:
                x, y, shelf = 0, y + shelf + PADDING, 0
            placed.append((name, x, y))
            x += im.width + PADDING
            shelf = max(shelf, im.height)
        height = y + shelf
        assert height <= ATLAS_SIZE, f"{atlas} atlas overflows ({height} px): reduce sprite sizes"
        width = max(x + sprites[n].width for n, x, _ in placed)
        canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        for name, px, py in placed:
            canvas.alpha_composite(sprites[name], (px, py))
            rects[name] = (atlas, px, py, sprites[name].width, sprites[name].height)
        file = {"Logo": "logo.png", "Ui": "ui-atlas.png", "Creatures": "creatures-atlas.png"}[atlas]
        canvas.save(os.path.join(OUT, file), optimize=True)
        print(f"{file}: {canvas.width}x{canvas.height}, {len(placed)} sprites")
    return rects


def write_luau(rects: dict) -> None:
    lines = [
        "--!strict",
        "--[[",
        "\tArtSprites — GENERATED by tools/art/extract-ui-art.py (make ui-art). Do not edit by hand.",
        "\tWhere each sprite of the style sheet sits in its atlas image (pixels). Ids: UI/Art.",
        "]]",
        "",
        "export type Sprite = {",
        "\tatlas: string,",
        "\tx: number,",
        "\ty: number,",
        "\tw: number,",
        "\th: number,",
        "}",
        "",
        "local sprites: { [string]: Sprite } = {",
    ]
    for name in sorted(rects):
        atlas, x, y, w, h = rects[name]
        lines.append(f'\t["{name}"] = {{ atlas = "{atlas}", x = {x}, y = {y}, w = {w}, h = {h} }},')
    lines += ["}", "", "return table.freeze(sprites)", ""]
    with open(LUAU, "w") as handle:
        handle.write("\n".join(lines))
    print(f"wrote {os.path.relpath(LUAU, REPO)}")


def main() -> None:
    if not os.path.exists(os.path.join(ART, "venv")) or sys.prefix != os.path.join(ART, "venv"):
        sys.exit(f"run with {ART}/venv/bin/python (tools/art/setup.sh installs it): make ui-art")
    os.makedirs(OUT, exist_ok=True)
    write_luau(pack(cut_all()))


if __name__ == "__main__":
    main()
