"""Roblox-scale reference dummy (block R15 proportions, ~5.25 studs tall).

Facing -Y like every asset. Its right side is Blender -X. Attachment
positions follow the R15 attachment names that rigid accessories and tools
use. They are approximations of a Classic-scale block avatar, so treat
them as a fitting guide, not exact R15 data.
"""

import math

from mathutils import Matrix, Vector

from .kit import Model

HEIGHT = 5.25
R15 = {
    "HatAttachment": (0, 0, 5.25),
    "FaceFrontAttachment": (0, -0.6, 4.62),
    "NeckAttachment": (0, 0, 4.0),
    "BodyFrontAttachment": (0, -0.5, 3.25),
    "BodyBackAttachment": (0, 0.5, 3.25),
    "WaistCenterAttachment": (0, 0, 2.2),
    "WaistFrontAttachment": (0, -0.5, 2.2),
    "WaistBackAttachment": (0, 0.5, 2.2),
    "LeftShoulderAttachment": (1.5, 0, 4.0),
    "RightShoulderAttachment": (-1.5, 0, 4.0),
    "LeftGripAttachment": (1.5, 0, 2.0),
    "RightGripAttachment": (-1.5, 0, 2.0),
}
SHOULDER_PIVOT_Z = 3.75


def hold_grip():
    """World position of RightGripAttachment with the right arm raised
    forward 90 degrees (Roblox's default tool-hold pose)."""
    drop = SHOULDER_PIVOT_Z - R15["RightGripAttachment"][2]
    return Vector((-1.5, -drop, SHOULDER_PIVOT_Z))


def build_dummy(pose="idle", name="SM_Reference_Dummy_R15"):
    m = Model(name, density=3.0, smooth_angle=30)
    mat, dark = "bone", "cloth_dark"
    for sx in (-0.5, 0.5):
        m.box(dark, (0.95, 1.0, 1.0), loc=(sx, 0, 0.5), bevel=0.06)
        m.box(mat, (0.95, 1.0, 1.0), loc=(sx, 0, 1.5), bevel=0.06)
    m.box(dark, (2.0, 1.0, 0.4), loc=(0, 0, 2.2), bevel=0.06)
    m.box(mat, (2.0, 1.0, 1.6), loc=(0, 0, 3.2), bevel=0.08)
    m.box(mat, (1.2, 1.2, 1.2), loc=(0, 0, 4.65), bevel=0.2)
    m.box("nose", (0.16, 0.05, 0.26), loc=(-0.25, -0.6, 4.75))
    m.box("nose", (0.16, 0.05, 0.26), loc=(0.25, -0.6, 4.75))
    for side in (1, -1):
        v = m.box(mat, (0.95, 1.0, 1.0), loc=(side * 1.5, 0, 3.5), bevel=0.06)
        v += m.box(dark, (0.95, 1.0, 1.0), loc=(side * 1.5, 0, 2.5), bevel=0.06)
        if pose == "hold" and side == -1:
            p = Vector((-1.5, 0, SHOULDER_PIVOT_Z))
            rot = Matrix.Translation(p) @ Matrix.Rotation(math.radians(-90), 4, "X") @ \
                Matrix.Translation(-p)
            m.transform(v, rot)
    return m
