"""Original flat UI icons for Egg Farm, drawn with Pillow from simple vector-like shapes.

    python3 assets/ui/make_icons.py      # writes assets/ui/icons/<name>.png (256x256 RGBA)

Style: bright flat fills, one thick dark outline around each silhouette, a few dark detail lines
and soft white shines. Every icon is drawn at 4x (1024 px) and downsampled for smooth edges.
No fonts, images or third-party art are used: every shape is defined in this file.
"""

import math
import os

from PIL import Image, ImageDraw

S = 1024  # working size
OUT_SIZE = 256
W = 30  # outline thickness at working size (~7.5 px at 256)
INK = (44, 34, 52, 255)
HERE = os.path.dirname(os.path.abspath(__file__))
OUTDIR = os.path.join(HERE, "icons")

# palette (bright, matches the meadow theme)
WHITE = (255, 255, 255, 255)
CREAM = (255, 244, 220, 255)
YELLOW = (255, 214, 74, 255)
GOLD = (255, 186, 40, 255)
ORANGE = (255, 150, 40, 255)
RED = (230, 72, 60, 255)
DARKRED = (180, 46, 40, 255)
GREEN = (96, 196, 84, 255)
DARKGREEN = (58, 150, 70, 255)
MINT = (150, 230, 140, 255)
BLUE = (70, 150, 235, 255)
SKY = (150, 210, 255, 255)
PURPLE = (160, 100, 230, 255)
PINK = (255, 110, 170, 255)
BROWN = (176, 112, 66, 255)
TAN = (226, 180, 120, 255)
GREY = (170, 178, 190, 255)
LIGHTGREY = (215, 222, 230, 255)
DARKGREY = (110, 116, 130, 255)
SKIN = (250, 204, 160, 255)
SHINE = (255, 255, 255, 150)


def arc_pts(cx, cy, rx, ry, a0, a1, n=48):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def egg_pts(cx, cy, rx, ry, n=72):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        dx, dy = math.cos(a), math.sin(a)
        k = 1 - 0.16 * max(0.0, -dy)  # narrower top
        pts.append((cx + rx * dx * k, cy + ry * dy * (1.08 if dy < 0 else 0.92)))
    return pts


def star_pts(cx, cy, r_out, r_in, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


class Icon:
    """Ordered list of ops. Outlined ops contribute to the dark silhouette pass."""

    def __init__(self):
        self.ops = []

    # outlined shapes
    def ellipse(self, cx, cy, rx, ry, fill, outline=True):
        self.ops.append(("ellipse", (cx, cy, rx, ry), fill, outline))

    def circle(self, cx, cy, r, fill, outline=True):
        self.ellipse(cx, cy, r, r, fill, outline)

    def rect(self, x0, y0, x1, y1, fill, r=0, outline=True):
        self.ops.append(("rect", (x0, y0, x1, y1, r), fill, outline))

    def poly(self, pts, fill, outline=True):
        self.ops.append(("poly", list(pts), fill, outline))

    def stroke(self, pts, w, fill, outline=True):
        self.ops.append(("stroke", (list(pts), w), fill, outline))

    # details: drawn only in the fill pass, in order
    def line(self, pts, w=16, fill=INK):
        self.ops.append(("stroke", (list(pts), w), fill, False))

    def shine(self, cx, cy, rx, ry):
        self.ellipse(cx, cy, rx, ry, SHINE, outline=False)

    # ------------------------------------------------------------ rendering
    @staticmethod
    def _draw(d, kind, geo, fill, grow):
        if kind == "ellipse":
            cx, cy, rx, ry = geo
            d.ellipse((cx - rx - grow, cy - ry - grow, cx + rx + grow, cy + ry + grow), fill=fill)
        elif kind == "rect":
            x0, y0, x1, y1, r = geo
            box = (x0 - grow, y0 - grow, x1 + grow, y1 + grow)
            if r or grow:
                d.rounded_rectangle(box, radius=r + grow, fill=fill)
            else:
                d.rectangle(box, fill=fill)
        elif kind == "poly":
            d.polygon(geo, fill=fill)
            if grow:
                d.line(geo + [geo[0]], fill=fill, width=int(grow * 2), joint="curve")
                for x, y in geo:
                    d.ellipse((x - grow, y - grow, x + grow, y + grow), fill=fill)
        elif kind == "stroke":
            pts, w = geo
            ww = w + grow * 2
            d.line(pts, fill=fill, width=int(ww), joint="curve")
            for x, y in (pts[0], pts[-1]):
                d.ellipse((x - ww / 2, y - ww / 2, x + ww / 2, y + ww / 2), fill=fill)

    def render(self):
        img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for kind, geo, fill, outline in self.ops:
            if outline:
                self._draw(d, kind, geo, INK, W)
        for kind, geo, fill, outline in self.ops:
            if fill[3] < 255:
                layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
                self._draw(ImageDraw.Draw(layer), kind, geo, fill, 0)
                img.alpha_composite(layer)
                d = ImageDraw.Draw(img)
            else:
                self._draw(d, kind, geo, fill, 0)
        return img.resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS)


