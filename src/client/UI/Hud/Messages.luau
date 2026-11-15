--!strict
-- StarterPlayerScripts.Client.UI.Hud.Messages | Dono: Squad A. Avisos em português.
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
	ALREADY_UNLOCKED = "Área já liberada.",
	UNKNOWN_ITEM = "Item não encontrado.",
	TOO_FAR = "Chegue mais perto.",
	NOT_IMPLEMENTED = "Disponível em breve.",
} :: { [string]: string })
function Messages.message(code: any): string
	return if type(code) == "string" then Messages.codes[code] or Messages.codes.INTERNAL else Messages.codes.INTERNAL
end
return Messages
