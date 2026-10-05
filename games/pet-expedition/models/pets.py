"""All 40 pets, built from a few chibi archetypes (quadruped, bunny, bird,
dragon, unicorn, sea creatures...) plus per-species details from the Look
briefs in src/shared/Pets.luau.

Pets are authored in loose "units" (head radius ~1) and normalised to their
rarity height by gen_models.py. Front = -Z.
"""
import math
from lib import (ball, box, cyl, wedge, T, sym, mirror, eyes, blush, cone, spike, tri, chain, ring,
                 crystal, on_surface, ell_point, rot, mmul, rx, ry, rz, face_rot, up_rot, shade, mix,
                 EYE, WHITE, PINK, RAINBOW, add, mul, norm)

DARK = 0x2A2433
GOLD = 0xFFC93C


# ======================================================================= parts
def ear(kind, col, inner=None, at=(0.55, 2.52, -0.3), w=0.78, h=0.85, roll=-16, pitch=-6, size=1.0):
    """One ear on the +X side (mirror for the other)."""
    w, h = w * size, h * size
    if kind == "pointy":
        p = tri((0, 0, 0), w, h, 0.3 * size, col)
        if inner is not None:
            p += tri((0, 0.06 * size, -0.13 * size), w * 0.55, h * 0.62, 0.08, inner)
        return T(p, at, r=(pitch, 0, roll))
    if kind == "round":
        p = [ball((0.62 * size, 0.6 * size, 0.32 * size), (0, 0, 0), col)]
        if inner is not None:
            p.append(ball((0.36 * size, 0.34 * size, 0.1), (0, -0.02, -0.13 * size), inner))
        return T(p, at, r=(pitch, 0, roll))
    if kind == "floppy":
        p = [ball((0.44 * size, 1.0 * size, 0.34 * size), (0, -0.35 * size, 0), col)]
        return T(p, at, r=(pitch, 0, roll))
    raise ValueError(kind)


def legs4(col, paw=None, front_z=-0.35, back_z=0.78, x=0.42, size=(0.44, 0.62, 0.48), y=0.31, back_col=None):
    out = []
    for z in (front_z, back_z):
        c = col if (z == front_z or back_col is None) else back_col
        out.append(ball(size, (x, y, z), c))
        if paw is not None:
            out.append(ball((size[0] * 1.02, size[1] * 0.4, size[2] * 1.05), (x, size[1] * 0.18, z - 0.03), paw))
    return sym(out)


def quad(body, head=None, belly=None, snout=None, nose=DARK, ears=("pointy", None, None), tail="thin", tail_col=None,
         tip=None, paw=None, eye_iris=None, eye_size=0.52, snout_size=(0.78, 0.52, 0.5), long_snout=False,
         blush_col=PINK, head_size=(2.0, 1.8, 1.76), extras=None, leg_col=None, ear_size=1.0, eye_yaw=30, eye_pitch=8,
         body_size=(1.25, 1.0, 1.55)):
    """Chibi standing quadruped: big head, small body, stubby legs."""
    head = head if head is not None else body
    leg_col = leg_col if leg_col is not None else body
    hc = (0.0, 1.95, -0.3)
    hr = (head_size[0] / 2, head_size[1] / 2, head_size[2] / 2)
    p = []
    p += legs4(leg_col, paw)
    p.append(ball(body_size, (0, 0.85, 0.28), body, tag="Body"))
    if belly is not None:
        p.append(ball((0.82, 0.72, 0.5), (0, 0.98, -0.32), belly))
    p.append(ball(head_size, hc, head, tag="Body"))
    # snout / muzzle
    if snout is not None:
        if long_snout:
            p.append(ball((snout_size[0] * 0.9, snout_size[1] * 0.9, snout_size[2] * 1.9), (0, 1.62, -1.12), snout))
            p.append(ball((0.28, 0.2, 0.2), (0, 1.74, -1.6), nose))
        else:
            p.append(ball(snout_size, (0, 1.62, -1.08), snout))
            p.append(ball((0.3, 0.2, 0.2), (0, 1.8, -1.32), nose))
    p += eyes(hc, hr, yaw=eye_yaw, pitch=eye_pitch, size=eye_size, iris=eye_iris)
    if blush_col is not None:
        p += blush(hc, hr, yaw=50, pitch=-10, size=0.34, col=blush_col)
    kind, ecol, inner = ears
    if kind:
        ecol = ecol if ecol is not None else head
        if kind == "pointy":
            p += sym(ear("pointy", ecol, inner, at=(0.56, 2.55, -0.25), size=ear_size))
        elif kind == "round":
            p += sym(ear("round", ecol, inner, at=(0.7, 2.6, -0.25), roll=-20, size=ear_size))
        elif kind == "floppy":
            p += sym(ear("floppy", ecol, inner, at=(0.88, 2.35, -0.22), roll=18, size=ear_size))
    tc = tail_col if tail_col is not None else body
    if tail == "thin":
        p += chain([(0, 1.02, 1.0), (0, 1.25, 1.22), (0, 1.55, 1.32), (0, 1.85, 1.3)], [0.3, 0.28, 0.27, 0.3], tc)
        if tip is not None:
            p[-1] = p[-1].copy(col=tip)
    elif tail == "bushy":
        d = norm((0, 0.75, 0.66))
        p.append(ball((0.8, 0.8, 1.5), (0, 1.4, 1.32), tc, r=(-48, 0, 0)))
        if tip is not None:
            p.append(ball((0.66, 0.66, 0.62), add((0, 1.4, 1.32), mul(d, 0.62)), tip, r=(-48, 0, 0)))
    elif tail == "pom":
        p.append(ball(0.55, (0, 1.0, 1.02), tc))
    if extras:
        p += extras
    return p


def bunny(body, inner=PINK, nose=0xFF7FA0, extras=None, ear_col=None, eye_iris=None, belly=None, foot=None):
    """Sitting bunny with long upright ears."""
    hc = (0.0, 1.78, -0.15)
    hr = (0.93, 0.8, 0.8)
    ec = ear_col if ear_col is not None else body
    p = [
        ball((1.4, 1.22, 1.38), (0, 0.68, 0.15), body, tag="Body"),
        ball((1.86, 1.6, 1.6), hc, body, tag="Body"),
        ball(0.55, (0, 0.62, 0.86), WHITE if body != WHITE else 0xF4F0F4),
    ]
    p += sym([ball((0.52, 0.32, 0.82), (0.4, 0.16, -0.28), foot if foot is not None else body),
              ball((0.34, 0.4, 0.34), (0.3, 0.42, -0.48), body)])
    if belly is not None:
        p.append(ball((0.85, 0.75, 0.4), (0, 0.72, -0.42), belly))
    earp = [ball((0.5, 1.55, 0.34), (0, 0.72, 0), ec)]
    if inner is not None:
        earp.append(ball((0.27, 1.15, 0.12), (0, 0.72, -0.13), inner))
    p += sym(T(earp, (0.36, 2.35, 0.02), r=(8, 0, -10)))
    p += eyes(hc, hr, yaw=30, pitch=2, size=0.48, iris=eye_iris)
    p += blush(hc, hr, yaw=48, pitch=-16, size=0.32)
    p.append(ball((0.2, 0.13, 0.12), (0, 1.62, -0.93), nose))
    p.append(box((0.2, 0.17, 0.06), (0, 1.43, -0.9), WHITE))
    if extras:
        p += extras
    return p


def wings_bat(shoulder, col, membrane, n=3, span=1.6, sweep=-30, lift=25, mat_m="P", t=0.0, tag=None):
    """Fan of flattened ellipsoids forming a wing on the +X side."""
    p = []
    for i in range(n):
        a = math.radians(lift + 60 - i * (60 / max(1, n - 1)) * 1.4)
        d = (math.cos(a), math.sin(a), 0)
        L = span * (1.0 - i * 0.12)
        p.append(ball((L, 0.62, 0.07), mul(d, L * 0.45), membrane, mat_m, R=rz(math.degrees(a)), t=t, tag=tag))
    a0 = math.radians(lift + 62)
    p.append(ball((span * 1.05, 0.16, 0.16), mul((math.cos(a0), math.sin(a0), 0), span * 0.5), col, R=rz(math.degrees(a0))))
    return T(p, shoulder, r=(0, sweep, 0))


