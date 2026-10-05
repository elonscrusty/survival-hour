--!strict
-- Fits an uploaded mesh to the size the pack catalog says it should have.
-- FBX files uploaded through Open Cloud may come in with a different unit
-- scale or with two axes swapped (up/forward conventions), so the loader
-- compares the mesh's local size with the authored size and picks the axis
-- mapping that matches best. Pure; tested by tests/AssetFit.spec.luau.

local AssetFit = {}

export type Fit = {
	Perm: { number }, -- Perm[i] = catalog (world) axis that local axis i points along
	Sign: { number }, -- +1 / -1 per local axis (keeps the rotation proper)
	LocalSize: { number }, -- size to give the mesh, in its own axes
	Scale: number, -- uniform scale the upload was off by (1 = correct)
	Error: number, -- max relative mismatch after the uniform scale
}

local PERMS = { { 1, 2, 3 }, { 1, 3, 2 }, { 2, 1, 3 }, { 2, 3, 1 }, { 3, 1, 2 }, { 3, 2, 1 } }
local ODD = { false, true, true, false, false, true }

local function score(mesh: { number }, target: { number }, perm: { number }): (number, number)
	local ratios = {}
	local sum = 0
	for i = 1, 3 do
		local r = mesh[i] / math.max(target[perm[i]], 1e-4)
		ratios[i] = r
		sum += r
	end
	local k = sum / 3
	local err = 0
	for i = 1, 3 do
		err = math.max(err, math.abs(ratios[i] / k - 1))
	end
	return err, k
end

-- mesh: the uploaded MeshPart's Size; target: the catalog size (Roblox axes).
function AssetFit.Fit(mesh: { number }, target: { number }): Fit
	local idErr, idK = score(mesh, target, PERMS[1])
	local best, bestErr, bestK = 1, idErr, idK
	-- only re-orient when the plain mapping is clearly wrong
	if idErr > 0.15 then
		for i = 2, #PERMS do
			local e, k = score(mesh, target, PERMS[i])
			if e < bestErr - 0.05 then
				best, bestErr, bestK = i, e, k
			end
		end
	end
	local perm = PERMS[best]
	-- An odd axis swap needs one flipped axis to stay a rotation: flip the one that
	-- lands on world X (left/right) so up and forward keep their direction.
	local sign = { 1, 1, 1 }
	if ODD[best] then
		for i = 1, 3 do
			if perm[i] == 1 then
				sign[i] = -1
			end
		end
	end
	local localSize = { target[perm[1]], target[perm[2]], target[perm[3]] }
	return { Perm = perm, Sign = sign, LocalSize = localSize, Scale = bestK, Error = bestErr }
end

-- Rotation columns (world direction of the mesh's local X, Y, Z) for a Fit.
function AssetFit.Axes(fit: Fit): { { number } }
	local cols = {}
	for i = 1, 3 do
		local v = { 0, 0, 0 }
		v[fit.Perm[i]] = fit.Sign[i]
		cols[i] = v
	end
	return cols
end

return AssetFit
