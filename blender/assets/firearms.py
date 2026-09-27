"""Original, unbranded survival firearms: pistol, pump shotgun, bolt rifle.

Orientation: barrel forward along Roblox -Z (Blender -Y), up +Y. Origin =
grip point in the firing hand (RightGripAttachment); default Tool.Grip is
identity. Attachments: Grip, Muzzle, ShellEject (right side), plus
SecondHand for long guns. Moving parts are separate meshes with their own
pivot; 'placement' in the catalog gives their rest CFrame in the gun's space.
"""

import math

from sh.pipeline import asset

HELD = 1.2
PIVOT = ("Grip point (RightGripAttachment). Barrel along -Z (LookVector), up +Y. Default Tool.Grip = identity.")


def grip(m, h=0.75, back=0.12, mat="wood"):
    """Angled pistol grip hanging below the origin."""
    m.box(mat, (0.26, 0.42, h), loc=(0, back, -h / 2 + 0.2), rot=(-14, 0, 0), bevel=0.05)
    m.box("gunmetal", (0.28, 0.44, 0.08), loc=(0, back + 0.06, -h + 0.22), rot=(-14, 0, 0))


def trigger(m, y=-0.25):
    m.torus("gunmetal", 0.17, 0.03, seg=10, tseg=3, loc=(0, y, 0.12), rot=(0, 90, 0), arc=200,
            scale=(1, 1.3, 1))
    m.box("gunmetal", (0.05, 0.05, 0.16), loc=(0, y + 0.02, 0.14), rot=(15, 0, 0))


@asset("SM_Pistol", "Firearms", "Equippable", density=HELD, pivot=PIVOT,
       use="Sidearm. Slide is SM_Pistol_Slide (recoils +Z about 0.3 studs).",
       notes="Muzzle_Att: flash/raycast origin. ShellEject_Att: casing particles, right side.")
def pistol(m):
    grip(m, 0.75, 0.12, "wood_dark")
    m.box("gunmetal", (0.24, 1.2, 0.26), loc=(0, -0.25, 0.3), bevel=0.03)  # frame
    trigger(m)
    m.box("gunmetal", (0.24, 0.12, 0.14), loc=(0, -0.95, 0.22))
    s = m.part("SM_Pistol_Slide", placement=(0, 0, 0.47))
    s.meta["pivot"] = "Slide at rest. Animate along +Z (backwards) ~0.3 studs per shot."
    s.box("metal_dark", (0.26, 1.3, 0.24), loc=(0, -0.3, 0), bevel=0.03)
    for i in range(5):
        s.box("gunmetal", (0.27, 0.04, 0.2), loc=(0, 0.1 + i * 0.07, 0))
    s.box("gunmetal", (0.05, 0.06, 0.07), loc=(0, -0.9, 0.14))  # front sight
    s.box("gunmetal", (0.16, 0.06, 0.07), loc=(0, 0.27, 0.14))
    s.cylinder("gunmetal", 0.07, 0.07, 0.12, seg=8, loc=(0, -0.95, 0), rot=(90, 0, 0))
    s.box("metal", (0.02, 0.28, 0.12), loc=(-0.13, -0.05, 0.02))  # ejection port
    m.attach("Grip", (0, 0, 0))
    m.attach("Muzzle", (0, -1.08, 0.47))
    m.attach("ShellEject", (-0.2, -0.1, 0.52), (0, 0, 90))


@asset("SM_Shotgun", "Firearms", "Equippable", density=HELD, pivot=PIVOT,
       use="Pump shotgun. Fore-end is SM_Shotgun_Pump (slides +Z 0.6 studs to cycle).",
       notes="SecondHand_Att on the pump for the left hand.")
