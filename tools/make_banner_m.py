# Generate MTLauncher TV banner (320x180) and splash (3840x2160):
# striped glowing "M" + "TLAUNCHER" text on dark navy, matching the
# original FLauncher design language (stripes + glow + teal accent).
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res")
BANNER = os.path.join(ROOT, "drawable-xhdpi", "banner.jpg")
SPLASH = os.path.join(ROOT, "drawable-xhdpi", "splash.jpg")

# Sample the dark navy background from the old assets
bg_color = Image.open(BANNER).convert("RGB").getpixel((4, 4))
print("sampled bg:", bg_color)

FONT_BOLD = "C:/Windows/Fonts/impact.ttf"
FONT_TEXT = "C:/Windows/Fonts/segoeuil.ttf"

TEXT_COLOR = (139, 148, 158)   # muted gray like the original "AUNCHER"
WHITE = (240, 244, 248, 255)
TEAL = (95, 150, 175, 255)


def draw_letter_striped(img, letter, font, x0, y0, band, gap, accent_scale=1.0):
    """Draw a striped glowing letter at (x0, y0); returns (draw_img, letter_bbox)."""
    W, H = img.size
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).text((x0, y0), letter, font=font, fill=255)
    bx = mask.getbbox()

    bands = Image.new("L", (W, H), 0)
    bd = ImageDraw.Draw(bands)
    y = bx[1]
    while y < bx[3]:
        bd.rectangle([bx[0], y, bx[2], min(y + band, bx[3]) - 1], fill=255)
        y += band + gap
    striped = ImageChops.multiply(mask, bands)

    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer.paste(Image.new("RGBA", (W, H), WHITE), (0, 0), striped)
    glow = layer.filter(ImageFilter.GaussianBlur(max(4, W // 60)))

    out = Image.alpha_composite(img, glow)
    out = Image.alpha_composite(out, layer)

    # teal L-bracket accent on the letter's left stem
    tw, th = bx[2] - bx[0], bx[3] - bx[1]
    acc = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ad = ImageDraw.Draw(acc)
    bar_w = max(3, int(th * 0.055 * accent_scale))
    foot_w = max(12, int(tw * 0.42 * accent_scale))
    foot_h = max(3, int(th * 0.045 * accent_scale))
    lx = bx[0] + int(tw * 0.10)
    ly = bx[1] + int(th * 0.36)
    ad.rectangle([lx, ly, lx + bar_w, ly + int(th * 0.42)], fill=TEAL)
    ad.rectangle([lx, ly + int(th * 0.42) - foot_h, lx + foot_w, ly + int(th * 0.42)], fill=TEAL)
    acc_glow = acc.filter(ImageFilter.GaussianBlur(max(2, W // 120)))
    out = Image.alpha_composite(out, acc_glow)
    out = Image.alpha_composite(out, acc)

    return out, bx


def draw_text(img, text, font, x, y_center, color, letter_spacing=0.0):
    d = ImageDraw.Draw(img)
    bbox = d.textbbox((0, 0), text, font=font)
    th = bbox[3] - bbox[1]
    y = y_center - th // 2 - bbox[1]
    if letter_spacing <= 0:
        d.text((x, y), text, font=font, fill=color)
        return d.textlength(text, font=font)
    cx = x
    for ch in text:
        d.text((cx, y), ch, font=font, fill=color)
        cx += d.textlength(ch, font=font) + letter_spacing
    return cx - x


def make_banner():
    W, H = 320, 180
    img = Image.new("RGBA", (W, H), bg_color + (255,))
    d = ImageDraw.Draw(img)

    m_font = ImageFont.truetype(FONT_BOLD, 128)
    bbox = d.textbbox((0, 0), "M", font=m_font)
    m_h = bbox[3] - bbox[1]
    x0 = 22 - bbox[0]
    y0 = (H - m_h) // 2 - bbox[1]

    img, mbx = draw_letter_striped(img, "M", m_font, x0, y0, band=8, gap=4)

    t_font = ImageFont.truetype(FONT_TEXT, 34)
    draw_text(img, "TLAUNCHER", t_font, mbx[2] + 12, (mbx[1] + mbx[3]) // 2, TEXT_COLOR, letter_spacing=1.5)

    img.convert("RGB").save(BANNER, quality=92)
    img.convert("RGB").save(os.path.join(os.path.dirname(__file__), "banner_preview.png"))
    print("wrote", BANNER)


def make_splash():
    W, H = 3840, 2160
    img = Image.new("RGBA", (W, H), bg_color + (255,))

    # subtle radial-ish vignette: slightly lighter center, like the original
    grad = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(grad)
    steps = 24
    for i in range(steps):
        alpha = int(10 * (1 - i / steps))
        inset = int(min(W, H) * 0.18 * i / steps)
        gd.ellipse([inset * 2, inset, W - inset * 2, H - inset], fill=alpha)
    light = Image.new("RGBA", (W, H), tuple(min(255, c + 22) for c in bg_color) + (255,))
    img = Image.composite(light, img, grad)

    m_font = ImageFont.truetype(FONT_BOLD, 1100)
    bbox = ImageDraw.Draw(img).textbbox((0, 0), "M", font=m_font)
    m_h = bbox[3] - bbox[1]
    x0 = 950 - bbox[0]
    y0 = (H - m_h) // 2 - bbox[1]

    img, mbx = draw_letter_striped(img, "M", m_font, x0, y0, band=62, gap=26)

    t_font = ImageFont.truetype(FONT_TEXT, 280)
    draw_text(img, "TLAUNCHER", t_font, mbx[2] + 120, (mbx[1] + mbx[3]) // 2, TEXT_COLOR, letter_spacing=14)

    img.convert("RGB").save(SPLASH, quality=90)
    print("wrote", SPLASH)


make_banner()
make_splash()
print("done")