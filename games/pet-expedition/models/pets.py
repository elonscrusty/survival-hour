"""All 41 pets in the blocky voxel-toy style of reference/puppy_variants.jpg:
box head bigger than the body, box ears, legs and square paws, and a flat
cute face on the front of the head (big round disc eyes with two highlights,
pink disc blush, small nose, open smiling mouth with a tongue).

Big boxes are split into horizontal slabs so the Rainbow variant (hue by
height) paints stripes across them like the reference.

Part tags used by the runtime recolour (Models/init.luau):
  Eye     eyes, highlights, blush, nose, mouth: never recoloured
  Collar  collar and bell: keep their colour on Golden/Rainbow
  Face    muzzle / face patch: kept cream on Rainbow, gilded on Golden
  Body    everything else that should be recoloured
  Glow    neon accents
Pets are authored in loose units and normalised to their rarity height by
gen_models.py. Front = -Z.
"""
import math
from lib import (ball, box, cyl, wedge, T, sym, mirror, tri, crystal, rot, mmul, rx, ry, rz, shade, mix,
                 add, mul, RAINBOW)

EYE = 0x15121C
WHITE = 0xFFFFFF
CREAM = 0xFFF3DC
BLUSH = 0xFF8FA8
MOUTH = 0x5A1E2A
TONGUE = 0xFF6F86
DARK = 0x1E1A22
GOLD = 0xFFC93C
COLLAR = 0xE03A44


# ======================================================================= building blocks
def slab(size, center, col, n=1, mat="P", tag="Body", cols=None, t=0.0):
    """A box split into n horizontal slabs (looks like one box, stripes on Rainbow)."""
    sx, sy, sz = size
    cx, cy, cz = center
    h = sy / n
    return [box((sx, h, sz), (cx, cy - sy / 2 + h * (i + 0.5), cz), cols[i % len(cols)] if cols else col, mat, tag=tag, t=t)
            for i in range(n)]


def disc(d, pos, col, mat="P", tag="Eye", th=0.06):
    """Flat round disc facing -Z (a short cylinder)."""
    return cyl(d, th, pos, col, mat, r=(90, 0, 0), tag=tag)


def face(c, s=1.0, eye_dx=0.68, eye_y=0.2, eye=0.8, muzzle=CREAM, muzzle_w=1.1, muzzle_h=0.8, blaze=None,
         mouth=True, nose=DARK, blush=BLUSH, iris=None, eye_col=EYE, R=None, open_mouth=True, nose_y=-0.2, small_hi=True):
    """Flat cartoon face. c = centre of the face plane (front surface of the
    head); the face looks along -Z. Sizes scale with s (head height ~2)."""
    p = []
    z = 0.0
    if muzzle is not None:
        p.append(box((muzzle_w, muzzle_h, 0.08), (0, -0.48, z - 0.03), muzzle, tag="Face"))
    if blaze is not None:
        p.append(box((0.3, 0.75, 0.08), (0, 0.18, z - 0.03), blaze, tag="Face"))
    for sx in (-1, 1):
        ex = sx * eye_dx
        p.append(disc(eye, (ex, eye_y, z - 0.04), eye_col))
        if iris is not None:
            p.append(disc(eye * 0.62, (ex, eye_y - eye * 0.05, z - 0.08), iris, th=0.04))
        p.append(disc(eye * 0.36, (ex + eye * 0.16, eye_y + eye * 0.17, z - 0.1), WHITE, "N", th=0.04))
        if small_hi:
            p.append(disc(eye * 0.16, (ex - eye * 0.15, eye_y - eye * 0.18, z - 0.1), WHITE, "N", th=0.04))
        if blush is not None:
            p.append(disc(0.4, (sx * (eye_dx + 0.3), eye_y - 0.6, z - 0.03), blush))
    if nose is not None:
        p.append(ball((0.32, 0.22, 0.18), (0, nose_y, z - 0.1), nose, tag="Eye"))
    if mouth:
        if open_mouth:
            mc = muzzle if muzzle is not None else None
            p.append(disc(0.56, (0, -0.52, z - 0.08), MOUTH, th=0.05))
            if mc is not None:
                p.append(box((0.66, 0.29, 0.06), (0, -0.375, z - 0.1), mc, tag="Face"))
            p.append(disc(0.3, (0, -0.66, z - 0.11), TONGUE, th=0.04))
        else:
            p.append(box((0.36, 0.07, 0.05), (0, -0.48, z - 0.09), MOUTH, tag="Eye"))
    return T(p, c, s=s, R=R)


def legs(col, paw=None, x=0.5, zf=-0.3, zb=1.0, size=(0.58, 0.7, 0.6), back=True):
    out = []
    for z in ((zf, zb) if back else (zf,)):
        out.append(box(size, (x, size[1] / 2 + 0.05, z), col))
        if paw is not None:
            out.append(box((size[0] + 0.06, 0.3, size[2] + 0.08), (x, 0.15, z - 0.03), paw))
    return sym(out)


def ears(kind, col, inner=None, hw=2.5, top=3.6, hz=-0.35, size=1.0):
    """Ears for a head of width hw whose top is at y=top."""
    s = size
    if kind == "floppy":
        return sym([box((0.5 * s, 1.5 * s, 1.0 * s), (hw / 2 + 0.2 * s, top - 0.62 * s, hz + 0.05), col, r=(0, 0, 14))])
    if kind == "pointy":
        p = tri((0, 0, 0), 0.9 * s, 0.85 * s, 0.42 * s, col)
        if inner is not None:
            p += tri((0, 0.05, -0.2 * s), 0.5 * s, 0.5 * s, 0.06, inner)
        return sym(T(p, (hw / 2 - 0.45 * s, top - 0.05, hz), r=(0, 0, -10)))
    if kind == "round":
        p = [box((0.68 * s, 0.6 * s, 0.4 * s), (0, 0, 0), col)]
        if inner is not None:
            p.append(box((0.38 * s, 0.32 * s, 0.06), (0, -0.04, -0.22 * s), inner))
        return sym(T(p, (hw / 2 - 0.35 * s, top + 0.15 * s, hz), r=(0, 0, -8)))
    if kind == "long":
        p = [box((0.55 * s, 1.75 * s, 0.38 * s), (0, 0.85 * s, 0), col)]
        if inner is not None:
            p.append(box((0.3 * s, 1.35 * s, 0.06), (0, 0.85 * s, -0.21 * s), inner))
        return sym(T(p, (0.55 * s, top - 0.1, hz + 0.1), r=(6, 0, -8)))
    raise ValueError(kind)


def tail(kind, col, tip=None, base=(0, 1.55, 1.25)):
    bx, by, bz = base
    if kind == "dog":
        return [box((0.42, 0.7, 0.42), (bx, by + 0.15, bz + 0.1), col, r=(-35, 0, 0)),
                box((0.4, 0.55, 0.4), (bx, by + 0.6, bz + 0.38), tip if tip is not None else col, r=(-35, 0, 0))]
    if kind == "bushy":
        p = [box((0.85, 0.85, 1.3), (bx, by + 0.3, bz + 0.55), col, r=(-40, 0, 0))]
        p.append(box((0.75, 0.75, 0.6), (bx, by + 0.95, bz + 1.15), tip if tip is not None else col, r=(-40, 0, 0)))
        return p
    if kind == "cat":
        return [box((0.32, 0.32, 0.8), (bx, by - 0.1, bz + 0.3), col), box((0.32, 1.0, 0.32), (bx, by + 0.45, bz + 0.6), col),
                box((0.34, 0.34, 0.34), (bx, by + 1.05, bz + 0.6), tip if tip is not None else col)]
    if kind == "pom":
        return [box((0.6, 0.6, 0.5), (bx, by - 0.15, bz + 0.05), tip if tip is not None else col)]
    if kind == "long":
        return [box((0.55, 0.45, 0.8), (bx, by - 0.6, bz + 0.3), col), box((0.42, 0.36, 0.8), (bx, by - 0.75, bz + 1.0), col),
                box((0.32, 0.3, 0.6), (bx, by - 0.8, bz + 1.6), tip if tip is not None else col)]
    raise ValueError(kind)


