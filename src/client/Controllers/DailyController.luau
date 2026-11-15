--!strict
-- StarterPlayerScripts.Client.Controllers.DailyController | Dono: Squad A. Resgate diário e estado de exibição.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local NetClient = require(script.Parent.Parent.Net.NetClient)
local DailyUI = require(script.Parent.Parent.UI.Daily.DailyUI)
local Messages = require(script.Parent.Parent.UI.Hud.Messages)
local Daily = require(ReplicatedStorage.Shared.Logic.Daily)
local DailyRewards = require(ReplicatedStorage.Shared.Config.DailyRewards)

local DailyController = {}
local started = false
local openedAutomatically = false
local pending = false
local requestCount = 0
local pendingRequest: number? = nil
local rebirths = 0
local confirmedDay: number? = nil
local state: { LastClaimDay: number, Streak: number }? = nil

local function refresh()
	local now = workspace:GetServerTimeNow()
	local today = Daily.dayIndex(now)
	local current = state
	local available = false
	local nextStreak: number? = nil
	if current then
		available, nextStreak = Daily.evaluate(current, today, #DailyRewards.Days)
	end
	-- A resposta pode chegar antes do DataChanged; não permite outro pedido nesse intervalo.
	available = available and confirmedDay ~= today
	local claimed = if current then current.Streak else 0
	if current and not available then
		local tomorrowState = current
		if confirmedDay == today and current.LastClaimDay < today then
			local _, confirmedStreak = Daily.evaluate(current, today, #DailyRewards.Days)
			if confirmedStreak then
				tomorrowState = { LastClaimDay = today, Streak = confirmedStreak }
				claimed = confirmedStreak
			end
		end
		local _, tomorrowStreak = Daily.evaluate(tomorrowState, today + 1, #DailyRewards.Days)
		nextStreak = tomorrowStreak
		if nextStreak == 1 then
			claimed = 0
		end
	end
	if available and nextStreak then
		claimed = nextStreak - 1
	end
	DailyUI.Refresh(current ~= nil, available, nextStreak, claimed, pending, Daily.secondsUntilNext(now), rebirths)
	if current and available and not openedAutomatically then
		openedAutomatically = true
		DailyUI.SetOpen(true)
	end
end

local function claim()
	local current = state
	local today = Daily.dayIndex(workspace:GetServerTimeNow())
	if pending or not current or confirmedDay == today then
		return
	end
	local available = Daily.evaluate(current, today, #DailyRewards.Days)
	if not available then
		refresh()
		return
	end
	pending = true
	requestCount += 1
	local request = requestCount
	pendingRequest = request
	refresh()
	local timeoutExpired = false
	local timeout = task.delay(8, function()
		timeoutExpired = true
		if pendingRequest ~= request then
			return
		end
		pendingRequest = nil
		pending = false
		DailyUI.ShowStatus("Ainda aguardando o servidor...")
		refresh()
	end)
	task.spawn(function()
		local result = NetClient.Invoke("ClaimDaily")
		if not timeoutExpired then
			task.cancel(timeout)
		end
		if pendingRequest == request then
			pendingRequest = nil
			pending = false
		end
		if result.ok then
			confirmedDay = today
			DailyUI.SetOpen(false)
		else
			local currentDay = Daily.dayIndex(workspace:GetServerTimeNow())
			local latestState = state
			if
				request ~= requestCount
				or confirmedDay == currentDay
				or (latestState and latestState.LastClaimDay == currentDay)
			then
				refresh()
				return
			end
			local message = Messages.message(result.err)
			HudController.Toast(message, "error")
			DailyUI.ShowStatus(message)
		end
		refresh()
	end)
end

function DailyController.Init()
	-- Observe e criação da interface ficam em Start; Init não espera replicação.
end

function DailyController.Start()
	if started then
		return
	end
	started = true
	DailyUI.Create(claim)
	DataController.Observe("Daily", function(value: any)
		if type(value) == "table" then
			state = value
		end
		refresh()
	end)
	DataController.Observe("Rebirths", function(value: any)
		if type(value) == "number" then
			rebirths = value
		end
		refresh()
	end)
	refresh()
	task.spawn(function()
		while DailyUI.IsMounted() do
			task.wait(1)
			refresh()
		end
	end)
end

return DailyController