def shotgun(m):
    grip(m, 0.62, 0.15)
    m.box("gunmetal", (0.3, 1.0, 0.4), loc=(0, -0.45, 0.35), bevel=0.04)  # receiver
    trigger(m)
    m.cylinder("metal_dark", 0.1, 0.1, 2.7, seg=10, loc=(0, -0.9, 0.42), rot=(90, 0, 0))  # barrel
    m.cylinder("gunmetal", 0.08, 0.08, 2.1, seg=8, loc=(0, -0.9, 0.22), rot=(90, 0, 0))  # tube
    m.box("gunmetal", (0.06, 0.08, 0.08), loc=(0, -3.5, 0.55))
    # stock
    m.box("wood", (0.24, 1.6, 0.34), loc=(0, 0.9, 0.18), rot=(-8, 0, 0), bevel=0.05)
    m.box("wood", (0.26, 0.5, 0.62), loc=(0, 1.7, 0.08), rot=(-8, 0, 0), bevel=0.06)
    m.box("leather", (0.28, 0.12, 0.64), loc=(0, 1.97, 0.04), rot=(-8, 0, 0))
    m.torus("rope", 0.14, 0.03, seg=8, tseg=3, loc=(0, -2.6, 0.42), rot=(90, 0, 0))
    p = m.part("SM_Shotgun_Pump", placement=(0, -1.9, 0.22))
    p.meta["pivot"] = "Pump at rest. Slide along +Z 0.6 studs and back to cycle."
    p.cylinder("wood", 0.15, 0.15, 0.9, seg=10, loc=(0, 0.45, 0), rot=(90, 0, 0))
    for i in range(4):
        p.torus("wood_dark", 0.15, 0.025, seg=10, tseg=3, loc=(0, 0.1 + i * 0.2, 0), rot=(90, 0, 0))
    m.attach("Grip", (0, 0, 0))
    m.attach("Muzzle", (0, -3.6, 0.42))
    m.attach("ShellEject", (-0.2, -0.45, 0.45), (0, 0, 90))
    m.attach("SecondHand", (0, -1.5, 0.22))


@asset("SM_Rifle", "Firearms", "Equippable", density=HELD, pivot=PIVOT,
       use="Bolt-action hunting rifle. Bolt is SM_Rifle_Bolt (lift and pull back +Z 0.5 studs).",
       notes="Longest gun: 4.6 studs. SecondHand_Att under the fore-stock.")
def rifle(m):
    m.box("wood", (0.26, 3.2, 0.34), loc=(0, -0.55, 0.28), bevel=0.05)  # full stock fore
    m.box("wood", (0.24, 0.55, 0.45), loc=(0, 0.08, -0.05), rot=(-20, 0, 0), bevel=0.05)  # wrist/grip
    m.box("wood", (0.26, 1.3, 0.4), loc=(0, 1.2, 0.12), rot=(-6, 0, 0), bevel=0.06)
    m.box("wood", (0.28, 0.45, 0.72), loc=(0, 1.95, 0.02), rot=(-6, 0, 0), bevel=0.06)
    m.box("leather", (0.3, 0.1, 0.74), loc=(0, 2.2, -0.02), rot=(-6, 0, 0))
    m.cylinder("gunmetal", 0.13, 0.13, 1.0, seg=10, loc=(0, 0.2, 0.52), rot=(90, 0, 0))  # receiver
    m.cylinder("metal_dark", 0.08, 0.07, 2.6, seg=10, loc=(0, -0.8, 0.52), rot=(90, 0, 0))  # barrel
    m.box("gunmetal", (0.05, 0.08, 0.12), loc=(0, -3.3, 0.62))
    m.box("gunmetal", (0.14, 0.08, 0.1), loc=(0, -0.95, 0.62))
    trigger(m, y=-0.1)
    m.box("gunmetal", (0.2, 0.5, 0.22), loc=(0, -0.3, 0.12))  # magazine well
    for y in (-1.8, 1.4):  # sling swivels + leather sling
        m.torus("metal", 0.08, 0.02, seg=6, tseg=3, loc=(0, y, 0.05), rot=(0, 90, 0))
    m.sweep("leather", [(0.02, -1.8, 0.0), (0.02, -0.2, -0.55), (0.02, 1.4, 0.0)], 0.04, 4, flat=0.3)
    for y in (-2.0, -1.2):
        m.torus("metal_dark", 0.19, 0.03, seg=10, tseg=3, loc=(0, y, 0.34), rot=(90, 0, 0), scale=(0.75, 1.2, 1))
    b = m.part("SM_Rifle_Bolt", placement=(0, 0.35, 0.52))
    b.meta["pivot"] = "Bolt axis at rest. Rotate 60 deg about -Z (lift handle), then slide +Z 0.5 studs."
    b.cylinder("metal", 0.07, 0.07, 0.8, seg=8, loc=(0, 0.4, 0), rot=(90, 0, 0))
    b.sweep("metal", [(0, 0.25, 0), (-0.28, 0.3, -0.05), (-0.34, 0.32, -0.2)], 0.035, 5)
    b.blob("metal_dark", 0.08, loc=(-0.34, 0.32, -0.22))
    m.attach("Grip", (0, 0, 0))
    m.attach("Muzzle", (0, -3.4, 0.52))
    m.attach("ShellEject", (-0.2, 0.05, 0.6), (0, 0, 90))
    m.attach("SecondHand", (0, -1.4, 0.2))