# ---------------------------------------------------------------- icons
def cash():
    i = Icon()
    i.rect(150, 300, 820, 700, DARKGREEN, r=40)
    i.rect(210, 340, 880, 740, GREEN, r=40)
    i.rect(270, 400, 820, 680, MINT, r=24, outline=False)
    i.circle(545, 540, 120, GREEN)
    # dollar sign from strokes
    s_top = arc_pts(545, 498, 52, 42, -30, -270, 30)
    s_bot = arc_pts(545, 582, 52, 42, -90, 150, 30)
    i.line(s_top + s_bot, 24, INK)
    i.line([(545, 425), (545, 655)], 22)
    for x in (300, 790):
        i.circle(x, 540, 26, DARKGREEN, outline=False)
    return i


def egg_icon(fill, deco=None):
    i = Icon()
    i.poly(egg_pts(512, 540, 300, 380), fill)
    if deco:
        deco(i)
    i.shine(410, 380, 60, 110)
    return i


def egg():
    return egg_icon(CREAM, lambda i: [i.circle(x, y, r, (236, 210, 170, 255), outline=False)
                                      for x, y, r in ((600, 640, 34), (430, 700, 24), (650, 470, 22))])


def gold_egg():
    def deco(i):
        i.poly(egg_pts(512, 560, 230, 300), YELLOW, outline=False)
        i.poly(star_pts(600, 640, 70, 30), WHITE, outline=False)
        i.poly(star_pts(400, 720, 40, 17), WHITE, outline=False)
    return egg_icon(GOLD, deco)


def star_egg():
    def deco(i):
        i.poly(star_pts(512, 580, 190, 85), YELLOW)
        i.shine(470, 530, 30, 40)
        for x, y in ((330, 400), (690, 420), (700, 760)):
            i.poly(star_pts(x, y, 40, 16), WHITE, outline=False)
    return egg_icon(PURPLE, deco)


def chicken():
    i = Icon()
    i.stroke([(440, 760), (440, 880)], 30, ORANGE)
    i.stroke([(580, 760), (580, 880)], 30, ORANGE)
    i.stroke([(400, 885), (470, 885)], 26, ORANGE)
    i.stroke([(545, 885), (615, 885)], 26, ORANGE)
    i.poly([(700, 420), (880, 300), (870, 520), (720, 600)], CREAM)  # tail
    for cx, cy, r in ((390, 230, 50), (450, 200, 58), (510, 235, 48)):  # comb
        i.circle(cx, cy, r, RED)
    i.ellipse(520, 580, 300, 230, WHITE)  # body
    i.circle(410, 360, 150, WHITE)  # head
    i.poly([(270, 360), (190, 400), (275, 440)], ORANGE)  # beak
    i.ellipse(290, 480, 38, 55, RED)  # wattle
    i.circle(380, 330, 28, INK, outline=False)
    i.circle(372, 320, 9, WHITE, outline=False)
    i.ellipse(580, 560, 160, 105, (232, 236, 244, 255), outline=False)  # wing
    i.line(arc_pts(580, 560, 160, 105, 10, 170, 24), 16)
    i.shine(470, 300, 50, 35)
    return i


def chick():
    i = Icon()
    i.circle(512, 470, 230, YELLOW)  # body
    i.circle(512, 300, 150, YELLOW)  # head
    i.poly([(470, 330), (512, 390), (554, 330)], ORANGE)
    i.circle(450, 280, 26, INK, outline=False)
    i.circle(574, 280, 26, INK, outline=False)
    i.circle(442, 270, 8, WHITE, outline=False)
    i.circle(566, 270, 8, WHITE, outline=False)
    i.circle(395, 345, 28, (255, 160, 140, 200), outline=False)
    i.circle(629, 345, 28, (255, 160, 140, 200), outline=False)
    for cx in (480, 540):
        i.poly([(cx, 160), (cx - 30, 110), (cx + 25, 130)], YELLOW, outline=False)
    # cracked eggshell bottom
    teeth = []
    for k in range(9):
        x = 230 + k * 70
        teeth.append((x, 560 if k % 2 == 0 else 500))
    shell = [(230, 560)] + teeth[1:] + [(790, 560)] + arc_pts(512, 600, 280, 300, 0, 180, 40)
    i.poly(shell, CREAM)
    i.circle(640, 760, 30, (236, 210, 170, 255), outline=False)
    i.circle(400, 700, 22, (236, 210, 170, 255), outline=False)
    i.shine(440, 220, 50, 30)
    return i