def quad(body, head=None, face_kw=None, ears_kw=None, tail_kw=None, paw=None, belly=CREAM, collar=None, extras=None,
         head_size=(2.6, 2.1, 2.2), body_size=(1.5, 1.15, 1.7), leg_col=None, head_n=3, body_n=2, legs_on=True):
    """Blocky standing quadruped, puppy proportions: head ~55% of the height."""
    head = head if head is not None else body
    hw, hh, hd = head_size
    bw, bh, bd = body_size
    leg_h = 0.62
    body_c = (0, leg_h + bh / 2 - 0.05, 0.35)
    head_c = (0, leg_h + bh - 0.25 + hh / 2, -0.25)
    top = head_c[1] + hh / 2
    p = []
    if legs_on:
        p += legs(leg_col if leg_col is not None else body, paw, x=bw / 2 - 0.3, zf=body_c[2] - bd / 2 + 0.32,
                  zb=body_c[2] + bd / 2 - 0.32, size=(0.56, leg_h, 0.58))
    p += slab(body_size, body_c, body, body_n)
    if belly is not None:
        p.append(box((bw * 0.62, bh * 0.75, 0.08), (0, body_c[1] - 0.05, body_c[2] - bd / 2 - 0.03), belly, tag="Face"))
    p += slab(head_size, head_c, head, head_n)
    fk = dict(face_kw or {})
    p += face((0, head_c[1] - 0.12, head_c[2] - hd / 2 - 0.01), **fk)
    if ears_kw:
        ek = dict(ears_kw)
        kind = ek.pop("kind")
        col = ek.pop("col", head)
        p += ears(kind, col, hw=hw, top=top, hz=head_c[2], **ek)
    if tail_kw:
        tk = dict(tail_kw)
        kind = tk.pop("kind")
        col = tk.pop("col", body)
        p += tail(kind, col, base=(0, body_c[1] + 0.2, body_c[2] + bd / 2 - 0.1), **tk)
    if collar is not None:
        p.append(box((bw + 0.14, 0.28, 1.0), (0, leg_h + bh - 0.2, body_c[2] - bd / 2 + 0.45), collar, tag="Collar"))
        p.append(ball(0.36, (0, leg_h + bh - 0.42, body_c[2] - bd / 2 - 0.08), GOLD, "F", tag="Collar"))
    if extras:
        p += extras
    return p


HEAD_TOP = 0.62 + 1.15 - 0.25 + 2.1  # quad(): top of the default head (y)
HEAD_C = (0, 0.62 + 1.15 - 0.25 + 1.05, -0.25)
HEAD_FRONT = -0.25 - 1.1
BODY_TOP = 0.62 + 1.15 - 0.05  # quad(): top of the default body (y)


def sitter(body, head=None, face_kw=None, ears_kw=None, tail_kw=None, paw=None, belly=CREAM, extras=None,
           head_size=(2.5, 2.1, 2.1), body_size=(1.7, 1.5, 1.6), head_n=3):
    """Blocky sitting pet (bunnies, bears): big feet in front, no back legs."""
    head = head if head is not None else body
    hw, hh, hd = head_size
    bw, bh, bd = body_size
    body_c = (0, bh / 2, 0.25)
    head_c = (0, bh - 0.2 + hh / 2, -0.1)
    top = head_c[1] + hh / 2
    p = slab(body_size, body_c, body, 2)
    p += sym([box((0.6, 0.36, 0.95), (bw / 2 - 0.3, 0.18, -0.35), paw if paw is not None else body),
              box((0.42, 0.55, 0.42), (bw / 2 - 0.42, bh * 0.45, body_c[2] - bd / 2 - 0.05), body)])
    if belly is not None:
        p.append(box((bw * 0.6, bh * 0.6, 0.08), (0, bh * 0.45, body_c[2] - bd / 2 - 0.03), belly, tag="Face"))
    p += slab(head_size, head_c, head, head_n)
    p += face((0, head_c[1] - 0.12, head_c[2] - hd / 2 - 0.01), **(face_kw or {}))
    if ears_kw:
        ek = dict(ears_kw)
        kind = ek.pop("kind")
        col = ek.pop("col", head)
        p += ears(kind, col, hw=hw, top=top, hz=head_c[2], **ek)
    if tail_kw:
        tk = dict(tail_kw)
        kind = tk.pop("kind")
        col = tk.pop("col", body)
        p += tail(kind, col, base=(0, 0.75, body_c[2] + bd / 2 - 0.1), **tk)
    if extras:
        p += extras
    return p


def wing(col, membrane=None, span=1.8, at=(1.0, 2.0, 0.6), lift=25, sweep=-25, mat="P", t=0.0, tag=None):
    """Blocky wing on the +X side: a spar and two stepped membrane boxes."""
    m = membrane if membrane is not None else col
    p = [box((span, 0.28, 0.28), (span / 2, 0.15, 0), col),
         box((span * 0.85, 0.75, 0.12), (span * 0.45, -0.3, 0), m, mat, t=t, tag=tag),
         box((span * 0.55, 0.55, 0.12), (span * 0.3, -0.85, 0), m, mat, t=t, tag=tag)]
    return T(p, at, r=(0, sweep, lift))


def horn(base, col, mat="P", n=3, s=0.42, h=0.9, r=(0, 0, 0), tag=None, cols=None):
    """Stepped blocky horn: shrinking cubes stacked along local Y."""
    out = []
    for i in range(n):
        f = 1 - 0.7 * i / max(1, n - 1) if n > 2 else 1 - 0.3 * i
        c = cols[i % len(cols)] if cols else col
        out.append(box((s * f, h / n * 1.05, s * f), (0, h / n * (i + 0.5), 0), c, mat, r=(0, 45 * (i % 2), 0), tag=tag))
    return T(out, base, r=r)


def cubes(points, col, size=0.18, mat="N", tag="Glow"):
    return [box((size, size, size), pt, col, mat, r=(0, 45, 0), tag=tag) for pt in points]


# ======================================================================= Meadow
def puppy():
    return quad(0xE7B57A, face_kw=dict(blaze=CREAM), ears_kw=dict(kind="floppy", col=0x9A6235),
                tail_kw=dict(kind="dog"), paw=CREAM, collar=COLLAR)


def kitten():
    o, dk = 0xF59A3A, 0xC8641E
    hc = HEAD_C
    stripes = [box((0.3, 0.5, 0.08), (x, HEAD_TOP - 0.3, HEAD_FRONT - 0.03), dk) for x in (-0.45, 0, 0.45)]
    stripes += [box((1.56, 0.06, 0.25), (0, BODY_TOP + 0.01, 0.35 + dz), dk) for dz in (-0.3, 0.3)]
    return quad(o, face_kw=dict(nose=0xFF7FA0), ears_kw=dict(kind="pointy", inner=0xFFB0C4),
                tail_kw=dict(kind="cat", tip=dk), paw=CREAM, extras=stripes)