def dragon(body, belly, horn, wing, membrane, spine=None, horn_mat="P", membrane_mat="P", extras=None, eye_iris=None,
           tail_tip=None, spines=None, horns=None, wings=None, head=None, mem_t=0.0):
    hc = (0.0, 1.95, -0.3)
    hr = (1.0, 0.88, 0.88)
    head = head if head is not None else body
    p = []
    p += legs4(body)
    p.append(ball((1.3, 1.08, 1.6), (0, 0.88, 0.3), body, tag="Body"))
    p.append(ball((0.86, 0.85, 0.5), (0, 0.95, -0.32), belly))
    p.append(ball((2.0, 1.76, 1.76), hc, head, tag="Body"))
    p.append(ball((1.05, 0.62, 0.7), (0, 1.58, -1.05), head))
    p.append(ball((0.82, 0.3, 0.55), (0, 1.42, -1.1), belly))
    p += eyes(hc, hr, yaw=30, pitch=10, size=0.52, iris=eye_iris)
    p += blush(hc, hr, yaw=52, pitch=-8, size=0.3)
    if horns is None:
        p += sym(cone((0.5, 2.6, -0.05), 0.36, 0.95, horn, horn_mat, n=3, r=(-28, 0, -22), tip=0.3))
    else:
        p += horns
    if wings is None:
        p += sym(wings_bat((0.5, 1.4, 0.5), wing, membrane, mat_m=membrane_mat, t=mem_t))
    else:
        p += wings
    # tail
    tp = [(0, 0.85, 1.1), (0, 0.85, 1.55), (0, 1.1, 1.9)]
    p += chain(tp, [0.62, 0.46, 0.34], body)
    if tail_tip is not None:
        p += tail_tip
    else:
        p += T(tri((0, 0, 0), 0.5, 0.45, 0.14, spine if spine is not None else horn), (0, 1.32, 2.06), r=(-30, 0, 0))
    if spines is None:
        sc = spine if spine is not None else horn
        for i, (y, z) in enumerate(((1.42, 0.12), (1.38, 0.55), (1.18, 0.95))):
            p.append(spike((0, y, z), 0.3, 0.32, sc, r=(-20 - i * 12, 0, 0)))
    else:
        p += spines
    if extras:
        p += extras
    return p


def unicorn(body, mane_cols, horn_cols, hoof, muzzle=None, extras=None, horn_mat="P", mane_mat="P", eye_iris=None,
            speckle=None):
    hc = (0.0, 2.2, -0.45)
    hr = (0.92, 0.85, 0.85)
    p = []
    for z in (-0.25, 0.8):
        p += sym([ball((0.38, 0.95, 0.42), (0.4, 0.5, z), body), ball((0.42, 0.26, 0.46), (0.4, 0.12, z - 0.02), hoof)])
    p.append(ball((1.3, 1.05, 1.75), (0, 1.15, 0.28), body, tag="Body"))
    p.append(ball((0.9, 1.0, 0.85), (0, 1.55, -0.3), body))  # neck
    p.append(ball((1.84, 1.7, 1.7), hc, body, tag="Body"))
    mz = muzzle if muzzle is not None else mix(body, 0xFFB6C8, 0.35)
    p.append(ball((1.05, 0.78, 0.8), (0, 1.86, -1.22), mz))
    p += eyes(hc, hr, yaw=32, pitch=10, size=0.5, iris=eye_iris)
    p += blush(hc, hr, yaw=52, pitch=-8, size=0.28)
    p += sym(ear("pointy", body, None, at=(0.45, 2.88, -0.25), w=0.5, h=0.6, roll=-14, size=1.0))
    # horn: stacked cylinders, colours alternate for a spiral look
    p += cone((0, 2.92, -0.95), 0.36, 1.2, horn_cols[0], horn_mat, n=4, r=(-28, 0, 0), tip=0.25, cols=horn_cols)
    # mane: balls down the back of the head and neck
    mp = [(0, 3.0, -0.3), (0, 2.85, 0.1), (0, 2.5, 0.35), (0, 2.1, 0.45), (0, 1.75, 0.4)]
    ms = [0.72, 0.7, 0.66, 0.6, 0.5]
    for i, (pt, s) in enumerate(zip(mp, ms)):
        p.append(ball((s * 1.05, s, s), pt, mane_cols[i % len(mane_cols)], mane_mat))
    p.append(ball((0.5, 0.42, 0.4), (0, 3.06, -0.8), mane_cols[-1], mane_mat))  # forelock
    tp = [(0, 1.42, 1.1), (0, 1.2, 1.45), (0, 0.85, 1.6), (0, 0.5, 1.58)]
    for i, (pt, s) in enumerate(zip(tp, [0.55, 0.6, 0.55, 0.45])):
        p.append(ball(s, pt, mane_cols[(i + 2) % len(mane_cols)], mane_mat))
    if speckle is not None:
        for pt in ((0.52, 1.4, 0.2), (-0.5, 1.2, 0.6), (-0.66, 2.5, -0.6), (0.68, 2.45, -0.2)):
            p.append(ball(0.14, pt, speckle, "N"))
    if extras:
        p += extras
    return p


# ======================================================================= Meadow
def puppy():
    tan, brown, cream = 0xE2B07A, 0x8B5A36, 0xFAE8CC
    ex = [cyl(1.32, 0.22, (0, 1.2, -0.2), 0xE03A44, r=(12, 0, 0)), ball(0.26, (0, 1.0, -0.86), GOLD, "F"),
          ball((0.24, 0.1, 0.22), (0.1, 1.4, -1.28), 0xFF6F86, r=(30, 0, 0)),
          on_surface((0, 1.95, -0.3), (1.0, 0.9, 0.88), 34, 22, (0.7, 0.6, 0.14), brown, inset=0.35)]
    return quad(tan, belly=cream, snout=cream, ears=("floppy", brown, None), tail="thin", paw=cream, extras=ex)


def kitten():
    o, dk, cream = 0xF59A3A, 0xC8641E, 0xFFF1DE
    hc, hr = (0, 1.95, -0.3), (1.0, 0.9, 0.88)
    ex = [on_surface(hc, hr, 0, 62, (0.22, 0.75, 0.12), dk), on_surface(hc, hr, -18, 54, (0.18, 0.6, 0.12), dk, spin=-14),
          on_surface(hc, hr, 18, 54, (0.18, 0.6, 0.12), dk, spin=14),
          ball((0.16, 0.95, 0.9), (0, 1.33, 0.25), dk), ball((0.95, 0.16, 0.6), (0, 1.32, 0.55), dk, r=(0, 0, 0)),
          box((0.05, 0.05, 0.62), (0.62, 1.66, -1.18), WHITE, r=(0, 72, 6)), box((0.05, 0.05, 0.62), (-0.62, 1.66, -1.18), WHITE, r=(0, -72, -6)),
          ]
    p = quad(o, belly=cream, snout=cream, nose=0xFF7FA0, ears=("pointy", o, 0xFFB0C4), tail="thin", paw=cream,
             snout_size=(0.7, 0.42, 0.4), extras=ex)
    return p


def bunny_pet():
    return bunny(0xFAFAFA, inner=0xFFA6C0, eye_iris=None)


def fox(body=0xEC6A2C, chest=WHITE, sock=0x3A2A2A, ear_inner=0x3A2A2A, tail_tip=WHITE, extras=None, eye_iris=None, head=None):
    ex = [ball((0.95, 0.5, 0.6), (0, 1.55, -0.9), chest)]
    ex += extras or []
    return quad(body, head=head, belly=chest, snout=chest, long_snout=True, snout_size=(0.6, 0.42, 0.45), nose=DARK,
                ears=("pointy", body, ear_inner), tail="bushy", tip=tail_tip, paw=sock, ear_size=1.12,
                eye_iris=eye_iris, extras=ex)


def honey_bear():
    gold, cream, pot, honey = 0xE7A63A, 0xFCE3B0, 0xC9732E, 0xFFC531
    hc, hr = (0, 2.2, -0.15), (1.02, 0.92, 0.9)
    p = [
        ball((1.75, 1.6, 1.5), (0, 0.95, 0.15), gold, tag="Body"),
        ball((1.1, 1.0, 0.4), (0, 0.95, -0.5), cream),
        ball((2.04, 1.84, 1.8), hc, gold, tag="Body"),
        ball((0.8, 0.55, 0.5), (0, 1.86, -0.95), cream),
        ball((0.3, 0.2, 0.2), (0, 2.02, -1.18), DARK),
    ]
    p += eyes(hc, hr, yaw=30, pitch=10, size=0.5)
    p += blush(hc, hr, yaw=50, pitch=-10, size=0.32)
    p += sym(ear("round", gold, cream, at=(0.72, 2.95, -0.1), roll=-20))
    p += sym([ball((0.62, 0.45, 0.9), (0.55, 0.22, -0.35), gold), ball((0.42, 0.42, 0.12), (0.55, 0.22, -0.82), cream)])
    # honey pot held in front with both arms
    p += [cyl(1.0, 0.85, (0, 1.05, -1.05), pot), cyl(0.82, 0.2, (0, 1.55, -1.05), shade(pot, 0.8)),
          ball((0.78, 0.3, 0.78), (0, 1.62, -1.05), honey, "N"), ball((0.22, 0.4, 0.22), (0.3, 1.32, -1.5), honey, "N"),
          box((0.55, 0.3, 0.05), (0, 1.0, -1.55), 0xFFF3D6)]
    p += sym([ball((0.45, 0.9, 0.45), (0.62, 1.3, -0.75), gold, r=(50, 0, 25))])
    # bee wings and a little stripe band
    p += sym([ball((1.2, 0.75, 0.08), (0.75, 1.75, 0.85), 0xE8F6FF, "G", r=(0, -30, 30), t=0.35),
              ball((0.85, 0.55, 0.08), (0.62, 1.2, 0.9), 0xE8F6FF, "G", r=(0, -30, -15), t=0.35)])
    p.append(ball((1.5, 0.3, 1.3), (0, 1.4, 0.25), 0x3A2A1A))
    return p


