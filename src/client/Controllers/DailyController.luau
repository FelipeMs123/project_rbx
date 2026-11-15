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
local requestToken = 0
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
	if available and nextStreak then
		claimed = nextStreak - 1
	end
	DailyUI.Refresh(current ~= nil, available, nextStreak, claimed, pending, Daily.secondsUntilNext(now))
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
	requestToken += 1
	local token = requestToken
	refresh()
	task.delay(8, function()
		if requestToken ~= token or not pending then
			return
		end
		requestToken += 1
		pending = false
		HudController.Toast("Demorou um pouquinho. Tente de novo!", "error")
		refresh()
	end)
	task.spawn(function()
		local result = NetClient.Invoke("ClaimDaily")
		if token ~= requestToken then
			return
		end
		pending = false
		if result.ok then
			confirmedDay = today
		else
			HudController.Toast(Messages.message(result.err), "error")
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
	refresh()
	task.spawn(function()
		while DailyUI.IsMounted() do
			task.wait(1)
			refresh()
		end
	end)
end

return DailyController
