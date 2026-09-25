--!strict
-- Store layouts. Builder is the name of a module in ServerScriptService.Server that has
-- Build() -> Model and SetupLighting(). Only one store exists at a time.
local Stores = {
	QuikStop = { DisplayName = "QUIK STOP", Builder = "StoreBuilder" },
}

return Stores
