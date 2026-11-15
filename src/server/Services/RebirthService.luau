--!strict
-- RebirthService.luau (ServerScriptService.Server.Services.RebirthService)
-- Dono: Squad B. Rebirth (remote RequestRebirth).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.Game)
local ErrorCodes = require(Shared.ErrorCodes)
local Rebirth = require(Shared.Logic.Rebirth)
local RequestIdempotency = require(Shared.Logic.RequestIdempotency)
local Types = require(Shared.Types)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local REQUEST_REBIRTH_RATE = 2
local REQUEST_REBIRTH_BURST = 3
local MAX_CACHED_RESULTS = 100

local rebirthIdempotency = RequestIdempotency.new(MAX_CACHED_RESULTS)
local playerRemovingConnected = false

local RebirthService = {}

local function executeRequestRebirth(player: Player): Types.Result
	if player.Parent ~= Players or not DataService.IsLoaded(player) then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end
	local data = DataService.Get(player)
	if data == nil then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end

	local cost = Rebirth.cost(data.Rebirths, GameConfig.RebirthBaseCost, GameConfig.RebirthCostGrowth)
	local canRebirth, errCode =
		Rebirth.canRebirth(data.Coins, data.Rebirths, GameConfig.RebirthBaseCost, GameConfig.RebirthCostGrowth)
	if not canRebirth then
		return { ok = false, err = errCode or ErrorCodes.NOT_ENOUGH_COINS }
	end

	if cost > 0 and not EconomyService.Spend(player, "Coins", cost) then
		return { ok = false, err = ErrorCodes.NOT_ENOUGH_COINS }
	end

	local previousRebirths = data.Rebirths
	local updateOk, updatedRebirths = pcall(DataService.Update, player, "Rebirths", function(rebirths: number)
		local safeRebirths = if type(rebirths) == "number"
				and rebirths == rebirths
				and rebirths >= 0
			then rebirths
			else 0
		return safeRebirths + 1
	end)
	if not updateOk or updatedRebirths == nil then
		local currentData = DataService.Get(player)
		if currentData == nil or currentData.Rebirths == previousRebirths then
			if cost > 0 then
				local refundOk, refunded = pcall(DataService.Update, player, "Coins", function(coins: number)
					return (coins or 0) + cost
				end)
				if not refundOk or refunded == nil then
					warn(
						`[RebirthService] Falha ao estornar {cost} Coins de {player.UserId} após erro em Rebirths: {tostring(
							refunded
						)}`
					)
					return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
				end
			end
			return {
				ok = false,
				err = if not updateOk then ErrorCodes.INTERNAL else ErrorCodes.DATA_NOT_LOADED,
			}
		end

		warn(
			`[RebirthService] Exceção após incremento de Rebirths para {player.UserId}; finalizando commit: {tostring(
				updatedRebirths
			)}`
		)
		updatedRebirths = currentData.Rebirths
	end

	local resetCoinsOk, resetCoinsSet = pcall(DataService.Set, player, "Coins", GameConfig.StartingCoins)
	if not resetCoinsOk or not resetCoinsSet then
		warn(`[RebirthService] Falha pós-commit ao resetar Coins de {player.UserId}: {tostring(resetCoinsSet)}`)
	end

	local resetAreasOk, resetAreasSet = pcall(DataService.Set, player, "UnlockedAreas", { GameConfig.StartingArea })
	if not resetAreasOk or not resetAreasSet then
		warn(
			`[RebirthService] Falha pós-commit ao resetar UnlockedAreas de {player.UserId}: {tostring(resetAreasSet)}`
		)
	end

	local addGemsOk, gemsCredited = pcall(EconomyService.AddGems, player, GameConfig.RebirthGemReward)
	if not addGemsOk or (GameConfig.RebirthGemReward > 0 and (type(gemsCredited) ~= "number" or gemsCredited <= 0)) then
		warn(`[RebirthService] Falha pós-commit ao creditar Gems de {player.UserId}: {tostring(gemsCredited)}`)
	end

	local saveOk = pcall(DataService.Save, player)
	if not saveOk then
		warn(`[RebirthService] Falha pós-commit ao salvar dados de {player.UserId}`)
	end

	return {
		ok = true,
		data = {
			rebirths = updatedRebirths,
			gemsReward = GameConfig.RebirthGemReward,
		},
	}
end

local function handleRequestRebirth(player: Player, requestId: any): Types.Result
	return rebirthIdempotency:Execute(player, requestId, function()
		return executeRequestRebirth(player)
	end) :: Types.Result
end

function RebirthService.Init()
	NetServer.OnInvoke("RequestRebirth", handleRequestRebirth, {
		rate = REQUEST_REBIRTH_RATE,
		burst = REQUEST_REBIRTH_BURST,
	})
	if not playerRemovingConnected then
		playerRemovingConnected = true
		Players.PlayerRemoving:Connect(function(player)
			rebirthIdempotency:Remove(player)
		end)
	end
end

function RebirthService.Start() end

return RebirthService
