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

type RebirthCheckpoint = {
	rebirthsUpdated: number?,
	coinsDone: boolean,
	areasDone: boolean,
	gemsDone: boolean,
	targetGems: number?,
}

type PlayerCheckpointEntry = {
	map: { [string]: RebirthCheckpoint },
	order: { string },
}

local rebirthIdempotency = RequestIdempotency.new(MAX_CACHED_RESULTS)
local pendingCheckpoints: { [Player]: PlayerCheckpointEntry } = {}
local playerRemovingConnected = false

local RebirthService = {}

local function cloneAreaList(areas: { string }?): { string }
	local copy: { string } = {}
	if areas ~= nil then
		for _, area in areas do
			table.insert(copy, area)
		end
	end
	return copy
end

local function getOrCreateCheckpoint(player: Player, requestId: string): (PlayerCheckpointEntry, RebirthCheckpoint)
	local entry = pendingCheckpoints[player]
	if entry == nil then
		entry = {
			map = {},
			order = {},
		}
		pendingCheckpoints[player] = entry
	end
	local checkpoint = entry.map[requestId]
	if checkpoint == nil then
		checkpoint = {
			rebirthsUpdated = nil,
			coinsDone = false,
			areasDone = false,
			gemsDone = false,
			targetGems = nil,
		}
		entry.map[requestId] = checkpoint
		table.insert(entry.order, requestId)
		while #entry.order > MAX_CACHED_RESULTS do
			local oldest = table.remove(entry.order, 1)
			if oldest ~= nil then
				entry.map[oldest] = nil
			end
		end
	end
	return entry, checkpoint
end

local function removeCheckpoint(player: Player, entry: PlayerCheckpointEntry?, requestId: string)
	if entry == nil or pendingCheckpoints[player] ~= entry then
		return
	end
	if entry.map[requestId] ~= nil then
		entry.map[requestId] = nil
		local index = table.find(entry.order, requestId)
		if index ~= nil then
			table.remove(entry.order, index)
		end
	end
	if #entry.order == 0 then
		pendingCheckpoints[player] = nil
	end
end

local function tryCommitRebirth(player: Player, data: Types.PlayerData): (boolean, string?, number?)
	local cost = Rebirth.cost(data.Rebirths, GameConfig.RebirthBaseCost, GameConfig.RebirthCostGrowth)
	local canRebirth, errCode =
		Rebirth.canRebirth(data.Coins, data.Rebirths, GameConfig.RebirthBaseCost, GameConfig.RebirthCostGrowth)
	if not canRebirth then
		return false, errCode or ErrorCodes.NOT_ENOUGH_COINS, nil
	end

	if cost > 0 and not EconomyService.Spend(player, "Coins", cost) then
		return false, ErrorCodes.NOT_ENOUGH_COINS, nil
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
					return false, ErrorCodes.DATA_NOT_LOADED, nil
				end
			end
			return false, if not updateOk then ErrorCodes.INTERNAL else ErrorCodes.DATA_NOT_LOADED, nil
		end

		warn(
			`[RebirthService] Exceção após incremento de Rebirths para {player.UserId}; finalizando commit: {tostring(
				updatedRebirths
			)}`
		)
		updatedRebirths = currentData.Rebirths
	end

	return true, nil, updatedRebirths :: number
end

local function runPostCommitSteps(player: Player, checkpoint: RebirthCheckpoint, stopOnFailure: boolean)
	if not checkpoint.coinsDone then
		local resetCoinsOk, resetCoinsSet = pcall(DataService.Set, player, "Coins", GameConfig.StartingCoins)
		if resetCoinsOk and resetCoinsSet == true then
			checkpoint.coinsDone = true
		else
			warn(`[RebirthService] Falha pós-commit ao resetar Coins de {player.UserId}: {tostring(resetCoinsSet)}`)
			if stopOnFailure then
				return
			end
		end
	end

	if not checkpoint.areasDone then
		local resetAreasOk, resetAreasSet = pcall(DataService.Set, player, "UnlockedAreas", { GameConfig.StartingArea })
		if resetAreasOk and resetAreasSet == true then
			checkpoint.areasDone = true
		else
			warn(
				`[RebirthService] Falha pós-commit ao resetar UnlockedAreas de {player.UserId}: {tostring(
					resetAreasSet
				)}`
			)
			if stopOnFailure then
				return
			end
		end
	end

	if not checkpoint.gemsDone then
		local gemReward = math.floor(GameConfig.RebirthGemReward)
		if gemReward <= 0 then
			checkpoint.gemsDone = true
			return
		end

		local currentData = DataService.Get(player)
		if checkpoint.targetGems == nil then
			if currentData ~= nil and type(currentData.Gems) == "number" then
				checkpoint.targetGems = currentData.Gems + gemReward
			end
		end

		local targetGems = checkpoint.targetGems
		if targetGems == nil then
			warn(`[RebirthService] Falha pós-commit ao calcular targetGems de {player.UserId}`)
			return
		end

		if currentData ~= nil and type(currentData.Gems) == "number" and currentData.Gems >= targetGems then
			checkpoint.gemsDone = true
			return
		end

		local addGemsOk, gemsCredited = pcall(EconomyService.AddGems, player, GameConfig.RebirthGemReward)
		local afterData = DataService.Get(player)
		if afterData ~= nil and type(afterData.Gems) == "number" and afterData.Gems >= targetGems then
			if not addGemsOk then
				warn(
					`[RebirthService] Exceção após creditar Gems para {player.UserId}; mantendo checkpoint concluído: {tostring(
						gemsCredited
					)}`
				)
			end
			checkpoint.gemsDone = true
		else
			warn(`[RebirthService] Falha pós-commit ao creditar Gems de {player.UserId}: {tostring(gemsCredited)}`)
		end
	end
