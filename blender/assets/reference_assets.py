"""Scale reference exported with the pack."""

from sh.pipeline import asset
from sh.reference import build_dummy


@asset("SM_Reference_Dummy_R15", "Reference", "Reference", density=3.0, dummy=False,
       use="Scale reference: block R15 proportions, 5.25 studs tall, faces -Z (Roblox front).",
       pivot="Between the feet, on the ground.", fidelity="Box")
def dummy(m):
    d = build_dummy()
    m.bm.free()
    m.bm, m.l_mat, m.l_nat, m.l_nuv = d.bm, d.l_mat, d.l_nat, d.l_nuv
    m.smooth_angle = d.smooth_angle
    m.density = d.density
