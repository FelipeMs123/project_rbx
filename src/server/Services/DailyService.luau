--!strict
-- DailyService.luau (ServerScriptService.Server.Services.DailyService)
-- Dono: Squad A. Valida e entrega a recompensa diária pelo dia UTC do servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DailyRewards = require(Shared.Config.DailyRewards)
local Daily = require(Shared.Logic.Daily)
local ErrorCodes = require(Shared.ErrorCodes)
local Types = require(Shared.Types)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local DailyService = {}

local function claimDaily(player: Player): Types.Result
	local data = DataService.Get(player)
	if data == nil or player.Parent == nil then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end

	local today = Daily.dayIndex(os.time())
	local ready, streak = Daily.evaluate(data.Daily, today, #DailyRewards.Days)
	if not ready or streak == nil then
		return { ok = false, err = ErrorCodes.DAILY_NOT_READY }
	end

	local reward = Daily.reward(DailyRewards.Days, streak)
	if reward == nil then
		return { ok = false, err = ErrorCodes.INTERNAL }
	end

	-- Reserva o resgate sem yield antes de creditar para impedir pagamento duplicado.
	if not DataService.Set(player, "Daily", { LastClaimDay = today, Streak = streak }) then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end

	local coins = EconomyService.AddCoins(player, reward.Coins)
	local gems = if reward.Gems > 0 then EconomyService.AddGems(player, reward.Gems) else 0
	NetServer.Fire("Notify", player, "REWARD", { coins = coins, gems = gems })
	return { ok = true, data = { day = streak, streak = streak, coins = coins, gems = gems } }
end

function DailyService.Init()
	NetServer.OnInvoke("ClaimDaily", claimDaily, { rate = 2, burst = 3 })
end

function DailyService.Start() end

return DailyService
