#!/usr/bin/env python3
"""Bold single-emblem app icon: three overlapping playing cards, fanned — representing
the three hands (back/middle/front) you split your 13 cards into — on a deep-navy felt
gradient. No detailed scene, no text, matches the SamLoc portfolio icon style."""

from PIL import Image, ImageDraw, ImageFont

SIZE = 1024
img = Image.new("RGB", (SIZE, SIZE), "#081226")
draw = ImageDraw.Draw(img)

top = (10, 24, 56)
bottom = (4, 9, 24)
for y in range(SIZE):
    t = y / SIZE
    r = int(top[0] + (bottom[0] - top[0]) * t)
    g = int(top[1] + (bottom[1] - top[1]) * t)
    b = int(top[2] + (bottom[2] - top[2]) * t)
    draw.line([(0, y), (SIZE, y)], fill=(r, g, b))

try:
    font_big = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", int(SIZE * 0.26))
except OSError:
    font_big = ImageFont.load_default()

def centered_text(d, text, font, cx, cy, fill):
    bbox = d.textbbox((0, 0), text, font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((cx - w / 2 - bbox[0], cy - h / 2 - bbox[1]), text, font=font, fill=fill)

cw, ch = SIZE * 0.46, SIZE * 0.68
cx, cy = SIZE / 2, SIZE / 2

cards = [
    # (angle, offset_x, offset_y, rank, suit, color)
    (-16, -SIZE * 0.15, SIZE * 0.03, "A", "♠", (20, 20, 24, 255)),
    (0, 0, -SIZE * 0.02, "K", "♦", (196, 30, 40, 255)),
    (16, SIZE * 0.15, SIZE * 0.03, "Q", "♣", (20, 20, 24, 255)),
]

for angle, dx, dy, rank, suit, color in cards:
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ldraw = ImageDraw.Draw(layer)
    x, y = cx + dx, cy + dy
    ldraw.rounded_rectangle(
        [x - cw / 2, y - ch / 2, x + cw / 2, y + ch / 2],
        radius=SIZE * 0.045, fill=(250, 247, 238, 255)
    )
    centered_text(ldraw, rank, font_big, x, y - SIZE * 0.14, color)
    centered_text(ldraw, suit, font_big, x, y + SIZE * 0.12, color)
    rotated = layer.rotate(-angle, resample=Image.BICUBIC, expand=False, center=(x, y))
    img.paste(rotated, (0, 0), rotated)

img.save("/Users/q/Projects/SapXam/SapXam/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
print("wrote AppIcon.png", img.size)
