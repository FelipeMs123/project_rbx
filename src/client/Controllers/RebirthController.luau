--!strict
-- RebirthController.luau (StarterPlayerScripts.Client.Controllers.RebirthController)
-- Dono: Squad B. Controlador de Rebirth no cliente: observa saldo/rebirths e protege RequestRebirth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.Game)
local RequestGuard = require(Shared.Logic.RequestGuard)
local NetClient = require(script.Parent.Parent.Net.NetClient)
local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local RebirthHelpers = require(script.Parent.Parent.UI.Rebirth.RebirthHelpers)
local RebirthUI = require(script.Parent.Parent.UI.Rebirth.RebirthUI)

local REBIRTH_TIMEOUT_SECONDS = 8
local TIMEOUT_WAIT_MESSAGE = "O servidor ainda está respondendo. Aguarde antes de tentar novamente."

local RebirthController = {}

local function scheduleTimeoutThread(seconds: number, callback: () -> ()): any
	return task.delay(seconds, callback)
end

local function cancelTimeoutThread(handle: any)
	if typeof(handle) == "thread" and handle ~= coroutine.running() then
		pcall(task.cancel, handle)
	end
end

local connections: { RBXScriptConnection } = {}
local isStarted = false
local rebirthGuard = RequestGuard.new(cancelTimeoutThread)

local currentCoins = 0
local currentRebirths = 0
local currentGems = 0

local function sanitizeNumber(value: any, fallback: number): number
	if type(value) == "number" and value == value and value > -math.huge and value < math.huge then
		return value
	end
	return fallback
end

local function pushViewState()
	RebirthUI.SetState({
		Coins = currentCoins,
		Rebirths = currentRebirths,
		Gems = currentGems,
		IsBusy = rebirthGuard:IsInFlight(),
	})
end

local function syncFromSnapshot()
	local snapshot = DataController.Get()
	if snapshot then
		currentCoins = sanitizeNumber(snapshot.Coins, currentCoins)
		currentRebirths = sanitizeNumber(snapshot.Rebirths, currentRebirths)
		currentGems = sanitizeNumber(snapshot.Gems, currentGems)
	end
	pushViewState()
end

local function handleConfirmRebirth()
	if rebirthGuard:IsInFlight() then
		return
	end

	local snapshot = DataController.Get()
	if not snapshot then
		RebirthUI.ResetConfirmation()
		HudController.Toast(RebirthHelpers.translateError("DATA_NOT_LOADED"), "error")
		return
	end

	local coins = sanitizeNumber(snapshot.Coins, 0)
	local rebirths = sanitizeNumber(snapshot.Rebirths, 0)
	local cost = RebirthHelpers.computeCost(rebirths, GameConfig)
	local progress = RebirthHelpers.computeProgress(coins, cost)
	if not progress.CanRebirth then
		RebirthUI.ResetConfirmation()
		HudController.Toast(RebirthHelpers.translateError("NOT_ENOUGH_COINS"), "error")
		return
	end

	local token = rebirthGuard:Begin()
	if not token then
		return
	end
	pushViewState()

	rebirthGuard:ScheduleTimeout(token, REBIRTH_TIMEOUT_SECONDS, scheduleTimeoutThread, function()
		HudController.Toast(TIMEOUT_WAIT_MESSAGE, "error")
	end)

	task.spawn(function()
		local result = NetClient.Invoke("RequestRebirth")
		local accepted = rebirthGuard:Resolve(token)
		if not accepted then
			return
		end

		RebirthUI.ResetConfirmation()
		pushViewState()

		if result.ok then
			RebirthUI.SetModalOpen(false)
			HudController.Toast(`Rebirth concluído! Você ganhou +{GameConfig.RebirthGemReward} Gemas!`, "reward")
		else
			HudController.Toast(RebirthHelpers.translateError(result.err), "error")
		end
	end)
end

function RebirthController.Init()
	-- Init sem yield: apenas registra o callback de confirmação da UI.
	RebirthUI.Init(handleConfirmRebirth)
end

function RebirthController.Start()
	if isStarted then
		return
	end
	isStarted = true
	RebirthUI.Mount()
	syncFromSnapshot()

	local coinsConn = DataController.Observe("Coins", function(value: any)
		currentCoins = sanitizeNumber(value, 0)
		pushViewState()
	end)
	table.insert(connections, coinsConn :: any)

	local rebirthsConn = DataController.Observe("Rebirths", function(value: any)
		currentRebirths = sanitizeNumber(value, 0)
		pushViewState()
	end)
	table.insert(connections, rebirthsConn :: any)

	local gemsConn = DataController.Observe("Gems", function(value: any)
		currentGems = sanitizeNumber(value, 0)
		pushViewState()
	end)
	table.insert(connections, gemsConn :: any)
end

function RebirthController.Destroy()
	isStarted = false
	rebirthGuard:Reset()

	for _, conn in connections do
		conn:Disconnect()
	end
	table.clear(connections)

	RebirthUI.Destroy()
end

return RebirthController