def bunny_pet():
    return sitter(0xFAFAFA, face_kw=dict(nose=0xFF7FA0, muzzle=0xFFF0F4), ears_kw=dict(kind="long", inner=0xFFA6C0),
                  tail_kw=dict(kind="pom"), paw=0xF2EEF2, belly=0xFFF0F4)


def fox():
    body, dk = 0xEC6A2C, 0x3A2A2A
    return quad(body, face_kw=dict(muzzle=WHITE, muzzle_w=1.5, muzzle_h=0.9), ears_kw=dict(kind="pointy", inner=dk, size=1.1),
                tail_kw=dict(kind="bushy", tip=WHITE), paw=dk, belly=WHITE)


def honey_bear():
    gold, cream, pot, honey = 0xE7A63A, 0xFCE3B0, 0xC9732E, 0xFFC531
    ex = [box((1.1, 1.0, 1.0), (0, 1.0, -0.95), pot), box((0.9, 0.25, 0.9), (0, 1.6, -0.95), honey, "N", tag="Glow"),
          box((0.3, 0.45, 0.2), (0.3, 1.25, -1.5), honey, "N", tag="Glow"), box((0.7, 0.35, 0.06), (0, 0.95, -1.47), 0xFFF3D6)]
    ex += sym([box((0.45, 0.45, 1.0), (0.75, 1.3, -0.55), gold, r=(30, 0, 0)),
               box((1.2, 0.7, 0.08), (1.0, 2.7, 1.0), 0xE8F6FF, "G", r=(0, -30, 25), t=0.35),
               box((0.8, 0.5, 0.08), (0.85, 2.1, 1.05), 0xE8F6FF, "G", r=(0, -30, -10), t=0.35)])
    ex.append(box((1.82, 0.3, 1.72), (0, 1.25, 0.25), 0x3A2A1A))
    return sitter(gold, face_kw=dict(muzzle=cream), ears_kw=dict(kind="round", inner=cream), paw=cream, belly=cream,
                  extras=ex)


def sunflower_sprite():
    g, lg, petal, centre = 0x6CC24A, 0xA6E07A, 0xFFD12E, 0x6B3E1E
    hat = [box((1.5, 0.35, 1.5), (0, 0, 0), centre)]
    for i in range(8):
        a = 360 * i / 8
        ar = math.radians(a)
        hat.append(box((0.55, 0.16, 0.9), (math.sin(ar) * 1.05, -0.05, -math.cos(ar) * 1.05), petal, r=(0, -a, 0)))
    hat.append(box((0.15, 0.5, 0.15), (0, 0.4, 0), g))
    ex = T(hat, (0, 3.6, -0.15), r=(-12, 0, 6))
    ex += sym([box((0.9, 0.3, 0.45), (1.0, 1.25, 0.1), 0x8FD45A, r=(0, 0, 30)),
               box((1.0, 0.6, 0.08), (0.8, 1.7, 0.85), 0x9BE36A, r=(0, -35, 35))])
    return sitter(g, head=lg, face_kw=dict(muzzle=None, nose=None), body_size=(1.3, 1.3, 1.2), head_size=(2.2, 2.0, 1.9),
                  paw=0x4FA83A, belly=None, extras=ex)


# ======================================================================= Grove
def toadstool():
    red, spot, stem = 0xE0393E, 0xFFF6EA, 0xFFF0D8
    p = slab((1.7, 1.6, 1.5), (0, 0.95, 0), stem, 2)
    p += sym([box((0.6, 0.35, 0.8), (0.45, 0.17, -0.2), 0xD9B48A)])
    p += face((0, 0.95, -0.76), s=0.75, muzzle=None)
    p += [box((3.0, 0.75, 3.0), (0, 2.15, 0), red, tag="Body"), box((2.2, 0.55, 2.2), (0, 2.75, 0), red, tag="Body"),
          box((2.6, 0.2, 2.6), (0, 1.72, 0), 0xF0D2B0)]
    for pos in ((0.6, 3.04, 0.3), (-0.55, 3.04, -0.45), (1.52, 2.2, 0.5), (-1.52, 2.25, -0.3), (0.3, 2.3, -1.52), (-0.6, 2.1, 1.52)):
        sz = (0.5, 0.06, 0.5) if pos[1] > 3 else ((0.06, 0.45, 0.45) if abs(pos[0]) > 1.5 else (0.45, 0.45, 0.06))
        p.append(box(sz, pos, spot))
    return p


def snail():
    body, shell, ring_c, moss = 0xD8C08A, 0xA0673E, 0xC8915A, 0x6AB04F
    p = [box((1.1, 0.6, 2.8), (0, 0.3, 0.1), body), box((1.2, 1.4, 1.1), (0, 1.0, -1.0), body)]
    p += face((0, 1.05, -1.56), s=0.55, muzzle=None)
    p += sym([box((0.14, 0.6, 0.14), (0.3, 1.95, -1.0), body), box((0.26, 0.26, 0.26), (0.3, 2.3, -1.0), body)])
    p += slab((1.3, 2.2, 2.2), (0, 1.65, 0.5), shell, 3)
    p += sym([box((0.06, 1.5, 1.5), (0.66, 1.7, 0.5), ring_c), box((0.06, 0.9, 0.9), (0.7, 1.75, 0.55), shell),
              box((0.06, 0.4, 0.4), (0.73, 1.8, 0.6), ring_c)])
    p += [box((1.0, 0.25, 1.1), (0.1, 2.85, 0.4), moss, "E"), box((0.6, 0.2, 0.6), (-0.2, 3.05, 0.6), moss, "E"),
          box((0.3, 0.12, 0.6), (0.1, 3.2, 0.35), 0x8CE06A, r=(0, 30, 30))]
    return p


def frog():
    g, belly, dk = 0x5BBF4A, 0xDDF2A8, 0x3E8F35
    p = slab((2.5, 1.6, 2.1), (0, 1.0, 0), g, 2)
    p.append(box((1.6, 0.9, 0.08), (0, 0.75, -1.08), belly, tag="Face"))
    p += sym([box((0.9, 0.85, 0.9), (0.72, 2.1, -0.4), g)])
    p += sym([disc(0.62, (0.72, 2.12, -0.88), EYE), disc(0.22, (0.82, 2.24, -0.93), WHITE, "N", th=0.04),
              disc(0.1, (0.62, 2.0, -0.93), WHITE, "N", th=0.04), disc(0.36, (0.95, 1.25, -1.08), BLUSH)])
    p += [disc(0.5, (0, 1.2, -1.1), MOUTH, th=0.05), box((0.6, 0.26, 0.06), (0, 1.33, -1.13), g),
          disc(0.26, (0, 1.08, -1.14), TONGUE, th=0.04)]
    p += sym([box((0.7, 0.6, 1.1), (1.15, 0.35, 0.4), g), box((0.75, 0.2, 0.7), (1.2, 0.1, -0.25), dk),
              box((0.45, 0.6, 0.45), (0.7, 0.35, -0.75), g), box((0.55, 0.16, 0.55), (0.75, 0.08, -0.88), dk)])
    p += [box((1.6, 0.14, 1.2), (0, 2.0, 0.35), 0x8FD94A, r=(-10, 25, 6)), box((0.1, 0.45, 0.1), (0.3, 2.25, -0.1), 0x5AA83A, r=(20, 0, 20))]
    return p