def sunflower_sprite():
    g, lg, petal, centre = 0x6CC24A, 0xA6E07A, 0xFFD12E, 0x6B3E1E
    hc, hr = (0, 1.75, -0.1), (0.85, 0.8, 0.8)
    p = [ball((0.95, 1.05, 0.9), (0, 0.72, 0.05), g, tag="Body"), ball((1.7, 1.6, 1.6), hc, lg, tag="Body")]
    p += sym([ball((0.32, 0.5, 0.36), (0.25, 0.2, -0.05), g), ball((0.7, 0.24, 0.36), (0.62, 0.95, -0.05), g, r=(0, 0, 30))])
    p += eyes(hc, hr, yaw=28, pitch=0, size=0.48)
    p += blush(hc, hr, size=0.3)
    p.append(ball((0.24, 0.08, 0.06), (0, 1.38, -0.88), 0x3A6A2A))
    # sunflower hat: brown disc + ring of petals
    hat = [cyl(1.15, 0.28, (0, 0, 0), centre)]
    for i in range(10):
        a = 360 * i / 10
        ar = math.radians(a)
        hat.append(ball((0.42, 0.12, 0.85), (math.sin(ar) * 0.82, -0.02, -math.cos(ar) * 0.82), petal, r=(0, -a, 0)))
    hat.append(cyl(0.12, 0.5, (0, 0.3, 0), g))
    p += T(hat, (0, 2.5, -0.05), r=(-14, 0, 8))
    # leaf wings
    p += sym([ball((0.9, 0.5, 0.06), (0.55, 1.1, 0.55), 0x9BE36A, "P", r=(0, -35, 35))])
    return p


# ======================================================================= Grove
def toadstool():
    red, spot, stem, gill = 0xE0393E, 0xFFF6EA, 0xFFF0D8, 0xF0D2B0
    hc = (0, 1.0, -0.05)
    hr = (0.72, 0.8, 0.66)
    p = [ball((1.44, 1.6, 1.32), hc, stem, tag="Body"),
         ball((2.7, 1.45, 2.7), (0, 2.25, 0.05), red, tag="Body"),
         ball((2.35, 0.4, 2.35), (0, 1.75, 0.05), gill)]
    cr = (1.35, 0.72, 1.35)
    for yaw, pitch, s in ((0, 30, 0.55), (60, 50, 0.45), (-70, 40, 0.5), (150, 35, 0.5), (-150, 55, 0.4), (100, 15, 0.4),
                          (-110, 12, 0.38), (0, 80, 0.5)):
        p.append(on_surface((0, 2.25, 0.05), cr, yaw, pitch, (s, s, 0.12), spot, inset=0.2))
    p += eyes(hc, hr, yaw=24, pitch=-5, size=0.42)
    p += blush(hc, hr, yaw=46, pitch=-22, size=0.26)
    p.append(ball((0.22, 0.1, 0.06), (0, 0.66, -0.66), 0x8A3A2A))
    p += sym([ball((0.5, 0.36, 0.7), (0.36, 0.17, -0.25), 0xD9B48A)])
    p += sym([ball((0.26, 0.45, 0.26), (0.72, 0.85, -0.05), stem, r=(0, 0, 35))])
    return p


def snail():
    body, shell, ring_c, moss = 0xD8C08A, 0xA0673E, 0xC8915A, 0x6AB04F
    p = [ball((1.0, 0.62, 2.6), (0, 0.31, 0.05), body, tag="Body"),
         ball((1.05, 1.25, 0.95), (0, 0.95, -1.0), body, tag="Body")]
    hc, hr = (0, 1.05, -1.0), (0.52, 0.62, 0.48)
    p += eyes(hc, hr, yaw=30, pitch=8, size=0.34)
    p += blush(hc, hr, yaw=50, pitch=-18, size=0.2)
    # eye stalks with little balls
    p += sym([cyl(0.12, 0.6, (0.22, 1.75, -1.0), body, r=(-10, 0, -15)), ball(0.24, (0.3, 2.05, -1.05), body)])
    # shell: big disc (axis X) with two inner rings for the spiral
    sc = (0, 1.45, 0.4)
    p.append(ball((1.15, 2.1, 2.1), sc, shell, tag="Body"))
    p += sym([ball((0.2, 1.45, 1.45), (0.5, 1.5, 0.45), ring_c), ball((0.18, 0.9, 0.9), (0.6, 1.58, 0.52), shell),
              ball((0.12, 0.42, 0.42), (0.66, 1.64, 0.58), ring_c)])
    for pt, s in (((0.15, 2.48, 0.25), 0.7), ((-0.25, 2.4, 0.7), 0.6), ((0.1, 2.25, 1.15), 0.5)):
        p.append(ball((s, 0.28, s), pt, moss, "E"))
    p.append(ball((0.3, 0.12, 0.5), (0.1, 2.7, 0.35), 0x8CE06A, r=(0, 30, 30)))
    return p


def frog():
    g, belly, dk = 0x5BBF4A, 0xDDF2A8, 0x3E8F35
    p = [ball((2.1, 1.35, 1.9), (0, 0.85, 0), g, tag="Body"), ball((1.4, 0.8, 0.5), (0, 0.65, -0.72), belly)]
    # bulging eye mounds on top with the eyes on their fronts
    for sx in (1,):
        p += sym([ball(0.9, (0.55, 1.55, -0.45), g)])
    p += sym(eyes((0.55, 1.55, -0.45), (0.45, 0.45, 0.45), yaw=8, pitch=8, size=0.55, both=False))
    p.append(ball((1.0, 0.09, 0.2), (0, 0.95, -0.92), 0x2E5A28, r=(0, 0, 0)))
    p += blush((0, 0.85, 0), (1.05, 0.67, 0.95), yaw=48, pitch=0, size=0.3)
    p += sym([ball((0.55, 0.5, 1.0), (0.85, 0.42, 0.35), g), ball((0.55, 0.18, 0.6), (0.95, 0.09, -0.12), dk),
              ball((0.32, 0.5, 0.32), (0.55, 0.35, -0.65), g), ball((0.4, 0.14, 0.42), (0.6, 0.07, -0.78), dk)])
    # leaf hat between the eyes
    leaf = 0x3FA34D
    p += [ball((1.5, 0.16, 1.15), (0, 1.75, 0.15), 0x8FD94A, r=(-12, 25, 6)), ball((0.07, 0.07, 1.05), (0, 1.82, 0.15), 0x5AA83A, r=(-12, 25, 6)),
          cyl(0.09, 0.4, (0.22, 1.9, -0.38), 0x5AA83A, r=(25, 0, 25))]
    for pt in ((0.5, 1.25, 0.6), (-0.7, 1.1, 0.4), (0.2, 1.45, 0.75)):
        p.append(ball((0.3, 0.12, 0.3), pt, dk))
    return p