def basket():
    i = Icon()
    i.stroke(arc_pts(512, 520, 270, 300, 180, 360, 40), 50, BROWN)  # handle
    for cx, cy, c in ((390, 470, CREAM), (530, 440, WHITE), (650, 480, GOLD)):
        i.poly(egg_pts(cx, cy, 95, 120), c)
    i.poly([(170, 500), (854, 500), (760, 880), (264, 880)], TAN)
    i.rect(150, 480, 874, 560, BROWN, r=30)
    for k in range(1, 6):
        x0 = 170 + k * 114
        i.line([(x0, 580), (264 + (760 - 264) * k / 6 - 0, 860)], 14)
    i.line([(220, 700), (804, 700)], 14)
    return i


def house():
    i = Icon()
    i.rect(700, 170, 780, 360, DARKGREY)  # chimney
    i.rect(230, 450, 794, 860, CREAM)
    i.poly([(130, 500), (512, 160), (894, 500)], RED)
    i.rect(450, 620, 580, 860, BROWN, r=16)
    i.circle(555, 745, 12, YELLOW, outline=False)
    i.rect(290, 560, 400, 670, SKY, r=10)
    i.line([(345, 560), (345, 670)], 12)
    i.line([(290, 615), (400, 615)], 12)
    i.rect(630, 560, 740, 670, SKY, r=10)
    i.line([(685, 560), (685, 670)], 12)
    i.line([(630, 615), (740, 615)], 12)
    i.circle(512, 390, 50, YELLOW)
    i.shine(380, 400, 60, 22)
    return i


def truck():
    i = Icon()
    i.rect(110, 280, 640, 720, WHITE, r=24)  # cargo
    i.rect(640, 430, 900, 720, YELLOW, r=24)  # cab
    i.poly([(660, 430), (800, 430), (890, 560), (660, 560)], YELLOW)
    i.poly([(700, 460), (790, 460), (850, 550), (700, 550)], SKY, outline=False)
    i.rect(110, 600, 900, 660, DARKGREY, outline=False)
    i.poly(egg_pts(375, 470, 85, 110), GOLD)
    for x in (260, 520, 770):
        i.circle(x, 740, 95, (60, 60, 70, 255))
        i.circle(x, 740, 40, LIGHTGREY, outline=False)
    i.rect(880, 600, 930, 640, ORANGE, r=8, outline=False)
    return i


def worker():
    i = Icon()
    i.rect(250, 600, 774, 930, RED, r=120)  # shirt shoulders
    i.rect(380, 640, 644, 930, BLUE, r=30)  # overalls bib
    i.stroke([(400, 620), (400, 700)], 30, BLUE, outline=False)
    i.stroke([(624, 620), (624, 700)], 30, BLUE, outline=False)
    i.circle(440, 720, 16, YELLOW, outline=False)
    i.circle(584, 720, 16, YELLOW, outline=False)
    i.circle(512, 420, 190, SKIN)  # head
    i.ellipse(512, 260, 320, 70, YELLOW)  # hat brim
    i.rect(370, 120, 654, 270, YELLOW, r=60)  # hat crown
    i.rect(370, 220, 654, 262, RED, outline=False)
    i.circle(445, 430, 24, INK, outline=False)
    i.circle(579, 430, 24, INK, outline=False)
    i.line(arc_pts(512, 480, 70, 50, 20, 160, 16), 16)
    i.circle(400, 500, 26, (255, 160, 140, 180), outline=False)
    i.circle(624, 500, 26, (255, 160, 140, 180), outline=False)
    return i


def silo():
    i = Icon()
    i.rect(300, 340, 724, 900, LIGHTGREY, r=16)
    i.poly(arc_pts(512, 350, 230, 210, 180, 360, 40), RED)
    i.line([(282, 350), (742, 350)], 16)
    for y in (500, 640, 780):
        i.line([(300, y), (724, y)], 14)
    for x in (360, 410):  # ladder rails
        i.line([(x, 360), (x, 900)], 10)
    for y in range(400, 900, 50):
        i.line([(360, y), (410, y)], 8)
    i.circle(512, 135, 32, YELLOW)
    i.rect(560, 790, 680, 900, BROWN, r=8)
    i.shine(640, 560, 26, 110)
    return i