def owl():
    br, face_c, belly, beak, wing_c = 0x8A5A3C, 0xE2C29A, 0xC9A27C, 0xF2A33A, 0x6E4630
    p = slab((2.4, 2.8, 2.2), (0, 1.55, 0), br, 3)
    p += sym([box((1.0, 1.0, 0.08), (0.52, 2.1, -1.13), face_c, tag="Face")])
    p.append(box((1.4, 1.2, 0.08), (0, 0.9, -1.13), belly, tag="Face"))
    p += sym([disc(0.8, (0.52, 2.12, -1.18), 0xFFC93C), disc(0.48, (0.52, 2.1, -1.22), EYE, th=0.04),
              disc(0.2, (0.6, 2.22, -1.25), WHITE, "N", th=0.03), disc(0.09, (0.44, 2.0, -1.25), WHITE, "N", th=0.03),
              disc(0.34, (0.95, 1.55, -1.14), BLUSH)])
    p += T(tri((0, 0, 0), 0.4, 0.4, 0.25, beak), (0, 1.75, -1.2), r=(0, 0, 180))
    p += sym([box((0.4, 1.7, 1.4), (1.35, 1.4, 0.2), wing_c, r=(0, 0, 8))])
    p += sym(T(tri((0, 0, 0), 0.6, 0.65, 0.4, br), (0.85, 2.92, -0.2), r=(0, 0, -15)))
    p += sym([box((0.5, 0.2, 0.6), (0.5, 0.1, -0.5), beak)])
    return p


def glowcap_dragon():
    purple, belly, cap = 0x7A4FC9, 0xC9A8F0, 0xFF6AD5
    def mush(at, s, col):
        return T([box((0.25, 0.4, 0.25), (0, 0.2, 0), 0xF6EEDC), box((0.75, 0.35, 0.75), (0, 0.52, 0), col, "N", tag="Glow")], at, s=s)
    ex = mush((0.6, HEAD_TOP - 0.05, -0.3), 1.0, 0x52F2FF) + mush((-0.55, HEAD_TOP - 0.05, -0.4), 0.85, cap)
    ex += mush((0, BODY_TOP, 0.6), 0.8, cap)
    ex += sym(wing(purple, 0xB57CFF, span=1.6, at=(0.7, BODY_TOP, 0.5)))
    return quad(purple, belly=belly, face_kw=dict(muzzle=belly, small_hi=False), ears_kw=dict(kind="pointy", size=0.7),
                tail_kw=dict(kind="long", tip=0x52F2FF), paw=belly, extras=ex)


def fairy_moth():
    fluff, body, wing_c = 0xFFF4E2, 0xE8D6C0, 0x5CF2E0
    ex = sym([box((2.2, 1.6, 0.1), (1.6, 3.0, 0.7), wing_c, "N", r=(0, -25, -18), t=0.25, tag="Glow"),
              box((1.6, 1.1, 0.1), (1.4, 1.8, 0.8), wing_c, "N", r=(0, -25, 20), t=0.25, tag="Glow"),
              box((0.5, 0.5, 0.12), (1.9, 3.2, 0.62), 0xFFF2A8, "N", r=(0, -25, -18)),
              box((0.12, 0.9, 0.12), (0.5, HEAD_TOP + 0.75, -0.6), 0x8A6E52, r=(-20, 0, -20)),
              box((0.45, 0.7, 0.12), (0.72, HEAD_TOP + 1.25, -0.8), fluff, r=(-20, 0, -20))])
    ex.append(box((1.9, 0.5, 1.5), (0, 2.0, 0.1), WHITE))
    return sitter(body, head=fluff, face_kw=dict(muzzle=None), belly=fluff, paw=body, extras=ex)


# ======================================================================= Frost
def penguin():
    blk, wh, org, scarf = 0x2B2E44, 0xFAFAFA, 0xFF9A2E, COLLAR
    p = slab((2.3, 3.0, 2.0), (0, 1.6, 0), blk, 3)
    p.append(box((1.7, 1.6, 0.08), (0, 1.0, -1.03), wh, tag="Face"))
    p.append(box((2.0, 1.05, 0.08), (0, 2.35, -1.03), wh, tag="Face"))
    p += face((0, 2.4, -1.08), s=0.8, muzzle=None, nose=None, mouth=False)
    p += T(tri((0, 0, 0), 0.5, 0.45, 0.4, org), (0, 2.12, -1.2), r=(0, 0, 180))
    p += sym([box((0.35, 1.4, 0.8), (1.25, 1.5, 0.05), blk, r=(0, 0, 15)), box((0.7, 0.2, 0.9), (0.5, 0.1, -0.3), org)])
    p += [box((2.4, 0.38, 2.1), (0, 1.75, 0), scarf, "X", tag="Collar"), box((0.42, 0.9, 0.14), (0.55, 1.25, -1.1), scarf, "X", tag="Collar")]
    return p


def snow_bunny():
    pale, muff = 0xCFE6FF, 0xFF7FB0
    top = 1.5 - 0.2 + 2.1
    ex = sym([box((0.6, 0.7, 0.7), (1.38, top - 1.0, -0.1), muff, "X", tag="Collar")])
    ex.append(box((2.9, 0.22, 0.3), (0, top + 0.15, -0.6), muff, "X", tag="Collar"))
    ex += sym([box((0.22, 1.0, 0.3), (1.38, top - 0.4, -0.6), muff, "X", tag="Collar")])
    return sitter(pale, face_kw=dict(nose=0xFF8FB0, muzzle=WHITE), ears_kw=dict(kind="long", inner=0x9CCBFF),
                  tail_kw=dict(kind="pom", tip=WHITE), paw=WHITE, belly=WHITE, extras=ex)


def arctic_fox():
    return quad(0xF4F6FA, face_kw=dict(muzzle=WHITE, muzzle_w=1.5, iris=0x4FB0F0), ears_kw=dict(kind="pointy", inner=0x9FD6FF, size=1.1),
                tail_kw=dict(kind="bushy", tip=0x6FC8FF), paw=0xDDE6F0, belly=WHITE)


def yeti():
    wh, face_c, horn_c = 0xF6F8FC, 0x7EC8F0, 0xEDE3C8
    p = slab((2.8, 2.4, 2.2), (0, 2.2, 0), wh, 3)
    p += slab((2.2, 1.2, 1.8), (0, 0.75, 0.1), wh, 1)
    p.append(box((2.0, 1.5, 0.08), (0, 2.1, -1.13), face_c, tag="Face"))
    p += face((0, 2.25, -1.18), s=0.85, muzzle=None, nose=0x2A3A5A)
    p += sym([box((0.12, 0.2, 0.06), (0.15, 1.82, -1.22), WHITE, tag="Eye")])
    p += sym(horn((1.1, 3.3, -0.3), horn_c, r=(0, 0, -30), s=0.4, h=0.8))
    p += sym([box((0.8, 1.7, 0.8), (1.75, 1.5, -0.2), wh, r=(10, 0, 10)), box((0.7, 0.4, 0.7), (1.85, 0.55, -0.35), face_c),
              box((0.8, 0.4, 1.0), (0.6, 0.2, -0.3), wh)])
    for pos in ((1.0, 3.45, 0.4), (-0.9, 3.45, 0.6), (0.1, 3.5, 0.9)):
        p.append(box((0.6, 0.3, 0.6), pos, wh, r=(0, 30, 0)))
    return p


