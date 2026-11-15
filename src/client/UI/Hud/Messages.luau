--!strict
-- StarterPlayerScripts.Client.UI.Hud.Messages | Dono: Squad A. Avisos em português.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AreasConfig = require(ReplicatedStorage.Shared.Config.Areas)
local FusionConfig = require(ReplicatedStorage.Shared.Config.Fusion)

local Messages = {}
Messages.codes = table.freeze({
	INVALID_ARGS = "Pedido inválido.",
	RATE_LIMITED = "Espere um instante.",
	DATA_NOT_LOADED = "Seus dados estão carregando.",
	INTERNAL = "Algo deu errado. Tente de novo.",
	NOT_ENOUGH_COINS = "Moedas insuficientes.",
	NOT_ENOUGH_GEMS = "Gemas insuficientes.",
	NOT_OWNED = "Esse pet não é seu.",
	ALREADY_EQUIPPED = "Pet já equipado.",
	NOT_EQUIPPED = "Esse pet não está equipado.",
	MAX_EQUIPPED = "Limite de pets equipados.",
	INVENTORY_FULL = "Inventário cheio.",
	AREA_LOCKED = "Libere a área anterior primeiro.",
	AREA_NOT_UNLOCKED = "Compre esta área no portão para entrar.",
	DAILY_NOT_READY = "Volte amanhã para pegar mais!",
	FUSE_INVALID = "Escolha " .. FusionConfig.RequiredCount .. " pets iguais e não equipados.",
	PURCHASE_FAILED = "A compra não foi concluída.",
	ALREADY_UNLOCKED = "Área já liberada.",
	UNKNOWN_ITEM = "Item não encontrado.",
	TOO_FAR = "Chegue mais perto.",
	NOT_IMPLEMENTED = "Disponível em breve.",
} :: { [string]: string })
function Messages.message(code: any, payload: any?): string
	if code == "AREA_NOT_UNLOCKED" and type(payload) == "table" and type(payload.areaId) == "string" then
		local area = AreasConfig[payload.areaId]
		if area then
			return "Compre " .. area.Name .. " no portão para entrar."
		end
	end
	return if type(code) == "string" then Messages.codes[code] or Messages.codes.INTERNAL else Messages.codes.INTERNAL
end
return Messages