def upgrade():
    i = Icon()
    i.poly([(512, 110), (860, 470), (660, 470), (660, 900), (364, 900), (364, 470), (164, 470)], GREEN)
    i.poly([(512, 190), (760, 440), (620, 440), (620, 860), (560, 860), (560, 440)], MINT, outline=False)
    return i


def flask():
    i = Icon()
    body = [(420, 130), (604, 130), (604, 400), (850, 840), (174, 840), (420, 400)]
    i.poly(body, (230, 245, 255, 255))
    liquid = [(285, 600), (739, 600), (850, 840), (174, 840)]
    i.poly(liquid, PURPLE, outline=False)
    i.line([(285, 600), (739, 600)], 14)
    i.rect(390, 100, 634, 160, LIGHTGREY, r=20)
    for x, y, r in ((420, 720, 30), (560, 680, 22), (620, 770, 36), (500, 520, 20)):
        i.circle(x, y, r, (220, 190, 255, 255), outline=False)
    i.shine(470, 330, 22, 90)
    return i


def clock():
    i = Icon()
    for a in (-35, 35):  # bells
        x = 512 + 330 * math.sin(math.radians(a))
        i.circle(x, 512 - 330 * math.cos(math.radians(a)), 90, RED)
    i.circle(512, 540, 360, BLUE)
    i.circle(512, 540, 285, WHITE, outline=False)
    for k in range(12):
        a = math.radians(k * 30)
        r0, r1 = (225, 265) if k % 3 else (200, 265)
        i.line([(512 + r0 * math.sin(a), 540 - r0 * math.cos(a)), (512 + r1 * math.sin(a), 540 - r1 * math.cos(a))],
               18 if k % 3 == 0 else 12)
    i.line([(512, 540), (512, 360)], 30)
    i.line([(512, 540), (640, 610)], 30)
    i.circle(512, 540, 36, RED)
    return i


def potion():
    i = Icon()
    i.rect(430, 150, 594, 360, (230, 245, 255, 255), r=20)
    i.rect(410, 100, 614, 190, BROWN, r=30)
    i.circle(512, 620, 290, (230, 245, 255, 255))
    i.poly(arc_pts(512, 620, 260, 260, 0, 180, 40), PINK, outline=False)
    i.rect(252, 600, 772, 625, PINK, outline=False)
    i.line(arc_pts(512, 620, 262, 18, 180, 360, 20), 14)
    # lightning bolt
    i.poly([(540, 470), (430, 660), (510, 660), (470, 800), (610, 600), (530, 600), (580, 470)], YELLOW)
    i.shine(380, 520, 40, 70)
    return i


def gift():
    i = Icon()
    i.ellipse(400, 230, 120, 80, YELLOW)  # bow
    i.ellipse(624, 230, 120, 80, YELLOW)
    i.rect(200, 450, 824, 900, RED, r=20)
    i.rect(160, 300, 864, 470, DARKRED, r=24)
    i.rect(460, 300, 564, 900, YELLOW)
    i.circle(512, 280, 60, GOLD)
    i.line([(200, 470), (824, 470)], 16)
    return i


def calendar():
    i = Icon()
    i.rect(150, 200, 874, 880, WHITE, r=50)
    i.rect(150, 200, 874, 400, RED, r=50)
    i.rect(150, 340, 874, 400, RED, outline=False)
    i.line([(150, 400), (874, 400)], 16)
    for x in (330, 694):
        i.rect(x - 30, 120, x + 30, 280, DARKGREY, r=30)
    for r in range(3):
        for c in range(4):
            x = 250 + c * 155
            y = 470 + r * 130
            col = YELLOW if (r, c) == (1, 2) else LIGHTGREY
            i.rect(x, y, x + 105, y + 90, col, r=16, outline=(r, c) == (1, 2))
    i.line([(630, 650), (665, 690), (725, 610)], 20)
    return i


def quest():
    i = Icon()
    i.rect(220, 200, 804, 820, CREAM, r=10)
    i.rect(170, 140, 854, 240, TAN, r=50)
    i.rect(170, 780, 854, 880, TAN, r=50)
    for k, y in enumerate((330, 420, 510, 600)):
        i.line([(300, y), (720 - (k % 2) * 120, y)], 20)
    i.poly(star_pts(660, 680, 70, 30), YELLOW)
    i.circle(200, 190, 26, BROWN, outline=False)
    i.circle(824, 830, 26, BROWN, outline=False)
    return i