def owl():
    br, face, belly, beak, wing = 0x8A5A3C, 0xE2C29A, 0xC9A27C, 0xF2A33A, 0x6E4630
    c = (0, 1.35, 0)
    p = [ball((2.2, 2.5, 2.0), c, br, tag="Body"), ball((1.4, 1.5, 0.5), (0, 0.85, -0.78), belly)]
    # face disc around each eye
    p += sym([ball((0.95, 0.95, 0.3), (0.4, 1.75, -0.85), face, r=(0, -15, 0))])
    p += sym(eyes((0.4, 1.75, -0.85), (0.48, 0.48, 0.2), yaw=12, pitch=0, size=0.7, iris=0xFFC93C, depth=0.3, both=False))
    p.append(spike((0, 1.42, -1.0), 0.28, 0.32, beak, r=(180, 0, 0)))
    p += sym([ball((0.5, 1.5, 1.2), (1.05, 1.2, 0.15), wing, r=(0, 0, 10))])
    p += sym(T(tri((0, 0, 0), 0.55, 0.6, 0.25, br), (0.65, 2.42, -0.25), r=(0, 0, -25)))
    for pt in ((0, 1.05, -0.98), (0.3, 0.8, -0.95), (-0.3, 0.8, -0.95), (0, 0.55, -0.9)):
        p.append(ball((0.22, 0.12, 0.06), pt, shade(belly, 0.75)))
    p += sym([ball((0.2, 0.16, 0.35), (0.38 + dx, 0.08, -0.45), beak) for dx in (-0.12, 0.12)])
    return p


def glowcap_dragon():
    purple, belly, cap = 0x7A4FC9, 0xC9A8F0, 0x52F2FF
    def mush(at, s, r):
        return T([cyl(0.18, 0.4, (0, 0.2, 0), 0xF6EEDC), ball((0.6, 0.32, 0.6), (0, 0.45, 0), cap, "N", tag="Glow")], at, r=r, s=s)
    spines = mush((0, 1.4, 0.15), 1.0, (-15, 0, 0)) + mush((0, 1.3, 0.62), 0.85, (-30, 0, 0)) + mush((0, 1.0, 1.0), 0.7, (-50, 0, 0))
    horns = sym(mush((0.45, 2.6, -0.1), 1.05, (-15, 0, -22)))
    tip = mush((0, 1.3, 2.05), 0.8, (-40, 0, 0))
    return dragon(purple, belly, cap, shade(purple, 0.75), 0x9E7AE0, spines=spines, horns=horns, tail_tip=tip,
                  eye_iris=0x52F2FF)


def fairy_moth():
    fluff, body, wing, eye = 0xFFF4E2, 0xE8D6C0, 0x5CF2E0, 0x1C1A2B
    hc, hr = (0, 2.05, -0.35), (0.85, 0.8, 0.8)
    p = [ball((1.25, 1.5, 1.35), (0, 1.05, 0.25), body, tag="Body"), ball((1.7, 1.6, 1.6), hc, fluff, tag="Body")]
    for pt, s in (((0, 1.45, -0.35), 1.0), ((0.45, 1.38, -0.2), 0.7), ((-0.45, 1.38, -0.2), 0.7), ((0, 1.35, 0.25), 0.9)):
        p.append(ball(s, pt, fluff))
    p += eyes(hc, hr, yaw=28, pitch=4, size=0.58)
    p += blush(hc, hr, size=0.28)
    # feathery antennae
    p += sym([cyl(0.08, 0.9, (0.3, 2.95, -0.45), 0x8A6E52, r=(-25, 0, -25)),
              ball((0.3, 0.6, 0.12), (0.55, 3.35, -0.62), fluff, r=(-25, 0, -25))])
    # four glowing wings
    p += sym([ball((2.3, 1.6, 0.08), (1.3, 2.15, 0.55), 0x3ED8C8, "P", r=(0, -28, -22), t=0.1),
              ball((1.9, 1.25, 0.1), (1.25, 2.15, 0.53), wing, "N", r=(0, -28, -22), t=0.2, tag="Glow"),
              ball((1.5, 1.1, 0.08), (1.0, 1.05, 0.7), wing, "N", r=(0, -28, 28), t=0.2, tag="Glow"),
              ball((0.5, 0.42, 0.12), (1.55, 2.3, 0.6), 0xFFF2A8, "N", r=(0, -28, -22))])
    p += sym([ball((0.3, 0.3, 0.4), (0.3, 0.18, 0.0), body), ball((0.3, 0.3, 0.4), (0.32, 0.18, 0.5), body)])
    return p


# ======================================================================= Frost
def penguin():
    blk, wh, org, scarf = 0x2B2E44, 0xFAFAFA, 0xFF9A2E, 0xE0353F
    c = (0, 1.4, 0)
    p = [ball((2.0, 2.6, 1.85), c, blk, tag="Body"), ball((1.5, 1.85, 0.6), (0, 1.05, -0.68), wh),
         ball((1.5, 1.05, 0.5), (0, 2.0, -0.62), wh)]
    p += eyes((0, 1.95, 0), (1.0, 1.3, 0.93), yaw=24, pitch=22, size=0.52)
    p.append(spike((0, 1.82, -1.0), 0.32, 0.3, org, r=(-90, 0, 0)))
    p += blush((0, 1.4, 0), (1.0, 1.3, 0.93), yaw=40, pitch=12, size=0.25)
    p += sym([ball((0.45, 1.35, 0.6), (1.0, 1.3, 0.05), blk, r=(0, 0, 18)),
              ball((0.55, 0.2, 0.8), (0.4, 0.1, -0.3), org)])
    # red scarf: band + hanging end
    p += [cyl(2.04, 0.3, (0, 1.42, 0.0), scarf), box((0.34, 0.6, 0.12), (0.5, 1.12, -0.9), scarf, r=(12, 0, 10)),
          box((0.36, 0.06, 0.13), (0.52, 0.86, -0.95), WHITE, r=(12, 0, 10))]
    p.append(spike((0, 0.35, 0.95), 0.4, 0.35, blk, r=(110, 0, 0)))
    return p


def snow_bunny():
    pale, muff = 0xCFE6FF, 0xFF7FB0
    ex = sym([ball((0.62, 0.62, 0.55), (0.98, 1.8, -0.1), muff, "X"), ball((0.4, 0.4, 0.3), (1.08, 1.8, -0.1), 0xFFFFFF)])
    for i in range(5):
        a = math.radians(25 + i * 32.5)
        ex.append(box((0.62, 0.14, 0.18), (math.cos(a) * 1.0, 1.85 + math.sin(a) * 1.0, -0.1), 0xFF7FB0, r=(0, 0, math.degrees(a) + 90)))
    return bunny(pale, inner=0x9CCBFF, nose=0xFF8FB0, extras=ex, belly=WHITE)


def arctic_fox():
    return fox(body=0xF4F6FA, chest=0xFFFFFF, sock=0xDDE6F0, ear_inner=0x9FD6FF, tail_tip=0x6FC8FF, eye_iris=0x4FB0F0)


def yeti():
    wh, face, horn = 0xF6F8FC, 0x7EC8F0, 0xEDE3C8
    c = (0, 1.5, 0.05)
    p = [ball((2.3, 2.5, 2.0), c, wh, tag="Body")]
    for pt, s in (((0.85, 2.4, 0.2), 0.9), ((-0.85, 2.4, 0.2), 0.9), ((0, 2.75, 0.15), 1.1), ((0.95, 1.2, 0.3), 0.9),
                  ((-0.95, 1.2, 0.3), 0.9), ((0, 0.75, 0.55), 1.0)):
        p.append(ball(s, pt, wh))
    fc, fr = (0, 2.0, -0.78), (0.72, 0.62, 0.3)
    p.append(ball((1.44, 1.24, 0.6), fc, face))
    p += eyes(fc, fr, yaw=28, pitch=12, size=0.42)
    p.append(ball((0.6, 0.2, 0.1), (0, 1.62, -1.05), 0x2A3A5A))
    p += sym([spike((0.15, 1.58, -1.08), 0.1, 0.14, WHITE, r=(180, 0, 0))])
    p += blush(fc, fr, yaw=40, pitch=-25, size=0.22)
    p += sym(cone((0.65, 2.95, -0.2), 0.32, 0.6, horn, n=3, r=(-10, 0, -30), tip=0.3))
    p += sym([ball((0.75, 1.6, 0.8), (1.25, 1.15, -0.25), wh, r=(15, 0, 12)),
              ball((0.55, 0.3, 0.55), (1.35, 0.42, -0.45), face),
              ball((0.75, 0.42, 1.0), (0.55, 0.21, -0.25), wh)])
    return p


def aurora_wolf():
    navy, belly = 0x2B2F4A, 0x5A6080
    hc, hr = (0, 1.95, -0.3), (1.0, 0.9, 0.88)
    ex = []
    cols = (0x4CFFB0, 0x4CC9FF, 0xB06CFF)
    for i, (z, c) in enumerate(zip((-0.1, 0.3, 0.7), cols)):
        ex.append(ball((1.18, 0.16, 0.22), (0, 1.25 - i * 0.03, z), c, "N", tag="Glow"))
    ex += [on_surface(hc, hr, 0, 60, (0.22, 0.7, 0.1), 0x4CFFB0, "N", tag="Glow")]
    ex += sym([on_surface(hc, hr, 40, 35, (0.12, 0.5, 0.1), 0x4CC9FF, "N", spin=30, tag="Glow")])
    ex.append(ball((0.5, 0.5, 0.5), (0, 2.0, 1.95), 0xB06CFF, "N", tag="Glow"))
    return quad(navy, belly=belly, snout=belly, long_snout=True, snout_size=(0.66, 0.46, 0.5), nose=0x111111,
                ears=("pointy", navy, 0x4CC9FF), tail="bushy", tip=0x4CFFB0, paw=0x1C1F33, eye_iris=0x7CF2FF,
                ear_size=1.15, extras=ex, blush_col=None)


