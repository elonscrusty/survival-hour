"""Modeling kit: builds one watertight, atlas-mapped mesh per asset.

Conventions (match Roblox's recommended Blender -> FBX settings):
  * 1 Blender unit = 1 stud. Scene unit system: None.
  * Front of every asset faces Blender -Y (becomes Roblox -Z / LookVector).
  * Up is +Z (becomes Roblox +Y). Blender +X becomes Roblox -X.
  * Every asset is one mesh with one material (the shared atlas).
"""

import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

from . import textures as tx

FIT_NONE, FIT_ALL, FIT_V = 0, 1, 2
FIT_MATS = {"end_grain": FIT_ALL, "leather_stitch": FIT_V}


def xform(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    r = Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
    if not hasattr(scale, "__len__"):
        scale = (scale, scale, scale)
    return Matrix.Translation(Vector(loc)) @ r @ Matrix.Diagonal(Vector((*scale, 1.0)))


def blender_to_roblox(v):
    """Blender (x, y, z) -> Roblox (x, y, z) for FBX Forward=Z, Up=Y."""
    return (-v[0], v[2], v[1])


class Model:
    def __init__(self, name, seed=0, density=4.0, lod=0, grain=None, smooth_angle=38.0,
                 uv_box=False):
        self.name = name
        self.rng = random.Random(seed)
        self.density = density  # studs covered by one atlas tile
        self.lod = lod
        self.grain = Vector(grain).normalized() if grain else None
        self.smooth_angle = smooth_angle
        self.uv_box = uv_box  # continuous box projection (organic shapes)
        self.bm = bmesh.new()
        self.l_mat = self.bm.faces.layers.int.new("mat")
        self.l_nat = self.bm.faces.layers.int.new("native")
        self.l_nuv = self.bm.loops.layers.uv.new("nuv")
        self.attachments = []  # (name, loc, rot_degrees)
        self.collision = []  # (center, size, rot_degrees)
        self.meta = {}
        self.parts = []  # (Model, placement Matrix) for separate moving parts
        self.stats = {}

    # ------------------------------------------------------------------ utils
    def seg(self, n):
        return max(3 if n < 6 else 4, int(round(n * 0.55))) if self.lod else n

    def _faces_of(self, verts):
        fs = set()
        for v in verts:
            fs.update(v.link_faces)
        return fs

    def paint(self, verts, mat):
        i = tx.TILE_INDEX[mat]
        for f in self._faces_of(verts):
            f[self.l_mat] = i
        return verts

    def paint_where(self, verts, mat, pred):
        """Repaint faces of `verts` whose centre satisfies pred(center, normal)."""
        i = tx.TILE_INDEX[mat]
        for f in self._faces_of(verts):
            if pred(f.calc_center_median(), f.normal):
                f[self.l_mat] = i

    def tone(self, verts, q, pred=None):
        """Flat colour: faces of `verts` (optionally only where pred(center, normal))
        take one colour from their tile, at lightness percentile q (0..100)."""
        lay = self.bm.faces.layers.int.get("tone")
        if lay is None:
            lay = self.bm.faces.layers.int.new("tone")
        for f in self._faces_of(verts):
            if pred is None or pred(f.calc_center_median(), f.normal):
                f[lay] = int(q) + 1
        return verts

    def fit_bounds(self, lo, hi):
        """Stretch the model so its box is exactly lo..hi while the origin stays put:
        each side of each axis scales on its own (keeps a trunk on the pivot while
        matching a published, off-centre bounding box). Moves attachments and
        collision boxes along."""
        vs = list(self.bm.verts)
        cur_lo = [min(v.co[i] for v in vs) for i in range(3)]
        cur_hi = [max(v.co[i] for v in vs) for i in range(3)]

        def k(i, x):
            if x >= 0:
                return hi[i] / cur_hi[i] if cur_hi[i] > 1e-6 else 1.0
            return lo[i] / cur_lo[i] if cur_lo[i] < -1e-6 else 1.0

        def f(p):
            return tuple(p[i] * k(i, p[i]) for i in range(3))
        for v in vs:
            v.co = f(v.co)
        self.attachments = [(n, f(loc), rot) for n, loc, rot in self.attachments]
        self.collision = [(f(c), tuple(s * k(i, c[i]) for i, s in enumerate(size)), rot)
                          for c, size, rot in self.collision]

    def jitter(self, verts, amount, axes=(1, 1, 1)):
        if amount:
            for v in verts:
                v.co += Vector([self.rng.uniform(-amount, amount) * a for a in axes])
        return verts

    def transform(self, verts, matrix):
        bmesh.ops.transform(self.bm, matrix=matrix, verts=list(verts))
        return verts

    def flatten_below(self, z=0.0, verts=None):
        for v in (verts if verts is not None else self.bm.verts):
            if v.co.z < z:
                v.co.z = z

    def bend(self, verts, axis_len="y", amount=0.0, up="z"):
        """Quadratic bend: displace `up` by amount * t^2 where t is along axis."""
        ai, ui = "xyz".index(axis_len), "xyz".index(up)
        for v in verts:
            v.co[ui] += amount * v.co[ai] ** 2

    # ------------------------------------------------------------- primitives
    def cylinder(self, mat, r1, r2, h, seg=8, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1),
                 cap=None, top_cap=None):
        """Cylinder/cone standing on its base at `loc` (before rotation). r2=0: cone."""
        seg = self.seg(seg)
        m = xform(loc, rot, scale) @ Matrix.Translation((0, 0, h / 2))
        verts = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                      radius1=r1, radius2=r2, depth=h, matrix=m)["verts"]
        self.paint(verts, mat)
        minv = m.inverted()
        rot3 = minv.to_3x3()
        sx = (scale[0] + scale[1]) / 2 if hasattr(scale, "__len__") else scale
        rr = (r1 + r2) / 2 * sx
        for f in self._faces_of(verts):
            ln = rot3 @ f.normal
            if ln.length > 0 and abs(ln.normalized().z) > 0.999:  # cap
                c = (minv @ f.calc_center_median()).z
                use = top_cap if (c > 0 and top_cap) else cap
                if use:
                    f[self.l_mat] = tx.TILE_INDEX[use]
            else:
                self._native_cyl(f, minv, rr, h)
        return verts

    def _native_cyl(self, f, minv, rr, h):
        angs = []
        for loop in f.loops:
            p = minv @ loop.vert.co
            angs.append(math.atan2(p.y, p.x))
        if max(angs) - min(angs) > math.pi:
            angs = [a + 2 * math.pi if a < 0 else a for a in angs]
        for loop, a in zip(f.loops, angs):
            p = minv @ loop.vert.co
            loop[self.l_nuv].uv = ((p.z + h / 2), a * rr)
        f[self.l_nat] = 1

    def cone(self, mat, r, h, seg=8, **kw):
        return self.cylinder(mat, r, 0, h, seg, **kw)

    def box(self, mat, size, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0):
        """Box of `size` centred on `loc`. bevel > 0 chamfers edges (studs)."""
        m = xform(loc, rot, size)
        verts = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)["verts"]
        if bevel > 0 and not self.lod:
            faces = self._faces_of(verts)
            edges = list({e for f in faces for e in f.edges})
            res = bmesh.ops.bevel(self.bm, geom=list(verts) + edges, offset=bevel,
                                  offset_type="OFFSET", segments=1, profile=0.5,
                                  affect="EDGES", clamp_overlap=True)
            verts = list({v for f in res["faces"] for v in f.verts} | set(verts))
            verts = [v for v in verts if v.is_valid]
        return self.paint(verts, mat)

    def blob(self, mat, radius, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), jitter=0.0,
             subdiv=2):
        """Jittered icosphere. subdiv 1 = 20 tris, 2 = 80, 3 = 320."""
        subdiv = max(1, subdiv - 1) if self.lod else subdiv
        verts = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=radius,
                                           matrix=xform(loc, rot, scale))["verts"]
        self.jitter(verts, jitter)
        return self.paint(verts, mat)

    def sweep(self, mat, points, radii, seg=6, caps=True, cap_mat=None, closed=False,
              flat=1.0, up_hint=(0, 0, 1)):
        """Tube along a polyline. radii: number or list per point. flat < 1
        squashes the cross-section (ribbon-like leaves, straps, blades)."""
        seg = self.seg(seg)
        pts = [Vector(p) for p in points]
        n = len(pts)
        rs = radii if hasattr(radii, "__len__") else [radii] * n
        tangents = []
        for i in range(n):
            if closed:
                t = pts[(i + 1) % n] - pts[i - 1]
            else:
                t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
            tangents.append(t.normalized())
        up = Vector(up_hint)
        if abs(up.dot(tangents[0])) > 0.95:
            up = Vector((1, 0, 0)) if abs(tangents[0].x) < 0.9 else Vector((0, 1, 0))
        normal = (up - tangents[0] * up.dot(tangents[0])).normalized()
        rings, arc, arcs = [], 0.0, []
        for i in range(n):
            if i > 0:
                arc += (pts[i] - pts[i - 1]).length
                # parallel transport
                t0, t1 = tangents[i - 1], tangents[i]
                axis = t0.cross(t1)
                if axis.length > 1e-6:
                    ang = t0.angle(t1)
                    normal = Matrix.Rotation(ang, 3, axis.normalized()) @ normal
            binormal = tangents[i].cross(normal)
            ring = []
            for k in range(seg):
                a = 2 * math.pi * k / seg
                off = normal * math.cos(a) * rs[i] * flat + binormal * math.sin(a) * rs[i]
                ring.append(self.bm.verts.new(pts[i] + off))
            rings.append(ring)
            arcs.append(arc)
        faces = []
        count = n if closed else n - 1
        for i in range(count):
            j = (i + 1) % n
            a_j = arcs[j] if j > i else arc + (pts[0] - pts[-1]).length
            for k in range(seg):
                k2 = (k + 1) % seg
                f = self.bm.faces.new((rings[i][k], rings[i][k2], rings[j][k2], rings[j][k]))
                circ = 2 * math.pi * max((rs[i] + rs[j]) / 2, 0.02)
                v0, v1 = k / seg * circ, (k + 1) / seg * circ
                for loop, uv in zip(f.loops, ((arcs[i], v0), (arcs[i], v1), (a_j, v1), (a_j, v0))):
                    loop[self.l_nuv].uv = uv
                f[self.l_nat] = 1
                faces.append(f)
        verts = [v for r in rings for v in r]
        if caps and not closed:
            for ring, rev in ((rings[0], True), (rings[-1], False)):
                if rs[0 if rev else -1] > 1e-4:
                    faces.append(self.bm.faces.new(list(reversed(ring)) if rev else ring))
                else:
                    c = self.bm.verts.new(sum((v.co for v in ring), Vector()) / seg)
                    verts.append(c)
                    for k in range(seg):
                        tri = (ring[k], ring[(k + 1) % seg], c)
                        faces.append(self.bm.faces.new(tuple(reversed(tri)) if rev else tri))
        self.paint(verts, mat)
        if cap_mat and caps:
            for f in faces:
                if len(f.verts) == seg:
                    f[self.l_mat] = tx.TILE_INDEX[cap_mat]
        return verts

    def lathe(self, mat, profile, seg=10, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1),
              band_mats=None, closed=False):
        """Revolve [(radius, z), ...] (bottom to top) around local Z. Ends with
        radius 0 close to a point; otherwise they are capped."""
        seg = self.seg(seg)
        m = xform(loc, rot, scale)
        rings = []
        for r, z in profile:
            if r <= 1e-5:
                rings.append([self.bm.verts.new(m @ Vector((0, 0, z)))])
            else:
                rings.append([self.bm.verts.new(m @ Vector((r * math.cos(2 * math.pi * k / seg),
                                                            r * math.sin(2 * math.pi * k / seg), z)))
                              for k in range(seg)])
        arc = [0.0]
        for i in range(1, len(profile)):
            arc.append(arc[-1] + math.hypot(profile[i][0] - profile[i - 1][0],
                                            profile[i][1] - profile[i - 1][1]))
        verts = [v for r in rings for v in r]
        self.paint(verts, mat)  # no faces yet; painted below
        pairs = list(range(len(rings) - 1)) + ([len(rings) - 1] if closed else [])
        for i in pairs:
            a, b = rings[i], rings[(i + 1) % len(rings)]
            if len(a) == 1 and len(b) == 1:
                continue  # two poles: nothing to bridge
            bm_i = band_mats[i % len(band_mats)] if band_mats else mat
            rr = max((profile[i][0] + profile[(i + 1) % len(profile)][0]) / 2, 0.02)
            for k in range(seg):
                k2 = (k + 1) % seg
                if len(a) == 1:
                    f = self.bm.faces.new((a[0], b[k2], b[k]))
                elif len(b) == 1:
                    f = self.bm.faces.new((a[k], a[k2], b[0]))
                else:
                    f = self.bm.faces.new((a[k], a[k2], b[k2], b[k]))
                f[self.l_mat] = tx.TILE_INDEX[bm_i]
                v0 = k / seg * 2 * math.pi * rr
                v1 = (k + 1) / seg * 2 * math.pi * rr
                for loop in f.loops:
                    lv = loop.vert
                    ri = i if lv in a else min(i + 1, len(arc) - 1)
                    kk = (a.index(lv) if lv in a else (b.index(lv) if lv in b else 0))
                    loop[self.l_nuv].uv = (arc[ri], v0 if kk == k else v1)
                f[self.l_nat] = 1
        if len(rings[0]) > 1 and not closed:
            f = self.bm.faces.new(list(reversed(rings[0])))
            f[self.l_mat] = tx.TILE_INDEX[band_mats[0] if band_mats else mat]
        if len(rings[-1]) > 1 and not closed:
            f = self.bm.faces.new(rings[-1])
            f[self.l_mat] = tx.TILE_INDEX[band_mats[-1] if band_mats else mat]
        return verts

    def prism(self, mat, profile, depth, loc=(0, 0, 0), rot=(0, 0, 0), side_mat=None,
              scale=(1, 1, 1)):
        """Extrude a 2D polygon [(x, z), ...] (counter-clockwise seen from -Y)
        along Y by `depth`, centred on loc."""
        m = xform(loc, rot, scale)
        front = [self.bm.verts.new(m @ Vector((x, -depth / 2, z))) for x, z in profile]
        back = [self.bm.verts.new(m @ Vector((x, depth / 2, z))) for x, z in profile]
        ff = self.bm.faces.new(front)
        bf = self.bm.faces.new(list(reversed(back)))
        n = len(profile)
        sides = []
        for i in range(n):
            j = (i + 1) % n
            sides.append(self.bm.faces.new((front[i], back[i], back[j], front[j])))
        for f in (ff, bf):
            f[self.l_mat] = tx.TILE_INDEX[mat]
        for f in sides:
            f[self.l_mat] = tx.TILE_INDEX[side_mat or mat]
        return front + back

    def torus(self, mat, R, r, seg=12, tseg=6, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1),
              arc=360.0):
        m = xform(loc, rot, scale)
        closed = arc >= 360
        n = seg if closed else seg + 1
        pts = [m @ Vector((R * math.cos(math.radians(arc) * i / seg),
                           R * math.sin(math.radians(arc) * i / seg), 0)) for i in range(n)]
        return self.sweep(mat, pts, r, tseg, closed=closed,
                          up_hint=(m.to_3x3() @ Vector((0, 0, 1))))

    def heightfield(self, size_x, size_y, nx, ny, height, mat_fn, base=-1.0, loc=(0, 0, 0),
                    warp=None, skirt_mat="dirt"):
        """Solid terrain slab. height(x, y) -> z; mat_fn(x, y, z, slope) -> tile.
        warp(x, y) -> (x, y) lets bends/curves reuse the same grid."""
        ox, oy, oz = loc
        grid = []
        for j in range(ny + 1):
            row = []
            for i in range(nx + 1):
                x = -size_x / 2 + size_x * i / nx
                y = -size_y / 2 + size_y * j / ny
                z = height(x, y)
                wx, wy = warp(x, y) if warp else (x, y)
                row.append(self.bm.verts.new((wx + ox, wy + oy, z + oz)))
            grid.append(row)
        bottom = [[self.bm.verts.new((v.co.x, v.co.y, base + oz)) for v in row] for row in grid]
        top_faces = []
        for j in range(ny):
            for i in range(nx):
                q = (grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
                f = self.bm.faces.new(q)
                f.normal_update()
                c = f.calc_center_median()
                slope = 1 - abs(f.normal.z)
                f[self.l_mat] = tx.TILE_INDEX[mat_fn(c.x - ox, c.y - oy, c.z - oz, slope)]
                top_faces.append(f)
        for j in range(ny):
            for i in range(nx):
                f = self.bm.faces.new((bottom[j][i], bottom[j + 1][i], bottom[j + 1][i + 1],
                                       bottom[j][i + 1]))
                f[self.l_mat] = tx.TILE_INDEX[skirt_mat]
        edges = ([(grid[0][i], grid[0][i + 1], bottom[0][i + 1], bottom[0][i]) for i in range(nx)] +
                 [(grid[ny][i + 1], grid[ny][i], bottom[ny][i], bottom[ny][i + 1]) for i in range(nx)] +
                 [(grid[j + 1][0], grid[j][0], bottom[j][0], bottom[j + 1][0]) for j in range(ny)] +
                 [(grid[j][nx], grid[j + 1][nx], bottom[j + 1][nx], bottom[j][nx]) for j in range(ny)])
        for q in edges:
            f = self.bm.faces.new(q)
            f[self.l_mat] = tx.TILE_INDEX[skirt_mat]
        return [v for r in grid for v in r] + [v for r in bottom for v in r]

    # --------------------------------------------------------- game metadata
    def attach(self, name, loc, rot=(0, 0, 0)):
        self.attachments.append((name, tuple(loc), tuple(rot)))

    def col_box(self, center, size, rot=(0, 0, 0)):
        self.collision.append((tuple(center), tuple(size), tuple(rot)))

    def part(self, name, placement=(0, 0, 0), rot=(0, 0, 0), **kw):
        """Separate moving part with its own pivot. `placement` is where its
        pivot sits in this asset's space."""
        kw.setdefault("density", self.density)
        kw.setdefault("grain", tuple(self.grain) if self.grain else None)
        kw.setdefault("smooth_angle", self.smooth_angle)
        p = Model(name, seed=self.rng.randint(0, 1 << 30), lod=self.lod, **kw)
        self.parts.append((p, xform(placement, rot)))
        return p

    # ----------------------------------------------------------------- build
    def _uv_face(self, f, uv_layer):
        lay = self.bm.faces.layers.int.get("tone")
        if lay is not None and f[lay]:
            u, v = tx.tone_uv(f[self.l_mat], f[lay] - 1)
            d = 0.5 / tx.ATLAS
            for j, l in enumerate(f.loops):
                a = j * math.tau / len(f.loops)
                l[uv_layer].uv = (u + d * math.cos(a), v + d * math.sin(a))
            return
        mat = tx.TILE_NAMES[f[self.l_mat]]
        u0, v0, u1, v1 = tx.tile_rect(f[self.l_mat])
        fit = FIT_MATS.get(mat, FIT_NONE)
        if f[self.l_nat] and fit == FIT_NONE and not self.uv_box:
            coords = [Vector(l[self.l_nuv].uv) / self.density for l in f.loops]
        elif self.uv_box and fit == FIT_NONE:
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            pick = {0: (1, 2), 1: (0, 2), 2: (1, 0)}[ax]
            coords = [Vector((l.vert.co[pick[0]], l.vert.co[pick[1]])) / self.density for l in f.loops]
        else:
            n = f.normal
            t = None
            if self.grain is not None:
                t = self.grain - n * self.grain.dot(n)
                if t.length < 0.3:
                    t = None
            if t is None:
                e = max(f.edges, key=lambda e: e.calc_length())
                t = e.verts[1].co - e.verts[0].co
                t = t - n * t.dot(n)
            if t.length < 1e-9:
                t = n.orthogonal()
            t.normalize()
            b = n.cross(t)
            coords = [Vector((l.vert.co.dot(t), l.vert.co.dot(b))) / self.density for l in f.loops]
        us = [c.x for c in coords]
        vs = [c.y for c in coords]
        if fit == FIT_ALL:
            du, dv = max(us) - min(us) or 1, max(vs) - min(vs) or 1
            coords = [Vector(((c.x - min(us)) / du, (c.y - min(vs)) / dv)) for c in coords]
        else:
            def place(vals):
                lo, hi = min(vals), max(vals)
                if hi - lo > 1:  # face larger than a tile: compress to fit
                    return [(x - lo) / (hi - lo) for x in vals]
                base = math.floor(lo)
                if hi - base > 1:
                    base = lo
                return [x - base for x in vals]
            us = place(us)
            if fit == FIT_V:
                dv = max(vs) - min(vs) or 1
                vs = [(x - min(vs)) / dv for x in vs]
            else:
                vs = place(vs)
            coords = [Vector((u, v)) for u, v in zip(us, vs)]
        for l, c in zip(f.loops, coords):
            l[uv_layer].uv = (u0 + c.x * (u1 - u0), v0 + c.y * (v1 - v0))

    def _finalize_bm(self):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        ngons = [f for f in bm.faces if len(f.verts) > 4]
        if ngons:
            bmesh.ops.triangulate(bm, faces=ngons, quad_method="BEAUTY", ngon_method="BEAUTY")
        degenerate = [f for f in bm.faces if f.calc_area() < 1e-7]
        if degenerate:
            bmesh.ops.delete(bm, geom=degenerate, context="FACES")
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.normal_update()
        # validation stats
        seen, dup = set(), 0
        for f in bm.faces:
            key = tuple(sorted(v.index for v in f.verts))
            if key in seen:
                dup += 1
            seen.add(key)
        boundary = sum(1 for e in bm.edges if len(e.link_faces) == 1)
        nonmanifold = sum(1 for e in bm.edges if len(e.link_faces) > 2)
        # shading: smooth faces, sharp edges above the angle
        lim = math.radians(self.smooth_angle)
        for f in bm.faces:
            f.smooth = self.smooth_angle > 0
        for e in bm.edges:
            if len(e.link_faces) == 2:
                e.smooth = e.calc_face_angle(math.pi) < lim
            else:
                e.smooth = False
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            self._uv_face(f, uv)
        tris = sum(len(f.verts) - 2 for f in bm.faces)
        self.stats = dict(tris=tris, verts=len(bm.verts), duplicate_faces=dup,
                          open_edges=boundary, nonmanifold_edges=nonmanifold,
                          removed_degenerate=len(degenerate),
                          tiles=sorted({tx.TILE_NAMES[f[self.l_mat]] for f in bm.faces}))
        bm.loops.layers.uv.remove(self.l_nuv)
        bm.faces.layers.int.remove(self.l_mat)
        bm.faces.layers.int.remove(self.l_nat)
        if bm.faces.layers.int.get("tone") is not None:
            bm.faces.layers.int.remove(bm.faces.layers.int.get("tone"))

    def build(self, material, collection, name=None):
        self._finalize_bm()
        name = name or self.name
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        self.bm.free()
        mesh.materials.append(material)
        obj = bpy.data.objects.new(name, mesh)
        collection.objects.link(obj)
        lo = Vector([min(v.co[i] for v in mesh.vertices) for i in range(3)])
        hi = Vector([max(v.co[i] for v in mesh.vertices) for i in range(3)])
        self.stats["bounds_min"] = tuple(round(c, 3) for c in lo)
        self.stats["bounds_max"] = tuple(round(c, 3) for c in hi)
        self.stats["size"] = tuple(round(c, 2) for c in (hi - lo))
        for aname, loc, rot in self.attachments:
            add_attachment(obj, aname, loc, rot, material, collection)
        return obj


_ATT_MESH = None


def add_attachment(parent, name, loc, rot, material, collection):
    """Tiny mesh named <Name>_Att; Roblox's importer converts it to an Attachment."""
    global _ATT_MESH
    if _ATT_MESH is None or _ATT_MESH.name not in bpy.data.meshes:
        s = 0.04
        _ATT_MESH = bpy.data.meshes.new("AttachmentMarker")
        _ATT_MESH.from_pydata([(s, s, s), (-s, -s, s), (-s, s, -s), (s, -s, -s)], [],
                              [(0, 1, 2), (0, 3, 1), (0, 2, 3), (1, 3, 2)])
    # Stored as "<Asset>__<Name>_Att" so names stay unique inside one .blend;
    # the exporter strips the prefix so the FBX node is exactly "<Name>_Att".
    o = bpy.data.objects.new(f"{parent.name}__{name}_Att", _ATT_MESH)
    o.location = loc
    o.rotation_euler = [math.radians(a) for a in rot]
    o.parent = parent
    o.hide_render = True
    collection.objects.link(o)
    return o
