local AssetFit = require("../src/shared/Logic/AssetFit")

local function det(c)
	local a, b, d = c[1], c[2], c[3]
	return a[1] * (b[2] * d[3] - b[3] * d[2]) - a[2] * (b[1] * d[3] - b[3] * d[1]) + a[3] * (b[1] * d[2] - b[2] * d[1])
end

return {
	exact_upload_is_identity = function(t)
		local f = AssetFit.Fit({ 9, 7.83, 6.96 }, { 9, 7.83, 6.96 })
		t.eq(f.Perm[1] * 100 + f.Perm[2] * 10 + f.Perm[3], 123)
		t.ok(math.abs(f.Scale - 1) < 1e-6)
		t.eq(det(AssetFit.Axes(f)), 1, "proper rotation")
	end,
	wrong_units_rescaled_not_rotated = function(t)
		-- e.g. imported in centimetres: 100x too big
		local f = AssetFit.Fit({ 900, 783, 696 }, { 9, 7.83, 6.96 })
		t.eq(f.Perm[2], 2)
		t.ok(math.abs(f.Scale - 100) < 1e-6)
		t.eq(f.LocalSize[1], 9)
	end,
	swapped_up_axis_detected = function(t)
		-- a tall tree (20 up) that arrived lying down (Y/Z swapped)
		local f = AssetFit.Fit({ 12.21, 12.03, 20.41 }, { 12.21, 20.41, 12.03 })
		t.eq(f.Perm[3], 2, "local Z is world up")
		t.eq(f.LocalSize[3], 20.41)
		t.eq(det(AssetFit.Axes(f)), 1, "still a proper rotation")
		t.eq(f.Sign[3], 1, "trees stay upright (up axis not flipped)")
	end,
	near_cubes_stay_put = function(t)
		local f = AssetFit.Fit({ 3.4, 2.5, 2.4 }, { 3.4, 2.4, 2.47 })
		t.eq(f.Perm[1] * 100 + f.Perm[2] * 10 + f.Perm[3], 123)
	end,
}