def polar_king():
    wh, crown, cape, trim = 0xF2F4F8, 0x9FE6FF, 0xC0263A, 0xFFFFFF
    hc = (0, 1.95, -0.3)
    cr = []
    cr += [cyl(1.3, 0.28, (0, 0, 0), GOLD, "F")]
    for i in range(5):
        a = 2 * math.pi * i / 5
        cr += crystal((math.sin(a) * 0.55, 0.05, -math.cos(a) * 0.55), 0.26, 0.75 if i == 0 else 0.55, crown, "G", t=0.1)
    cr.append(ball(0.24, (0, 0.1, -0.66), 0x4FB0FF, "N", tag="Glow"))
    ex = T(cr, (0, 2.78, -0.3), r=(-8, 0, 0))
    ex += [ball((1.45, 1.1, 1.7), (0, 0.98, 0.42), cape, "X"),
           ball((1.6, 0.42, 1.0), (0, 1.36, -0.02), trim, "X")]
    ex += [ball(0.1, (x, 1.45, -0.48), 0x222222) for x in (-0.4, 0, 0.4)]
    return quad(wh, belly=0xFFFFFF, snout=0xFFFFFF, nose=0x222222, ears=("round", wh, 0xDDE3EE), tail="pom",
                paw=0xE4E8F0, eye_iris=None, extras=ex, snout_size=(0.85, 0.55, 0.55))


# ======================================================================= Coral
def crab():
    red, belly, claw = 0xE5483A, 0xFFB09A, 0xF0584A
    c = (0, 0.95, 0)
    p = [ball((2.3, 1.1, 1.7), c, red, tag="Body"), ball((1.6, 0.4, 1.2), (0, 0.55, -0.1), belly)]
    # eye stalks
    for sx in (1,):
        p += sym([cyl(0.16, 0.6, (0.38, 1.6, -0.45), red), ball(0.62, (0.38, 2.05, -0.45), WHITE)])
    p += sym([ball((0.38, 0.44, 0.2), (0.38, 2.05, -0.72), EYE, tag="Eye"), ball(0.14, (0.42, 2.13, -0.82), WHITE, "N", tag="Eye")])
    p += sym([ball((0.3, 0.18, 0.1), (0.75, 1.0, -0.8), PINK)])
    p.append(ball((0.5, 0.12, 0.1), (0, 0.95, -0.85), 0x7A1E1E))
    # claws: arm + big pincer + small pincer
    p += sym([ball((0.8, 0.35, 0.35), (1.25, 1.0, -0.5), red, r=(0, 35, 20)),
              ball((0.95, 0.75, 1.05), (1.55, 1.35, -1.05), claw, r=(0, 20, 0)),
              ball((0.4, 0.32, 0.7), (1.3, 1.65, -1.45), claw, r=(-15, 20, 0))])
    # legs
    for i, z in enumerate((-0.2, 0.25, 0.65)):
        p += sym([ball((0.95, 0.2, 0.22), (1.3, 0.42, z), red, r=(0, -10 + i * 15, -35))])
    return p


def turtle():
    shell, rim, plate, skin = 0x3E9A57, 0xC9DD86, 0x2D7843, 0x8FD18A
    p = [ball((2.0, 1.25, 2.2), (0, 0.95, 0.15), shell, tag="Body"), ball((2.3, 0.4, 2.5), (0, 0.55, 0.15), rim)]
    sc, sr = (0, 0.95, 0.15), (1.0, 0.625, 1.1)
    p.append(on_surface(sc, sr, 0, 90, (0.7, 0.7, 0.12), plate, inset=0.2))
    for yaw in (0, 72, 144, 216, 288):
        p.append(on_surface(sc, sr, yaw + 36, 40, (0.55, 0.5, 0.1), plate, inset=0.2))
    hc, hr = (0, 1.25, -1.35), (0.62, 0.58, 0.58)
    p.append(ball((1.24, 1.16, 1.16), hc, skin, tag="Body"))
    p.append(ball((0.6, 0.6, 0.7), (0, 0.8, -0.95), skin))
    p += eyes(hc, hr, yaw=32, pitch=8, size=0.4)
    p += blush(hc, hr, yaw=50, pitch=-15, size=0.22)
    p.append(ball((0.4, 0.07, 0.08), (0, 1.07, -1.88), 0x2E5A28))
    p += sym([ball((1.3, 0.2, 0.55), (1.15, 0.45, -0.55), skin, r=(0, 35, -10)),
              ball((0.75, 0.2, 0.42), (0.9, 0.35, 0.95), skin, r=(0, -35, -5))])
    p.append(spike((0, 0.6, 1.4), 0.3, 0.3, skin, r=(90, 0, 0)))
    for pt in ((0.3, 1.55, -1.35), (-0.25, 1.62, -1.2)):
        p.append(ball((0.18, 0.08, 0.18), pt, shade(skin, 0.75)))
    return p


def pufferfish():
    y, belly, fin = 0xFFD23F, 0xFFF3C4, 0xFF9E3A
    c = (0, 1.35, 0)
    r = (1.15, 1.1, 1.1)
    p = [ball((2.3, 2.2, 2.2), c, y, tag="Body"), ball((1.6, 1.0, 1.6), (0, 0.72, -0.1), belly)]
    for yaw, pitch in ((0, 55), (60, 35), (-60, 35), (120, 40), (-120, 40), (180, 50), (90, -5), (-90, -5),
                       (150, -10), (-150, -10), (30, 75), (0, 0)):
        if (yaw, pitch) == (0, 0):
            continue
        pos, n = ell_point(c, r, yaw, pitch, inset=-0.05)
        p.append(spike(pos, 0.2, 0.32, 0xF0A030, R=up_rot(n)))
    p += eyes(c, r, yaw=32, pitch=12, size=0.6)
    p += blush(c, r, yaw=52, pitch=-8, size=0.3)
    mp, n = ell_point(c, r, 0, -12, inset=0.02)
    p += [ball((0.42, 0.36, 0.16), mp, 0xE86A7A, R=rot(face_rot(n))), ball((0.24, 0.2, 0.1), add(mp, (0, 0, -0.06)), 0x8A2A3A, R=rot(face_rot(n)))]
    p += sym([ball((0.7, 0.5, 0.1), (1.18, 1.25, -0.05), fin, r=(0, -50, 20))])
    p += [ball((0.12, 0.9, 0.8), (0, 1.35, 1.2), fin), ball((0.1, 0.6, 0.55), (0, 2.45, 0.35), fin, r=(30, 0, 0))]
    return p


def octopus():
    pink, spot = 0xF27BB0, 0xD95495
    hc, hr = (0, 1.95, 0.05), (1.05, 1.1, 1.0)
    p = [ball((2.1, 2.2, 2.0), hc, pink, tag="Body")]
    for yaw, pitch, s in ((40, 55, 0.4), (-50, 45, 0.35), (150, 50, 0.4), (-140, 30, 0.3), (0, 75, 0.35)):
        p.append(on_surface(hc, hr, yaw, pitch, (s, s, 0.1), spot, inset=0.2))
    p += eyes(hc, hr, yaw=26, pitch=-12, size=0.56)
    p += blush(hc, hr, yaw=48, pitch=-28, size=0.3)
    p.append(ball((0.26, 0.12, 0.08), (0, 1.15, -0.9), 0x8A2A5A))
    # six curly tentacles
    for i, a in enumerate((25, 75, 130, 180 + 50, 180 + 105, 335 - 0)):
        ar = math.radians(a)
        dx, dz = math.sin(ar), -math.cos(ar)
        pts = [(dx * 0.65, 0.65, dz * 0.65 + 0.05), (dx * 1.05, 0.32, dz * 1.05 + 0.05), (dx * 1.4, 0.25, dz * 1.4 + 0.05),
               (dx * 1.62, 0.5, dz * 1.62 + 0.05)]
        p += chain(pts, [0.62, 0.5, 0.4, 0.32], pink)
    return p