def aurora_wolf():
    navy, belly = 0x2B2F4A, 0x5A6080
    ex = [box((1.7, 0.18, 0.3), (0, BODY_TOP + 0.03, z), c, "N", tag="Glow") for z, c in ((-0.1, 0x4CFFB0), (0.4, 0x4CC9FF), (0.9, 0xB06CFF))]
    ex += [box((0.3, 0.7, 0.08), (0, HEAD_TOP - 0.45, HEAD_FRONT - 0.03), 0x4CFFB0, "N", tag="Glow")]
    ex += sym([box((0.08, 0.15, 0.7), (1.32, HEAD_C[1] + 0.2, HEAD_C[2]), 0x4CC9FF, "N", tag="Glow")])
    return quad(navy, face_kw=dict(muzzle=belly, muzzle_w=1.4, iris=0x7CF2FF, blush=None), ears_kw=dict(kind="pointy", inner=0x4CC9FF, size=1.15),
                tail_kw=dict(kind="bushy", tip=0x4CFFB0), paw=0x1C1F33, belly=belly, extras=ex)


def polar_king():
    wh, crown, cape, trim = 0xF2F4F8, 0x9FE6FF, 0xC0263A, 0xFFFFFF
    cr = [box((1.8, 0.3, 1.5), (0, 0, 0), GOLD, "F", tag="Collar")]
    for x in (-0.6, 0, 0.6):
        cr += crystal((x, 0.1, -0.5), 0.3, 0.9 if x == 0 else 0.65, crown, "G", t=0.1)
    cr.append(box((0.26, 0.26, 0.1), (0, 0.05, -0.78), 0x4FB0FF, "N", tag="Glow"))
    ex = T(cr, (0, HEAD_TOP + 0.1, -0.25))
    ex += [box((1.85, 1.0, 1.9), (0, 1.7, 0.45), cape, "X", tag="Collar"), box((1.9, 0.4, 0.4), (0, 1.95, -0.6), trim, "X", tag="Collar")]
    return quad(wh, face_kw=dict(muzzle=WHITE), ears_kw=dict(kind="round", inner=0xDDE3EE), tail_kw=dict(kind="pom"),
                paw=0xE4E8F0, belly=None, extras=ex)


# ======================================================================= Coral
def crab():
    red, belly, claw = 0xE5483A, 0xFFB09A, 0xF0584A
    p = slab((2.6, 1.3, 2.0), (0, 1.1, 0), red, 2)
    p.append(box((1.8, 0.5, 0.08), (0, 0.85, -1.03), belly, tag="Face"))
    p += sym([box((0.2, 0.7, 0.2), (0.5, 2.05, -0.4), red), box((0.75, 0.75, 0.6), (0.5, 2.6, -0.4), WHITE),
              disc(0.5, (0.5, 2.6, -0.72), EYE), disc(0.18, (0.6, 2.7, -0.76), WHITE, "N", th=0.04),
              disc(0.34, (0.9, 1.2, -1.03), BLUSH)])
    p += [disc(0.44, (0, 1.2, -1.06), MOUTH, th=0.05), box((0.52, 0.22, 0.05), (0, 1.32, -1.09), red),
          disc(0.22, (0, 1.1, -1.1), TONGUE, th=0.04)]
    p += sym([box((0.9, 0.35, 0.35), (1.55, 1.2, -0.6), red, r=(0, 30, 20)),
              box((1.0, 0.9, 1.1), (1.95, 1.5, -1.25), claw), box((0.45, 0.4, 0.7), (1.75, 2.05, -1.5), claw, r=(-15, 0, 0))])
    for i, z in enumerate((-0.3, 0.3, 0.8)):
        p += sym([box((1.0, 0.24, 0.24), (1.55, 0.45, z), red, r=(0, -10 + i * 15, -35))])
    return p


def turtle():
    shell, rim, plate, skin = 0x3E9A57, 0xC9DD86, 0x2D7843, 0x8FD18A
    p = [box((2.7, 0.45, 2.9), (0, 0.6, 0.2), rim), box((2.4, 0.7, 2.6), (0, 1.15, 0.2), shell), box((1.8, 0.5, 2.0), (0, 1.7, 0.2), shell),
         box((1.0, 0.1, 1.0), (0, 1.98, 0.2), plate)]
    p += [box((0.7, 0.1, 0.7), (x, 1.53, z), plate) for x, z in ((0.8, -0.5), (-0.8, -0.5), (0.8, 0.9), (-0.8, 0.9))]
    p += slab((1.6, 1.4, 1.4), (0, 1.5, -1.6), skin, 2)
    p += face((0, 1.45, -2.31), s=0.6, muzzle=None)
    p += sym([box((1.4, 0.25, 0.6), (1.4, 0.45, -0.7), skin, r=(0, 35, -10)), box((0.8, 0.25, 0.5), (1.1, 0.35, 1.2), skin, r=(0, -35, -5))])
    p.append(box((0.4, 0.3, 0.6), (0, 0.6, 1.75), skin))
    return p


def pufferfish():
    y, belly, fin, spk = 0xFFD23F, 0xFFF3C4, 0xFF9E3A, 0xF0A030
    p = slab((2.6, 2.6, 2.4), (0, 1.5, 0), y, 3)
    p.append(box((2.0, 0.9, 0.08), (0, 0.65, -1.23), belly, tag="Face"))
    p += face((0, 1.6, -1.22), s=0.9, muzzle=None, nose=None)
    for pos, r in (((0, 2.95, 0), (0, 45, 0)), ((1.4, 1.6, 0), (0, 0, 45)), ((-1.4, 1.6, 0), (0, 0, 45)), ((0.9, 2.6, 0.7), (45, 0, 45)),
                   ((-0.9, 2.6, 0.7), (45, 0, 45)), ((1.4, 1.0, 0.8), (45, 0, 45)), ((-1.4, 1.0, 0.8), (45, 0, 45)), ((0, 2.7, 1.2), (45, 0, 0)),
                   ((0.8, 2.85, -0.6), (0, 45, 45)), ((-0.8, 2.85, -0.6), (0, 45, 45))):
        p.append(box((0.35, 0.35, 0.35), pos, spk, r=r))
    p += sym([box((0.12, 0.6, 0.7), (1.35, 1.4, -0.2), fin, r=(0, -30, 0))])
    p.append(box((0.15, 1.0, 0.8), (0, 1.5, 1.6), fin))
    return p


def octopus():
    pink, spot = 0xF27BB0, 0xD95495
    p = slab((2.6, 2.6, 2.4), (0, 2.4, 0), pink, 3)
    p += [box((0.5, 0.06, 0.5), (0.6, 3.72, 0.3), spot), box((0.4, 0.06, 0.4), (-0.6, 3.72, -0.4), spot),
          box((0.06, 0.45, 0.45), (1.32, 2.9, 0.3), spot), box((0.06, 0.4, 0.4), (-1.32, 2.7, -0.2), spot)]
    p += face((0, 2.2, -1.22), s=0.85, muzzle=None, nose=None)
    for i, a in enumerate((25, 80, 135, 225, 280, 335)):
        ar = math.radians(a)
        dx, dz = math.sin(ar), -math.cos(ar)
        p += [box((0.55, 0.8, 0.55), (dx * 0.85, 0.75, dz * 0.85), pink, r=(0, -a, 0)),
              box((0.48, 0.45, 0.8), (dx * 1.35, 0.25, dz * 1.35), pink, r=(0, -a, 0)),
              box((0.42, 0.55, 0.42), (dx * 1.75, 0.45, dz * 1.75), pink, r=(0, -a, 0))]
    return p


