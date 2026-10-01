"""Housing tiers (coops -> Mega Dome), warehouse with loading dock, and silo.
Units: studs, front = -Y. Sizes target the footprints listed in the brief (W x H x D)."""

import math


# ---------------------------------------------------------------- helpers
def window(b, x, y, z, w=1.6, h=1.6, frame="White", face=-1, glass="Glass", axis="y"):
    """Framed window on a wall. axis='y' -> wall facing +-Y at depth y; axis='x' -> wall facing +-X."""
    t = 0.25
    if axis == "y":
        b.box((w + 0.5, t, h + 0.5), (x, y + face * t / 2, z), frame)
        b.box((w, t, h), (x, y + face * t, z), glass)
        b.box((w, t * 1.6, 0.18), (x, y + face * t * 1.1, z), frame)
        b.box((0.18, t * 1.6, h), (x, y + face * t * 1.1, z), frame)
    else:
        b.box((t, w + 0.5, h + 0.5), (x + face * t / 2, y, z), frame)
        b.box((t, w, h), (x + face * t, y, z), glass)
        b.box((t * 1.6, w, 0.18), (x + face * t * 1.1, y, z), frame)
        b.box((t * 1.6, 0.18, h), (x + face * t * 1.1, y, z), frame)


def barn_door(b, x, y, z0, w, h, panel="Roof", trim="White"):
    """Classic barn door with white X bracing on the -Y face at depth y (z0 = bottom)."""
    t = 0.3
    b.boxb((w + 0.8, t, h + 0.4), (x, y - t / 2, z0), trim)
    b.boxb((w, t, h), (x, y - t, z0), panel)
    diag = math.degrees(math.atan2(h, w / 2))
    for half in (-1, 1):
        cx = x + half * w / 4
        b.box((math.hypot(w / 2, h) - 0.3, t, 0.35), (cx, y - t * 1.5, z0 + h / 2), trim, rot=(0, diag, 0))
        b.box((math.hypot(w / 2, h) - 0.3, t, 0.35), (cx, y - t * 1.5, z0 + h / 2), trim, rot=(0, -diag, 0))
        b.box((0.35, t, h), (cx + half * w / 4 - half * 0.17, y - t * 1.5, z0 + h / 2), trim)
    b.box((0.3, t, h), (x, y - t * 1.5, z0 + h / 2), trim)
    b.box((w, t, 0.35), (x, y - t * 1.5, z0 + h - 0.17), trim)
    b.box((w, t, 0.35), (x, y - t * 1.5, z0 + 0.17), trim)


def corner_trims(b, w, d, h, z0=0, mat="White", t=0.5):
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.boxb((t, t, h), (sx * (w / 2), sy * (d / 2), z0), mat)


def plank_lines(b, w, d, z0, h, mat="WoodDark", step=1.6, face=-1):
    """Thin horizontal plank grooves on the front (-Y) face."""
    z = z0 + step
    while z < z0 + h - 0.3:
        b.box((w - 0.2, 0.08, 0.1), (0, face * (d / 2 + 0.03), z), mat)
        z += step


def gambrel(b, w, d, wall_h, roof_mat="RoofDark", wall_mat="Roof", trim="White", over=0.8):
    """Gambrel (barn) roof over a w x d box whose walls end at wall_h. Gable ends painted wall_mat."""
    hw = w / 2 + over
    knee_x = w / 2 * 0.62
    knee_z = w * 0.24
    top = w * 0.36
    prof = [(-hw, -0.4), (-knee_x - 0.4, knee_z), (0, top + 0.5), (knee_x + 0.4, knee_z), (hw, -0.4)]
    b.prism(prof, d + over * 2, (0, 0, wall_h), roof_mat)
    inner = [(-w / 2, 0), (-knee_x, knee_z - 0.4), (0, top - 0.3), (knee_x, knee_z - 0.4), (w / 2, 0)]
    b.prism(inner, d + over * 2 + 0.12, (0, 0, wall_h), wall_mat)
    # white trim lines along the gable ends
    for sy in (-1, 1):
        y = sy * (d / 2 + over + 0.1)
        for (x0, z0), (x1, z1) in zip(inner[:-1], inner[1:]):
            L = math.hypot(x1 - x0, z1 - z0)
            ang = math.degrees(math.atan2(z1 - z0, x1 - x0))
            b.box((L + 0.3, 0.2, 0.35), ((x0 + x1) / 2, y, wall_h + (z0 + z1) / 2), trim, rot=(0, -ang, 0))
    return top


