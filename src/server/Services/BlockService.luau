--!strict
-- BlockService.luau (ServerScriptService.Server.Services.BlockService)
-- Dono: Squad A. Blocos, validação dos golpes, recompensa e respawn no servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.Game)
local Areas = require(Shared.Config.Areas)
local Blocks = require(Shared.Config.Blocks)
local Formulas = require(Shared.Logic.Formulas)
local NetServer = require(script.Parent.Parent.Net.NetServer)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PetService = require(script.Parent.PetService)

type BlockState = {
	model: Model,
	spawn: BasePart,
	area: string,
	blockType: string,
	hp: number,
	maxHp: number,
	dead: boolean,
	damageLog: { Formulas.Hit },
}

local states: { [string]: BlockState } = {}
local random = Random.new()
local blocksFolder: Folder
local colors: { [string]: Color3 } = {
	GummyBlock = Color3.fromRGB(255, 100, 160),
	LollipopBlock = Color3.fromRGB(100, 220, 255),
	ChocoBlock = Color3.fromRGB(110, 65, 40),
	CloudBlock = Color3.fromRGB(230, 200, 255),
}

local function spawnBlock(spawn: BasePart, areaId: string)
	if not spawn:IsDescendantOf(Workspace) then
		return
	end
	local area = Areas[areaId]
	if not area then
		return
	end
	local blockType = spawn:GetAttribute("BlockType")
	if blockType == nil and #area.Blocks > 0 then
		blockType = area.Blocks[random:NextInteger(1, #area.Blocks)]
	end
	if typeof(blockType) ~= "string" or not Blocks[blockType] then
		warn(`[BlockService] Tipo de bloco inválido no spawn {spawn:GetFullName()}`)
		return
	end
	local definition = Blocks[blockType]
	local templates = ServerStorage:FindFirstChild("BlockTemplates")
	local template = templates and templates:FindFirstChild(blockType)
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
		-- O sync ao vivo do Rojo não preenche PrimaryPart; busca o filho 'Core' como fallback
		if not model.PrimaryPart then
			local core = model:FindFirstChild("Core")
			if core and core:IsA("BasePart") then
				model.PrimaryPart = core
			end
		end
		if not model.PrimaryPart then
			model:Destroy()
			model = Instance.new("Model")
			local part = Instance.new("Part")
			part.Size = Vector3.new(4, 4, 4)
			part.Anchored = true
			part.Color = colors[blockType] or Color3.fromRGB(255, 255, 255)
			part.Parent = model
			model.PrimaryPart = part
		end
	else
		model = Instance.new("Model")
		local part = Instance.new("Part")
		part.Size = Vector3.new(4, 4, 4)
		part.Anchored = true
		part.Color = colors[blockType] or Color3.fromRGB(255, 255, 255)
		part.Parent = model
		model.PrimaryPart = part
	end
	model.Name = blockType
	model:PivotTo(spawn.CFrame)
	local id = HttpService:GenerateGUID(false)
	model:SetAttribute("BlockId", id)
	model:SetAttribute("BlockType", blockType)
	model:SetAttribute("HP", definition.MaxHP)
	model:SetAttribute("MaxHP", definition.MaxHP)
	model:SetAttribute("Area", areaId)
	states[id] = {
		model = model,
		spawn = spawn,
		area = areaId,
		blockType = blockType,
		hp = definition.MaxHP,
		maxHp = definition.MaxHP,
		dead = false,
		damageLog = {},
	}
	model.Parent = blocksFolder
end

local function onClick(player: Player, blockId: any)
	if typeof(blockId) ~= "string" or #blockId < 1 or #blockId > 64 then
		return
	end
	local state = states[blockId]
	if not state or state.dead or state.hp <= 0 or state.model.Parent ~= blocksFolder then
		return
	end
	if player.Parent ~= Players or DataService.Get(player) == nil or not EconomyService.HasArea(player, state.area) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local primary = state.model.PrimaryPart
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") or not primary then
		return
	end
	local position = primary.Position
	local reach = GameConfig.MaxHitDistance + GameConfig.HitDistanceTolerance
	if not ((root.Position - position).Magnitude <= reach) then
		return
	end
	local damage = Formulas.damage(GameConfig.BaseDamage, PetService.GetDamageBonus(player))
	if damage ~= damage or damage <= 0 or damage == math.huge then
		return
	end
	-- Guardar dano efetivo mantém o rateio correto mesmo após remover quem saiu.
	table.insert(state.damageLog, { key = player, damage = math.min(damage, state.hp) })
	state.hp = math.max(0, state.hp - damage)
	state.dead = state.hp == 0
	state.model:SetAttribute("HP", state.hp)
	NetServer.FireNearby("BlockHit", position, GameConfig.EffectsRadius, blockId, state.hp, state.maxHp, damage, player)
	if not state.dead then
		return
	end
	states[blockId] = nil
	local definition = Blocks[state.blockType]
	local rewards = Formulas.splitReward(definition.Coins, definition.Gems, state.maxHp, state.damageLog)
	for recipient, reward in rewards do
		if recipient.Parent == Players then
			local coins = EconomyService.AddCoins(recipient, reward.coins)
			local gems = EconomyService.AddGems(recipient, reward.gems)
			if coins > 0 or gems > 0 then
				NetServer.Fire("Notify", recipient, "REWARD", { coins = coins, gems = gems })
			end
		end
	end
	NetServer.FireNearby("BlockBroken", position, GameConfig.EffectsRadius, blockId, position, state.blockType)
	state.model:Destroy()
	task.delay(definition.RespawnSeconds, function()
		spawnBlock(state.spawn, state.area)
	end)
end

local BlockService = {}

function BlockService.Init()
	NetServer.OnEvent("RequestClick", onClick, { rate = GameConfig.ClicksPerSecond, burst = GameConfig.ClickBurst })
	Players.PlayerRemoving:Connect(function(player)
		for _, state in states do
			for index = #state.damageLog, 1, -1 do
				if state.damageLog[index].key == player then
					table.remove(state.damageLog, index)
				end
			end
		end
	end)
end

function BlockService.Start()
	local existing = Workspace:FindFirstChild("Blocks")
	if existing and existing:IsA("Folder") then
		blocksFolder = existing
	else
		blocksFolder = Instance.new("Folder")
		blocksFolder.Name = "Blocks"
		blocksFolder.Parent = Workspace
	end
	local spawns: { { spawn: BasePart, area: string } } = {}
	local areasFolder = Workspace:FindFirstChild("Areas")
	if areasFolder then
		for _, area in areasFolder:GetChildren() do
			local folder = area:FindFirstChild("BlockSpawns")
			if folder then
				for _, spawn in folder:GetChildren() do
					if spawn:IsA("BasePart") then
						table.insert(spawns, { spawn = spawn, area = area.Name })
					end
				end
			end
		end
	end
	if #spawns == 0 then
		if not RunService:IsStudio() then
			warn("[BlockService] Nenhum BlockSpawn encontrado; nenhum bloco será criado.")
			return
		end
		if not areasFolder then
			areasFolder = Instance.new("Folder")
			areasFolder.Name = "Areas"
			areasFolder.Parent = Workspace
		end
		local area = areasFolder:FindFirstChild("CandyPlaza")
		if not area then
			area = Instance.new("Folder")
			area.Name = "CandyPlaza"
			area.Parent = areasFolder
		end
		local folder = area:FindFirstChild("BlockSpawns")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "BlockSpawns"
			folder.Parent = area
		end
		for index = 1, 6 do
			local angle = (index - 1) * math.pi / 3
			local spawn = Instance.new("Part")
			spawn.Name = `Spawn{index}`
			spawn.Anchored = true
			spawn.CanCollide = false
			spawn.CanQuery = false
			spawn.CanTouch = false
			spawn.Transparency = 1
			spawn.CFrame = CFrame.new(25 * math.cos(angle), 3, 25 * math.sin(angle))
			spawn.Parent = folder
			table.insert(spawns, { spawn = spawn :: BasePart, area = "CandyPlaza" })
		end
	end
	for _, entry in spawns do
		spawnBlock(entry.spawn, entry.area)
	end
end

return BlockService