def narwhal():
    blue, belly, h1, h2 = 0x4A86D8, 0xDDEBFF, 0xFFD45A, 0xE0A92E
    p = slab((2.4, 2.0, 3.2), (0, 1.15, 0.2), blue, 2)
    p.append(box((1.9, 0.6, 0.08), (0, 0.55, -1.43), belly, tag="Face"))
    p += face((0, 1.3, -1.42), s=0.8, muzzle=None, nose=None)
    p += [box((1.4, 1.2, 0.9), (0, 1.3, 2.1), blue), box((0.9, 0.8, 0.8), (0, 1.55, 2.8), blue)]
    p += sym([box((1.0, 0.2, 0.6), (0.5, 2.0, 3.2), blue, r=(0, -25, 12)), box((0.9, 0.2, 0.5), (1.35, 0.6, -0.3), blue, r=(0, 30, -30))])
    p += horn((0, 2.0, -1.0), h1, "F", n=5, s=0.5, h=1.9, r=(-60, 0, 0), cols=[h1, h2])
    return p


def pearl_seahorse():
    body, belly, fin, pearl = 0xF3C9E8, 0xFFF0F8, 0xB9E4FF, 0xFFFCF4
    p = slab((1.8, 1.7, 1.7), (0, 3.2, -0.1), body, 2)
    p += face((0, 3.15, -0.96), s=0.7, muzzle=None, nose=None, mouth=False)
    p += [box((0.5, 0.5, 1.0), (0, 2.85, -1.3), body), box((0.55, 0.55, 0.15), (0, 2.85, -1.85), shade(body, 0.8))]
    for i, (y, z, s) in enumerate(((2.05, 0.05, 1.3), (1.25, 0.15, 1.1), (0.6, 0.4, 0.8), (0.25, 0.85, 0.6), (0.5, 1.25, 0.45))):
        p.append(box((s, s * 0.8, s), (0, y, z), body))
    for y in (2.2, 1.7, 1.25):
        p.append(box((0.9, 0.16, 0.1), (0, y, -0.62 + (2.2 - y) * 0.15), belly, tag="Face"))
    p.append(box((0.12, 1.2, 0.8), (0, 1.8, 0.85), fin, "G", t=0.25))
    p += sym([box((0.5, 0.35, 0.08), (0.95, 2.7, 0.1), fin, "G", r=(0, -40, 0), t=0.2)])
    p += [box((0.12, 0.6, 0.5), (0, 4.25, 0.1), fin, "G", t=0.15), box(0.62 * 1, (0, 4.45, -0.35), pearl) if False else ball(0.62, (0, 4.4, -0.35), pearl),
          ball(0.18, (0.13, 4.55, -0.58), WHITE, "N")]
    return p


# ======================================================================= Volcano
def lava_slime():
    o, glow, crust = 0xFF7A1F, 0xFFC23A, 0x3A2A2A
    p = [box((2.8, 0.3, 2.7), (0, 0.15, 0), 0xFF9A2A, "N", tag="Glow")]
    p += slab((2.5, 1.9, 2.4), (0, 1.15, 0), o, 2)
    p.append(box((1.7, 0.6, 1.6), (0, 2.35, 0), o))
    p += face((0, 1.25, -1.22), s=0.85, muzzle=None, nose=None, blush=0xFFB060)
    p += [box((0.7, 0.25, 0.6), (0.6, 2.7, 0.3), crust, "B"), box((0.5, 0.2, 0.5), (-0.7, 2.15, 0.7), crust, "B"),
          box((0.08, 0.45, 0.45), (1.27, 1.6, 0.4), glow, "N", tag="Glow"), box((0.08, 0.35, 0.35), (-1.27, 1.0, -0.3), glow, "N", tag="Glow"),
          box((0.35, 0.6, 0.3), (0.85, 0.75, -1.25), o)]
    return p


def salamander():
    red, spot, belly = 0xE0402E, 0xFFD43A, 0xFF9A5A
    ex = [box((0.36, 0.08, 0.36), pt, spot) for pt in ((0.4, BODY_TOP + 0.03, 0.1), (-0.35, BODY_TOP + 0.03, 0.6), (0.2, BODY_TOP + 0.03, 0.95),
                                                       (-0.5, HEAD_TOP + 0.04, -0.6), (0.55, HEAD_TOP + 0.04, 0.1))]
    return quad(red, face_kw=dict(muzzle=belly), tail_kw=dict(kind="long", tip=spot), paw=belly, belly=belly,
                body_size=(1.7, 1.1, 2.3), head_size=(2.5, 1.8, 2.0), extras=ex)


def ember_bat():
    blk, ember, ear_in = 0x2A2230, 0xF0561A, 0xFF5A3A
    p = slab((2.4, 2.4, 2.0), (0, 1.6, 0), blk, 3)
    p += face((0, 1.65, -1.02), s=0.85, muzzle=0x4A3A48, iris=0xFFB03A, nose=None)
    p += sym([box((0.1, 0.18, 0.06), (0.14, 1.03, -1.12), WHITE, tag="Eye")])
    p += sym(T(tri((0, 0, 0), 0.9, 1.1, 0.4, blk) + tri((0, 0.08, -0.2), 0.5, 0.6, 0.06, ear_in), (0.75, 2.75, 0), r=(0, 0, -15)))
    p += sym(wing(blk, ember, span=2.0, at=(1.15, 2.0, 0.2), lift=10, sweep=-15, mat="N", t=0.1))
    p += sym([box((0.35, 0.4, 0.35), (0.45, 0.2, 0.1), blk)])
    return p


def lava_golem():
    rock, dark, lava = 0x4A3E3C, 0x2E2626, 0xFF6A00
    p = slab((2.2, 1.8, 1.6), (0, 1.6, 0.1), rock, 2, mat="B")
    p += slab((2.1, 1.7, 1.8), (0, 3.25, -0.1), rock, 2, mat="B")
    p += face((0, 3.15, -1.01), s=0.75, muzzle=None, eye_col=0xFFD23A, nose=None, blush=0xFF8A3A)
    p += sym([box((0.75, 1.4, 0.8), (1.55, 1.8, -0.05), rock, "B", r=(0, 0, 8)), box((1.0, 0.9, 1.0), (1.7, 0.75, -0.15), dark, "B"),
              box((0.8, 0.75, 0.9), (0.55, 0.38, 0.1), dark, "B")])
    for pos, rr, size in (((0.35, 1.7, -0.71), (0, 0, 35), (0.9, 0.1, 0.06)), ((-0.35, 1.35, -0.71), (0, 0, -25), (0.8, 0.1, 0.06)),
                          ((0.6, 3.9, -1.01), (0, 0, -30), (0.5, 0.08, 0.05)), ((0, 2.45, 0.92), (0, 0, 20), (1.2, 0.1, 0.06))):
        p.append(box(size, pos, lava, "N", r=rr, tag="Glow"))
    p.append(box((1.0, 0.3, 0.8), (0.2, 4.2, 0.0), lava, "N", tag="Glow"))
    return p


def inferno_dragon():
    red, belly, flame = 0xD8322A, 0xFFB04A, 0xFF8A1A
    ex = sym(horn((0.75, HEAD_TOP - 0.1, -0.4), flame, "N", n=3, s=0.42, h=1.0, r=(-15, 0, -18), cols=[0xFF5A1A, flame, 0xFFD23A], tag="Glow"))
    ex += sym(wing(0x8A1E1A, 0xFF7A2A, span=1.8, at=(0.7, BODY_TOP, 0.5)))
    ex += [box((0.4, 0.35, 0.4), (0, BODY_TOP + 0.03, z), 0xFFB04A, r=(0, 45, 0)) for z in (0.1, 0.6, 1.05)]
    return quad(red, face_kw=dict(muzzle=belly, iris=0xFFC23A, small_hi=False), tail_kw=dict(kind="long", tip=0xFFD23A), paw=belly, belly=belly,
                extras=ex)