end

local function rollbackRebirth(
	player: Player,
	previousRebirths: number,
	previousCoins: number,
	previousAreas: { string }
)
	local okRebirths, setRebirths = pcall(DataService.Set, player, "Rebirths", previousRebirths)
	if not okRebirths or setRebirths ~= true then
		warn(`[RebirthService] Falha no rollback de Rebirths de {player.UserId}: {tostring(setRebirths)}`)
	end

	local okCoins, setCoins = pcall(DataService.Set, player, "Coins", previousCoins)
	if not okCoins or setCoins ~= true then
		warn(`[RebirthService] Falha no rollback de Coins de {player.UserId}: {tostring(setCoins)}`)
	end

	local okAreas, setAreas = pcall(DataService.Set, player, "UnlockedAreas", previousAreas)
	if not okAreas or setAreas ~= true then
		warn(`[RebirthService] Falha no rollback de UnlockedAreas de {player.UserId}: {tostring(setAreas)}`)
	end
end

local function executeRequestRebirth(player: Player, requestId: any): Types.Result
	if player.Parent ~= Players or not DataService.IsLoaded(player) then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end
	local data = DataService.Get(player)
	if data == nil then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end

	local isIdempotent = RequestIdempotency.IsValidRequestId(requestId)
	local checkpointEntry: PlayerCheckpointEntry? = nil
	local checkpoint: RebirthCheckpoint
	if isIdempotent then
		checkpointEntry, checkpoint = getOrCreateCheckpoint(player, requestId :: string)
	else
		checkpoint = {
			rebirthsUpdated = nil,
			coinsDone = false,
			areasDone = false,
			gemsDone = false,
			targetGems = nil,
		}
	end

	local previousCoins = data.Coins
	local previousRebirths = data.Rebirths
	local previousAreas = if not isIdempotent then cloneAreaList(data.UnlockedAreas) else {}

	if checkpoint.rebirthsUpdated == nil then
		local commitOk, errCode, updatedRebirths = tryCommitRebirth(player, data)
		if not commitOk or updatedRebirths == nil then
			if isIdempotent then
				removeCheckpoint(player, checkpointEntry, requestId :: string)
			end
			return { ok = false, err = errCode or ErrorCodes.INTERNAL }
		end
		checkpoint.rebirthsUpdated = updatedRebirths
	end

	runPostCommitSteps(player, checkpoint, not isIdempotent)

	if not (checkpoint.coinsDone and checkpoint.areasDone and checkpoint.gemsDone) then
		if not isIdempotent then
			rollbackRebirth(player, previousRebirths, previousCoins, previousAreas)
		end
		return { ok = false, err = ErrorCodes.INTERNAL }
	end

	if isIdempotent then
		removeCheckpoint(player, checkpointEntry, requestId :: string)
	end

	local saveOk = pcall(DataService.Save, player)
	if not saveOk then
		warn(`[RebirthService] Falha pós-commit ao salvar dados de {player.UserId}`)
	end

	return {
		ok = true,
		data = {
			rebirths = checkpoint.rebirthsUpdated,
			gemsReward = GameConfig.RebirthGemReward,
		},
	}
end

local function handleRequestRebirth(player: Player, requestId: any): Types.Result
	return rebirthIdempotency:Execute(player, requestId, function()
		return executeRequestRebirth(player, requestId)
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
			pendingCheckpoints[player] = nil
		end)
	end
end

function RebirthService.Start() end

return RebirthService
