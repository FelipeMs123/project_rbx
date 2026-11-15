--!strict
-- AreaService.luau (ServerScriptService.Server.Services.AreaService)
-- Dono: Squad A. Desbloqueio de áreas (remote UnlockArea).
-- Para checar se uma área está liberada use EconomyService.HasArea.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage.Shared
local AreasConfig = require(Shared.Config.Areas)
local Areas = require(Shared.Logic.Areas)
local ErrorCodes = require(Shared.ErrorCodes)
local Types = require(Shared.Types)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local AreaService = {}
local previousAreas: { [Player]: { string } } = {}
local recentResetUntil: { [Player]: number } = {}

local function unlockArea(player: Player, areaId: any): Types.Result
	if typeof(areaId) ~= "string" or #areaId < 1 or #areaId > 64 then
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
		return {
			ok = false,
			err = if DataService.IsLoaded(player) then ErrorCodes.NOT_ENOUGH_COINS else ErrorCodes.DATA_NOT_LOADED,
		}
	end
	local updated = DataService.Update(player, "UnlockedAreas", function(list: { string })
		table.insert(list, areaId)
		return list
	end)
	if updated == nil then
		if area.Price > 0 then
			local refunded = DataService.Update(player, "Coins", function(coins: number)
				return coins + area.Price
			end)
			if refunded == nil then
				warn(`[AreaService] Não foi possível estornar a área {areaId} para {player.Name}`)
			end
		end
		return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
	end
	DataService.Save(player)
	return { ok = true, data = { areaId = areaId } }
end

function AreaService.Init()
	NetServer.OnInvoke("UnlockArea", unlockArea, { rate = 2, burst = 3 })
	DataService.Loaded:Connect(function(player: Player, data: Types.PlayerData)
		previousAreas[player] = table.clone(data.UnlockedAreas)
	end)
	DataService.Changed:Connect(function(player: Player, key: string, value: any)
		if key ~= "UnlockedAreas" then
			return
		end
		local previous = previousAreas[player]
		if previous then
			for _, areaId in previous do
				if not table.find(value, areaId) then
					recentResetUntil[player] = os.clock() + 3
					break
				end
			end
		end
		previousAreas[player] = table.clone(value)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		previousAreas[player] = nil
		recentResetUntil[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data then
			previousAreas[player] = table.clone(data.UnlockedAreas)
		end
	end
end

local function coordinates(position: Vector3): Areas.Position
	return { X = position.X, Y = position.Y, Z = position.Z }
end

local function areaBox(area: Instance, areaId: string): Areas.Box?
	local bounds = area:FindFirstChild("Bounds")
	if bounds and bounds:IsA("BasePart") then
		local halfSize = bounds.Size / 2
		return {
			id = areaId,
			min = coordinates(bounds.Position - halfSize),
			max = coordinates(bounds.Position + halfSize),
		}
	end
	local minimum: Vector3? = nil
	local maximum: Vector3? = nil
	for _, part in area:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local excluded = false
		local ancestor: Instance? = part
		while ancestor and ancestor ~= area do
			if ancestor.Name == "Gate" and (ancestor:IsA("Model") or ancestor:IsA("BasePart")) then
				excluded = true
				break
			end
			ancestor = ancestor.Parent
		end
		if excluded then
			continue
		end
		-- Os oito cantos produzem uma AABB mesmo para peças rotacionadas.
		local halfSize = part.Size / 2
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = part.CFrame:PointToWorldSpace(halfSize * Vector3.new(x, y, z))
					minimum = if minimum then minimum:Min(corner) else corner
					maximum = if maximum then maximum:Max(corner) else corner
				end
			end
		end
	end
	if minimum and maximum then
		return { id = areaId, min = coordinates(minimum), max = coordinates(maximum + Vector3.new(0, 50, 0)) }
	end
	return nil
end

local function findSpawn(folder: Instance, areaId: string?): BasePart?
	local area = if areaId then folder:FindFirstChild(areaId) else nil
	local spawn = area and area:FindFirstChild("SpawnLocation")
	return if spawn and spawn:IsA("BasePart") then spawn else nil
end

local function enforceArea(player: Player, folder: Instance, boxes: { Areas.Box })
	local data = DataService.Get(player)
	local character = player.Character
	if not data or player.Parent ~= Players or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end
	local lockedAreaId = Areas.lockedAreaAt(boxes, data.UnlockedAreas, coordinates(root.Position))
	if not lockedAreaId then
		return
	end
	local lastId = Areas.lastUnlocked(AreasConfig :: any, data.UnlockedAreas)
	local recentReset = (recentResetUntil[player] or 0) > os.clock()
	local spawn = if recentReset
		then findSpawn(folder, "CandyPlaza")
		else findSpawn(folder, lastId) or findSpawn(folder, "CandyPlaza")
	if spawn then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
		if not recentReset then
			NetServer.Fire("Notify", player, ErrorCodes.AREA_NOT_UNLOCKED, { areaId = lockedAreaId })
		end
	end
end

function AreaService.Start()
	task.spawn(function()
		local watchedFolder: Instance? = nil
		local connections: { RBXScriptConnection } = {}
		local boxes: { Areas.Box } = {}
		local dirty = true
		local function invalidate()
			dirty = true
		end
		while true do
			local folder = Workspace:FindFirstChild("Areas")
			if folder ~= watchedFolder then
				for _, connection in connections do
					connection:Disconnect()
				end
				table.clear(connections)
				watchedFolder = folder
				dirty = true
				if folder then
					table.insert(connections, folder.ChildAdded:Connect(invalidate))
					table.insert(connections, folder.ChildRemoved:Connect(invalidate))
					table.insert(connections, folder.DescendantAdded:Connect(invalidate))
					table.insert(connections, folder.DescendantRemoving:Connect(invalidate))
				end
			end
			if dirty then
				boxes = {}
				if folder then
					for areaId in AreasConfig do
						local area = folder:FindFirstChild(areaId)
						local box = if area then areaBox(area, areaId) else nil
						if box then
							table.insert(boxes, box)
						end
					end
				end
				dirty = false
			end
			if folder then
				for _, player in Players:GetPlayers() do
					local areasFolder: Instance = folder
					local ok, err = pcall(function()
						enforceArea(player, areasFolder, boxes)
					end)
					if not ok then
						warn(`[AreaService] Checagem de área falhou para {player.Name}: {err}`)
					end
				end
			end
			task.wait(1)
		end
	end)
end

return AreaService
