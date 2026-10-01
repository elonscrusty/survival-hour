--!strict
-- SIMULATED checkout used only by the test place (and unit tests). It never contacts Roblox,
-- never opens a paid purchase prompt and never spends Robux. Purchase ids are prefixed "TEST-"
-- and the test place saves to memory only, so simulated entitlements can't reach real profiles.
--   mode "success" -> grants through the same Economy.GrantProduct path real receipts use
--   mode "cancel"  -> nothing granted ("cancelled")
--   mode "fail"    -> nothing granted ("failed")

local TestCheckout = {}
TestCheckout.Kind = "test"

export type Checkout = {
	mode: string,
	products: { ById: { [string]: any } },
	counter: number,
	Buy: (self: Checkout, productId: string, grant: (productId: string, purchaseId: string) -> (boolean, string)) -> { ok: boolean, code: string, message: string? },
}

local function buy(self: Checkout, productId: string, grant: (string, string) -> (boolean, string))
	local p = self.products.ById[productId]
	if not p or p.kind == "gold" then
		return { ok = false, code = "invalid", message = "That item isn't sold for Robux." }
	end
	if self.mode == "cancel" then
		return { ok = false, code = "cancelled", message = "(Test) Purchase cancelled." }
	elseif self.mode == "fail" then
		return { ok = false, code = "failed", message = "(Test) Purchase failed. Nothing was charged." }
	end
	self.counter += 1
	local ok, code = grant(productId, string.format("TEST-%s-%d", productId, self.counter))
	if not ok then
		return { ok = false, code = code, message = "That purchase could not be completed." }
	end
	return { ok = true, code = "ok", message = "(Test) Purchased " .. p.name .. "!" }
end

-- `products` is shared/Data/Products (passed in so this module has no cross-service requires).
function TestCheckout.new(products: any, mode: string?): Checkout
	return { mode = mode or "success", products = products, counter = 0, Buy = buy }
end

return TestCheckout
