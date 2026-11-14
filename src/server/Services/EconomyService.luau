--!strict
-- EconomyService.luau (ServerScriptService.Server.Services.EconomyService)
-- Dono: fundação. Única porta para mexer em moedas e gemas e para checar áreas liberadas.
-- As duas squads usam: Squad A credita moedas dos blocos, Squad B cobra ovos e rebirth.
-- Não tem remote: o cliente nunca mexe em dinheiro direto.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.Game)
local Economy = require(Shared.Logic.Economy)
local DataService = require(script.Parent.DataService)

export type Currency = "Coins" | "Gems"

local EconomyService = {}

-- Soma moedas já com o bônus de rebirth. Devolve o valor creditado (0 se não deu).
function EconomyService.AddCoins(player: Player, amount: number): number
	local data = DataService.Get(player)
	if data == nil or not Economy.isValidAmount(amount) then
		return 0
	end
	local credited = Economy.applyCoinBonus(amount, data.Rebirths, GameConfig.RebirthCoinBonus)
	if credited <= 0 then
		return 0
	end
	DataService.Update(player, "Coins", function(coins: number)
		return coins + credited
	end)
	return credited
end

-- Soma gemas (sem bônus). Devolve o valor creditado (0 se não deu).
function EconomyService.AddGems(player: Player, amount: number): number
	if DataService.Get(player) == nil or not Economy.isValidAmount(amount) then
		return 0
	end
	local credited = math.floor(amount)
	if credited <= 0 then
		return 0
	end
	DataService.Update(player, "Gems", function(gems: number)
		return gems + credited
	end)
	return credited
end

-- Tenta gastar. Devolve true se tinha saldo e descontou.
-- Checagem e desconto acontecem sem yield no meio, então dois pedidos simultâneos não gastam o mesmo saldo.
function EconomyService.Spend(player: Player, currency: Currency, amount: number): boolean
	local data = DataService.Get(player)
	if data == nil or not Economy.isValidAmount(amount) then
		return false
	end
	if currency ~= "Coins" and currency ~= "Gems" then
		return false
	end
	local balance: number = (data :: any)[currency]
	if balance < amount then
		return false
	end
	DataService.Update(player, currency, function(current: number)
		return current - amount
	end)
	return true
end

-- Saldo atual (0 se os dados não carregaram).
function EconomyService.GetBalance(player: Player, currency: Currency): number
	local data = DataService.Get(player)
	return if data then (data :: any)[currency] or 0 else 0
end

function EconomyService.HasArea(player: Player, areaId: string): boolean
	local data = DataService.Get(player)
	return data ~= nil and table.find(data.UnlockedAreas, areaId) ~= nil
end

function EconomyService.Init() end

function EconomyService.Start() end

return EconomyService