def shop_bag():
    i = Icon()
    i.stroke(arc_pts(512, 360, 150, 170, 180, 360, 32), 40, BROWN)
    i.poly([(220, 340), (804, 340), (860, 900), (164, 900)], ORANGE)
    i.rect(200, 330, 824, 400, (255, 186, 90, 255), outline=False)
    i.line([(220, 400), (804, 400)], 14)
    for x in (362, 662):
        i.circle(x, 360, 22, INK, outline=False)
    i.poly(egg_pts(512, 650, 120, 150), CREAM)
    i.shine(470, 590, 26, 40)
    return i


def gear():
    i = Icon()
    pts = []
    teeth = 8
    for k in range(teeth * 4):
        a = 2 * math.pi * k / (teeth * 4) + math.pi / (teeth * 4)
        r = 400 if (k % 4) in (1, 2) else 300
        pts.append((512 + r * math.cos(a), 512 + r * math.sin(a)))
    i.poly(pts, GREY)
    i.circle(512, 512, 200, LIGHTGREY, outline=False)
    i.circle(512, 512, 110, DARKGREY)
    i.circle(512, 512, 60, (60, 60, 70, 255), outline=False)
    i.shine(420, 400, 50, 30)
    return i


def crown():
    i = Icon()
    pts = [(150, 330), (330, 560), (512, 220), (694, 560), (874, 330), (800, 780), (224, 780)]
    i.poly(pts, GOLD)
    i.rect(200, 720, 824, 860, YELLOW, r=24)
    for x, y in ((150, 310), (512, 200), (874, 310)):
        i.circle(x, y, 55, YELLOW)
    for x, c in ((340, RED), (512, BLUE), (684, GREEN)):
        i.circle(x, 790, 38, c)
    i.poly(star_pts(512, 520, 90, 40), WHITE, outline=False)
    return i


def lock():
    i = Icon()
    i.stroke(arc_pts(512, 420, 190, 220, 180, 360, 32) + [(702, 470)], 70, LIGHTGREY)
    i.stroke([(322, 420), (322, 470)], 70, LIGHTGREY, outline=True)
    i.rect(200, 450, 824, 900, GOLD, r=60)
    i.rect(240, 490, 784, 540, YELLOW, r=20, outline=False)
    i.circle(512, 640, 60, (60, 50, 60, 255), outline=False)
    i.poly([(480, 650), (544, 650), (570, 790), (454, 790)], (60, 50, 60, 255), outline=False)
    return i


def check():
    i = Icon()
    i.stroke([(190, 540), (420, 770), (840, 280)], 150, GREEN)
    i.line([(220, 520), (420, 720), (800, 280)], 30, MINT)
    return i


def close():
    i = Icon()
    i.stroke([(230, 230), (794, 794)], 160, RED)
    i.stroke([(794, 230), (230, 794)], 160, RED)
    i.line([(260, 230), (760, 730)], 26, (255, 140, 130, 255))
    return i


ICONS = {
    "cash": cash,
    "gold_egg": gold_egg,
    "star_egg": star_egg,
    "chicken": chicken,
    "egg": egg,
    "basket": basket,
    "house": house,
    "truck": truck,
    "worker": worker,
    "silo": silo,
    "upgrade": upgrade,
    "lab_flask": flask,
    "clock": clock,
    "boost_potion": potion,
    "gift": gift,
    "calendar_daily": calendar,
    "quest_scroll": quest,
    "shop_bag": shop_bag,
    "settings_gear": gear,
    "crown_vip": crown,
    "lock": lock,
    "check": check,
    "close": close,
    "spawn_chick": chick,
}


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    for name, fn in ICONS.items():
        fn().render().save(os.path.join(OUTDIR, name + ".png"), optimize=True)
    # contact sheet for quick review
    cols = 6
    rows = (len(ICONS) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * 140, rows * 140), (232, 240, 248, 255))
    for k, name in enumerate(ICONS):
        im = Image.open(os.path.join(OUTDIR, name + ".png")).resize((128, 128), Image.LANCZOS)
        sheet.alpha_composite(im, ((k % cols) * 140 + 6, (k // cols) * 140 + 6))
    sheet.save(os.path.join(HERE, "icons_sheet.png"), optimize=True)
    print(f"wrote {len(ICONS)} icons to {os.path.relpath(OUTDIR)}")


if __name__ == "__main__":
    main()
