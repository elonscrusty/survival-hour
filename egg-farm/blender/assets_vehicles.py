"""Delivery vehicles. Units: studs; length along Y, front (bonnet) faces -Y. Sizes are W x H x L."""


def wheel(b, x, y, r=1.2, w=1.0, z=None, dual=False):
    z = r if z is None else z
    side = 1 if x > 0 else -1
    b.cyl(r, w, (x, y, z), "Tyre", segs=12, rot=(0, 90, 0))
    b.cyl(r * 0.55, w + 0.12, (x + side * 0.02, y, z), "Metal", segs=8, rot=(0, 90, 0))
    b.cyl(r * 0.2, w + 0.25, (x + side * 0.04, y, z), "GreyDark", segs=6, rot=(0, 90, 0))
    if dual:
        b.cyl(r, w, (x - side * w, y, z), "Tyre", segs=12, rot=(0, 90, 0))


def lights(b, w, y, z, size=0.7):
    for sx in (-1, 1):
        b.box((size * 1.3, 0.2, size), (sx * (w / 2 - size), y, z), "Light")


def egg_logo(b, x, y, z, s=1.0, side=-1, axis="x", ring="Accent"):
    """Flat egg emblem on a vehicle side (axis='x' -> on a +-X face at x)."""
    if axis == "x":
        b.cyl(1.25 * s, 0.12, (x + side * 0.04, y, z), ring, segs=14, rot=(0, 90, 0), scale=(1.0, 0.85, 1))
        b.sphere(0.95 * s, (x + side * 0.08, y, z), "White", scale=(0.12, 0.8, 1.0), u=12, v=8)
    else:
        b.cyl(1.25 * s, 0.12, (x, y + side * 0.04, z), ring, segs=14, rot=(90, 0, 0), scale=(0.85, 1.0, 1))
        b.sphere(0.95 * s, (x, y + side * 0.08, z), "White", scale=(0.8, 0.12, 1.0), u=12, v=8)


def crate(b, x, y, z, s=1.0):
    b.boxb((2.0 * s, 1.6 * s, 1.0 * s), (x, y, z), "Wood")
    b.boxb((2.1 * s, 0.2 * s, 0.25 * s), (x, y - 0.8 * s, z + 0.6 * s), "WoodDark")
    b.boxb((2.1 * s, 0.2 * s, 0.25 * s), (x, y + 0.8 * s, z + 0.6 * s), "WoodDark")
    for dx in (-0.5, 0.5):
        for dy in (-0.35, 0.35):
            b.sphere(0.32 * s, (x + dx * s, y + dy * s, z + 1.15 * s), "White", scale=(1, 1, 1.3), u=8, v=5)


def farm_pickup(b):  # ~8 x 6 x 16
    body, trim = "Roof", "White"
    for y in (-5.0, 4.6):
        for sx in (-1, 1):
            wheel(b, sx * 3.3, y, 1.25, 1.0)
    b.boxb((6.0, 14.8, 0.8), (0, 0, 1.0), "GreyDark")  # chassis
    # bonnet
    b.boxb((7.2, 4.4, 1.9), (0, -5.6, 1.6), body)
    b.box((5.0, 0.2, 1.0), (0, -7.85, 2.4), "GreyDark")  # grille
    lights(b, 7.2, -7.85, 3.0, 0.6)
    b.boxb((7.6, 0.6, 0.6), (0, -7.9, 1.2), "Metal")  # bumper
    # cab
    b.boxb((7.2, 4.0, 1.9), (0, -1.4, 1.6), body)
    b.boxb((6.8, 3.6, 2.2), (0, -1.2, 3.5), body)
    b.box((6.2, 0.2, 1.7), (0, -3.05, 4.6), "Glass", rot=(-12, 0, 0))
    for sx in (-1, 1):
        b.box((0.2, 2.6, 1.5), (sx * 3.42, -1.2, 4.6), "Glass")
    b.boxb((7.0, 3.8, 0.3), (0, -1.2, 5.7), trim)  # roof cap
    # bed
    b.boxb((7.2, 7.4, 0.5), (0, 3.9, 1.6), "WoodDark")
    for sx in (-1, 1):
        b.boxb((0.4, 7.4, 1.6), (sx * 3.4, 3.9, 2.1), body)
        b.boxb((0.5, 7.4, 0.2), (sx * 3.4, 3.9, 3.7), trim)
    b.boxb((7.2, 0.4, 1.6), (0, 7.4, 2.1), body)
    b.boxb((7.6, 0.6, 0.6), (0, 7.8, 1.2), "Metal")
    for sx in (-1, 1):
        b.box((0.6, 0.2, 0.6), (sx * 3.0, 7.65, 3.2), "Comb")  # tail lights
    # wheel arches
    for y in (-5.0, 4.6):
        for sx in (-1, 1):
            b.boxb((0.5, 3.2, 0.5), (sx * 3.6, y, 2.6), "Black")
    # cargo
    crate(b, -1.5, 2.4, 2.1)
    crate(b, 1.5, 5.0, 2.1)


