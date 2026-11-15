--!strict
-- RebirthService.luau (ServerScriptService.Server.Services.RebirthService)
-- Dono: Squad B. Rebirth (remote RequestRebirth).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.Game)
local ErrorCodes = require(Shared.ErrorCodes)
local Rebirth = require(Shared.Logic.Rebirth)
local Types = require(Shared.Types)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local REQUEST_REBIRTH_RATE = 2
local REQUEST_REBIRTH_BURST = 3

local RebirthService = {}

local function handleRequestRebirth(player: Player): Types.Result
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

	DataService.Set(player, "Coins", GameConfig.StartingCoins)
	local newRebirths = DataService.Update(player, "Rebirths", function(rebirths: number)
		local safeRebirths = if type(rebirths) == "number"
				and rebirths == rebirths
				and rebirths >= 0
			then rebirths
			else 0
		return safeRebirths + 1
	end)
	DataService.Set(player, "UnlockedAreas", { GameConfig.StartingArea })
	EconomyService.AddGems(player, GameConfig.RebirthGemReward)
	DataService.Save(player)

	return {
		ok = true,
		data = {
			rebirths = newRebirths,
			gemsReward = GameConfig.RebirthGemReward,
		},
	}
end

function RebirthService.Init()
	NetServer.OnInvoke("RequestRebirth", handleRequestRebirth, {
		rate = REQUEST_REBIRTH_RATE,
		burst = REQUEST_REBIRTH_BURST,
	})
end

function RebirthService.Start() end

return RebirthService
