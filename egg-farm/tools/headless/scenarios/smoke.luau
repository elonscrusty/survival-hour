local n = H.boot()
local a = H.join("Alice")
local s = Lib.waitSnap(a)
H.check("snapshot", type(s) == "table", s and { cash = s.cash, step = s.tutorial.step, pop = s.population })
local plot, idx = Lib.plotOf(a)
H.check("plot", plot ~= nil, idx)
local root = a:root()
H.check("character", root ~= nil, root and tostring(root.Position))
local guis = {}
for _, g in a:playerGui():GetChildren() do table.insert(guis, g.Name) end
H.log(table.concat(guis, ","))
H.log("parts in workspace", H.countDescendants(workspace, function(d) return d:IsA("BasePart") end))
H.wait(3)