def phoenix():
    red, org, yel = 0xE8402A, 0xFF8A1A, 0xFFD23A
    p = slab((2.2, 2.6, 2.0), (0, 1.75, 0.1), red, 3)
    p.append(box((1.5, 1.2, 0.08), (0, 1.1, -0.93), org, tag="Face"))
    p += face((0, 2.25, -0.92), s=0.8, muzzle=None, nose=None, mouth=False, iris=0xFFC23A)
    p += T(tri((0, 0, 0), 0.5, 0.5, 0.45, yel), (0, 1.95, -1.05), r=(0, 0, 180))
    for x, h, rr in ((0, 1.1, 0), (0.4, 0.8, -20), (-0.4, 0.8, 20)):
        p += horn((x, 3.0, 0.1), org, "N", n=3, s=0.4, h=h, r=(-15, 0, rr), cols=[red, org, yel], tag="Glow")
    p += sym(wing(red, org, span=2.0, at=(1.05, 2.3, 0.3), lift=35, mat="N", tag="Glow"))
    for i, (x, col) in enumerate(((0, yel), (0.4, org), (-0.4, org))):
        p.append(box((0.35, 0.2, 2.4 - i * 0.3), (x, 0.9, 1.9), col, "N", r=(25, -x * 20, 0), tag="Glow"))
    p += sym([box((0.25, 0.5, 0.25), (0.4, 0.25, 0.2), yel)])
    return p


# ======================================================================= Starfall
def comet_cat():
    navy, belly, comet = 0x24346E, 0x5F78C8, 0xFFE66B
    ex = [box((0.4, 0.4, 0.08), (0, HEAD_TOP - 0.4, HEAD_FRONT - 0.04), comet, "N", r=(0, 0, 45), tag="Glow"),
          box((0.75, 0.75, 0.75), (0, 2.7, 1.5), comet, "N", r=(0, 45, 0), tag="Glow"),
          box((0.6, 0.6, 0.9), (0, 2.2, 1.6), 0xFFF5C0, "N", t=0.3, tag="Glow"), box((0.45, 0.45, 0.8), (0, 1.8, 1.45), 0xBFD7FF, "N", t=0.5)]
    return quad(navy, face_kw=dict(muzzle=belly, nose=0xFF8FB8, iris=0xFFE66B), ears_kw=dict(kind="pointy", inner=0x9FB8FF),
                paw=belly, belly=belly, extras=ex)


def moon_bunny():
    lilac, moon = 0xC9A8F0, 0xFFE27A
    top = 1.5 - 0.2 + 2.1
    fz = -0.1 - 1.05 - 0.04
    ex = [disc(0.7, (0, top - 0.35, fz), moon, "N", tag="Glow"), disc(0.6, (0.2, top - 0.27, fz - 0.03), lilac, tag="Body"),
          box((0.2, 0.2, 0.2), (1.1, top + 1.6, 0), moon, "N", r=(0, 45, 45)), box((0.15, 0.15, 0.15), (-1.2, top + 1.2, 0.2), moon, "N", r=(0, 45, 45))]
    return sitter(lilac, face_kw=dict(nose=0xFF8FC8, muzzle=0xEDE0FF, iris=0xB08CFF), ears_kw=dict(kind="long", inner=0x8E6AD8),
                  tail_kw=dict(kind="pom", tip=WHITE), paw=0xEDE0FF, belly=0xEDE0FF, extras=ex)


def nebula_fox():
    purple, pink = 0x7B3FC4, 0xF06AC8
    ex = cubes(((0.5, 2.1, 0.0), (-0.4, 1.4, 1.36), (0.3, HEAD_TOP + 0.05, -0.6), (-0.6, HEAD_TOP + 0.05, 0.1), (0.81, 1.5, 0.6),
                (1.32, HEAD_C[1] + 0.4, -0.3)), WHITE)
    return quad(purple, face_kw=dict(muzzle=pink, muzzle_w=1.5, iris=0xF06AC8), ears_kw=dict(kind="pointy", inner=pink, size=1.1),
                tail_kw=dict(kind="bushy", tip=pink), paw=0x3A1E6E, belly=pink, extras=ex)


def galaxy_axolotl():
    blue, belly, f1, f2 = 0x1E2A6E, 0x3A4AA0, 0xFF6AD5, 0x6AE8FF
    ex = []
    for i, (col, a) in enumerate(((f1, 35), (f2, 5), (f1, -25))):
        ex += sym([box((1.1, 0.26, 0.2), (1.75, HEAD_C[1] + 0.45 - i * 0.35, HEAD_C[2] + 0.1), col, "N", r=(0, -15, a), tag="Glow")])
    ex += cubes(((0.5, BODY_TOP + 0.03, 0.3), (-0.4, BODY_TOP + 0.03, 0.8), (0.6, HEAD_TOP + 0.05, -0.2)), WHITE)
    return quad(blue, face_kw=dict(muzzle=belly, blush=f1), tail_kw=dict(kind="long", tip=f2), paw=belly, belly=belly,
                head_size=(2.8, 1.8, 2.0), body_size=(1.6, 1.0, 2.2), extras=ex)


def celestial_dragon():
    wh, gold, glow = 0xF7F3E6, 0xF2C44E, 0xFFE27A
    halo = []
    for i in range(5):
        a = 2 * math.pi * i / 5
        halo.append(box((0.62, 0.14, 0.14), (math.sin(a) * 0.62, 0, -math.cos(a) * 0.62), glow, "N", r=(0, -math.degrees(a), 0), tag="Glow"))
    ex = T(halo, (0, HEAD_TOP + 0.6, -0.25), r=(-15, 0, 0))
    ex += sym(horn((0.7, HEAD_TOP - 0.1, -0.4), gold, "F", n=2, s=0.38, h=0.8, r=(-15, 0, -18)))
    ex += sym(wing(gold, 0xFFF4D0, span=1.9, at=(0.7, BODY_TOP, 0.5)) + [box((0.3, 0.3, 0.3), (2.6, 2.7, 1.3), glow, "N", r=(45, 0, 45), tag="Glow")])
    return quad(wh, face_kw=dict(muzzle=0xFFF0C8, iris=0x6AB8FF, small_hi=False), tail_kw=dict(kind="dog", tip=gold), paw=gold, belly=None,
                extras=ex)


def unicorn(body, mane, horn_cols, hoof, muzzle=None, horn_mat="P", mane_mat="P", iris=None, speckle=None):
    mz = muzzle if muzzle is not None else mix(body, 0xFFB6C8, 0.35)
    ex = horn((0, HEAD_TOP - 0.05, HEAD_C[2] - 0.55), horn_cols[0], horn_mat, n=4, s=0.55, h=1.9, r=(-18, 0, 0), cols=horn_cols)
    for i, (y, z) in enumerate(((HEAD_TOP + 0.1, -0.1), (HEAD_TOP - 0.2, 0.5), (HEAD_TOP - 0.8, 0.75), (HEAD_TOP - 1.4, 0.75))):
        ex.append(box((0.9, 0.62, 0.75), (0, y, z + 0.15), mane[i % len(mane)], mane_mat))
    ex.append(box((0.8, 0.4, 0.4), (0, HEAD_TOP + 0.05, -0.95), mane[-1], mane_mat))
    if speckle is not None:
        ex += cubes(((0.5, BODY_TOP + 0.03, 0.2), (-0.5, BODY_TOP + 0.03, 0.9), (1.32, HEAD_C[1] + 0.3, 0.2)), speckle)
    sz = HEAD_FRONT - 0.3
    sy = HEAD_C[1] - 0.6
    ex += [box((1.5, 0.85, 0.6), (0, sy, sz + 0.28), mz, tag="Face"),
           disc(0.16, (-0.35, sy + 0.15, sz - 0.03), DARK), disc(0.16, (0.35, sy + 0.15, sz - 0.03), DARK),
           disc(0.4, (0, sy - 0.2, sz - 0.03), MOUTH, th=0.05), box((0.48, 0.21, 0.06), (0, sy - 0.1, sz - 0.05), mz, tag="Face")]
    p = quad(body, face_kw=dict(muzzle=None, iris=iris, small_hi=False, nose=None, mouth=False, eye_y=0.42),
             ears_kw=dict(kind="pointy", size=0.7), paw=hoof, belly=None, extras=ex, tail_kw=None)
    p += [box((0.55, 0.9, 0.55), (0, 1.4, 1.3), mane[2 % len(mane)], mane_mat, r=(-20, 0, 0)),
          box((0.5, 0.8, 0.5), (0, 0.85, 1.5), mane[3 % len(mane)], mane_mat)]
    return p


