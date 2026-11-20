"""Draws the three star-dust layers of the background (assets/art/background/dust_*.png):
2560x800 transparent PNGs with small soft dots in the palette's cream and gold.
Usage: python3 tools/make_star_dust.py   (needs Pillow)"""
import random
from PIL import Image, ImageDraw, ImageFilter

COLOURS = [(255, 248, 230), (246, 226, 170), (233, 205, 140)]
LAYERS = {"dust_a": (60, 2, 6), "dust_b": (45, 2, 5), "dust_c": (30, 2, 4)}  # name: (dots, min r, max r)

for seed, (name, (count, r_min, r_max)) in enumerate(LAYERS.items()):
    rng = random.Random(seed + 1)
    glow = Image.new("RGBA", (2560, 800))
    core = Image.new("RGBA", (2560, 800))
    for _ in range(count):
        x, y, r = rng.randint(20, 2540), rng.randint(20, 780), rng.randint(r_min, r_max)
        colour = rng.choice(COLOURS)
        ImageDraw.Draw(glow).ellipse((x - r * 3, y - r * 3, x + r * 3, y + r * 3), fill=colour + (70,))
        ImageDraw.Draw(core).ellipse((x - r, y - r, x + r, y + r), fill=colour + (235,))
    glow = glow.filter(ImageFilter.GaussianBlur(6))
    glow.alpha_composite(core)
    glow.save("assets/art/background/%s.png" % name)
    print("saved", name)