def delivery_van(b):  # ~8 x 8 x 18
    body = "White"
    for y in (-5.5, 5.5):
        for sx in (-1, 1):
            wheel(b, sx * 3.4, y, 1.3, 1.0)
    b.boxb((6.2, 16.0, 0.8), (0, 0, 1.0), "GreyDark")
    b.boxb((7.6, 13.0, 6.2), (0, 2.0, 1.6), body)  # cargo body
    b.boxb((7.6, 3.6, 2.6), (0, -6.3, 1.6), body)  # nose
    # sloped windshield block between nose and roof
    b.prism([(0, 0), (3.0, 0), (0, 3.6)], 7.6, (0, -4.5, 4.2), body, rot=(0, 0, -90))
    b.box((6.6, 0.2, 3.6), (0, -6.12, 6.08), "Glass", rot=(-40, 0, 0))
    for sx in (-1, 1):
        b.box((0.2, 2.0, 1.6), (sx * 3.82, -3.6, 5.2), "Glass")
    lights(b, 7.6, -8.15, 3.2, 0.6)
    b.box((4.0, 0.2, 0.8), (0, -8.15, 2.6), "GreyDark")
    b.boxb((8.0, 0.6, 0.7), (0, -8.3, 1.2), "Metal")
    b.boxb((8.0, 0.6, 0.7), (0, 8.7, 1.2), "Metal")
    # stripes + logo
    for sx in (-1, 1):
        b.boxb((0.1, 13.0, 0.7), (sx * 3.83, 2.0, 3.0), "Accent")
        b.boxb((0.1, 13.0, 0.3), (sx * 3.83, 2.0, 3.9), "Roof")
        egg_logo(b, sx * 3.8, 3.5, 5.7, 1.0, side=sx)
    # rear doors
    b.box((0.15, 0.2, 5.6), (0, 8.55, 4.6), "GreyDark")
    for sx in (-1, 1):
        b.box((0.6, 0.2, 0.6), (sx * 3.2, 8.55, 2.8), "Comb")
    b.boxb((5.0, 2.0, 0.4), (0, 0, 7.8), "Roof")  # roof vent box


def box_truck(b):  # ~9 x 11 x 24
    cab = "Green"
    for y in (-8.5,):
        for sx in (-1, 1):
            wheel(b, sx * 3.8, y, 1.5, 1.1)
    for y in (5.0, 8.4):
        for sx in (-1, 1):
            wheel(b, sx * 3.8, y, 1.5, 1.1, dual=True)
    b.boxb((6.2, 21.0, 1.0), (0, 0, 1.2), "GreyDark")
    # cab
    b.boxb((8.0, 5.6, 3.0), (0, -8.6, 1.8), cab)
    b.boxb((8.0, 4.4, 3.4), (0, -8.0, 4.8), cab)
    b.box((7.2, 0.2, 2.6), (0, -10.25, 6.4), "Glass", rot=(-10, 0, 0))
    for sx in (-1, 1):
        b.box((0.2, 2.6, 2.0), (sx * 4.02, -8.4, 6.3), "Glass")
        b.box((0.3, 0.3, 1.4), (sx * 4.5, -10.2, 6.2), "GreyDark")  # mirrors
    b.box((5.0, 0.2, 1.2), (0, -11.45, 3.4), "GreyDark")
    lights(b, 8.0, -11.45, 4.4, 0.7)
    b.boxb((8.4, 0.6, 0.8), (0, -11.6, 1.4), "Metal")
    b.boxb((8.4, 1.2, 0.5), (0, -8.4, 8.2), "Accent")  # roof marker bar
    # cargo box
    b.boxb((9.0, 15.8, 8.6), (0, 3.6, 2.2), "White")
    b.boxb((9.1, 15.9, 0.4), (0, 3.6, 2.2), "Grey")
    b.boxb((9.1, 15.9, 0.4), (0, 3.6, 10.4), cab)
    for sx in (-1, 1):
        b.boxb((0.1, 15.0, 1.0), (sx * 4.52, 3.6, 3.2), "Accent")
        egg_logo(b, sx * 4.5, 3.6, 7.0, 1.7, side=sx)
    b.box((8.4, 0.2, 7.6), (0, 11.55, 6.4), "Metal")  # roller door
    for z in range(3, 10):
        b.box((8.2, 0.3, 0.1), (0, 11.6, z + 0.2), "Grey")
    for sx in (-1, 1):
        b.box((0.6, 0.2, 0.8), (sx * 4.0, 11.6, 2.8), "Comb")