def cosmic_unicorn():
    return unicorn(0x2E2466, [0xFF6AD5, 0x6AE8FF, 0xB06CFF], [0xFFFFFF, 0x9FF4FF], 0x1A1440, muzzle=0x4A3A90, horn_mat="N",
                   mane_mat="N", iris=0xB06CFF, speckle=WHITE)


def void_kraken():
    blk, vio = 0x1E1630, 0xB04CFF
    p = slab((2.6, 2.8, 2.4), (0, 2.7, 0.1), blk, 3)
    p += face((0, 2.5, -1.12), s=0.95, muzzle=None, nose=None, eye_col=vio, iris=0xE8B0FF, blush=0x6A2A9A)
    p = [q.copy(mat="N", tag="Glow") if q.col == vio else q for q in p]
    p += [box((0.4, 0.06, 0.4), pos, vio, "N", tag="Glow") for pos in ((0.6, 4.12, 0.4), (-0.5, 4.12, -0.3))]
    for i, a in enumerate((30, 90, 150, 210, 270, 330)):
        ar = math.radians(a)
        dx, dz = math.sin(ar), -math.cos(ar)
        p += [box((0.6, 1.0, 0.6), (dx * 0.95, 0.85, dz * 0.95 + 0.1), blk, r=(0, -a, 0)),
              box((0.5, 0.45, 0.9), (dx * 1.5, 0.25, dz * 1.5 + 0.1), blk, r=(0, -a, 0)),
              box((0.25, 0.25, 0.25), (dx * 1.85, 0.55, dz * 1.85 + 0.1), vio, "N", r=(0, 45, 0), tag="Glow")]
    return p


# ======================================================================= Prism
def crystal_pup():
    ice, deep = 0xA8E4FF, 0x6FC8F0
    ex = crystal((0.4, BODY_TOP, 0.3), 0.32, 0.9, 0xD8F6FF, "G", r=(-10, 0, -15), t=0.15)
    ex += crystal((-0.3, BODY_TOP, 0.8), 0.28, 0.7, 0xD8F6FF, "G", r=(-25, 0, 20), t=0.15)
    ex += crystal((0, HEAD_TOP - 0.05, -0.1), 0.3, 0.7, deep, "G", r=(-15, 0, 0), t=0.1)
    p = quad(ice, face_kw=dict(blaze=0xE8FAFF, muzzle=0xE8FAFF, iris=0x3FA8E0), ears_kw=dict(kind="floppy", col=deep),
             tail_kw=dict(kind="dog", tip=0xE8FAFF), paw=0xE8FAFF, belly=0xE8FAFF, extras=ex)
    return [q.copy(mat="I") if q.col in (ice, deep) and q.mat == "P" else q for q in p]


def prism_fox():
    cols = [0xFFB3D9, 0xC9B3FF, 0xB3E6FF, 0xB3FFD9, 0xFFF0B3]
    ex = crystal((0, BODY_TOP, 0.4), 0.32, 0.8, 0xFFFFFF, "G", r=(-20, 0, 0), t=0.2)
    p = quad(cols[1], head=cols[0], face_kw=dict(muzzle=WHITE, muzzle_w=1.5, iris=0xB06CFF),
             ears_kw=dict(kind="pointy", inner=cols[3], size=1.1), tail_kw=dict(kind="bushy", col=cols[2], tip=cols[4]),
             paw=cols[2], belly=WHITE, extras=ex)
    # alternate pastel slabs on head and body for the prism look
    out, k = [], 0
    for q in p:
        if q.tag == "Body" and q.shape == "box" and q.col in cols[:2]:
            q = q.copy(col=cols[k % len(cols)])
            k += 1
        out.append(q)
    return out


def rainbow_unicorn():
    return unicorn(0xFBF8FF, RAINBOW, [GOLD, 0xFFE9A0], 0xF2C44E, horn_mat="F")


def diamond_dragon():
    d, deep, glow = 0x9FF0FF, 0x4FC8E8, 0x6AF2FF
    ex = sym(crystal((0.7, HEAD_TOP - 0.1, -0.3), 0.3, 0.9, 0xE0FCFF, "G", r=(-20, 0, -20), t=0.05))
    w = []
    for i, (L, a) in enumerate(((1.9, 55), (1.4, 15))):
        w += crystal((0, 0, 0), 0.32, L, d if i % 2 == 0 else deep, "G", r=(0, 0, -90 + a), t=0.1)
    ex += sym(T(w, (0.7, BODY_TOP, 0.5), r=(0, -30, 0)))
    ex += crystal((0, BODY_TOP, 0.3), 0.24, 0.6, glow, "N", r=(-20, 0, 0), tag="Glow")
    p = quad(d, face_kw=dict(muzzle=0xE0FCFF, iris=0x2A9AD0, small_hi=False), tail_kw=dict(kind="long", tip=glow), paw=deep, belly=0xE0FCFF, extras=ex)
    return [q.copy(mat="G", tr=0.08) if q.tag == "Body" and q.col == d else q for q in p]


# ======================================================================= registry
BUILDERS = {
    "Puppy": puppy, "Kitten": kitten, "Bunny": bunny_pet, "Fox": fox, "HoneyBear": honey_bear,
    "SunflowerSprite": sunflower_sprite,
    "Toadstool": toadstool, "Snail": snail, "Frog": frog, "Owl": owl, "GlowcapDragon": glowcap_dragon,
    "FairyMoth": fairy_moth,
    "Penguin": penguin, "SnowBunny": snow_bunny, "ArcticFox": arctic_fox, "Yeti": yeti, "AuroraWolf": aurora_wolf,
    "PolarKing": polar_king,
    "Crab": crab, "Turtle": turtle, "Pufferfish": pufferfish, "Octopus": octopus, "Narwhal": narwhal,
    "PearlSeahorse": pearl_seahorse,
    "LavaSlime": lava_slime, "Salamander": salamander, "EmberBat": ember_bat, "LavaGolem": lava_golem,
    "InfernoDragon": inferno_dragon, "Phoenix": phoenix,
    "CometCat": comet_cat, "MoonBunny": moon_bunny, "NebulaFox": nebula_fox, "GalaxyAxolotl": galaxy_axolotl,
    "CelestialDragon": celestial_dragon, "CosmicUnicorn": cosmic_unicorn, "VoidKraken": void_kraken,
    "CrystalPup": crystal_pup, "PrismFox": prism_fox, "RainbowUnicorn": rainbow_unicorn, "DiamondDragon": diamond_dragon,
}
