--!strict
-- The game's type, in one place. Three faces instead of one chunky pixel font everywhere:
--   Title  big headings, banners, the catch / fired screens (typewriter: store memo, police report)
--   Body   buttons, lists, descriptions (clean and easy to read at any size)
--   Mono   HUD numbers and the bodycam readout (fixed width, so counters don't jitter)
--   Sign   in-world store signs (condensed, like printed signage)
local function family(name: string, weight: Enum.FontWeight?): Font
	return Font.new("rbxasset://fonts/families/" .. name .. ".json", weight or Enum.FontWeight.Regular)
end

local Fonts = {
	Title = family("SpecialElite"),
	Body = family("GothamSSm", Enum.FontWeight.Medium),
	Bold = family("GothamSSm", Enum.FontWeight.Bold),
	Mono = family("RobotoMono", Enum.FontWeight.Medium),
	Sign = family("Oswald", Enum.FontWeight.Bold),
}

return Fonts