def narwhal():
    blue, belly, horn1, horn2 = 0x4A86D8, 0xDDEBFF, 0xFFD45A, 0xE0A92E
    c = (0, 1.15, 0.2)
    r = (0.95, 0.85, 1.4)
    p = [ball((1.9, 1.7, 2.8), c, blue, tag="Body"), ball((1.4, 0.8, 2.2), (0, 0.65, 0.1), belly)]
    p += eyes(c, r, yaw=30, pitch=12, size=0.45)
    p += blush(c, r, yaw=46, pitch=-6, size=0.26)
    p.append(ball((0.34, 0.08, 0.06), (0, 0.98, -1.36), 0x22315A))
    # tail and flukes
    p += chain([(0, 1.2, 1.55), (0, 1.38, 1.95)], [0.85, 0.6], blue)
    p += sym([ball((0.8, 0.12, 0.5), (0.35, 1.55, 2.2), blue, r=(0, -30, 10))])
    p += sym([ball((0.75, 0.15, 0.45), (0.95, 0.65, -0.2), blue, r=(0, 30, -30))])
    for pt in ((0.4, 1.8, 0.3), (-0.3, 1.9, 0.6), (0.1, 1.95, 0.9), (-0.5, 1.6, -0.1)):
        p.append(ball((0.15, 0.08, 0.15), pt, 0x3566B0))
    # golden spiral horn
    p += cone((0, 1.75, -1.0), 0.42, 1.9, horn1, "F", n=6, r=(-62, 0, 0), tip=0.18, cols=[horn1, horn2])
    return p


def pearl_seahorse():
    body, belly, fin, pearl = 0xF3C9E8, 0xFFF0F8, 0xB9E4FF, 0xFFFCF4
    hc, hr = (0, 2.7, -0.15), (0.7, 0.7, 0.72)
    p = [ball((1.4, 1.4, 1.44), hc, body, tag="Body")]
    p.append(ball((0.34, 0.34, 1.15), (0, 2.5, -0.95), body, r=(-10, 0, 0)))
    p.append(ball((0.36, 0.3, 0.16), (0, 2.6, -1.5), shade(body, 0.8)))
    p += eyes(hc, hr, yaw=40, pitch=10, size=0.46)
    p += blush(hc, hr, yaw=58, pitch=-12, size=0.24)
    # body S-curve and curled tail
    p += chain([(0, 1.9, 0.0), (0, 1.35, 0.05), (0, 0.85, 0.15), (0, 0.45, 0.4), (0, 0.32, 0.8), (0, 0.55, 1.05),
                (0, 0.85, 0.95)], [1.15, 1.05, 0.85, 0.65, 0.5, 0.4, 0.32], body)
    for i, y in enumerate((1.95, 1.6, 1.25, 0.95)):
        p.append(ball((0.7 - i * 0.08, 0.14, 0.45), (0, y, -0.4 + i * 0.04), belly))
    p.append(ball((0.12, 1.1, 0.75), (0, 1.55, 0.6), fin, "G", t=0.25))
    p += sym([ball((0.45, 0.32, 0.08), (0.62, 2.35, 0.05), fin, "G", r=(0, -40, 0), t=0.2)])
    # crest with a pearl
    p += [ball((0.12, 0.55, 0.45), (0, 3.4, 0.05), fin, "G", t=0.15), ball((0.12, 0.42, 0.35), (0, 3.15, 0.45), fin, "G", t=0.15)]
    p += [ball(0.52, (0, 3.55, -0.2), pearl, "P"), ball(0.16, (0.12, 3.68, -0.4), WHITE, "N")]
    return p


# ======================================================================= Volcano
def lava_slime():
    o, glow, crust = 0xFF7A1F, 0xFFC23A, 0x3A2A2A
    c, r = (0, 1.0, 0), (1.25, 1.0, 1.2)
    p = [ball((2.5, 2.0, 2.4), c, o, tag="Body"), ball((2.75, 0.3, 2.65), (0, 0.15, 0), 0xFF9A2A, "N", tag="Glow"),
         ball((1.3, 0.8, 1.2), (0.25, 1.55, 0.05), glow, "N", t=0.15, tag="Glow")]
    p += eyes(c, r, yaw=24, pitch=8, size=0.55)
    p += blush(c, r, yaw=44, pitch=-10, size=0.3, col=0xFFB060)
    p.append(ball((0.42, 0.22, 0.12), ell_point(c, r, 0, -14, 0.03)[0], 0x7A1E10))
    for yaw, pitch, s in ((70, 40, 0.5), (-60, 50, 0.42), (150, 30, 0.6), (-150, 60, 0.45)):
        p.append(on_surface(c, r, yaw, pitch, (s, s * 0.8, 0.22), crust, "B", inset=0.3))
    for yaw, pitch, s in ((100, 10, 0.3), (-110, 15, 0.25), (180, 20, 0.35), (-30, 65, 0.25)):
        p.append(on_surface(c, r, yaw, pitch, (s, s, 0.25), glow, "N", inset=0.2, tag="Glow"))
    return p


def salamander():
    red, spot, belly = 0xE0402E, 0xFFD43A, 0xFF9A5A
    hc, hr = (0, 1.25, -0.9), (0.92, 0.65, 0.78)
    p = [ball((1.3, 0.85, 2.0), (0, 0.62, 0.3), red, tag="Body"), ball((1.84, 1.3, 1.56), hc, red, tag="Body"),
         ball((1.4, 0.4, 1.0), (0, 0.9, -1.15), belly)]
    p += eyes(hc, hr, yaw=36, pitch=26, size=0.5)
    p += blush(hc, hr, yaw=58, pitch=-4, size=0.26)
    p.append(ball((0.9, 0.08, 0.2), (0, 1.0, -1.6), 0x7A1E1E))
    p += chain([(0, 0.55, 1.3), (0.2, 0.45, 1.75), (0.5, 0.4, 2.05), (0.8, 0.45, 2.15)], [0.65, 0.5, 0.38, 0.28], red)
    p += sym([ball((0.75, 0.32, 0.36), (0.75, 0.3, -0.35), red, r=(0, 30, -15)),
              ball((0.75, 0.32, 0.36), (0.75, 0.3, 0.75), red, r=(0, -30, -15)),
              ball((0.36, 0.14, 0.4), (1.05, 0.08, -0.52), belly), ball((0.36, 0.14, 0.4), (1.05, 0.08, 0.95), belly)])
    for pt in ((0.35, 1.0, 0.1), (-0.3, 1.0, 0.45), (0.15, 0.95, 0.8), (-0.2, 1.75, -0.95), (0.4, 1.7, -0.7), (0.2, 0.7, 1.65)):
        p.append(ball((0.24, 0.12, 0.24), pt, spot))
    return p


def ember_bat():
    blk, ember, ear_in = 0x2A2230, 0xF0561A, 0xFF5A3A
    c, r = (0, 1.55, 0), (1.05, 1.0, 0.95)
    p = [ball((2.1, 2.0, 1.9), c, blk, tag="Body"), ball((1.0, 0.7, 0.3), (0, 0.85, -0.7), 0x4A3A48)]
    p += eyes(c, r, yaw=28, pitch=12, size=0.55, iris=0xFFB03A)
    p += blush(c, r, yaw=48, pitch=-6, size=0.28, col=0xFF7A5A)
    p += sym([spike((0.18, 1.12, -0.88), 0.12, 0.16, WHITE, r=(195, 0, 0))])
    p += sym(ear("pointy", blk, ear_in, at=(0.52, 2.35, 0.0), w=0.8, h=1.0, roll=-20))
    p += sym(wings_bat((0.85, 1.6, 0.2), blk, ember, n=3, span=1.9, sweep=-15, lift=5, mat_m="N", t=0.1))
    p += sym([ball((0.3, 0.35, 0.3), (0.4, 0.45, 0.1), blk)])
    return p


