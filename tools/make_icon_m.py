# Generate MTLauncher launcher icon: striped glowing "M" on dark navy,
# matching the original FLauncher "F" design language (stripes + glow + teal accent).
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res")
SRC = os.path.join(ROOT, "mipmap-xxxhdpi", "ic_launcher.png")

orig = Image.open(SRC).convert("RGB")
bg_color = orig.getpixel((6, 6))
print("sampled bg:", bg_color)

W = 1024
img = Image.new("RGB", (W, W), bg_color)
d = ImageDraw.Draw(img)

# subtle vertical gradient for depth (slightly lighter center band)
top = tuple(max(0, c - 14) for c in bg_color)
bot = tuple(min(255, c + 10) for c in bg_color)
for y in range(W):
    t = y / W
    d.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bot)))

FONT = "C:/Windows/Fonts/impact.ttf"


def fit_font(text, target_w):
    size = 100
    f = ImageFont.truetype(FONT, size)
    w = d.textlength(text, font=f)
    return ImageFont.truetype(FONT, int(size * target_w / w))


font = fit_font("M", 590)
bbox = d.textbbox((0, 0), "M", font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
x0 = (W - tw) // 2 - bbox[0]
y0 = (W - th) // 2 - bbox[1] - 20  # optically slightly above center

# letter mask, then horizontal scanline stripes
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).text((x0, y0), "M", font=font, fill=255)

striped = Image.new("L", (W, W), 0)
sd = ImageDraw.Draw(striped)
bx = mask.getbbox()  # (left, top, right, bottom)
bands = Image.new("L", (W, W), 0)
bd = ImageDraw.Draw(bands)
band, gap = 24, 11
y = bx[1]
while y < bx[3]:
    bd.rectangle([bx[0], y, bx[2], min(y + band, bx[3]) - 1], fill=255)
    y += band + gap
striped = ImageChops.multiply(mask, bands)  # stripes clipped to the letter

letter = Image.new("RGBA", (W, W), (0, 0, 0, 0))
white = Image.new("RGBA", (W, W), (240, 244, 248, 255))
letter.paste(white, (0, 0), striped)

# glow: blur of striped letter composited under it
glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
glow.paste(white, (0, 0), striped)
glow = glow.filter(ImageFilter.GaussianBlur(16))
img = Image.alpha_composite(img.convert("RGBA"), glow)
img = Image.alpha_composite(img, letter)

# teal L-bracket accent overlapping the M's left stem (echoes the original F)
teal = (95, 150, 175, 255)
acc = Image.new("RGBA", (W, W), (0, 0, 0, 0))
ad = ImageDraw.Draw(acc)
lx = x0 + int(tw * 0.145)  # inside left stem
ly = y0 + int(th * 0.38)
ad.rectangle([lx, ly, lx + 26, ly + 210], fill=teal)            # vertical bar
ad.rectangle([lx, ly + 184, lx + 150, ly + 210], fill=teal)     # horizontal foot
acc_glow = acc.filter(ImageFilter.GaussianBlur(10))
img = Image.alpha_composite(img, acc_glow)
img = Image.alpha_composite(img, acc)

final = img.convert("RGB")

SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for dpi, s in SIZES.items():
    out = os.path.join(ROOT, "mipmap-%s" % dpi, "ic_launcher.png")
    final.resize((s, s), Image.LANCZOS).save(out)
    print("wrote", out)

final.resize((256, 256), Image.LANCZOS).save(os.path.join(os.path.dirname(__file__), "preview.png"))
print("done")