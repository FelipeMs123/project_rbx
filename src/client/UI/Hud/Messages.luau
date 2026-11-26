--!strict
-- StarterPlayerScripts.Client.UI.Hud.Messages | Dono: Squad A. Avisos em português.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AreasConfig = require(ReplicatedStorage.Shared.Config.Areas)
local FusionConfig = require(ReplicatedStorage.Shared.Config.Fusion)

local Messages = {}
Messages.codes = table.freeze({
	INVALID_ARGS = "Invalid request.",
	RATE_LIMITED = "Wait a moment.",
	DATA_NOT_LOADED = "Your data is loading.",
	INTERNAL = "Something went wrong. Try again.",
	NOT_ENOUGH_COINS = "Not enough coins.",
	NOT_ENOUGH_GEMS = "Not enough gems.",
	NOT_OWNED = "This pet is not yours.",
	ALREADY_EQUIPPED = "Pet already equipped.",
	NOT_EQUIPPED = "This pet is not equipped.",
	MAX_EQUIPPED = "Maximum pets equipped.",
	INVENTORY_FULL = "Inventory full.",
	AREA_LOCKED = "Unlock the previous area first.",
	AREA_NOT_UNLOCKED = "Buy this area at the gate to enter.",
	DAILY_NOT_READY = "Come back tomorrow for more!",
	FUSE_INVALID = "Choose " .. FusionConfig.RequiredCount .. " matching unequipped pets.",
	PURCHASE_FAILED = "Purchase was not completed.",
	ALREADY_UNLOCKED = "Area already unlocked.",
	UNKNOWN_ITEM = "Item not found.",
	TOO_FAR = "Get closer.",
	NOT_IMPLEMENTED = "Coming soon.",
} :: { [string]: string })
function Messages.message(code: any, payload: any?): string
	if code == "AREA_NOT_UNLOCKED" and type(payload) == "table" and type(payload.areaId) == "string" then
		local area = AreasConfig[payload.areaId]
		if area then
			return "Buy " .. area.Name .. " at the gate to enter."
		end
	end
	return if type(code) == "string" then Messages.codes[code] or Messages.codes.INTERNAL else Messages.codes.INTERNAL
end
return Messages
