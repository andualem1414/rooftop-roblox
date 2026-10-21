--!strict
-- Every piece of furniture in the tower, by name (Kit.Prop says what one is). They're built from parts in
-- their own frame and double as cover: the pieces with bulk stop bullets (Kit's "cover"), the body of each
-- collides, and the trims, screens and ornaments are only for show.
--   PropsHome  the lobby, offices, library, hotel, penthouse and art studio
--   PropsWork  the car park, warehouse, server room, boiler room, lab, building site, archive, machine room
--   PropsFun   the laundrette, gym, canteen, greenhouse, arcade and nightclub
local Kit = require(script.Parent.Kit)

local Props: { [string]: Kit.Prop } = {}

for _, group in { require(script.Parent.PropsHome), require(script.Parent.PropsWork), require(script.Parent.PropsFun) } do
	for name, prop in group do
		assert(Props[name] == nil, `two props are called {name}`)
		Props[name] = prop
	end
end

-- a loose crate you can shove (the tower builder makes these itself)
Props.crate = {
	w = 3.6,
	d = 3.6,
	h = 2.85,
	kind = "crate",
	wall = false,
	build = function() end,
}

return Props
