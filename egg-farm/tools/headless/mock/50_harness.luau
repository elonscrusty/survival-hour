-- Headless Roblox mock, part 5: GUI layout engine (AbsolutePosition/AbsoluteSize, UI dumps),
-- JSON, world dumps, and the scenario API `H`.

local V = M.Vector3.new
local Vector2 = M.Vector2
local Enum = M.Enum
local isA = M.isA
local isInst = M.isInst
local canSee = M.canSee
local game = M.game
local SignalApi = M.SignalApi
local getSignal = M.getSignal

------------------------------------------------------------------------------------------ JSON
local function jnum(n)
	if n ~= n or n == math.huge or n == -math.huge then
		return "null"
	end
	if n == math.floor(n) and math.abs(n) < 1e15 then
		return string.format("%d", n)
	end
	return string.format("%.6g", n)
end
local function jstr(s)
	s = string.gsub(s, '[%c"\\]', function(c)
		if c == '"' then
			return '\\"'
		elseif c == "\\" then
			return "\\\\"
		elseif c == "\n" then
			return "\\n"
		elseif c == "\t" then
			return "\\t"
		end
		return string.format("\\u%04x", string.byte(c))
	end)
	return '"' .. s .. '"'
end
local function json(v, seen)
	local t = type(v)
	if t == "nil" then
		return "null"
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "number" then
		return jnum(v)
	elseif t == "string" then
		return jstr(v)
	elseif t == "table" then
		if isInst(v) then
			return jstr("<" .. tostring(rawget(v, "_class").name) .. " " .. tostring(rawget(v, "_p").Name) .. ">")
		end
		local mt = getmetatable(v)
		if mt and M.TYPE[mt] then
			return jstr(tostring(v))
		end
		seen = seen or {}
		if seen[v] then
			return '"<cycle>"'
		end
		seen[v] = true
		local n = #v
		local count = 0
		for _ in v do
			count += 1
		end
		local out = {}
		if n > 0 and count == n then
			for i = 1, n do
				out[i] = json(v[i], seen)
			end
			seen[v] = nil
			return "[" .. table.concat(out, ",") .. "]"
		end
		local keys = {}
		for k in v do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, k in keys do
			table.insert(out, jstr(tostring(k)) .. ":" .. json(v[k], seen))
		end
		seen[v] = nil
		return "{" .. table.concat(out, ",") .. "}"
	end
	return jstr(tostring(v))
end
M.json = json

------------------------------------------------------------------------------------------ GUI layout
-- Approximates Roblox's 2D layout: UDim2 size/position/anchor, UIScale, UIPadding,
-- UISizeConstraint, UIAspectRatioConstraint, UIListLayout, UIGridLayout, AutomaticSize (text is
-- estimated at 0.55 x TextSize per character), ScrollingFrame canvases, screen insets.
-- It is a sanity check for placement, NOT a pixel-accurate renderer.
local layoutCache = setmetatable({}, { __mode = "k" }) -- root gui -> { version, vp, nodes }

local function childOfClass(obj, cls)
	for _, ch in rawget(obj, "_kids") do
		if isA(ch, cls) then
			return ch
		end
	end
	return nil
end

local function viewportFor(gui)
	local owner = rawget(gui, "_owner")
	if owner and owner.camera then
		return rawget(owner.camera, "_p").ViewportSize or Vector2.new(1280, 720)
	end
	-- a server-owned gui under a client's PlayerGui
	local p = gui
	while p do
		if isA(p, "Player") then
			local ctx = rawget(p, "_ctx")
			if ctx and ctx.camera then
				return rawget(ctx.camera, "_p").ViewportSize
			end
		end
		p = rawget(p, "_parent")
	end
	return Vector2.new(1280, 720)
end

local function insetsFor(gui, vp)
	if not isA(gui, "ScreenGui") then
		return 0, 0, 0, 0
	end
	local mode = gui.ScreenInsets
	local portrait = vp.Y > vp.X
	local phone = math.min(vp.X, vp.Y) < 500
	local notchTop = if phone and portrait then 47 else 0
	local notchBottom = if phone then 34 else 0
	local notchSide = if phone and not portrait then 47 else 0
	if mode == Enum.ScreenInsets.None then
		if gui.IgnoreGuiInset then
			return 0, 0, 0, 0
		end
		return 0, 58, 0, 0
	elseif mode == Enum.ScreenInsets.DeviceSafeInsets then
		return notchSide, notchTop, notchSide, notchBottom
	end
	-- CoreUISafeInsets / TopbarSafeInsets: below the 58 px top bar and inside notches
	return notchSide, math.max(58, notchTop + 44), notchSide, notchBottom
