# Final MTLauncher icon — variant D "极简气泡字":
# flauncher dark-navy background, big white bubbly "MT" with thick teal
# outline, minimal sparkle decorations. Writes the full mipmap set.
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math, os

ROOT = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res")
W = 1024

_cur = Image.open(os.path.join(ROOT, "mipmap-xxxhdpi", "ic_launcher.png")).convert("RGB")
NAVY = _cur.getpixel((6, 6))
WHITE = (255, 255, 255)
TEAL = (95, 150, 175)
F_BLACK = "C:/Windows/Fonts/seguibl.ttf"

# background: same subtle vertical gradient as make_icon_m.py
img = Image.new("RGB", (W, W))
d = ImageDraw.Draw(img)
top = tuple(max(0, c - 14) for c in NAVY)
bot = tuple(min(255, c + 10) for c in NAVY)
for y in range(W):
    t = y / W
    d.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bot)))
img = img.convert("RGBA")

# --- bubbly MT -------------------------------------------------------------
font = ImageFont.truetype(F_BLACK, 340)
tmp = Image.new("RGBA", (W, W), (0, 0, 0, 0))
td = ImageDraw.Draw(tmp)
bb = td.textbbox((0, 0), "MT", font=font)
tx = W / 2 - (bb[2] - bb[0]) / 2 - bb[0]
ty = W / 2 - (bb[3] - bb[1]) / 2 - bb[1] - 10
stroke = 36
# soft drop shadow for depth
sh = Image.new("RGBA", (W, W), (0, 0, 0, 0))
ImageDraw.Draw(sh).text((tx, ty + 16), "MT", font=font, fill=(0, 0, 0, 140),
                        stroke_width=stroke, stroke_fill=(0, 0, 0, 140))
img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(22)))
# teal outline pass
out = Image.new("RGBA", (W, W), (0, 0, 0, 0))
ImageDraw.Draw(out).text((tx, ty), "MT", font=font, fill=TEAL + (255,),
                         stroke_width=stroke, stroke_fill=TEAL + (255,))
img.alpha_composite(out.filter(ImageFilter.GaussianBlur(2)))
img.alpha_composite(out)
# white fill on top
wm = Image.new("L", (W, W), 0)
ImageDraw.Draw(wm).text((tx, ty), "MT", font=font, fill=255)
wf = Image.new("RGBA", (W, W), (0, 0, 0, 0))
wf.paste(Image.new("RGBA", (W, W), WHITE + (255,)), (0, 0), wm)
img.alpha_composite(wf)


def sparkle(d, cx, cy, r):
    q = r * 0.22
    d.polygon([(cx, cy - r), (cx + q, cy - q), (cx + r, cy), (cx + q, cy + q),
               (cx, cy + r), (cx - q, cy + q), (cx - r, cy), (cx - q, cy - q)], fill=WHITE)


# --- decorations (sparse, tucked into corners) ------------------------------
dd = ImageDraw.Draw(img)
sparkle(dd, W * 0.13, W * 0.14, 40)
sparkle(dd, W * 0.88, W * 0.13, 26)
sparkle(dd, W * 0.87, W * 0.87, 42)
sparkle(dd, W * 0.15, W * 0.86, 22)
# shooting star, top right
x0, y0, x1, y1 = W * 0.58, W * 0.10, W * 0.74, W * 0.062
dd.line([x0, y0, x1, y1], fill=WHITE, width=9)
ang = math.atan2(y1 - y0, x1 - x0)
r = 24
sparkle(dd, x1 + r * 0.4 * math.cos(ang), y1 + r * 0.4 * math.sin(ang), r)

final = img.convert("RGB")

SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for dpi, s in SIZES.items():
    out_path = os.path.join(ROOT, "mipmap-%s" % dpi, "ic_launcher.png")
    final.resize((s, s), Image.LANCZOS).save(out_path)
    print("wrote", out_path)

final.resize((256, 256), Image.LANCZOS).save(os.path.join(os.path.dirname(__file__), "preview.png"))
print("done")