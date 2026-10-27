"""Pack Blender-rendered frames into U9-compatible 32×48 spritesheet with nearest downscale."""
from PIL import Image
import os
import sys

FRAME_W, FRAME_H = 32, 48
COLS, ROWS = 4, 6  # idle 3 faces + walk 3 faces

def main():
    out_dir = os.environ.get(
        "U11_OUT",
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "u11"),
    )
    manifest = os.path.join(out_dir, "frames_manifest.txt")
    sheet_path = os.path.join(out_dir, "you-sheet.png")
    with open(manifest) as f:
        paths = [ln.strip() for ln in f if ln.strip()]
    if len(paths) != COLS * ROWS:
        raise SystemExit(f"expected {COLS*ROWS} frames, got {len(paths)}")

    sheet = Image.new("RGBA", (FRAME_W * COLS, FRAME_H * ROWS), (0, 0, 0, 0))
    for i, p in enumerate(paths):
        im = Image.open(p).convert("RGBA")
        # nearest downscale to logical frame
        im = im.resize((FRAME_W, FRAME_H), Image.NEAREST)
        col = i % COLS
        row = i // COLS
        sheet.paste(im, (col * FRAME_W, row * FRAME_H), im)
    sheet.save(sheet_path, "PNG")
    print("WROTE", sheet_path, sheet.size)
    # also write a 4× preview strip of idle-down for docs
    preview = Image.new("RGBA", (FRAME_W * COLS, FRAME_H), (0, 0, 0, 0))
    for col in range(COLS):
        cell = sheet.crop((col * FRAME_W, 0, (col + 1) * FRAME_W, FRAME_H))
        preview.paste(cell, (col * FRAME_W, 0), cell)
    preview_path = os.path.join(out_dir, "you-idle-down-preview.png")
    preview.save(preview_path, "PNG")
    print("PREVIEW", preview_path)

if __name__ == "__main__":
    main()