end

local function prop(obj, k)
	-- base value read through the instance (respects overlays of the current context)
	return obj[k]
end

local function guiChildren(obj, ctx)
	local out = {}
	for _, ch in rawget(obj, "_kids") do
		if isA(ch, "GuiObject") and (ctx == nil or canSee(ctx, ch)) then
			table.insert(out, ch)
		end
	end
	return out
end

local function textExtent(obj, s, width)
	local text = tostring(prop(obj, "Text") or "")
	if prop(obj, "RichText") then
		text = string.gsub(text, "<[^>]+>", "")
	end
	local size = (prop(obj, "TextSize") or 14) * s
	local w = #text * size * 0.55
	if width and prop(obj, "TextWrapped") and width > 1 then
		local lines = math.max(1, math.ceil(w / width))
		for _ in string.gmatch(text, "\n") do
			lines += 1
		end
		return math.min(w, width), lines * size * 1.15
	end
	return w, size * 1.15
end

local measure

local function resolve(ud, pSize, s, own)
	return ud.Scale * pSize * own + ud.Offset * s
end

measure = function(obj, pSize, pScale, ctx, sizeOverride)
	local sc = childOfClass(obj, "UIScale")
	local own = if sc then prop(sc, "Scale") else 1
	local s = pScale * own
	local w, h
	if sizeOverride then
		w, h = sizeOverride.X, sizeOverride.Y
	else
		local sz = prop(obj, "Size")
		w = resolve(sz.X, pSize.X, pScale, own)
		h = resolve(sz.Y, pSize.Y, pScale, own)
		local sc2 = prop(obj, "SizeConstraint")
		if sc2 == Enum.SizeConstraint.RelativeXX then
			h = sz.Y.Scale * pSize.X * own + sz.Y.Offset * s
		elseif sc2 == Enum.SizeConstraint.RelativeYY then
			w = sz.X.Scale * pSize.Y * own + sz.X.Offset * s
		end
	end
	local function constrain()
		local c = childOfClass(obj, "UISizeConstraint")
		if c then
			local mn, mx = prop(c, "MinSize"), prop(c, "MaxSize")
			w = math.clamp(w, mn.X * s, math.max(mn.X * s, mx.X * s))
			h = math.clamp(h, mn.Y * s, math.max(mn.Y * s, mx.Y * s))
		end
		local ar = childOfClass(obj, "UIAspectRatioConstraint")
		if ar then
			local r = prop(ar, "AspectRatio")
			if w / math.max(h, 1e-6) > r then
				w = h * r
			else
				h = w / r
			end
		end
	end
	constrain()
	local pad = childOfClass(obj, "UIPadding")
	local pl, pr, pt, pb = 0, 0, 0, 0
	local function pads()
		if pad then
			pl = resolve(prop(pad, "PaddingLeft"), w, s, 1)
			pr = resolve(prop(pad, "PaddingRight"), w, s, 1)
			pt = resolve(prop(pad, "PaddingTop"), h, s, 1)
			pb = resolve(prop(pad, "PaddingBottom"), h, s, 1)
		end
	end
	pads()
	local isScroll = isA(obj, "ScrollingFrame")
	local content = Vector2.new(math.max(0, w - pl - pr), math.max(0, h - pt - pb))
	local canvas = content
	if isScroll and prop(obj, "AutomaticCanvasSize") == Enum.AutomaticSize.None then
		local cs = prop(obj, "CanvasSize")
		canvas = Vector2.new(math.max(content.X, cs.X.Scale * w + cs.X.Offset * s), math.max(content.Y, cs.Y.Scale * h + cs.Y.Offset * s))
	end
	local list = childOfClass(obj, "UIListLayout")
	local grid = childOfClass(obj, "UIGridLayout")
	local kids = guiChildren(obj, ctx)
	local nodes = {}
	local cellSize = nil
	if grid then
		local cs = prop(grid, "CellSize")
		cellSize = Vector2.new(cs.X.Scale * canvas.X + cs.X.Offset * s, cs.Y.Scale * canvas.Y + cs.Y.Offset * s)
	end
	for i, ch in kids do
		nodes[i] = measure(ch, canvas, s, ctx, if grid then cellSize else nil)
	end
	-- arrange
	local visibleNodes = {}
	for _, n in nodes do
		if n.visible then
			table.insert(visibleNodes, n)
		end
	end
	local extentX, extentY = 0, 0
	local function arrange(cw, ch_)
		if list then
			table.sort(visibleNodes, function(a, b)
				local la, lb = prop(a.obj, "LayoutOrder"), prop(b.obj, "LayoutOrder")
				if la == lb then
					return a.idx < b.idx
				end
				return la < lb
			end)
			local horizontal = prop(list, "FillDirection") == Enum.FillDirection.Horizontal
			local padU = prop(list, "Padding")
			local gap = padU.Scale * (if horizontal then cw else ch_) + padU.Offset * s
			local total = 0
			for i, n in visibleNodes do
				total += if horizontal then n.w else n.h
				if i > 1 then
					total += gap
				end
			end
			local ha, va = prop(list, "HorizontalAlignment"), prop(list, "VerticalAlignment")
			local cursor
			if horizontal then
				cursor = if ha == Enum.HorizontalAlignment.Center then (cw - total) / 2 elseif ha == Enum.HorizontalAlignment.Right then cw - total else 0
			else
				cursor = if va == Enum.VerticalAlignment.Center then (ch_ - total) / 2 elseif va == Enum.VerticalAlignment.Bottom then ch_ - total else 0
			end
			for _, n in visibleNodes do
				if horizontal then
					n.x = cursor
					n.y = if va == Enum.VerticalAlignment.Center then (ch_ - n.h) / 2 elseif va == Enum.VerticalAlignment.Bottom then ch_ - n.h else 0
					cursor += n.w + gap
				else
					n.y = cursor
					n.x = if ha == Enum.HorizontalAlignment.Center then (cw - n.w) / 2 elseif ha == Enum.HorizontalAlignment.Right then cw - n.w else 0
					cursor += n.h + gap
				end
			end
			if horizontal then
				extentX, extentY = math.max(0, total), 0
				for _, n in visibleNodes do
					extentY = math.max(extentY, n.h)
				end
			else
				extentX, extentY = 0, math.max(0, total)
				for _, n in visibleNodes do
					extentX = math.max(extentX, n.w)
				end
			end
		elseif grid then
			table.sort(visibleNodes, function(a, b)
				local la, lb = prop(a.obj, "LayoutOrder"), prop(b.obj, "LayoutOrder")
				if la == lb then
					return a.idx < b.idx
				end
				return la < lb
			end)
			local cp = prop(grid, "CellPadding")
			local gx, gy = cp.X.Scale * cw + cp.X.Offset * s, cp.Y.Scale * ch_ + cp.Y.Offset * s
			local cols = math.max(1, math.floor((cw + gx) / math.max(1, cellSize.X + gx)))
			local maxCells = prop(grid, "FillDirectionMaxCells")
			if maxCells and maxCells > 0 then
				cols = math.min(cols, maxCells)
			end
			local rows = math.ceil(#visibleNodes / cols)
			local ha = prop(grid, "HorizontalAlignment")
			for i, n in visibleNodes do
				local r, c = (i - 1) // cols, (i - 1) % cols
				local inRow = math.min(cols, #visibleNodes - r * cols)
				local rowW = inRow * cellSize.X + (inRow - 1) * gx
				local x0 = if ha == Enum.HorizontalAlignment.Center then (cw - rowW) / 2 elseif ha == Enum.HorizontalAlignment.Right then cw - rowW else 0
				n.x = x0 + c * (cellSize.X + gx)
				n.y = r * (cellSize.Y + gy)
			end
			extentX = math.min(#visibleNodes, cols) * (cellSize.X + gx) - gx
			extentY = rows * (cellSize.Y + gy) - gy
		else
			for _, n in nodes do
				local pos = prop(n.obj, "Position")
				local ap = prop(n.obj, "AnchorPoint")
				n.x = pos.X.Scale * cw + pos.X.Offset * s - ap.X * n.w
				n.y = pos.Y.Scale * ch_ + pos.Y.Offset * s - ap.Y * n.h
				if n.visible then
					extentX = math.max(extentX, n.x + n.w)
					extentY = math.max(extentY, n.y + n.h)
				end
			end
		end
	end
	arrange(canvas.X, canvas.Y)
	-- automatic size
	local auto = prop(obj, "AutomaticSize")
	if auto and auto ~= Enum.AutomaticSize.None then
		local ex, ey = extentX, extentY
		if isA(obj, "TextLabel") or isA(obj, "TextButton") or isA(obj, "TextBox") then
			local tw, th = textExtent(obj, s, if auto == Enum.AutomaticSize.Y then content.X else nil)
			ex, ey = math.max(ex, tw), math.max(ey, th)
		end
		local nw, nh = w, h
		if auto == Enum.AutomaticSize.X or auto == Enum.AutomaticSize.XY then
			nw = math.max(w, ex + pl + pr)
		end
		if auto == Enum.AutomaticSize.Y or auto == Enum.AutomaticSize.XY then
			nh = math.max(h, ey + pt + pb)
		end
		if nw ~= w or nh ~= h then
			w, h = nw, nh
			constrain()
			pads()
			content = Vector2.new(math.max(0, w - pl - pr), math.max(0, h - pt - pb))
			if not isScroll then
				canvas = content
			end
			arrange(canvas.X, canvas.Y)
		end
	end
	if isScroll then
		local acs = prop(obj, "AutomaticCanvasSize")
		if acs ~= Enum.AutomaticSize.None then
			canvas = Vector2.new(
				if acs == Enum.AutomaticSize.X or acs == Enum.AutomaticSize.XY then math.max(content.X, extentX) else content.X,
				if acs == Enum.AutomaticSize.Y or acs == Enum.AutomaticSize.XY then math.max(content.Y, extentY) else content.Y
			)
		end
	end
	for i, n in nodes do
		n.idx = i
	end
	return {
		obj = obj,
		w = w,
		h = h,
		x = 0,
		y = 0,
		pl = pl,
		pt = pt,
		scale = s,
		kids = nodes,
		visible = prop(obj, "Visible") ~= false,
		content = Vector2.new(extentX, extentY),
		canvas = canvas,
		scroll = if isScroll then prop(obj, "CanvasPosition") else nil,
		idx = 0,
	}
end

local function assignAbs(node, ox, oy, out, parentVisible)
	local ax, ay = ox + node.x, oy + node.y
	local vis = parentVisible and node.visible
	out[node.obj] = {
		pos = Vector2.new(math.floor(ax + 0.5), math.floor(ay + 0.5)),
		size = Vector2.new(math.floor(node.w + 0.5), math.floor(node.h + 0.5)),
		content = node.content,
		canvas = node.canvas,
		visible = vis,
		scale = node.scale,
		node = node,
	}
	local cx, cy = ax + node.pl, ay + node.pt
	if node.scroll then
		cx -= node.scroll.X
		cy -= node.scroll.Y
	end
	for _, k in node.kids do
		assignAbs(k, cx, cy, out, vis)
	end
end

local function rootGuiOf(obj)
	local p = obj
	while p do
		if isA(p, "LayerCollector") then
			return p
		end
		p = rawget(p, "_parent")
	end
	return nil
end

local function layoutRoot(gui, ctx)
	local vp = viewportFor(gui)
	local c = layoutCache[gui]
	if c and c.version == M.guiVersion and c.vp == vp then
		return c.out
	end
	local out = {}
	local ox, oy, w, h
	if isA(gui, "ScreenGui") then
		local l, t, r, b = insetsFor(gui, vp)
		ox, oy, w, h = l, t, vp.X - l - r, vp.Y - t - b
	elseif isA(gui, "SurfaceGui") then
		local cs = prop(gui, "CanvasSize")
		ox, oy, w, h = 0, 0, cs.X, cs.Y
	elseif isA(gui, "BillboardGui") then
		local sz = prop(gui, "Size")
		ox, oy, w, h = 0, 0, sz.X.Offset, sz.Y.Offset
	else
		ox, oy, w, h = 0, 0, vp.X, vp.Y
	end
	out[gui] = { pos = Vector2.new(ox, oy), size = Vector2.new(w, h), visible = prop(gui, "Enabled") ~= false }
	local enabled = prop(gui, "Enabled") ~= false
	for _, ch in guiChildren(gui, ctx) do
		local n = measure(ch, Vector2.new(w, h), 1, ctx)
		local pos = prop(ch, "Position")
		local ap = prop(ch, "AnchorPoint")
		n.x = pos.X.Scale * w + pos.X.Offset - ap.X * n.w
		n.y = pos.Y.Scale * h + pos.Y.Offset - ap.Y * n.h
		assignAbs(n, ox, oy, out, enabled)
	end
	layoutCache[gui] = { version = M.guiVersion, vp = vp, out = out }
	return out
end

function M.guiAbs(obj)
	local root = rootGuiOf(obj)
	if not root then
		return { pos = Vector2.new(0, 0), size = Vector2.new(0, 0), visible = false }
	end
	local out = layoutRoot(root, M.cur())
	return out[obj] or { pos = Vector2.new(0, 0), size = Vector2.new(0, 0), visible = false }
end
-- viewport changes must invalidate layouts
M.initHooks.Camera = function(cam) end

------------------------------------------------------------------------------------------ dumps
local function c3(c)
	if not c then
		return nil
	end
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

-- every BasePart under root with class, shape, size, cframe (12 numbers), color, material
function M.dumpParts(root, filter)
	local out = {}
	for _, d in M.descendantsRaw(root, {}) do
		if isA(d, "BasePart") and (not filter or filter(d)) then
			local p = rawget(d, "_p")
			local cf = d.CFrame
			local mesh = childOfClass(d, "SpecialMesh")
			table.insert(out, {
				n = p.Name,
				c = rawget(d, "_class").name,
				sh = if p.Shape then p.Shape.Name else nil,
				mesh = if mesh then mesh.MeshType.Name else nil,
				meshScale = if mesh then { mesh.Scale.X, mesh.Scale.Y, mesh.Scale.Z } else nil,
				s = { d.Size.X, d.Size.Y, d.Size.Z },
				cf = { cf:GetComponents() },
				col = c3(d.Color),
				m = d.Material.Name,
				t = d.Transparency,
				path = M.fullName(d),
			})
		end
	end
	return out
end

-- GUI boxes of one client (as that client sees them), in draw order
function M.dumpUi(ctx)
	local boxes = {}
	local pg = ctx.player:FindFirstChild("PlayerGui")
	local guis = {}
	for _, g in rawget(pg, "_kids") do
		if isA(g, "ScreenGui") and canSee(ctx, g) then
			table.insert(guis, g)
		end
	end
	table.sort(guis, function(a, b)
		return a.DisplayOrder < b.DisplayOrder
	end)
	local function emit(obj, info, clip, depth)
		local p = obj
		local text = nil
		local textColor, textSize = nil, nil
		if isA(obj, "TextLabel") or isA(obj, "TextButton") or isA(obj, "TextBox") then
			text = tostring(obj.Text)
			textColor = c3(obj.TextColor3)
			local ts = obj.TextSize * info.scale
			if obj.TextScaled then
				local maxT = 100
				local con = childOfClass(obj, "UITextSizeConstraint")
				if con then
					maxT = con.MaxTextSize
				end
				local fit = math.min(info.size.Y * 0.8, info.size.X / math.max(1, #text) / 0.55)
				ts = math.min(fit, maxT * info.scale)
			end
			textSize = math.floor(ts + 0.5)
			if obj.TextTransparency >= 1 then
				text = nil
			end
		end
		local stroke = childOfClass(obj, "UIStroke")
		local corner = childOfClass(obj, "UICorner")
		local grad = childOfClass(obj, "UIGradient")
		local cr = 0
		if corner then
			local u = corner.CornerRadius
			cr = u.Scale * math.min(info.size.X, info.size.Y) + u.Offset * info.scale
		end
		table.insert(boxes, {
			name = rawget(obj, "_p").Name,
			cls = rawget(obj, "_class").name,
			x = info.pos.X,
			y = info.pos.Y,
			w = info.size.X,
			h = info.size.Y,
			bg = c3(obj.BackgroundColor3),
			bgt = obj.BackgroundTransparency,
			text = text,
			tc = textColor,
			ts = textSize,
			scaled = (isA(obj, "TextLabel") or isA(obj, "TextButton") or isA(obj, "TextBox")) and obj.TextScaled or nil,
			stroke = if stroke and stroke.Enabled and stroke.Transparency < 1 then { c = c3(stroke.Color), w = stroke.Thickness * info.scale, border = stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Border } else nil,
			cr = cr,
			grad = grad ~= nil,
			clip = clip,
			img = if isA(obj, "ImageLabel") or isA(obj, "ImageButton") then obj.Image else nil,
			depth = depth,
		})
	end
	local function walk(obj, out, clip, depth)
		local kids = guiChildren(obj, ctx)
		-- Sibling z order: ZIndex then tree order
		for i, k in kids do
			rawset(k, "_zi", i)
		end
		table.sort(kids, function(a, b)
			if a.ZIndex == b.ZIndex then
				return rawget(a, "_zi") < rawget(b, "_zi")
			end
			return a.ZIndex < b.ZIndex
		end)
		for _, k in kids do
			local info = out[k]
			if info and info.visible then
				emit(k, info, clip, depth)
				local c2 = clip
				if k.ClipsDescendants or isA(k, "ScrollingFrame") then
					local r = { info.pos.X, info.pos.Y, info.pos.X + info.size.X, info.pos.Y + info.size.Y }
					if clip then
						r = { math.max(r[1], clip[1]), math.max(r[2], clip[2]), math.min(r[3], clip[3]), math.min(r[4], clip[4]) }
					end
					c2 = r
				end
				walk(k, out, c2, depth + 1)
			end
		end
	end
	for _, g in guis do
		if g.Enabled then
			local out = layoutRoot(g, ctx)
			table.insert(boxes, { gui = rawget(g, "_p").Name, order = g.DisplayOrder })
			walk(g, out, nil, 0)
		end
	end
	return boxes
end

------------------------------------------------------------------------------------------ H API
local H = {}
M.H = H
H.M = M
H.passed = 0
H.failed = 0
H.results = {}
H.Vector3 = M.Vector3
H.Vector2 = Vector2
H.CFrame = M.CFrame

local out = M.realPrint
function H.log(...)
	local parts = table.pack(...)
	for i = 1, parts.n do
		parts[i] = tostring(parts[i])
	end
	out(table.concat(parts, " ", 1, parts.n))
end
function H.section(name)
	out("")
	out("== " .. name .. string.format(" (sim t=%.1fs)", M.clock))
end
function H.check(name, cond, observed)
	local line = (if cond then "PASS " else "FAIL ") .. name
	if observed ~= nil then
		line ..= "  [" .. (if type(observed) == "string" then observed else json(observed)) .. "]"
	end
	out(line)
	if cond then
		H.passed += 1
	else
		H.failed += 1
	end
	table.insert(H.results, { name = name, ok = cond and true or false, observed = observed })
	return cond
end
function H.note(name, observed)
	out("NOTE " .. name .. (if observed ~= nil then "  [" .. (if type(observed) == "string" then observed else json(observed)) .. "]" else ""))
end
H.json = json
function H.emitFile(name, content)
	out("@@FILE " .. name)
	out(content)
	out("@@END")
end
function H.wait(seconds, dt)
	M.advance(seconds, dt)
end
function H.now()
	return M.clock
end
-- advance until fn() is truthy (checked every frame); returns the value or nil on timeout
function H.waitUntil(fn, timeout, dt)
	local deadline = M.clock + (timeout or 10)
	while M.clock < deadline do
		local v = fn()
		if v then
			return v
		end
		M.frame(dt)
	end
	return fn()
end

function H.boot()
	math.randomseed(20261001)
	M.buildDataModel()
	local n = M.startServer()
	M.advance(0.2)
	return n
end

function H.service(name)
	return game:GetService(name)
end
function H.game()
	return game
end

local function pathFind(root, path)
	local cur_ = root
	for seg in string.gmatch(path, "[^%.]+") do
		local nxt = nil
		for _, ch in rawget(cur_, "_kids") do
			if rawget(ch, "_p").Name == seg then
				nxt = ch
				break
			end
		end
		if not nxt then
			error("path not found: " .. path .. " (at " .. seg .. ")", 2)
		end
		cur_ = nxt
	end
	return cur_
end
H.pathFind = pathFind

-- server-side module (same table the server's scripts got)
function H.serverRequire(path)
	return M.requireIn(M.serverCtx, pathFind(game, path))
end

-- run fn in a context thread; advance the simulation until it finishes (max timeout s)
function H.runIn(ctx, fn, timeout)
	local done, res = false, nil
	local err = nil
	M.spawnIn(ctx, function()
		local r = table.pack(pcall(fn))
		if r[1] then
			res = r
		else
			err = r[2]
		end
		done = true
	end)
	local deadline = M.clock + (timeout or 10)
	while not done and M.clock < deadline do
		M.frame()
	end
	if not done then
		error("runIn timed out after " .. tostring(timeout or 10) .. "s", 2)
	end
	if err then
		error(err, 2)
	end
	return table.unpack(res, 2, res.n)
end
function H.asServer(fn, timeout)
	return H.runIn(M.serverCtx, fn, timeout)
end

-- count instances under root (raw, all owners)
function H.countDescendants(root, pred)
	local n = 0
	for _, d in M.descendantsRaw(root, {}) do
		if not pred or pred(d) then
			n += 1
		end
	end
	return n
end

------------------------------------------------------------------------------------------ clients
local Client = {}
Client.__index = Client

function H.join(name, opts)
	local p, ctx = M.addPlayer(name, opts)
	local c = setmetatable({ player = p, ctx = ctx, name = name }, Client)
	return c
end
function H.leave(c)
	M.removePlayer(c.player)
end

function Client:run(fn, timeout)
	return H.runIn(self.ctx, fn, timeout)
end
-- the module instance this client required (or requires now) at a path under PlayerScripts
-- ("Client.Store") or anywhere in the DataModel ("ReplicatedStorage.Shared.Logic.Tutorial")
function Client:require(path)
	local root = self.player
	local first = string.match(path, "^[^%.]+")
	if first == "ReplicatedStorage" or first == "StarterPlayer" or first == "Workspace" then
		root = game
	else
		root = pathFind(self.player, "PlayerScripts")
	end
	local inst = pathFind(root, path)
	return H.runIn(self.ctx, function()
		return M.requireIn(self.ctx, inst)
	end)
end
-- pre-load a module in this client's cache so the scenario can hook it before Main.client runs
function Client:hook(path, fn)
	local root = pathFind(self.player, "PlayerScripts")
	local inst = pathFind(root, path)
	M.spawnIn(self.ctx, function()
		fn(M.requireIn(self.ctx, inst))
	end)
end
function Client:playerGui()
	return self.player:FindFirstChild("PlayerGui")
end
-- find a GUI object by name under PlayerGui (as the client sees it); optional class filter
function Client:findGui(name, class, under)
	local root = under or self:playerGui()
	for _, d in M.descendantsRaw(root, {}) do
		if rawget(d, "_p").Name == name and canSee(self.ctx, d) and (not class or isA(d, class)) then
			return d
		end
	end
	return nil
end
function Client:findAllGui(pred, under)
	local res = {}
	for _, d in M.descendantsRaw(under or self:playerGui(), {}) do
		if canSee(self.ctx, d) and pred(d) then
			table.insert(res, d)
		end
	end
	return res
end
-- effective visibility: object + GUI ancestors Visible, ScreenGui Enabled, under PlayerGui
function Client:isShown(obj)
	local res = false
	M.spawnIn(self.ctx, function()
		local cur_ = obj
		while cur_ do
			if isA(cur_, "GuiObject") then
				if not cur_.Visible then
					return
				end
			elseif isA(cur_, "LayerCollector") then
				if not cur_.Enabled then
					return
				end
			elseif isA(cur_, "PlayerGui") then
				res = rawget(cur_, "_parent") == self.player
				return
			end
			cur_ = rawget(cur_, "_parent")
		end
	end)
	return res
end
-- a tap: Down, Up, Activated, Click (as the engine fires them), in the client's context
function Client:click(btn, opts)
	opts = opts or {}
	if not opts.force and not self:isShown(btn) then
		return false, "not visible"
	end
	if not opts.force then
		-- something modal above? a full-screen visible Modal button on a higher layer sinks taps
		local blocked = nil
		M.spawnIn(self.ctx, function()
			local myGui = rootGuiOf(btn)
			for _, g in self:playerGui():GetChildren() do
				if g ~= myGui and isA(g, "ScreenGui") and g.Enabled and g.DisplayOrder > myGui.DisplayOrder then
					for _, d in g:GetDescendants() do
						if isA(d, "GuiButton") and self:isShown(d) and d.Modal and d.Active then
							local a = M.guiAbs(d)
							local b = M.guiAbs(btn)
							local cx, cy = b.pos.X + b.size.X / 2, b.pos.Y + b.size.Y / 2
							if cx >= a.pos.X and cx <= a.pos.X + a.size.X and cy >= a.pos.Y and cy <= a.pos.Y + a.size.Y then
								blocked = M.fullName(d)
							end
						end
					end
				end
			end
		end)
		if blocked then
			return false, "covered by " .. blocked
		end
	end
	local ctx = self.ctx
	local function fire(ev, ...)
		local s = M.peekSignal(btn, ev)
		if s then
			SignalApi.FireFor(s, function(c)
				return c == ctx
			end, ...)
		end
	end
	local input = { UserInputType = if ctx.opts.touch then Enum.UserInputType.Touch else Enum.UserInputType.MouseButton1, UserInputState = Enum.UserInputState.Begin, KeyCode = Enum.KeyCode.Unknown, Position = V(0, 0, 0) }
	fire("InputBegan", input)
	fire("MouseButton1Down", 0, 0)
	if opts.hold then
		M.advance(opts.hold)
	end
	fire("MouseButton1Up", 0, 0)
	local endInput = table.clone(input)
	endInput.UserInputState = Enum.UserInputState.End
	fire("InputEnded", endInput)
	fire("Activated", input, 1)
	fire("MouseButton1Click")
	M.runDeferred()
	return true
end
-- press a key bound through ContextActionService
function Client:key(keyCode, state)
	local acts = M.actions[self.ctx] or {}
	local hit = 0
	for name, a in acts do
		if table.find(a.keys, keyCode) then
			hit += 1
			M.spawnIn(self.ctx, a.fn, name, state or Enum.UserInputState.Begin, { KeyCode = keyCode, UserInputState = state or Enum.UserInputState.Begin })
		end
	end
	return hit
end
function Client:character()
	return rawget(self.player, "_p").Character
end
function Client:root()
	local ch = self:character()
	return ch and ch:FindFirstChild("HumanoidRootPart")
end
function Client:teleport(pos)
	local ch = self:character()
	assert(ch, "no character")
	M.walkers[ch] = nil
	M.placeCharacter(ch, M.CFrame.new(pos))
end
-- walk at Humanoid.WalkSpeed in a straight line (no physics or collisions)
function Client:walkTo(pos, timeout)
	local ch = self:character()
	assert(ch, "no character")
	local hum = ch:FindFirstChildOfClass("Humanoid")
	M.walkers[ch] = { target = pos, hum = hum }
	H.waitUntil(function()
		return M.walkers[ch] == nil
	end, timeout or 60)
	return M.walkers[ch] == nil
end
-- trigger a ProximityPrompt as this player (engine-side: checks enabled + distance)
-- opts.force skips the client-side Enabled checks (simulates an exploiter firing the trigger)
function Client:triggerPrompt(prompt, opts)
	opts = opts or {}
	local enabled, serviceOn = false, true
	M.spawnIn(self.ctx, function()
		enabled = prompt.Enabled
		serviceOn = game:GetService("ProximityPromptService").Enabled
	end)
	if not opts.force and (not enabled or not serviceOn) then
		return false, "prompt disabled for this client"
	end
	local root = self:root()
	local parent = rawget(prompt, "_parent")
	local pos = parent and (if isA(parent, "BasePart") then parent.Position elseif isA(parent, "Attachment") then parent.WorldPosition else nil)
	if not opts.force and root and pos and (root.Position - pos).Magnitude > prompt.MaxActivationDistance + 0.01 then
		return false, string.format("too far (%.1f > %.1f)", (root.Position - pos).Magnitude, prompt.MaxActivationDistance)
	end
	local pps = game:GetService("ProximityPromptService")
	local me = self.ctx
	local function forMe(c)
		return c.kind ~= "client" or c == me
	end
	local trig = M.peekSignal(prompt, "Triggered")
	M.enqueue(function()
		if trig then
			SignalApi.FireFor(trig, forMe, self.player)
		end
		SignalApi.FireFor(getSignal(pps, "PromptTriggered"), forMe, prompt, self.player)
	end)
	M.advance(0.1)
	return true
end
function Client:setViewport(v)
	self.ctx.camera.ViewportSize = v
	-- property write from the harness: fire the client's listeners
	M.guiVersion += 1
end
function Client:dumpUi()
	local res
	M.spawnIn(self.ctx, function()
		res = M.dumpUi(self.ctx)
	end)
	return res
end

------------------------------------------------------------------------------------------ report
function H.finish()
	out("")
	out("== mock diagnostics")
	local nErr = #M.errors
	out(string.format("runtime errors in game threads: %d", nErr))
	local seen = {}
	for _, e in M.errors do
		local key = string.match(e.msg, "^[^\n]*")
		if not seen[key] then
			seen[key] = true
			out("  ERROR " .. e.ctx .. ": " .. key)
		end
	end
	out(string.format("warnings: %d", #M.warnings))
	local wseen = {}
	for _, w in M.warnings do
		local key = w.ctx .. ": " .. w.msg
		if not wseen[key] then
			wseen[key] = 0
		end
		wseen[key] += 1
	end
	for k, n in wseen do
		out(string.format("  WARN x%d %s", n, k))
	end
	local unk = {}
	for k, n in M.unknownWrites do
		table.insert(unk, k)
	end
	table.sort(unk)
	if #unk > 0 then
		out("properties written that the mock does not model (check for typos): " .. table.concat(unk, ", "))
	end
	if #M.typeErrors > 0 then
		out("property type errors: " .. table.concat(M.typeErrors, "; "))
	end
	local nw = {}
	for k, n in M.netWarnings do
		table.insert(nw, string.format("%s (x%d)", k, n))
	end
	table.sort(nw)
	if #nw > 0 then
		out("network serialization warnings: " .. table.concat(nw, "; "))
	end
	out(string.format("RESULT %d passed, %d failed, %d runtime errors", H.passed, H.failed, nErr))
end
