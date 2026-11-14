--!strict
-- EconomyService.luau (ServerScriptService.Server.Services.EconomyService)
-- Dono: Squad A. Moedas, gemas, rebirth e desbloqueio de áreas.
-- ESTADO: stub da fundação. Implementação = tarefa A2 (docs/ROADMAP.md).
-- A API pública abaixo é CONTRATO: outros Services só usam estas funções para mexer em dinheiro.

local EconomyService = {}

-- Soma moedas (já aplica o bônus de rebirth). Devolve o valor realmente creditado.
function EconomyService.AddCoins(_player: Player, _amount: number): number
	error("EconomyService.AddCoins: não implementado (tarefa A2)")
end

function EconomyService.AddGems(_player: Player, _amount: number): number
	error("EconomyService.AddGems: não implementado (tarefa A2)")
end

-- Tenta gastar. Devolve true se tinha saldo e descontou.
function EconomyService.Spend(_player: Player, _currency: "Coins" | "Gems", _amount: number): boolean
	error("EconomyService.Spend: não implementado (tarefa A2)")
end

function EconomyService.HasArea(_player: Player, _areaId: string): boolean
	return true -- stub: tudo liberado até A2
end

function EconomyService.Init() end

function EconomyService.Start() end

return EconomyService
