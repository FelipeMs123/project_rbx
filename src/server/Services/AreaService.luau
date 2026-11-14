--!strict
-- AreaService.luau (ServerScriptService.Server.Services.AreaService)
-- Dono: Squad A. Desbloqueio de áreas (remote UnlockArea).
-- Para checar se uma área está liberada use EconomyService.HasArea.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local AreasConfig = require(Shared.Config.Areas)
local Areas = require(Shared.Logic.Areas)
local ErrorCodes = require(Shared.ErrorCodes)
local Types = require(Shared.Types)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local AreaService = {}

local function unlockArea(player: Player, areaId: any): Types.Result
	if typeof(areaId) ~= "string" or #areaId > 64 then
		return { ok = false, err = ErrorCodes.INVALID_ARGS }
	end
	local area = AreasConfig[areaId]
	if area == nil then
		return { ok = false, err = ErrorCodes.UNKNOWN_ITEM }
	end
	local data = DataService.Get(player)
	if data == nil or player.Parent == nil then
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end
	local ok, err = Areas.canUnlock(AreasConfig :: any, data.UnlockedAreas, areaId, data.Coins)
	if not ok then
		return { ok = false, err = err }
	end
	if area.Price > 0 and not EconomyService.Spend(player, "Coins", area.Price) then
		return { ok = false, err = ErrorCodes.NOT_ENOUGH_COINS }
	end
	DataService.Update(player, "UnlockedAreas", function(list: { string })
		table.insert(list, areaId)
		return list
	end)
	DataService.Save(player)
	return { ok = true, data = { areaId = areaId } }
end

function AreaService.Init()
	NetServer.OnInvoke("UnlockArea", unlockArea, { rate = 2, burst = 3 })
end

function AreaService.Start() end

return AreaService
