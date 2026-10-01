--!strict
-- A Button bound to Logic/PurchaseState. Every Refresh(snapshot) recomputes the state from the
-- live price and balance, so the look is never stale:
--   affordable (green, price) | unaffordable (grey, red price) | owned (OWNED) | max (MAX, gold)
--   locked (LOCKED, dark) | loading ("...", while the request is in flight) | rejected (red +
--   shake + toast with the server's message, then back to the live state).
-- Taps that can't succeed (unaffordable, locked, max) never reach the server: they show the
-- reason locally. Requests go through Store.Request, which also dedupes by key.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PurchaseState = require(Shared:WaitForChild("Logic"):WaitForChild("PurchaseState"))
local Contract = require(Shared:WaitForChild("Contract"))
local Format = require(Shared:WaitForChild("Format"))

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Button = require(script.Parent.Button)
local Num = require(script.Parent.Num)

local PurchaseButton = {}

export type Result = { ok: boolean, code: string, message: string? }

export type Opts = {
	host: any, -- Menus/Host (Toast, Confirm, Sound, Store)
	parent: Instance?,
	size: UDim2?,
	position: UDim2?,
	anchor: Vector2?,
	order: number?,
	textSize: number?,
	currency: string?, -- "cash" | "gold" | "robux" | "free"
	verb: string?, -- caption when the price is free (CLAIM, USE, ...)
	-- returns price (nil = can't buy), reason code, owned flag
	quote: (snap: any) -> (number?, string?, boolean?),
	-- performs the request (yields) and returns the server result
	send: (snap: any) -> Result,
	-- optional confirmation; return nil to skip
	confirm: ((snap: any) -> any?)?,
	onResult: ((Result) -> ())?,
	successSound: string?,
	quiet: boolean?, -- no success toast
}

export type Handle = {
	Button: Button.Handle,
	Instance: TextButton,
	State: string,
	Refresh: (Handle, any) -> (),
	SetVisible: (Handle, boolean) -> (),
}

local function balanceOf(snap: any, currency: string): number
	if currency == "gold" then
		return snap.gold or 0
	end
	return snap.cash or 0
end

local function priceText(price: number, currency: string): string
	if currency == "gold" then
		return Num.Short(price)
	elseif currency == "robux" then
		return "R$ " .. Format.Commas(price)
	end
	return Num.Cash(price)
end

function PurchaseButton.new(o: Opts): Handle
	local currency = o.currency or "cash"
	local busy = false
	local lastRejectAt: number? = nil
	local h: any = { State = "unavailable" }

	local btn = Button.new({
		text = "",
		icon = if currency == "gold" then "gold" elseif currency == "cash" then "cash" else nil,
		iconSize = 30,
		color = Theme.Color.Green,
		size = o.size or UDim2.fromOffset(160, 60),
		position = o.position,
		anchor = o.anchor,
		order = o.order,
		textSize = o.textSize or Theme.Text.M,
		parent = o.parent,
	})
	h.Button = btn
	h.Instance = btn.Instance

	local function paint(state: string, price: number?)
		h.State = state
		local caption = PurchaseState.Caption(state)
		local text: string
		if caption then
			text = caption
		elseif price and price > 0 then
			text = priceText(price, currency)
		else
			text = o.verb or "FREE"
		end
		btn:SetText(text)
		if btn.Icon then
			btn.Icon.Visible = caption == nil and price ~= nil and price > 0
		end
		local color = Theme.Color.Green
		local textColor = Theme.Color.Text
		if state == "unaffordable" then
			color = Theme.Color.Gray
			textColor = Theme.Color.Bad
		elseif state == "owned" then
			color = Theme.Color.GreenDark
		elseif state == "max" then
			color = Theme.Color.Gold
		elseif state == "locked" or state == "unavailable" then
			color = Theme.Color.GrayDark
		elseif state == "rejected" then
			color = Theme.Color.Red
		elseif state == "loading" then
			color = Theme.Color.Gray
		elseif currency == "robux" then
			color = Theme.Color.Blue
		elseif currency == "gold" then
			color = Theme.Color.Orange
		end
		btn:SetColor(color)
		btn.Label.TextColor3 = textColor
		btn:SetEnabled(state == "affordable")
	end

	local function compute(snap: any): (PurchaseState.Output, number?)
		if not snap then
			return { state = "loading", canRequest = false, code = nil }, nil
		end
		local price, reason, owned = o.quote(snap)
		local out = PurchaseState.Compute({
			price = price,
			reason = reason,
			balance = balanceOf(snap, currency),
			currency = currency,
			owned = owned,
			busy = busy,
			lastRejectAt = lastRejectAt,
			now = os.clock(),
		})
		return out, price
	end

	function h.Refresh(self: Handle, snap: any)
		local out, price = compute(snap)
		paint(out.state, price)
	end

	function h.SetVisible(self: Handle, on: boolean)
		btn:SetVisible(on)
	end

	local function reject(message: string?)
		lastRejectAt = os.clock()
		o.host:Sound("error")
		Util.Shake(btn.Instance)
		if message then
			o.host:Toast(message, "bad")
		end
		h:Refresh(o.host.Store.Get())
		task.delay(PurchaseState.REJECT_SHOW + 0.05, function()
			h:Refresh(o.host.Store.Get())
		end)
	end

	local function run(snap: any)
		busy = true
		h:Refresh(snap)
		local ok, res = pcall(o.send, snap)
		busy = false
		local result: Result = if ok and type(res) == "table"
			then res
			else { ok = false, code = "error", message = "Something went wrong. Try again." }
		if result.ok then
			o.host:Sound(o.successSound or "buy")
			Util.Pop(btn.Instance, 0.1)
			h:Refresh(o.host.Store.Get())
		elseif PurchaseState.IsRejection(result) then
			reject(result.message or Contract.Messages[result.code] or "That didn't work.")
		else
			h:Refresh(o.host.Store.Get())
		end
		if o.onResult then
			o.onResult(result)
		end
	end

	btn.Instance.Activated:Connect(function()
		local snap = o.host.Store.Get()
		local out = compute(snap)
		if out.state == "loading" or out.state == "rejected" then
			return
		end
		if not out.canRequest then
			reject(if out.code then Contract.Messages[out.code] else nil)
			return
		end
		local confirmOpts = if o.confirm then o.confirm(snap) else nil
		if confirmOpts then
			o.host:Confirm(confirmOpts, function()
				local now = o.host.Store.Get()
				local again = compute(now)
				if again.canRequest then
					task.spawn(run, now)
				else
					reject(if again.code then Contract.Messages[again.code] else nil)
				end
			end)
		else
			task.spawn(run, snap)
		end
	end)

	h:Refresh(o.host.Store.Get())
	return h :: Handle
end

return PurchaseButton
