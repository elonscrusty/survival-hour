"""Store art for publishing: game icon (512x512) and thumbnails (1920x1080),
composed from the Blender scene renders in Renders/Scenes with the title.

    python3 tools/make_marketing.py   ->  Marketing/*.png
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCENES = os.path.join(ROOT, "Renders", "Scenes")
OUT = os.path.join(ROOT, "Marketing")
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
ORANGE = (255, 170, 80)
RED = (232, 72, 52)
CREAM = (255, 240, 215)


def font(size):
    return ImageFont.truetype(BOLD, size)


def cover(img, w, h, focus=(0.5, 0.5)):
    s = max(w / img.width, h / img.height)
    img = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    x = int((img.width - w) * focus[0])
    y = int((img.height - h) * focus[1])
    return img.crop((x, y, x + w, y + h))


def shadow_text(base, xy, text, fnt, fill, anchor="mm", stroke=6, blur=8):
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    d.text((xy[0] + 4, xy[1] + 6), text, font=fnt, fill=(0, 0, 0, 200), anchor=anchor, stroke_width=stroke, stroke_fill=(0, 0, 0, 200))
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(blur)))
    ImageDraw.Draw(base).text(xy, text, font=fnt, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=(40, 16, 6))


def vignette(img, strength=0.65):
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse((-w * 0.25, -h * 0.35, w * 1.25, h * 1.35), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(min(w, h) * 0.12))
    dark = Image.new("RGBA", (w, h), (0, 0, 0, int(255 * strength)))
    img.alpha_composite(Image.composite(Image.new("RGBA", (w, h), (0, 0, 0, 0)), dark, mask))
    return img


def title_block(img, cx, cy, scale):
    f = font(int(120 * scale))
    d = ImageDraw.Draw(img)
    w1 = d.textlength("SURVIVAL", font=f)
    w2 = d.textlength("HOUR", font=f)
    gap = 36 * scale
    left = cx - (w1 + gap + w2) / 2
    shadow_text(img, (left + w1 / 2, cy), "SURVIVAL", f, CREAM, stroke=int(6 * scale))
    shadow_text(img, (left + w1 + gap + w2 / 2, cy), "HOUR", f, RED, stroke=int(6 * scale))


def thumbnail(scene, name, tagline, focus=(0.5, 0.5), bright=1.05):
    im = Image.open(os.path.join(SCENES, scene)).convert("RGBA")
    im = cover(im, 1920, 1080, focus)
    im = ImageEnhance.Contrast(ImageEnhance.Brightness(im).enhance(bright)).enhance(1.08)
    im = vignette(im)
    title_block(im, 960, 150, 1.0)
    shadow_text(im, (960, 960), tagline, font(54), ORANGE, stroke=4)
    im.convert("RGB").save(os.path.join(OUT, name), quality=95)


def icon():
    im = Image.open(os.path.join(SCENES, "Scene_Camp_Night.png")).convert("RGBA")
    im = cover(im, 512, 512, (0.5, 0.55))
    im = ImageEnhance.Brightness(im).enhance(1.15)
    im = vignette(im, 0.5)
    shadow_text(im, (256, 90), "SURVIVAL", font(78), CREAM, stroke=5, blur=6)
    shadow_text(im, (256, 430), "HOUR", font(104), RED, stroke=6, blur=6)
    im.convert("RGB").save(os.path.join(OUT, "Icon_512.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    icon()
    thumbnail("Scene_Camp_Night.png", "Thumbnail_1_Night.png", "KEEP YOUR FIRE BURNING. OUTLAST EVERYONE.", bright=1.2)
    thumbnail("Scene_Camp_Day.png", "Thumbnail_2_Camp.png", "GATHER · CRAFT · BUILD · RAID")
    thumbnail("Scene_Clearing_Day.png", "Thumbnail_3_Forest.png", "EXPLORE CAVES, CABINS AND RUINS")
    print("written to", OUT)


if __name__ == "__main__":
    main()
