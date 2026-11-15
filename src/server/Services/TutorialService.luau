--!strict
-- TutorialService.luau (ServerScriptService.Server.Services.TutorialService)
-- Dono: Squad A. Salva o avanço do tutorial e pula os passos para jogadores veteranos.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local TutorialConfig = require(Shared.Config.Tutorial)
local Tutorial = require(Shared.Logic.Tutorial)
local ErrorCodes = require(Shared.ErrorCodes)
local Types = require(Shared.Types)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local DataService = require(script.Parent.DataService)

local TutorialService = {}

local function setTutorialStep(player: Player, step: any): Types.Result
	if typeof(step) ~= "number" then
		return { ok = false, err = ErrorCodes.INVALID_ARGS }
	end
	local data = DataService.Get(player)
	if data == nil or player.Parent ~= Players then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end
	if not Tutorial.isValidAdvance(data.TutorialStep, step, #TutorialConfig) then
		return { ok = false, err = ErrorCodes.INVALID_ARGS }
	end
	if not DataService.Set(player, "TutorialStep", step) then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end
	return { ok = true, data = { step = step } }
end

local function onProfileLoaded(player: Player, data: Types.PlayerData)
	if player.Parent ~= Players then
		return
	end
	if Tutorial.shouldSkip(data, #TutorialConfig) then
		DataService.Set(player, "TutorialStep", #TutorialConfig)
	end
end

function TutorialService.Init()
	NetServer.OnInvoke("SetTutorialStep", setTutorialStep, { rate = 2, burst = 3 })
end

function TutorialService.Start()
	DataService.Loaded:Connect(onProfileLoaded)
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data ~= nil then
			onProfileLoaded(player, data)
		end
	end
end

return TutorialService
