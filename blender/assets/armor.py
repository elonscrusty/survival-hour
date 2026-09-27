"""Level 3 survival armour: rigid R15 accessories.

Each piece is a single mesh (< 4k tris) with its origin at the R15
attachment it uses, so the pack's Luau helper just adds an Attachment of
that name at the origin inside an Accessory. Fitted to Classic-scale block
proportions (reference dummy). Roblox scales accessories with the avatar,
but tall or wide avatars may need Accessory adjustments. Rigid pieces
don't deform (not layered clothing).
"""

import math

from mathutils import Vector

from sh.pipeline import asset

D = 1.2


def piece(name, attach, use):
    def deco(fn):
        def wrapped(m):
            fn(m)
            m.meta["r15_attachment"] = attach
            m.attach(attach, (0, 0, 0))
        return asset(name, "Armor", "Accessory", density=D, dummy=False,
                     pivot=f"{attach} (origin). Front faces -Z.", use=use,
                     notes=f"Accessory > Handle (this mesh) > Attachment '{attach}' at the origin.")(wrapped)
    return deco


@piece("ACC_Armor_Helmet", "HatAttachment",
       "Leather cap with iron brow band, nasal guard and cheek flaps; team-coloured tail.")
def helmet(m):
    prof = [(0.0, 0.18), (0.4, 0.12), (0.62, -0.05), (0.72, -0.35), (0.74, -0.62)]
    inner = [(0.68, -0.62), (0.66, -0.35), (0.56, -0.08), (0.36, 0.06), (0.0, 0.1)]
    m.lathe("leather", prof + inner, 14, closed=True)
    m.torus("metal_dark", 0.74, 0.07, seg=16, tseg=4, loc=(0, 0, -0.5))
    m.lathe("metal", [(0.0, 0.2), (0.25, 0.16), (0.3, 0.1), (0.0, 0.1)], 8)  # crown plate
    for a in range(4):
        ang = a * math.tau / 4 + math.pi / 4
        m.box("metal_dark", (0.12, 0.08, 0.7), loc=(math.cos(ang) * 0.5, math.sin(ang) * 0.5, -0.15),
              rot=(math.degrees(math.sin(ang)) * -0.7, math.degrees(math.cos(ang)) * 0.7, 0))
    m.box("metal", (0.14, 0.08, 0.55), loc=(0, -0.78, -0.72), bevel=0.02)  # nasal
    for s in (-1, 1):
        m.box("leather_stitch", (0.08, 0.5, 0.5), loc=(s * 0.72, 0.05, -0.85), rot=(0, s * -8, 0), bevel=0.02)
    m.box("team_cloth", (0.35, 0.06, 0.8), loc=(0, 0.74, -0.55), rot=(12, 0, 0))


@piece("ACC_Armor_Chest", "BodyFrontAttachment",
       "Leather cuirass with three riveted iron lames and shoulder straps.")
def chest(m):
    m.box("leather", (2.15, 0.2, 1.75), loc=(0, -0.08, 0.0), bevel=0.06)
    for i, z in enumerate((0.45, 0.05, -0.35)):
        m.box("metal_dark" if i != 1 else "metal", (1.8 - i * 0.1, 0.1, 0.38), loc=(0, -0.22, z), bevel=0.03)
        for x in (-0.7, 0.7):
            m.blob("brass", 0.05, loc=(x, -0.28, z), subdiv=1)
    for s in (-1, 1):
        m.box("leather_stitch", (0.3, 1.1, 0.12), loc=(s * 0.7, 0.45, 0.88), bevel=0.02)
    m.box("leather_dark", (2.2, 0.22, 0.2), loc=(0, -0.1, -0.88), bevel=0.03)


@piece("ACC_Armor_Back", "BodyBackAttachment",
       "Back plate with a short team-coloured cape.")
def back(m):
    m.box("leather", (2.1, 0.2, 1.7), loc=(0, 0.08, 0.0), bevel=0.06)
    m.box("metal_dark", (1.6, 0.1, 0.35), loc=(0, 0.2, 0.4), bevel=0.03)
    v = m.box("team_cloth", (2.0, 0.06, 1.9), loc=(0, 0.26, -0.25))
    for vv in v:
        vv.co.y += 0.12 * max(0, -vv.co.z) + 0.05 * math.sin(vv.co.x * 4)
    m.box("cloth_dark", (2.1, 0.12, 0.18), loc=(0, 0.26, 0.72))


def pauldron(m, side):
    for i in range(3):
        z = 0.12 - i * 0.24
        prof = [(0.55 - i * 0.02, z - 0.28), (0.62, z - 0.1), (0.55, z + 0.12), (0.3, z + 0.28 - i * 0.04),
                (0.0, z + 0.32 - i * 0.05)]
        inner = [(0.0, z + 0.24 - i * 0.05), (0.26, z + 0.2), (0.48, z + 0.06), (0.54, z - 0.1),
                 (0.49, z - 0.28)]
        m.lathe("metal" if i == 0 else "metal_dark", prof + inner, 10, closed=True, scale=(1.0, 0.95, 0.9),
                loc=(side * 0.08 * i, 0, 0))
    m.box("leather_stitch", (0.9, 0.12, 0.3), loc=(side * -0.35, 0, 0.25), bevel=0.02)
    m.blob("brass", 0.07, loc=(side * 0.35, -0.55, 0.12), subdiv=1)


@piece("ACC_Armor_ShoulderL", "LeftShoulderAttachment", "Left layered iron pauldron (moves with the arm).")
def shoulder_l(m):
    pauldron(m, 1)


@piece("ACC_Armor_ShoulderR", "RightShoulderAttachment", "Right layered iron pauldron (moves with the arm).")
def shoulder_r(m):
    pauldron(m, -1)


@piece("ACC_Armor_Belt", "WaistCenterAttachment",
       "Wide belt with brass buckle, side pouch and leather tassets over the hips.")
def belt(m):
    W, Dp = 2.1, 1.1
    m.box("leather_stitch", (W, 0.12, 0.35), loc=(0, -Dp / 2, 0), bevel=0.02)
    m.box("leather_stitch", (W, 0.12, 0.35), loc=(0, Dp / 2, 0), bevel=0.02)
    for s in (-1, 1):
        m.box("leather_stitch", (0.12, Dp, 0.35), loc=(s * W / 2, 0, 0), bevel=0.02)
    m.box("brass", (0.35, 0.08, 0.3), loc=(0, -Dp / 2 - 0.07, 0), bevel=0.02)
    m.box("leather_dark", (0.45, 0.35, 0.5), loc=(0.85, -0.55, -0.2), bevel=0.06)
    for x in (-0.55, 0.55):
        v = m.box("leather", (0.75, 0.1, 0.7), loc=(x, -Dp / 2 - 0.06, -0.5), rot=(-6, 0, 0), bevel=0.03)
        m.box("metal_dark", (0.6, 0.08, 0.14), loc=(x, -Dp / 2 - 0.14, -0.4))
