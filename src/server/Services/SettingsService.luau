--!strict
-- SettingsService.luau (ServerScriptService.Server.Services.SettingsService)
-- Dono: Squad A. Valida e salva as preferências de música e sons do jogador.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ErrorCodes = require(Shared.ErrorCodes)
local Types = require(Shared.Types)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

local function setSetting(player: Player, key: any, value: any): Types.Result
	if typeof(key) ~= "string" or (key ~= "Music" and key ~= "Sfx") or typeof(value) ~= "boolean" then
		return { ok = false, err = ErrorCodes.INVALID_ARGS }
	end

	if player.Parent == nil or DataService.Get(player) == nil then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end

	local updated = DataService.Update(player, "Settings", function(old)
		local settings = table.clone(old)
		settings[key] = value
		return settings
	end)
	if updated == nil then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end

	return { ok = true, data = { key = key, value = value } }
end

function SettingsService.Init()
	NetServer.OnInvoke("SetSetting", setSetting, { rate = 2, burst = 3 })
end

function SettingsService.Start() end

return SettingsService
