--!strict
-- StarterPlayerScripts.Client.Controllers.SoundController | Dono: Squad A. Áudio local e preferências salvas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage.Shared
local Sounds = require(Shared.Config.Sounds)
local Pets = require(Shared.Config.Pets)
local Areas = require(Shared.Config.Areas)
local Rules = require(Shared.Logic.SoundRules)
local DataController = require(script.Parent.DataController)
local HudController = require(script.Parent.HudController)
local NetClient = require(script.Parent.Parent.Net.NetClient)
local SettingsUI = require(script.Parent.Parent.UI.Settings.SettingsUI)
local Messages = require(script.Parent.Parent.UI.Hud.Messages)

local SoundController = {}
local started = false
local loaded = false
local settings: { [string]: boolean } = { Music = false, Sfx = false }
local confirmed: { [string]: boolean } = { Music = false, Sfx = false }
local pending: { [string]: boolean } = {}
local versions: { [string]: number } = { Music = 0, Sfx = 0 }
local pools: { [string]: { Sound } } = {}
local cursors: { [string]: number } = {}
local tracks: { [string]: Sound } = {}
local tweens: { [Sound]: Tween } = {}
local currentArea: string? = nil
local random = Random.new()
local lastError = -math.huge

local function sfx(key: string, pitch: number?)
	if not loaded or not settings.Sfx then
		return
	end
	local pool = pools[key]
	if not pool then
		return
	end
	local index = ((cursors[key] or 0) % #pool) + 1
	cursors[key] = index
	local sound = pool[index]
	if sound.SoundId == "" then
		return
	end
	local active = 0
	for _, sounds in pools do
		for _, item in sounds do
			if item.IsPlaying then
				active += 1
			end
		end
	end
	-- Reserva duas vozes para a música durante o fade: no máximo oito no total.
	if active >= 6 and not sound.IsPlaying then
		return
	end
	sound:Stop()
	sound.PlaybackSpeed = pitch or 1
	sound:Play()
end

local function fade(sound: Sound, volume: number, pauseAfter: boolean)
	local previous = tweens[sound]
	if previous then
		previous:Cancel()
	end
	local tween = TweenService:Create(sound, TweenInfo.new(1), { Volume = volume })
	tweens[sound] = tween
	tween.Completed:Once(function(state)
		if tweens[sound] ~= tween then
			return
		end
		tweens[sound] = nil
		if state == Enum.PlaybackState.Completed and pauseAfter then
			sound:Pause()
		end
	end)
	tween:Play()
end

local function applySettings()
	for key, sound in tracks do
		if loaded and key == currentArea and settings.Music and sound.SoundId ~= "" then
			if not sound.IsPlaying then
				if sound.TimePosition == 0 then
					sound:Play()
				else
					sound:Resume()
				end
			end
			fade(sound, Sounds.Music[key].Volume, false)
		elseif not settings.Music then
			local tween = tweens[sound]
			if tween then
				tweens[sound] = nil
				tween:Cancel()
			end
			sound.Volume = 0
			sound:Pause()
		else
			fade(sound, 0, true)
		end
	end
	if not settings.Sfx then
		for _, pool in pools do
			for _, sound in pool do
				sound:Stop()
			end
		end
	end
	SettingsUI.Refresh(settings.Music, settings.Sfx, loaded, pending)
end

local function toggle(key: string)
	if not loaded or pending[key] or settings[key] == nil then
		return
	end
	local previous = settings[key]
	local value = not previous
	versions[key] += 1
	local version = versions[key]
	pending[key] = true
	settings[key] = value
	applySettings()
	local function finish(ok: boolean, err: string?)
		if versions[key] ~= version or not pending[key] then
			return
		end
		pending[key] = nil
		if ok then
			confirmed[key] = value
			settings[key] = value
		else
			settings[key] = confirmed[key]
			local message = Messages.message(err)
			HudController.Toast(message, "error")
			SettingsUI.ShowStatus(message)
		end
		applySettings()
	end
	local timeout = task.delay(8, function()
		finish(false, "INTERNAL")
	end)
	task.spawn(function()
		local result = NetClient.Invoke("SetSetting", key, value)
		if versions[key] == version and pending[key] then
			task.cancel(timeout)
			finish(result.ok, result.err)
		end
	end)
end

local function point(position: Vector3): Rules.Point
	return { X = position.X, Y = position.Y, Z = position.Z }
end

local function areaBox(area: Instance, id: string): Rules.Box?
	local bounds = area:FindFirstChild("Bounds")
	if bounds and bounds:IsA("BasePart") then
		return {
			id = id,
			min = point(bounds.Position - bounds.Size / 2),
			max = point(bounds.Position + bounds.Size / 2),
		}
	end
	local minimum: Vector3? = nil
	local maximum: Vector3? = nil
	for _, part in area:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local ancestor: Instance? = part
		local excluded = false
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
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = part.CFrame:PointToWorldSpace(part.Size / 2 * Vector3.new(x, y, z))
					minimum = if minimum then minimum:Min(corner) else corner
					maximum = if maximum then maximum:Max(corner) else corner
				end
			end
		end
	end
	if minimum and maximum then
		return { id = id, min = point(minimum), max = point(maximum + Vector3.new(0, 50, 0)) }
	end
	return nil
end

local function rootPart(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function SoundController.Init()
	-- NetClient.On e criação da interface podem esperar replicação: ficam em Start.
end

function SoundController.Start()
	if started then
		return
	end
	started = true
	local folder = Instance.new("Folder")
	folder.Name = "CandyAudio"
	folder.Parent = SoundService
	for key, definition in Sounds.SFX do
		local pool: { Sound } = {}
		for index = 1, if key == "BlockHit" then 3 else 1 do
			local sound = Instance.new("Sound")
			sound.Name = key .. tostring(index)
			sound.SoundId = definition.AssetId
			sound.Volume = definition.Volume
			sound.Parent = folder
			table.insert(pool, sound)
		end
		pools[key] = pool
	end
	for key, definition in Sounds.Music do
		local sound = Instance.new("Sound")
		sound.Name = key
		sound.SoundId = definition.AssetId
		sound.Volume = 0
		sound.Looped = true
		sound.Parent = folder
		tracks[key] = sound
	end
	SettingsUI.Create(toggle)
	DataController.Observe("Settings", function(value: any)
		if type(value) ~= "table" or type(value.Music) ~= "boolean" or type(value.Sfx) ~= "boolean" then
			return
		end
		loaded = true
		for _, key in { "Music", "Sfx" } do
			if type(value[key]) == "boolean" then
				confirmed[key] = value[key]
				if not pending[key] then
					settings[key] = value[key]
				end
			end
		end
		applySettings()
	end)
	local areaCount: number? = nil
	DataController.Observe("UnlockedAreas", function(value: any)
		if type(value) == "table" then
			if areaCount and #value > areaCount then
				sfx("AreaUnlock")
			end
			areaCount = #value
		end
	end)
	local inventory: { [string]: any }? = nil
	DataController.Observe("Inventory", function(value: any)
		if type(value) ~= "table" then
			return
		end
		local count = 0
		local previousCount = 0
		local special = false
		local previous = inventory
		if previous then
			for _ in previous do
				previousCount += 1
			end
		end
		for uuid, pet in value do
			count += 1
			if previous and not previous[uuid] then
				local definition = Pets[pet.Id]
				special = special or pet.Variant == "Golden" or (definition ~= nil and definition.Rarity == "Legendary")
			end
		end
		if previous and count > previousCount then
			sfx(if special then "LegendaryPet" else "EggHatch")
		end
		inventory = table.clone(value)
	end)
	local recentHits: { [string]: number } = {}
	local playedBreaks: { [string]: boolean } = {}
	local function playBreakOnce(id: string, blockType: string)
		local key, blockId = Rules.breakFromReward({ blockId = id, blockType = blockType }, playedBreaks)
		if key and blockId then
			playedBreaks[blockId] = true
			sfx(key)
		end
	end
	NetClient.On("BlockHit", function(id: string, _hp: number, _max: number, _damage: number, attacker: Player)
		if attacker == Players.LocalPlayer and type(id) == "string" then
			local now = os.clock()
			recentHits[id] = now
			task.delay(10, function()
				if recentHits[id] == now then
					recentHits[id] = nil
				end
			end)
			sfx("BlockHit", random:NextNumber(0.9, 1.1))
		end
	end)
	NetClient.On("BlockBroken", function(id: string, _position: Vector3, blockType: string)
		local hitAt = recentHits[id]
		if hitAt and os.clock() - hitAt <= 10 then
			recentHits[id] = nil
			playBreakOnce(id, blockType)
		end
	end)
	NetClient.On("Notify", function(code: string, payload: any)
		if code ~= "REWARD" then
			if os.clock() - lastError >= 0.5 then
				lastError = os.clock()
				sfx("Error")
			end
			return
		end
		if type(payload) ~= "table" then
			return
		end
		local key, blockId = Rules.breakFromReward(payload, playedBreaks)
		if key and blockId then
			playedBreaks[blockId] = true
			sfx(key)
		end
		if type(payload.coins) == "number" and payload.coins > 0 then
			sfx("CoinsCollect")
		end
		if type(payload.gems) == "number" and payload.gems > 0 then
			sfx("GemsCollect")
		end
	end)
	task.spawn(function()
		local ids: { string } = {}
		for id in Areas do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			return Areas[a].Order < Areas[b].Order
		end)
		local boxes: { Rules.Box } = {}
		local areasFolder: Instance? = nil
		local connections: { RBXScriptConnection } = {}
		local dirty = true
		local function watchAreas(nextFolder: Instance?)
			for _, connection in connections do
				connection:Disconnect()
			end
			table.clear(connections)
			areasFolder = nextFolder
			dirty = true
			if nextFolder then
				local function invalidate()
					dirty = true
				end
				table.insert(connections, nextFolder.ChildAdded:Connect(invalidate))
				table.insert(connections, nextFolder.DescendantAdded:Connect(invalidate))
				table.insert(connections, nextFolder.DescendantRemoving:Connect(invalidate))
			end
		end
		while folder.Parent do
			local found = workspace:FindFirstChild("Areas")
			if found ~= areasFolder then
				watchAreas(found)
			end
			if dirty then
				table.clear(boxes)
				if areasFolder then
					for _, id in ids do
						local area = areasFolder:FindFirstChild(id)
						local box = if area then areaBox(area, id) else nil
						if box then
							table.insert(boxes, box)
						end
					end
				end
				dirty = false
			end
			local root = rootPart()
			if root and areasFolder then
				local id = Rules.areaAt(boxes, point(root.Position))
				if id and id ~= currentArea then
					-- Interrompe fades mais antigos antes de iniciar outro crossfade.
					for key, sound in tracks do
						if key ~= currentArea then
							local tween = tweens[sound]
							if tween then
								tweens[sound] = nil
								tween:Cancel()
							end
							sound:Pause()
							sound.Volume = 0
						end
					end
					currentArea = id
					applySettings()
				end
			end
			task.wait(1)
		end
		watchAreas(nil)
	end)
end

return SoundController