def lava_golem():
    rock, dark, lava = 0x4A3E3C, 0x2E2626, 0xFF6A00
    p = [box((2.1, 1.75, 1.5), (0, 1.55, 0.1), rock, "B", r=(0, 0, 3), tag="Body"),
         box((1.5, 1.15, 1.25), (0, 2.8, -0.1), rock, "B", r=(0, 0, -4), tag="Body"),
         box((1.2, 0.35, 0.9), (0, 3.35, 0.05), dark, "B", r=(0, 0, -4))]
    # glowing eyes and mouth
    p += sym([box((0.3, 0.22, 0.08), (0.32, 2.88, -0.74), 0xFFD23A, "N", tag="Eye")])
    p.append(box((0.6, 0.1, 0.08), (0, 2.5, -0.74), lava, "N", tag="Glow"))
    # arms + fists, legs
    p += sym([box((0.7, 1.35, 0.75), (1.45, 1.75, -0.05), rock, "B", r=(0, 0, 10)), box((0.95, 0.85, 0.95), (1.62, 0.75, -0.15), dark, "B"),
              box((0.75, 0.75, 0.85), (0.55, 0.38, 0.1), dark, "B")])
    # lava cracks
    for pos, rr, size in (((0.3, 1.7, -0.66), (0, 0, 35), (0.9, 0.1, 0.06)), ((-0.35, 1.35, -0.66), (0, 0, -25), (0.8, 0.1, 0.06)),
                          ((0, 1.05, -0.66), (0, 0, 70), (0.55, 0.1, 0.06)), ((0.45, 3.05, -0.73), (0, 0, -30), (0.4, 0.08, 0.05)),
                          ((1.82, 1.95, -0.1), (0, 90, 60), (0.9, 0.1, 0.06)), ((-1.82, 1.95, -0.1), (0, 90, -60), (0.9, 0.1, 0.06)),
                          ((0, 2.45, 0.86), (0, 0, 20), (1.2, 0.1, 0.06))):
        p.append(box(size, pos, lava, "N", r=rr, tag="Glow"))
    p.append(ball((0.9, 0.3, 0.7), (0.15, 3.55, 0.05), lava, "N", tag="Glow"))
    return p


def inferno_dragon():
    red, belly, flame, dk = 0xD8322A, 0xFFB04A, 0xFF8A1A, 0x8A1E1A
    horns = sym(cone((0.5, 2.6, -0.05), 0.4, 1.1, flame, "N", n=3, r=(-28, 0, -22), tip=0.25, cols=[0xFF5A1A, flame, 0xFFD23A]))
    tip = [ball((0.5, 0.7, 0.5), (0, 1.5, 2.05), flame, "N", tag="Glow"), ball((0.3, 0.45, 0.3), (0, 1.85, 2.0), 0xFFD23A, "N", tag="Glow")]
    return dragon(red, belly, flame, dk, 0xFF7A2A, spine=0xFFB04A, horns=horns, tail_tip=tip, membrane_mat="P",
                  eye_iris=0xFFC23A)


def phoenix():
    red, org, yel = 0xE8402A, 0xFF8A1A, 0xFFD23A
    c, r = (0, 1.6, 0.1), (0.95, 1.05, 0.95)
    p = [ball((1.9, 2.1, 1.9), c, red, tag="Body"), ball((1.2, 1.2, 0.4), (0, 1.3, -0.7), org)]
    p += eyes(c, r, yaw=30, pitch=18, size=0.5, iris=0xFFC23A)
    p += blush(c, r, yaw=50, pitch=0, size=0.26)
    p.append(spike((0, 1.6, -1.0), 0.32, 0.36, yel, r=(-90, 0, 0)))
    # flame crest
    for i, (x, rr, h) in enumerate(((0, 0, 1.0), (0.28, -20, 0.75), (-0.28, 20, 0.75))):
        p += cone((x, 2.5, 0.05), 0.32, h, org, "N", n=3, r=(-15, 0, rr), tip=0.2, cols=[red, org, yel], tag="Glow")
    # layered wings
    for i, (col, L, a) in enumerate(((red, 2.0, 45), (org, 1.7, 25), (yel, 1.3, 5))):
        p += sym([ball((L, 0.5, 0.12), (0.9 + L * 0.35, 1.9 + i * -0.15 + L * 0.2, 0.4), col, "N" if i else "P",
                       r=(0, -25, a), tag="Glow" if i else None)])
    # long tail feathers
    for i, (x, col) in enumerate(((0, yel), (0.3, org), (-0.3, org), (0.55, red), (-0.55, red))):
        L_ = 2.6 - i * 0.2
        ang = 22 + abs(x) * 10
        d = (x * 0.35, -math.sin(math.radians(ang)), math.cos(math.radians(ang)))
        p.append(ball((0.3, 0.16, L_), add((x * 0.5, 1.15, 0.85), mul(d, L_ * 0.48)), col, "N" if i == 0 else "P",
                      r=(ang, -x * 18, 0), tag="Glow" if i == 0 else None))
        p.append(ball((0.42, 0.14, 0.55), add((x * 0.5, 1.15, 0.85), mul(d, L_ * 0.98)), yel, "N", r=(ang, -x * 18, 0), tag="Glow"))
    p += sym([ball((0.2, 0.4, 0.2), (0.3, 0.3, 0.2), yel)])
    return p


# ======================================================================= Starfall
def comet_cat():
    navy, belly, comet = 0x24346E, 0x5F78C8, 0xFFE66B
    hc, hr = (0, 1.95, -0.3), (1.0, 0.9, 0.88)
    ex = [on_surface(hc, hr, 0, 42, (0.36, 0.36, 0.14), comet, "N", spin=45, tag="Glow"),
          on_surface(hc, hr, 0, 42, (0.36, 0.36, 0.14), comet, "N", spin=0, tag="Glow"),
          box((0.05, 0.05, 0.62), (0.62, 1.66, -1.18), 0xBFD0FF, r=(0, 72, 6)), box((0.05, 0.05, 0.62), (-0.62, 1.66, -1.18), 0xBFD0FF, r=(0, -72, -6))]
    # comet tail: glowing head + fading trail
    ex += [ball(0.62, (0, 2.1, 1.35), comet, "N", tag="Glow"), ball((0.55, 0.55, 0.85), (0, 1.75, 1.45), 0xFFF5C0, "N", t=0.25, tag="Glow"),
           ball((0.45, 0.45, 0.7), (0, 1.4, 1.35), 0xBFD7FF, "N", t=0.45), ball((0.35, 0.35, 0.5), (0, 1.12, 1.15), 0x9FB8FF, "N", t=0.6)]
    return quad(navy, belly=belly, snout=belly, nose=0xFF8FB8, ears=("pointy", navy, 0x9FB8FF), tail=None, paw=belly,
                snout_size=(0.7, 0.42, 0.4), eye_iris=0xFFE66B, extras=ex)


def moon_bunny():
    lilac, moon = 0xC9A8F0, 0xFFE27A
    hc, hr = (0.0, 1.78, -0.15), (0.93, 0.8, 0.8)
    pos, n = ell_point(hc, hr, 0, 34, inset=0.02)
    R = rot(face_rot(n))
    cres = T([cyl(0.62, 0.08, (0, 0, 0), moon, "N", r=(90, 0, 0), tag="Glow"), cyl(0.56, 0.1, (0.17, 0.08, -0.02), lilac, r=(90, 0, 0))], pos, R=R)
    ex = cres + [ball(0.16, (0.7, 3.4, -0.2), moon, "N"), ball(0.12, (-0.75, 3.0, 0.1), moon, "N")]
    return bunny(lilac, inner=0x8E6AD8, nose=0xFF8FC8, extras=ex, eye_iris=0xB08CFF)


def nebula_fox():
    purple, pink = 0x7B3FC4, 0xF06AC8
    ex = [ball(0.14, pt, WHITE, "N") for pt in ((0.5, 1.2, 0.1), (-0.4, 1.0, 0.6), (0.3, 2.65, -0.5), (-0.55, 2.3, -0.75),
                                                 (0.15, 1.6, 1.6), (-0.2, 1.9, 1.3), (0.62, 2.05, -0.95))]
    return fox(body=purple, chest=pink, sock=0x3A1E6E, ear_inner=pink, tail_tip=pink, extras=ex, eye_iris=0xF06AC8)


def galaxy_axolotl():
    blue, belly, f1, f2 = 0x1E2A6E, 0x3A4AA0, 0xFF6AD5, 0x6AE8FF
    hc, hr = (0, 1.4, -0.55), (1.15, 0.78, 0.82)
    p = [ball((1.25, 0.95, 2.0), (0, 0.65, 0.5), blue, tag="Body"), ball((2.3, 1.56, 1.64), hc, blue, tag="Body"),
         ball((1.4, 0.5, 0.6), (0, 1.0, -0.95), belly)]
    p += eyes(hc, hr, yaw=36, pitch=12, size=0.46)
    p += blush(hc, hr, yaw=55, pitch=-10, size=0.28, col=f1)
    p.append(ball((0.8, 0.08, 0.12), (0, 1.12, -1.33), 0x0E1438))
    # glowing frills, 3 per side
    for i, (col, a) in enumerate(((f1, 35), (f2, 5), (f1, -25))):
        p += sym([ball((0.95, 0.24, 0.16), (1.3, 1.6 + i * -0.12, -0.45 + i * 0.12), col, "N", r=(0, -20, a), tag="Glow")])
    p += [ball((0.14, 0.7, 1.7), (0, 0.85, 1.65), blue), ball((0.1, 0.45, 1.4), (0, 1.15, 1.6), f2, "N", t=0.3, tag="Glow")]
    p += sym([ball((0.32, 0.4, 0.32), (0.55, 0.2, -0.15), blue), ball((0.32, 0.4, 0.32), (0.55, 0.2, 0.9), blue)])
    for pt in ((0.3, 1.15, 0.4), (-0.35, 1.05, 0.7), (0.5, 2.05, -0.5), (-0.6, 1.9, -0.3), (0.1, 0.95, 1.2)):
        p.append(ball(0.13, pt, WHITE, "N"))
    return p