def egg_hauler(b):  # semi: ~10 x 13 x 48
    cab = "Accent"
    # tractor wheels
    for sx in (-1, 1):
        wheel(b, sx * 4.0, -20.0, 1.6, 1.1)
        for y in (-11.5, -8.0):
            wheel(b, sx * 4.0, y, 1.6, 1.1, dual=True)
        for y in (13.0, 16.6, 20.2):
            wheel(b, sx * 4.0, y, 1.6, 1.1, dual=True)
    b.boxb((5.0, 17.0, 1.2), (0, -14.5, 1.4), "GreyDark")
    # bonnet + cab + sleeper
    b.boxb((8.4, 5.0, 3.4), (0, -20.5, 1.8), cab)
    b.prism([(0, 0), (5.0, 0), (0, 0.8)], 8.4, (0, -18.0, 5.2), cab, rot=(0, 0, -90))
    b.box((6.0, 0.25, 2.4), (0, -23.1, 3.4), "Metal")  # grille
    lights(b, 8.4, -23.1, 4.0, 0.7)
    b.boxb((9.0, 0.7, 0.9), (0, -23.3, 1.4), "Metal")
    b.boxb((8.4, 5.2, 7.2), (0, -15.6, 1.8), cab)
    b.box((7.4, 0.25, 2.8), (0, -18.25, 7.0), "Glass", rot=(-8, 0, 0))
    for sx in (-1, 1):
        b.box((0.2, 2.4, 2.2), (sx * 4.22, -16.6, 6.8), "Glass")
        b.box((0.3, 0.3, 1.6), (sx * 4.7, -18.3, 6.8), "GreyDark")
        b.cylb(0.32, 9.5, (sx * 3.4, -12.6, 2.6), "Metal", segs=8)  # exhaust stacks
        b.boxb((1.2, 3.0, 1.2), (sx * 4.2, -13.0, 2.0), "Metal")  # fuel tanks
    b.boxb((8.4, 3.4, 1.6), (0, -15.0, 9.0), cab)  # sleeper top / air dam
    b.boxb((8.6, 0.6, 0.4), (0, -17.0, 10.4), "Roof")
    b.boxb((3.6, 3.6, 0.4), (0, -9.6, 2.6), "GreyDark")  # fifth wheel
    # trailer
    tl, ty = 33.0, 7.4
    b.boxb((9.6, tl, 9.6), (0, ty, 3.6), "White")
    b.boxb((9.7, tl + 0.1, 0.5), (0, ty, 3.6), "Roof")
    b.boxb((9.7, tl + 0.1, 0.5), (0, ty, 12.7), "Roof")
    for sx in (-1, 1):
        b.boxb((0.1, tl - 2, 0.6), (sx * 4.83, ty, 4.4), "Accent")
        egg_logo(b, sx * 4.8, ty - 6.0, 8.4, 2.4, side=sx)
        egg_logo(b, sx * 4.8, ty + 6.5, 8.4, 1.6, side=sx, ring="Roof")
        egg_logo(b, sx * 4.8, ty + 14.0, 8.4, 1.6, side=sx, ring="Green")
    b.boxb((0.5, 0.5, 3.0), (-3.6, ty - 7.0, 0.6), "GreyDark")  # landing gear
    b.boxb((0.5, 0.5, 3.0), (3.6, ty - 7.0, 0.6), "GreyDark")
    b.boxb((6.0, 10.0, 1.0), (0, 16.6, 2.6), "GreyDark")  # rear bogie
    b.box((9.0, 0.2, 9.0), (0, ty + tl / 2 + 0.05, 8.4), "Metal")
    b.box((0.2, 0.3, 9.0), (0, ty + tl / 2 + 0.15, 8.4), "GreyDark")
    for sx in (-1, 1):
        b.box((0.8, 0.2, 0.6), (sx * 4.2, ty + tl / 2 + 0.15, 3.0), "Comb")


ASSETS = {
    "Vehicles": [
        ("FarmPickup", farm_pickup),
        ("DeliveryVan", delivery_van),
        ("BoxTruck", box_truck),
        ("EggHauler", egg_hauler),
    ],
}
