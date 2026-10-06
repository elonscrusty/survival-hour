"""Geometry helpers for the Pet Expedition model generator.

Everything is authored directly in Roblox space: X right, Y up, the model
faces -Z (its front is towards -Z). Units are studs. A model is a flat list of
Part objects. Rotations are stored as 3x3 matrices and only converted to Euler
angles when the Luau data is written.

Shapes (authoring names):
  ball   ellipsoid (Block part + SpecialMesh Sphere in Roblox)
  box    Block part
  cyl    cylinder whose axis is the local Y axis, size = (diameter, height, diameter)
  wedge  Roblox WedgePart (tall face at +Z, slope descending towards -Z)
"""
import math

# ---------------------------------------------------------------- matrices
I3 = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))


def mmul(a, b):
    return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))


def mvec(a, v):
    return tuple(sum(a[i][k] * v[k] for k in range(3)) for i in range(3))


def rx(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return ((1, 0, 0), (0, c, -s), (0, s, c))


def ry(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return ((c, 0, s), (0, 1, 0), (-s, 0, c))


def rz(deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return ((c, -s, 0), (s, c, 0), (0, 0, 1))


def rot(r):
    """Authoring rotation: (pitch, yaw, roll) degrees applied as Ry @ Rx @ Rz
    (same convention as Roblox CFrame.fromOrientation)."""
    if r is None or r == (0, 0, 0):
        return I3
    return mmul(ry(r[1]), mmul(rx(r[0]), rz(r[2])))


def to_euler_xyz(m):
    """Decompose m = Rx(a) @ Ry(b) @ Rz(c); returns degrees (a, b, c).
    Matches Roblox CFrame.fromEulerAnglesXYZ / CFrame.Angles."""
    s = max(-1.0, min(1.0, m[0][2]))
    b = math.asin(s)
    if abs(math.cos(b)) > 1e-6:
        a = math.atan2(-m[1][2], m[2][2])
        c = math.atan2(-m[0][1], m[0][0])
    else:
        a = math.atan2(m[2][1], m[1][1])
        c = 0.0
    return (math.degrees(a), math.degrees(b), math.degrees(c))


def norm(v):
    l = math.sqrt(sum(x * x for x in v)) or 1.0
    return tuple(x / l for x in v)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def face_rot(d):
    """(pitch, yaw, 0) so that the local -Z axis points along direction d."""
    d = norm(d)
    yaw = math.degrees(math.atan2(-d[0], -d[2]))
    pitch = math.degrees(math.asin(max(-1, min(1, d[1]))))
    return (pitch, yaw, 0)


def up_rot(d):
    """Rotation matrix taking the local +Y axis onto direction d."""
    d = norm(d)
    y = (0.0, 1.0, 0.0)
    dot = d[1]
    if dot > 0.999999:
        return I3
    if dot < -0.999999:
        return rx(180)
    ax = norm((y[1] * d[2] - y[2] * d[1], y[2] * d[0] - y[0] * d[2], y[0] * d[1] - y[1] * d[0]))
    ang = math.acos(dot)
    c, s, t = math.cos(ang), math.sin(ang), 1 - math.cos(ang)
    x, yy, z = ax
    return ((t * x * x + c, t * x * yy - s * z, t * x * z + s * yy),
            (t * x * yy + s * z, t * yy * yy + c, t * yy * z - s * x),
            (t * x * z - s * yy, t * yy * z + s * x, t * z * z + c))


# ---------------------------------------------------------------- colours
def hexc(c):
    return ((c >> 16) & 255, (c >> 8) & 255, c & 255)


def rgb(r, g, b):
    return (int(max(0, min(255, round(r)))) << 16) | (int(max(0, min(255, round(g)))) << 8) | int(max(0, min(255, round(b))))


def shade(c, f):
    r, g, b = hexc(c)
    return rgb(r * f, g * f, b * f)


def mix(c1, c2, t):
    a, b = hexc(c1), hexc(c2)
    return rgb(*(a[i] + (b[i] - a[i]) * t for i in range(3)))


def hsv(h, s, v):
    import colorsys
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, s, v)
    return rgb(r * 255, g * 255, b * 255)


RAINBOW = [0xFF4D5E, 0xFF9A3C, 0xFFE14D, 0x5EE07A, 0x4DB8FF, 0xA77BFF]

# Material codes written to the Luau data (see MATS in Models/init.luau).
MATERIALS = {
    "P": "SmoothPlastic", "N": "Neon", "G": "Glass", "F": "Foil", "M": "Metal", "I": "Ice",
    "L": "Glacier", "S": "Snow", "W": "Wood", "K": "WoodPlanks", "R": "Rock", "T": "Slate",
    "B": "Basalt", "C": "CrackedLava", "A": "Sand", "E": "Grass", "O": "Concrete", "X": "Fabric",
    "Y": "Marble", "D": "DiamondPlate", "Q": "Pebble", "Z": "ForceField", "U": "Cobblestone",
    "H": "Brick", "J": "Granite", "V": "Sandstone", "a": "Asphalt", "g": "Ground", "l": "LeafyGrass",
    "p": "Plastic", "s": "Salt", "c": "CeramicTiles", "m": "Mud",
}


# ---------------------------------------------------------------- parts
class Part:
    __slots__ = ("shape", "size", "pos", "R", "col", "mat", "tag", "tr")

    def __init__(self, shape, size, pos, R, col, mat="P", tag=None, tr=0.0):
        self.shape, self.size, self.pos, self.R = shape, tuple(size), tuple(pos), R
        self.col, self.mat, self.tag, self.tr = col, mat, tag, tr

    def copy(self, **kw):
        p = Part(self.shape, self.size, self.pos, self.R, self.col, self.mat, self.tag, self.tr)
        for k, v in kw.items():
            setattr(p, k, v)
        return p

    def native(self):
        """(code, size, pos, R) in Roblox-native terms: B block, S sphere-mesh,
        C cylinder (axis = local X), W wedge."""
        if self.shape == "cyl":
            d, h, d2 = self.size
            return "C", (h, d, d2), self.pos, mmul(self.R, rz(90))
        code = {"ball": "S", "box": "B", "wedge": "W"}[self.shape]
        return code, self.size, self.pos, self.R


def _p(shape, size, pos, col, mat="P", r=None, tag=None, t=0.0, R=None):
    return Part(shape, size, pos, R if R is not None else rot(r), col, mat, tag, t)


def ball(size, pos, col, mat="P", r=None, tag=None, t=0.0, R=None):
    if isinstance(size, (int, float)):
        size = (size, size, size)
    return _p("ball", size, pos, col, mat, r, tag, t, R)


def box(size, pos, col, mat="P", r=None, tag=None, t=0.0, R=None):
    return _p("box", size, pos, col, mat, r, tag, t, R)


def cyl(d, h, pos, col, mat="P", r=None, tag=None, t=0.0, R=None):
    return _p("cyl", (d, h, d), pos, col, mat, r, tag, t, R)


def wedge(size, pos, col, mat="P", r=None, tag=None, t=0.0, R=None):
    return _p("wedge", size, pos, col, mat, r, tag, t, R)


def T(parts, pos=(0, 0, 0), r=None, s=1.0, R=None):
    """Transform a group of parts: scale by s, rotate, then translate."""
    G = R if R is not None else rot(r)
    out = []
    for p in parts:
        np_ = add(mvec(G, mul(p.pos, s)), pos)
        out.append(p.copy(pos=np_, R=mmul(G, p.R), size=mul(p.size, s)))
    return out


M_X = ((-1, 0, 0), (0, 1, 0), (0, 0, 1))


def mirror(parts):
    out = []
    for p in parts:
        out.append(p.copy(pos=(-p.pos[0], p.pos[1], p.pos[2]), R=mmul(M_X, mmul(p.R, M_X))))
    return out


def sym(parts):
    return list(parts) + mirror(parts)


def recolor(parts, fn):
    return [p.copy(col=fn(p)) for p in parts]


# ---------------------------------------------------------------- bounds
def corners(p):
    code, size, pos, R = p.native()
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    pts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                pts.append(add(pos, mvec(R, (sx * hx, sy * hy, sz * hz))))
    return pts


def bounds(parts):
    xs, ys, zs = [], [], []
    for p in parts:
        if p.tr >= 1:
            continue
        code, size, pos, R = p.native()
        if code == "S":
            # Tighter ellipsoid extents: half-extent along world axis i is
            # sqrt(sum_j (R[i][j] * h_j)^2).
            h = (size[0] / 2, size[1] / 2, size[2] / 2)
            ext = [math.sqrt(sum((R[i][j] * h[j]) ** 2 for j in range(3))) for i in range(3)]
            xs += [pos[0] - ext[0], pos[0] + ext[0]]
            ys += [pos[1] - ext[1], pos[1] + ext[1]]
            zs += [pos[2] - ext[2], pos[2] + ext[2]]
        else:
            for c in corners(p):
                xs.append(c[0]); ys.append(c[1]); zs.append(c[2])
    return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


def normalize(parts, height=None, ground=True):
    """Scale to `height` (if given) and move so the bounding box sits on y=0,
    centred on x and z."""
    lo, hi = bounds(parts)
    s = 1.0 if height is None else height / (hi[1] - lo[1])
    cx, cz = (lo[0] + hi[0]) / 2, (lo[2] + hi[2]) / 2
    parts = T(parts, (0, 0, 0), s=s)
    lo, hi = bounds(parts)
    return T(parts, (-(lo[0] + hi[0]) / 2, -lo[1] if ground else 0, -(lo[2] + hi[2]) / 2))


# ---------------------------------------------------------------- building blocks
EYE = 0x1C1A2B
WHITE = 0xFFFFFF
PINK = 0xFF9EBB


def ell_point(c, r, yaw, pitch, inset=0.0):
    """Point on an ellipsoid (centre c, semi-axes r) in direction (yaw, pitch)
    measured from the front (-Z). Positive yaw = +X side. Returns (pos, dir)."""
    y, p = math.radians(yaw), math.radians(pitch)
    d = (math.sin(y) * math.cos(p), math.sin(p), -math.cos(y) * math.cos(p))
    # Scale to the surface along d.
    k = 1.0 / math.sqrt(sum((d[i] / r[i]) ** 2 for i in range(3)))
    n = norm((d[0] / r[0] ** 2, d[1] / r[1] ** 2, d[2] / r[2] ** 2))
    pos = add(c, mul(d, k))
    pos = sub(pos, mul(n, inset))
    return pos, n


def eyes(c, r, yaw=26, pitch=4, size=0.5, col=EYE, iris=None, hi=True, squash=1.12, depth=0.5, both=True):
    """Big glossy cartoon eyes on an ellipsoid head (centre c, semi-axes r)."""
    out = []
    pos, n = ell_point(c, r, yaw, pitch, inset=size * 0.16)
    R = rot(face_rot(n))
    e = [ball((size, size * squash, size * depth), (0, 0, 0), col, "P", tag="Eye")]
    if iris is not None:
        e.append(ball((size * 0.62, size * 0.66 * squash, size * 0.2), (0, -size * 0.06, -size * 0.2), iris, "P", tag="Eye"))
        e.append(ball((size * 0.32, size * 0.36 * squash, size * 0.15), (0, -size * 0.04, -size * 0.27), EYE, "P", tag="Eye"))
    if hi:
        e.append(ball(size * 0.36, (size * 0.13, size * 0.2, -size * 0.17), WHITE, "N", tag="Eye"))
        if iris is None:
            e.append(ball(size * 0.15, (-size * 0.15, -size * 0.2, -size * 0.2), WHITE, "N", tag="Eye"))
    e = T(e, pos, R=R)
    out += e
    if both:
        out = sym(out)
    return out


def on_surface(c, r, yaw, pitch, size, col, mat="P", inset=0.25, tag=None, t=0.0, spin=0.0):
    """A flattened ellipsoid (patch / spot) lying on an ellipsoid surface."""
    pos, n = ell_point(c, r, yaw, pitch, inset=size[2] * inset)
    R = mmul(rot(face_rot(n)), rz(spin))
    return ball(size, pos, col, mat, R=R, tag=tag, t=t)


def blush(c, r, yaw=46, pitch=-14, size=0.36, col=PINK):
    return sym([on_surface(c, r, yaw, pitch, (size, size * 0.6, 0.12), col, inset=0.3)])


def cone(base, d, h, col, mat="P", n=4, R=None, r=None, tip=0.2, tag=None, t=0.0, cols=None):
    """Stack of n cylinders narrowing from diameter d to d*tip along local +Y."""
    G = R if R is not None else rot(r)
    out = []
    seg = h / n
    for i in range(n):
        f = 1 - (1 - tip) * (i / max(1, n - 1))
        c = cols[i % len(cols)] if cols else col
        out.append(cyl(d * f, seg * 1.05, (0, seg * (i + 0.5), 0), c, mat, tag=tag, t=t))
    return T(out, base, R=G)


def spike(base, d, h, col, mat="P", R=None, r=None, tag=None, t=0.0):
    """A pointy spike: a squashed ellipsoid half-buried at the base (reads as a
    rounded cone at pet scale)."""
    G = R if R is not None else rot(r)
    return T([ball((d, h * 2, d), (0, 0, 0), col, mat, tag=tag, t=t)], base, R=G)[0]


def tri(base, w, h, d, col, mat="P", R=None, r=None, tag=None, t=0.0):
    """Isosceles triangle prism (two wedges) standing on `base`, triangle in the
    local XY plane, thickness d along Z. Used for pointy ears and fins."""
    G = R if R is not None else rot(r)
    a = wedge((d, h, w / 2), (-w / 4, h / 2, 0), col, mat, r=(0, 90, 0), tag=tag, t=t)
    b = wedge((d, h, w / 2), (w / 4, h / 2, 0), col, mat, r=(0, -90, 0), tag=tag, t=t)
    return T([a, b], base, R=G)


def chain(points, sizes, col, mat="P", tag=None, t=0.0, cols=None):
    """Ellipsoids at each point (for tails, tentacles)."""
    out = []
    for i, (p, s) in enumerate(zip(points, sizes)):
        c = cols[i % len(cols)] if cols else col
        out.append(ball(s, p, c, mat, tag=tag, t=t))
    return out


def ring(center, radius, n, size, col, mat="P", tilt=None, tag=None, t=0.0, phase=0.0):
    """n boxes arranged in a horizontal ring (halo, crown band, rims)."""
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n + phase
        pos = (math.sin(a) * radius, 0, -math.cos(a) * radius)
        seg = 2 * radius * math.tan(math.pi / n) * 1.04
        out.append(box((seg, size[1], size[2]), pos, col, mat, r=(0, -math.degrees(a), 0), tag=tag, t=t))
    return T(out, center, r=tilt)


def crystal(base, w, h, col, mat="G", R=None, r=None, tag=None, t=0.0):
    """Gem crystal: a square prism (rotated 45 deg) with a pointed cap (a cube
    stood on a vertex)."""
    G = R if R is not None else rot(r)
    body = box((w, h * 0.72, w), (0, h * 0.36, 0), col, mat, r=(0, 45, 0), tag=tag, t=t)
    # Cube stood on a vertex: 45 deg about Z, then -35.26 deg about X.
    cap_s = w * 0.82
    cap = box((cap_s, cap_s, cap_s), (0, h * 0.72, 0), col, mat, R=mmul(ry(45), mmul(rx(-35.264), rz(45))), tag=tag, t=t)
    return T([body, cap], base, R=G)