def celestial_dragon():
    wh, gold, glow = 0xF7F3E6, 0xF2C44E, 0xFFE27A
    halo = ring((0, 3.25, -0.2), 0.6, 5, (0, 0.1, 0.12), glow, "N", tilt=(-15, 0, 0), tag="Glow")
    star_tips = []
    wings = []
    for s in (1,):
        w = wings_bat((0.5, 1.4, 0.5), gold, 0xFFF4D0, n=3, span=1.7)
        w += T([ball(0.26, (1.6, 1.3, 0), glow, "N", tag="Glow")],
               (0.5, 1.4, 0.5), r=(0, -30, 0))
        wings += sym(w)
    horns = sym(cone((0.5, 2.6, -0.05), 0.36, 0.95, gold, "F", n=2, r=(-28, 0, -22), tip=0.4))
    spines = [spike((0, 1.42, 0.12), 0.3, 0.32, gold, r=(-20, 0, 0)), spike((0, 1.3, 0.6), 0.28, 0.3, gold, r=(-35, 0, 0))]
    return dragon(wh, 0xFFF0C8, gold, gold, 0xFFF4D0, spine=gold, horns=horns, wings=wings, extras=halo, spines=spines, eye_iris=0x6AB8FF)


def cosmic_unicorn():
    body = 0x2E2466
    return unicorn(body, [0xFF6AD5, 0x6AE8FF, 0xB06CFF], [0xFFFFFF, 0x9FF4FF], 0x1A1440, muzzle=0x4A3A90, horn_mat="N",
                   mane_mat="N", eye_iris=0xB06CFF, speckle=0xFFFFFF)


def void_kraken():
    blk, vio, dk = 0x1E1630, 0xB04CFF, 0x2E2248
    hc, hr = (0, 2.25, 0.1), (1.1, 1.25, 1.0)
    p = [ball((2.2, 2.5, 2.0), hc, blk, tag="Body")]
    for yaw, pitch, s in ((60, 40, 0.35), (-55, 50, 0.3), (150, 30, 0.4), (-140, 55, 0.3)):
        p.append(on_surface(hc, hr, yaw, pitch, (s, s, 0.12), vio, "N", inset=0.2, tag="Glow"))
    p += eyes(hc, hr, yaw=28, pitch=-6, size=0.62, col=vio, iris=0xE8B0FF, hi=True)
    p = [q.copy(mat="N") if q.col == vio else q for q in p]
    p += sym([ball((0.45, 0.12, 0.1), (0.45, 2.55, -0.92), vio, "N", r=(0, 25, -20), tag="Glow")])
    for i, a in enumerate((30, 90, 150, 210, 270, 330)):
        ar = math.radians(a)
        dx, dz = math.sin(ar), -math.cos(ar)
        curl = 1 if i % 2 else -1
        pts = [(dx * 0.8, 0.7, dz * 0.8 + 0.1), (dx * 1.4, 0.38, dz * 1.4 + 0.1),
               (dx * 1.9 + dz * 0.25 * curl, 0.62, dz * 1.9 + 0.1 - dx * 0.25 * curl)]
        p += chain(pts, [0.75, 0.55, 0.4], blk)
        p.append(ball(0.26, add(pts[1], (0, 0.22, 0)), vio, "N", tag="Glow"))
    return p


# ======================================================================= Prism
def crystal_pup():
    ice, deep = 0xA8E4FF, 0x6FC8F0
    ex = [ball((0.24, 0.1, 0.22), (0.1, 1.4, -1.28), 0xFF9EC8, r=(30, 0, 0))]
    ex += crystal((0.25, 1.25, 0.25), 0.32, 0.9, 0xD8F6FF, "G", r=(-10, 0, -15), t=0.15)
    ex += crystal((-0.2, 1.25, 0.6), 0.26, 0.7, 0xD8F6FF, "G", r=(-25, 0, 20), t=0.15)
    ex += crystal((0, 1.6, 1.15), 0.3, 0.8, deep, "G", r=(-50, 0, 0), t=0.1)
    ex += [ball(0.4, (0, 1.4, -0.1), 0x7FF4FF, "N", tag="Glow")]
    p = quad(ice, belly=0xE8FAFF, snout=0xE8FAFF, ears=("floppy", deep, None), tail=None, paw=0xE8FAFF,
             eye_iris=0x3FA8E0, extras=ex)
    return [q.copy(mat="I") if q.col in (ice, deep) and q.mat == "P" else q for q in p]


def prism_fox():
    cols = [0xFFB3D9, 0xC9B3FF, 0xB3E6FF, 0xB3FFD9, 0xFFF0B3]
    ex = crystal((0, 1.3, 0.35), 0.3, 0.8, 0xFFFFFF, "G", r=(-20, 0, 0), t=0.2)
    ex += [ball(0.14, pt, WHITE, "N") for pt in ((0.5, 1.25, 0.1), (-0.45, 2.4, -0.7), (0.2, 1.65, 1.6))]
    p = fox(body=cols[1], head=cols[0], chest=0xFFFFFF, sock=cols[2], ear_inner=cols[3], tail_tip=cols[4],
            extras=ex, eye_iris=0xB06CFF)
    # tail in a different hue band for the prism look
    out = []
    for q in p:
        if q.shape == "ball" and q.size[2] > 1.4 and q.pos[2] > 1.0:
            q = q.copy(col=cols[2])
        out.append(q.copy(mat="G", tr=0.0) if q.col in cols[:2] and q.tag == "Body" else q)
    return out


def rainbow_unicorn():
    return unicorn(0xFBF8FF, RAINBOW, [GOLD, 0xFFE9A0], 0xF2C44E, horn_mat="F")


def diamond_dragon():
    d, deep, glow = 0x9FF0FF, 0x4FC8E8, 0x6AF2FF
    p = []
    # faceted body: rotated blocks instead of spheres
    p += sym([box((0.42, 0.55, 0.42), (0.42, 0.28, z), deep, "G", r=(0, 45, 0), t=0.05) for z in (-0.35, 0.78)])
    p.append(box((1.1, 1.0, 1.4), (0, 0.95, 0.3), d, "G", r=(0, 45, 0), t=0.1, tag="Body"))
    p.append(box((0.9, 0.9, 0.9), (0, 1.0, 0.3), deep, "G", r=(35, 45, 0), t=0.1))
    hc = (0, 1.95, -0.3)
    p.append(box((1.55, 1.45, 1.55), hc, d, "G", r=(0, 45, 0), t=0.1, tag="Body"))
    p.append(box((1.35, 1.35, 1.35), (0, 2.05, -0.3), d, "G", r=(45, 45, 0), t=0.15))
    p.append(box((0.7, 0.5, 0.7), (0, 1.62, -1.15), d, "G", r=(0, 45, 0), t=0.1))
    p += eyes(hc, (0.98, 0.9, 0.98), yaw=30, pitch=8, size=0.5, iris=0x2A9AD0)
    p.append(ball(0.6, (0, 1.0, 0.3), glow, "N", tag="Glow"))
    p.append(ball(0.5, (0, 2.0, -0.3), glow, "N", t=0.3, tag="Glow"))
    p += sym(crystal((0.45, 2.55, -0.1), 0.26, 0.85, 0xE0FCFF, "G", r=(-25, 0, -25), t=0.05))
    # crystal wings
    w = []
    for i, (L, a) in enumerate(((1.7, 60), (1.4, 30), (1.1, 5))):
        w += crystal((0, 0, 0), 0.3, L, d if i % 2 == 0 else deep, "G", r=(0, 0, -90 + a), t=0.1)
    p += sym(T(w, (0.5, 1.4, 0.5), r=(0, -30, 0)))
    p += crystal((0, 1.0, 1.15), 0.3, 0.9, d, "G", r=(-60, 0, 0), t=0.1)
    for z in (0.0, 0.45):
        p += crystal((0, 1.5, z), 0.2, 0.5, glow, "N", r=(-20, 0, 0), tag="Glow")
    return p


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