def hay_loft(b, d, wall_h, over, top):
    y = -(d / 2 + over + 0.15)
    b.box((3.0, 0.3, 3.0), (0, y, wall_h + top * 0.45), "White")
    b.box((2.4, 0.4, 2.4), (0, y - 0.05, wall_h + top * 0.45), "WoodDark")
    b.box((0.3, 0.45, 2.4), (0, y - 0.1, wall_h + top * 0.45), "White")


def ramp(b, x, y_door, z_top, length, width, mat="Wood"):
    """Ramp leading from the ground (towards -Y) up to z_top at y_door."""
    b.prism([(0, 0), (length, 0), (0, z_top)], width, (x, y_door, 0), mat, rot=(0, 0, -90))
    # cleats
    n = max(2, int(length / 0.9))
    for i in range(1, n):
        t = i / n
        yy = y_door - length + length * t
        b.box((width - 0.1, 0.18, 0.12), (x, yy, z_top * t + 0.05), "WoodDark")


# ---------------------------------------------------------------- coops
def coop_body(b, x, w, d, h, leg=1.2, wall="Wood", roof="Roof", door=True, rise=None, nest=True):
    """Small raised coop centred at x: stilts, plank walls, gable roof, pop-hole and ramp."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.boxb((0.5, 0.5, leg), (x + sx * (w / 2 - 0.4), sy * (d / 2 - 0.4), 0), "WoodDark")
    b.boxb((w, d, h), (x, 0, leg), wall)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.boxb((0.45, 0.45, h), (x + sx * w / 2, sy * d / 2, leg), "White")
    # grooves on front
    z = leg + 1.0
    while z < leg + h - 0.4:
        b.box((w - 0.4, 0.08, 0.1), (x, -d / 2 - 0.03, z), "WoodDark")
        z += 1.0
    rise = rise if rise is not None else w * 0.36
    b.gable_fill(w, d, rise, (x, 0, leg + h), wall)
    b.gable(w, d, rise, (x, 0, leg + h), roof, overhang=0.7, thick=0.45)
    if door:
        b.boxb((1.5, 0.3, 1.9), (x - w * 0.18, -d / 2 - 0.1, leg + 0.15), "Black")
        b.boxb((2.0, 0.25, 0.3), (x - w * 0.18, -d / 2 - 0.12, leg + 2.05), "White")
        ramp(b, x - w * 0.18, -d / 2, leg + 0.15, 3.0, 1.4)
        window(b, x + w * 0.22, -d / 2, leg + h * 0.6, 1.3, 1.3, frame="Accent")
    if not nest:
        return
    # nest box on the right side
    b.boxb((1.4, d * 0.6, 1.6), (x + w / 2 + 0.7, 0, leg + 0.4), wall)
    b.prism([(0, 0), (1.6, 0), (0, 0.7)], d * 0.6 + 0.4, (x + w / 2, 0, leg + 2.0), roof)


def little_coop(b):  # ~10 x 8 x 10
    coop_body(b, 0, 7.0, 7.0, 3.8, leg=1.2)
    # little fenced run on the left
    for y in (-3.2, 3.2):
        b.boxb((0.15, 0.15, 1.2), (-4.6, y, 0), "WoodDark")
    b.boxb((0.1, 6.6, 0.12), (-4.6, 0, 1.1), "White")
    b.boxb((0.1, 6.6, 0.12), (-4.6, 0, 0.55), "White")


def twin_coop(b):  # ~17 x 9 x 10
    coop_body(b, -4.2, 7.0, 7.4, 4.0, leg=1.2, nest=False)
    coop_body(b, 4.6, 7.0, 7.4, 4.0, leg=1.2)
    # covered walkway joining the two
    b.boxb((2.2, 3.0, 0.3), (0.2, 0, 2.2), "Wood")
    b.prism([(-1.7, 0), (1.7, 0), (0, 1.2)], 3.6, (0.2, 0, 4.4), "RoofDark")
    for sx in (-0.8, 1.2):
        b.boxb((0.25, 0.25, 2.2), (sx, -1.4, 2.2), "White")


def hen_house(b):  # ~16 x 12 x 14
    w, d, h = 14.0, 12.0, 6.5
    b.boxb((w + 0.8, d + 0.8, 0.6), (0, 0, 0), "Path")  # stone footing
    b.boxb((w, d, h), (0, 0, 0.6), "Wood")
    corner_trims(b, w, d, h, 0.6)
    plank_lines(b, w, d, 0.6, h)
    rise = 4.6
    b.gable_fill(w, d, rise, (0, 0, 0.6 + h), "Wood")
    b.gable(w, d, rise, (0, 0, 0.6 + h), "Roof", overhang=1.0, thick=0.6)
    # front door + windows
    b.boxb((3.0, 0.4, 4.2), (0, -d / 2 - 0.1, 0.6), "White")
    b.boxb((2.4, 0.4, 3.8), (0, -d / 2 - 0.2, 0.6), "RoofDark")
    b.box((0.3, 0.3, 0.3), (0.8, -d / 2 - 0.45, 2.6), "Accent")
    for x in (-4.4, 4.4):
        window(b, x, -d / 2, 4.2, 2.0, 1.8, frame="White")
    for y in (-2.5, 2.5):
        window(b, w / 2, y, 4.2, 2.0, 1.8, frame="White", face=1, axis="x")
        window(b, -w / 2, y, 4.2, 2.0, 1.8, frame="White", face=-1, axis="x")
    # round vent in the gable
    b.cyl(0.9, 0.3, (0, -d / 2 - 0.1, 0.6 + h + 1.8), "Accent", segs=12, rot=(90, 0, 0))
    b.cyl(0.6, 0.3, (0, -d / 2 - 0.2, 0.6 + h + 1.8), "Black", segs=12, rot=(90, 0, 0))
    # steps and a little weather vane
    b.boxb((3.6, 1.4, 0.3), (0, -d / 2 - 0.9, 0), "Path")
    b.cylb(0.12, 2.0, (0, 0, 0.6 + h + rise + 0.6), "GreyDark", segs=6)
    b.prism([(0, 0), (1.4, 0.3), (0, 0.6)], 0.15, (0, 0, 0.6 + h + rise + 2.1), "Accent", rot=(0, 0, 90))


def red_barn(b, w=24.0, d=30.0, wall_h=11.0, cupola=False, lean_to=False):
    b.boxb((w + 0.6, d + 0.6, 0.6), (0, 0, 0), "Path")
    b.boxb((w, d, wall_h), (0, 0, 0.6), "Roof")
    corner_trims(b, w, d, wall_h, 0.6, t=0.7)
    b.boxb((w + 0.1, d + 0.1, 0.5), (0, 0, 0.6 + wall_h - 0.5), "White")
    top = gambrel(b, w, d, 0.6 + wall_h)
    hay_loft(b, d, 0.6 + wall_h, 0.8, top)
    barn_door(b, 0, -d / 2, 0.6, w * 0.38, wall_h * 0.72)
    # side windows
    for y in (-d * 0.3, 0, d * 0.3):
        window(b, w / 2, y, 0.6 + wall_h * 0.62, 2.2, 2.2, face=1, axis="x")
        window(b, -w / 2, y, 0.6 + wall_h * 0.62, 2.2, 2.2, face=-1, axis="x")
    for x in (-w * 0.36, w * 0.36):
        window(b, x, -d / 2, 0.6 + wall_h * 0.62, 2.2, 2.2)
    roof_top = 0.6 + wall_h + top + 0.5
    if cupola:
        b.boxb((3.2, 3.2, 3.0), (0, 0, roof_top - 0.8), "White")
        for sx in (-1, 1):
            b.box((0.2, 2.2, 1.6), (sx * 1.65, 0, roof_top + 1.0), "WoodDark")
        b.cylb(3.0, 2.0, (0, 0, roof_top + 2.2), "RoofDark", segs=4, r2=0.0)
        b.cylb(0.12, 1.6, (0, 0, roof_top + 4.0), "GreyDark", segs=6)
        b.sphere(0.35, (0, 0, roof_top + 5.6), "Accent", u=8, v=6)
    if lean_to:
        lw = 7.0
        lx = w / 2 + lw / 2
        b.boxb((lw, d * 0.7, 6.0), (lx, 0, 0.6), "Roof")
        b.boxb((lw + 0.1, d * 0.7 + 0.1, 0.4), (lx, 0, 6.2), "White")
        b.prism([(-lw / 2 - 0.2, 0), (lw / 2 + 0.8, 0), (lw / 2 + 0.8, 0.5), (-lw / 2 - 0.2, 3.4)], d * 0.7 + 1.2,
                (lx, 0, 6.6), "RoofDark")
        barn_door(b, lx + 0.4, -d * 0.35, 0.6, 4.0, 4.6)


def big_barn(b):  # ~32 x 24 x 38 (plus lean-to)
    red_barn(b, w=26.0, d=36.0, wall_h=12.0, cupola=True, lean_to=True)


def red_barn_std(b):  # ~24 x 20 x 30
    red_barn(b)


def poultry_hall(b):  # ~44 x 18 x 30, long low ventilated shed
    w, d, h = 42.0, 26.0, 8.0
    b.boxb((w + 1, d + 1, 0.6), (0, 0, 0), "Path")
    b.boxb((w, d, h), (0, 0, 0.6), "White")
    b.boxb((w + 0.1, d + 0.1, 1.2), (0, 0, 0.6), "Roof")  # red skirting
    corner_trims(b, w, d, h, 0.6, mat="Wood", t=0.6)
    rise = 5.0
    # ridge along X for a long hall: build the roof rotated by placing slabs along X
    half = d / 2
    ang = math.atan2(rise, half)
    over = 1.0
    slant = math.hypot(half, rise) + over
    for side in (-1, 1):
        my = side * (half / 2 + over * math.cos(ang) / 2)
        mz = rise / 2 - over * math.sin(ang) / 2 + 0.35
        b.box((w + 2 * over, slant, 0.6), (0, my, 0.6 + h + mz), "Roof", rot=(-side * math.degrees(ang), 0, 0))
    b.box((w + 2 * over, 1.0, 0.7), (0, 0, 0.6 + h + rise + 0.6), "RoofDark")
    for sx in (-1, 1):
        b.prism([(-half, 0), (half, 0), (0, rise)], 0.6, (sx * (w / 2 - 0.3), 0, 0.6 + h), "White",
                rot=(0, 0, 90))
    # long window strip on the front and back
    for x in range(-16, 17, 6):
        window(b, x, -d / 2, 0.6 + h * 0.6, 3.0, 1.6, frame="Wood")
        window(b, x, d / 2, 0.6 + h * 0.6, 3.0, 1.6, frame="Wood", face=1)
    # end doors (big sliding doors on the -X/+X ends) and a front entrance canopy
    for sx in (-1, 1):
        b.boxb((0.4, 8.0, 6.5), (sx * (w / 2 + 0.2), 0, 0.6), "Roof")
        b.boxb((0.5, 0.4, 6.5), (sx * (w / 2 + 0.25), 0, 0.6), "White")
    b.boxb((5.0, 0.4, 5.0), (0, -d / 2 - 0.15, 0.6), "Wood")
    b.prism([(-3.2, 0), (3.2, 0), (0, 1.4)], 3.0, (0, -d / 2 - 1.3, 6.0), "Roof")
    for sx in (-2.8, 2.8):
        b.boxb((0.35, 0.35, 5.4), (sx, -d / 2 - 2.6, 0.6), "White")
    # roof vents
    for x in (-14, -4.7, 4.7, 14):
        b.cylb(0.9, 1.4, (x, 0, 0.6 + h + rise), "Metal", segs=10)
        b.cylb(1.3, 0.5, (x, 0, 0.6 + h + rise + 1.4), "GreyDark", segs=10, r2=0.4)
    # sign board with an egg on it
    b.box((8.0, 0.3, 1.8), (0, -d / 2 - 0.4, 0.6 + h - 0.6), "Accent")
    b.sphere(0.6, (0, -d / 2 - 0.6, 0.6 + h - 0.6), "White", scale=(0.8, 0.4, 1.0), u=10, v=6)


def egg_factory(b):  # ~40 x 28 x 36
    w, d, h = 34.0, 30.0, 14.0
    b.boxb((w + 1, d + 1, 0.6), (0, 0, 0), "GreyDark")
    b.boxb((w, d, h), (0, 0, 0.6), "Cream")
    b.boxb((w + 0.1, d + 0.1, 1.6), (0, 0, 0.6), "Grey")
    b.boxb((w + 0.4, d + 0.4, 0.8), (0, 0, 0.6 + h - 0.8), "Roof")
    # sawtooth roof (teeth run along X, glass on the steep faces)
    n = 4
    tooth = d / n
    for i in range(n):
        y0 = -d / 2 + i * tooth
        b.prism([(0, 0), (tooth, 0), (tooth, 4.0)], w, (0, y0, 0.6 + h), "Grey", rot=(0, 0, 90))
        b.box((w - 1, 0.2, 3.4), (0, y0 + tooth - 0.15, 0.6 + h + 2.0), "Glass")
    # chimneys
    for x, hh in ((-11, 12.0), (-6.5, 9.0)):
        b.cylb(1.4, hh, (x, d * 0.3, 0.6 + h), "Roof", segs=12)
        for k in (0.3, 0.7):
            b.cylb(1.5, 0.6, (x, d * 0.3, 0.6 + h + hh * k), "White", segs=12)
    # loading door + windows
    b.boxb((10.0, 0.4, 8.0), (-6, -d / 2 - 0.1, 0.6), "GreyDark")
    for z in range(2, 8, 1):
        b.box((9.6, 0.5, 0.12), (-6, -d / 2 - 0.2, 0.6 + z), "Grey")
    for x in (5, 11):
        window(b, x, -d / 2, 0.6 + 4.0, 3.6, 2.6, frame="Roof")
        window(b, x, -d / 2, 0.6 + 10.0, 3.6, 2.6, frame="Roof")
    # conveyor tunnel coming out the right side with crates of eggs
    b.boxb((8.0, 4.0, 0.6), (w / 2 + 4, -4, 3.0), "GreyDark")
    for x in (w / 2 + 1, w / 2 + 7):
        b.boxb((0.5, 3.6, 3.0), (x, -4, 0), "Grey")
    b.boxb((8.0, 0.3, 0.8), (w / 2 + 4, -5.85, 3.6), "Accent")
    b.boxb((8.0, 0.3, 0.8), (w / 2 + 4, -2.15, 3.6), "Accent")
    for x in (w / 2 + 2, w / 2 + 5.5):
        b.boxb((2.4, 2.4, 1.0), (x, -4, 3.6), "Wood")
        for dx in (-0.6, 0.6):
            for dy in (-0.6, 0.6):
                b.sphere(0.45, (x + dx, -4 + dy, 4.75), "White", scale=(1, 1, 1.25), u=8, v=6)
    # giant egg mascot on the roof front
    b.boxb((10.0, 1.0, 0.8), (6, -d / 2 + 2, 0.6 + h), "GreyDark")
    b.sphere(3.0, (6, -d / 2 + 2, 0.6 + h + 4.6), "Accent", scale=(0.85, 0.5, 1.15), u=14, v=10)
    b.box((7.0, 0.3, 1.4), (6, -d / 2 + 0.3, 0.6 + h - 1.6), "Roof")


def hen_tower(b):  # ~16 x 40 x 16: stacked coop floors
    z = 0.0
    sizes = [(14.0, 8.0), (12.0, 7.5), (10.0, 7.0), (8.0, 6.5)]
    for i, (s, fh) in enumerate(sizes):
        wall = "Wood" if i % 2 == 0 else "Cream"
        b.boxb((s, s, fh), (0, 0, z), wall)
        corner_trims(b, s, s, fh, z)
        b.boxb((s + 1.6, s + 1.6, 0.5), (0, 0, z + fh), "Roof")  # floor ledge / balcony
        # railings on the ledge
        for sy in (-1, 1):
            b.boxb((s + 1.6, 0.15, 0.15), (0, sy * (s / 2 + 0.7), z + fh + 1.0), "White")
            b.boxb((0.15, s + 1.6, 0.15), (sy * (s / 2 + 0.7), 0, z + fh + 1.0), "White")
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.boxb((0.2, 0.2, 1.0), (sx * (s / 2 + 0.7), sy * (s / 2 + 0.7), z + fh + 0.5), "White")
        for x in (-s * 0.25, s * 0.25):
            window(b, x, -s / 2, z + fh * 0.55, 1.6, 1.8, frame="Accent")
        window(b, s / 2, 0, z + fh * 0.55, 1.6, 1.8, frame="Accent", face=1, axis="x")
        window(b, -s / 2, 0, z + fh * 0.55, 1.6, 1.8, frame="Accent", face=-1, axis="x")
        z += fh + 0.5
    b.boxb((3.0, 0.4, 4.0), (0, -7.1, 0), "RoofDark")
    # pyramid roof + flag
    b.cylb(6.6, 5.0, (0, 0, z), "Roof", segs=4, r2=0.0)
    b.cylb(0.12, 3.5, (0, 0, z + 4.6), "GreyDark", segs=6)
    b.prism([(0, 0), (2.2, 0.6), (0, 1.2)], 0.12, (0, 0, z + 6.7), "Accent", rot=(0, 0, 90))


def sky_roost(b):  # ~24 x 48 x 24: central column with roosting platforms
    b.cylb(6.0, 1.0, (0, 0, 0), "Path", segs=16)
    b.cylb(2.0, 36.0, (0, 0, 1.0), "Wood", segs=12, r2=1.6)
    for k in range(1, 6):
        b.cylb(2.1 - k * 0.07, 0.4, (0, 0, k * 6.0), "White", segs=12)
    # spiral of three platforms with mini coops
    plats = [(0, 10.0), (120, 18.0), (240, 26.0)]
    for ang, z in plats:
        a = math.radians(ang)
        px, py = math.cos(a) * 6.5, math.sin(a) * 6.5
        b.cylb(4.4, 0.6, (px, py, z), "WoodDark", segs=10)
        b.boxb((0.8, 6.5, 0.6), (math.cos(a) * 3.2, math.sin(a) * 3.2, z - 0.6), "WoodDark", rot=(0, 0, ang + 90))
        b.boxb((4.0, 3.4, 3.0), (px, py, z + 0.6), "Cream", rot=(0, 0, ang))
        b.cylb(3.2, 2.0, (px, py, z + 3.6), "Roof", segs=4, r2=0.0)
    # crow's-nest top coop
    top = 37.0
    b.cylb(8.0, 0.8, (0, 0, top), "WoodDark", segs=14)
    b.cylb(6.0, 4.5, (0, 0, top + 0.8), "Cream", segs=12)
    for i in range(6):
        a = math.radians(i * 60 + 30)
        b.box((0.3, 1.8, 1.8), (math.cos(a) * 6.0, math.sin(a) * 6.0, top + 3.0), "Glass", rot=(0, 0, i * 60 + 30))
    b.cylb(7.6, 5.0, (0, 0, top + 5.3), "Roof", segs=12, r2=0.2)
    b.cylb(0.15, 1.6, (0, 0, top + 10.2), "GreyDark", segs=6)
    b.sphere(0.6, (0, 0, top + 12.0), "Accent", u=8, v=6)
    # railing posts around the top deck
    for i in range(12):
        a = math.radians(i * 30)
        b.boxb((0.25, 0.25, 1.2), (math.cos(a) * 7.6, math.sin(a) * 7.6, top + 0.8), "White")


def mega_dome(b):  # ~50 x 30 x 50
    R = 22.0
    b.cylb(R + 3.0, 1.0, (0, 0, 0), "Path", segs=32)
    b.cylb(R + 0.6, 3.0, (0, 0, 1.0), "Roof", segs=32)
    b.cylb(R + 1.0, 0.6, (0, 0, 4.0), "Accent", segs=32)
    # dome: hemisphere squashed; alternate glass/white panels
    faces = b.sphere(R, (0, 0, 4.0), "White", scale=(1, 1, 1.15), u=24, v=12)
    idx_glass = b.mi("Glass")
    for f in faces:
        c = f.calc_center_median()
        if c.z < 4.0:
            continue
        ang = math.degrees(math.atan2(c.y, c.x)) % 360
        band = int((c.z - 4.0) / (R * 1.15) * 6)
        if int(ang / 15) % 2 == band % 2:
            f.material_index = idx_glass
    # remove the lower half of the dome (below the ring)
    import bmesh as _bm

    lower = [f for f in faces if f.calc_center_median().z < 4.0 - 0.01]
    _bm.ops.delete(b.bm, geom=lower, context="FACES")
    # ribs
    for i in range(8):
        a = i * 45
        for k in range(5):
            el = math.radians(8 + k * 17)
            r = R * math.cos(el) + 0.25
            zz = 4.0 + R * 1.15 * math.sin(el)
            b.box((0.6, 0.6, R * 0.32), (math.cos(math.radians(a)) * r, math.sin(math.radians(a)) * r, zz),
                  "Accent", rot=(0, -math.degrees(el), a))
    # entrance arch (front -Y)
    b.boxb((9.0, 5.0, 8.0), (0, -R - 1.0, 0), "White")
    b.prism([(-4.5, 0), (4.5, 0), (0, 2.5)], 5.4, (0, -R - 1.0, 8.0), "Roof")
    b.boxb((5.0, 0.4, 6.0), (0, -R - 3.5, 1.0), "Glass")
    b.boxb((5.6, 0.5, 0.5), (0, -R - 3.6, 7.0), "Accent")
    # top beacon
    b.cylb(2.0, 1.2, (0, 0, 4.0 + R * 1.15 - 0.4), "Accent", segs=12)
    b.sphere(1.2, (0, 0, 4.0 + R * 1.15 + 1.4), "Light", u=10, v=6)


# ---------------------------------------------------------------- farm buildings
def warehouse(b):  # ~40 x 24 x 30, loading dock on the front (-Y)
    w, d, h = 36.0, 24.0, 16.0
    b.boxb((w, d, h), (0, 0, 0), "Grey")
    # vertical cladding ribs
    x = -w / 2 + 1.5
    while x < w / 2 - 1:
        for sy in (-1, 1):
            b.boxb((0.3, 0.2, h), (x, sy * (d / 2 + 0.05), 0), "Metal")
        x += 3.0
    b.boxb((w + 0.2, d + 0.2, 1.0), (0, 0, h - 1.0), "Roof")
    rise = 4.0
    # roof ridge along X
    half = d / 2
    ang = math.atan2(rise, half)
    over = 0.8
    slant = math.hypot(half, rise) + over
    for side in (-1, 1):
        my = side * (half / 2 + over * math.cos(ang) / 2)
        mz = rise / 2 - over * math.sin(ang) / 2 + 0.3
        b.box((w + 2 * over, slant, 0.5), (0, my, h + mz), "GreyDark", rot=(-side * math.degrees(ang), 0, 0))
    for sx in (-1, 1):
        b.prism([(-half, 0), (half, 0), (0, rise)], 0.4, (sx * (w / 2 - 0.2), 0, h), "Grey", rot=(0, 0, 90))
    # loading dock: raised concrete platform with bumpers + roll-up doors
    dock_h = 3.6
    b.boxb((w - 4, 6.0, dock_h), (0, -d / 2 - 3.0, 0), "Path")
    b.boxb((w - 4, 0.3, 0.3), (0, -d / 2 - 6.0, dock_h - 0.15), "Accent")
    for x in (-10, 0, 10):
        b.boxb((7.0, 0.4, 8.0), (x, -d / 2 - 0.1, dock_h), "Metal")
        for z in range(1, 8):
            b.box((7.0, 0.55, 0.12), (x, -d / 2 - 0.2, dock_h + z), "GreyDark")
        b.boxb((8.0, 0.5, 0.6), (x, -d / 2 - 0.2, dock_h + 8.0), "Accent")
        for sx in (-2.6, 2.6):
            b.boxb((0.8, 0.6, 1.2), (x + sx, -d / 2 - 6.3, dock_h - 1.6), "Black")  # bumpers
    # dock canopy
    b.box((w - 2, 7.0, 0.5), (0, -d / 2 - 3.5, dock_h + 10.0), "Roof", rot=(-6, 0, 0))
    for x in (-16, 16):
        b.boxb((0.4, 0.4, 10.0), (x, -d / 2 - 6.4, dock_h), "White")
    # stairs on the left end of the dock
    for i in range(4):
        b.boxb((2.4, 1.0, dock_h * (i + 1) / 4), (-(w - 4) / 2 - 1.2, -d / 2 - 3.0 - 1.5 + i * 1.0, 0), "Path")
    # sign
    b.box((12.0, 0.3, 2.6), (0, -d / 2 - 0.3, h - 2.6), "Accent")
    b.sphere(0.9, (-4.5, -d / 2 - 0.5, h - 2.6), "White", scale=(0.8, 0.35, 1.05), u=10, v=6)


def silo(b):  # ~11 dia x 30 tall
    r = 5.0
    b.cylb(r + 0.6, 0.8, (0, 0, 0), "GreyDark", segs=20)
    b.cylb(r, 24.0, (0, 0, 0.8), "Metal", segs=20)
    for z in range(4, 24, 4):
        b.cylb(r + 0.15, 0.4, (0, 0, 0.8 + z), "Grey", segs=20)
    b.cylb(r + 0.2, 1.0, (0, 0, 0.8 + 11.0), "Roof", segs=20)  # red band
    # dome cap
    faces = b.sphere(r + 0.3, (0, 0, 24.8), "Roof", scale=(1, 1, 0.55), u=20, v=10)
    import bmesh as _bm

    _bm.ops.delete(b.bm, geom=[f for f in faces if f.calc_center_median().z < 24.79], context="FACES")
    b.cylb(0.9, 1.0, (0, 0, 24.8 + (r + 0.3) * 0.55 - 0.2), "Accent", segs=10, r2=0.5)
    # ladder up the front
    for sx in (-0.6, 0.6):
        b.boxb((0.18, 0.18, 26.0), (sx, -r - 0.5, 0.8), "GreyDark")
    for z in range(2, 26, 1):
        b.box((1.2, 0.14, 0.14), (0, -r - 0.5, 0.8 + z), "GreyDark")
    # chute out the side
    b.cyl(0.7, 4.0, (r + 1.4, 0, 3.5), "Grey", segs=8, rot=(0, 50, 0))
    b.boxb((1.6, 1.6, 2.0), (r + 0.4, 0, 0.8), "Wood")


ASSETS = {
    "Housing": [
        ("LittleCoop", little_coop),
        ("TwinCoop", twin_coop),
        ("HenHouse", hen_house),
        ("RedBarn", red_barn_std),
        ("BigBarn", big_barn),
        ("PoultryHall", poultry_hall),
        ("EggFactory", egg_factory),
        ("HenTower", hen_tower),
        ("SkyRoost", sky_roost),
        ("MegaDome", mega_dome),
    ],
    "Buildings": [
        ("Warehouse", warehouse),
        ("Silo", silo),
    ],
}
