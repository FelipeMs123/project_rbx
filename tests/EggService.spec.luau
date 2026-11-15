--!nocheck
-- tests/EggService.spec.luau (Lune). Dono: Squad B. Testes de integração do EggService com mocks de Roblox/DataService/NetServer.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local RateLimiter = require("../src/shared/Logic/RateLimiter")

local function makeSignal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			local token = {}
			listeners[token] = fn
			return {
				Disconnect = function()
					listeners[token] = nil
				end,
			}
		end,
		Fire = function(_, ...)
			for _, fn in listeners do
				fn(...)
			end
		end,
	}
end

local function makeVector3(x: number, y: number, z: number)
	local vec = { X = x, Y = y, Z = z }
	setmetatable(vec, {
		__sub = function(a, b)
			local dx = a.X - b.X
			local dy = a.Y - b.Y
			local dz = a.Z - b.Z
			return {
				X = dx,
				Y = dy,
				Z = dz,
				Magnitude = math.sqrt(dx * dx + dy * dy + dz * dz),
			}
		end,
	})
	return vec
end

local function makeInstance(name: string, className: string, children: { [string]: any }?, props: { [string]: any }?)
	local instance = {
		Name = name,
		ClassName = className,
		_children = children or {},
	}
	if props then
		for k, v in props do
			instance[k] = v
		end
	end
	function instance:IsA(targetClass: string)
		if self.ClassName == targetClass then
			return true
		end
		if targetClass == "BasePart" and (self.ClassName == "Part" or self.ClassName == "BasePart") then
			return true
		end
		return false
	end
	function instance:FindFirstChild(childName: string)
		return self._children[childName]
	end
	function instance:FindFirstChildOfClass(targetClass: string)
		for _, child in self._children do
			if child:IsA(targetClass) then
				return child
			end
		end
		return nil
	end
	function instance:FindFirstChildWhichIsA(targetClass: string, recursive: boolean?)
		for _, child in self._children do
			if child:IsA(targetClass) then
				return child
			end
			if recursive then
				local nested = child:FindFirstChildWhichIsA(targetClass, true)
				if nested ~= nil then
					return nested
				end
			end
		end
		return nil
	end
	if className == "Model" and instance.GetPivot == nil then
		function instance:GetPivot()
			return { Position = makeVector3(0, 0, 0) }
		end
	end
	if className == "Model" and instance.GetBoundingBox == nil then
		function instance:GetBoundingBox()
			local minX, minY, minZ = math.huge, math.huge, math.huge
			local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
			local found = false
			local function visit(node)
				for _, child in node._children do
					if child:IsA("BasePart") and child.Position ~= nil then
						found = true
						local p = child.Position
						minX = math.min(minX, p.X)
						minY = math.min(minY, p.Y)
						minZ = math.min(minZ, p.Z)
						maxX = math.max(maxX, p.X)
						maxY = math.max(maxY, p.Y)
						maxZ = math.max(maxZ, p.Z)
					end
					visit(child)
				end
			end
			visit(self)
			if not found then
				return { Position = makeVector3(0, 0, 0) }, makeVector3(0, 0, 0)
			end
			return {
				Position = makeVector3((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2),
			},
				makeVector3(maxX - minX, maxY - minY, maxZ - minZ)
		end
	end
	return instance
end

local function loadEggServiceHarness(options: {
	randomValues: { number }?,
	overrideEggs: { [string]: any }?,
	failAddPetWith: string?,
}?)
	local opts = options or {}
	local moduleCache = {}
	local guidCounter = 0
	local nowClock = 100
	local saveCount = 0
	local randomQueue = opts.randomValues or { 0.0 }
	local randomIndex = 0

	local playerRemovingSignal = makeSignal()
	local mockPlayersList = {}
	local mockPlayers = {
		PlayerRemoving = playerRemovingSignal,
		GetPlayers = function()
			return mockPlayersList
		end,
	}

	local mockWorkspace = makeInstance("Workspace", "Workspace", {})

	local function makePlayer(userId: number, name: string)
		local attributes = {}
		local player = {
			UserId = userId,
			Name = name,
			Parent = mockPlayers,
			Character = nil,
			SetAttribute = function(_, key, value)
				attributes[key] = value
			end,
			GetAttribute = function(_, key)
				return attributes[key]
			end,
		}
		table.insert(mockPlayersList, player)
		return player
	end

	local function setCharacterAt(player, position, health: number?)
		local hp = if health ~= nil then health else 100
		local humanoid = makeInstance("Humanoid", "Humanoid", nil, { Health = hp })
		local root = makeInstance("HumanoidRootPart", "Part", nil, { Position = position })
		player.Character = makeInstance("Character", "Model", {
			Humanoid = humanoid,
			HumanoidRootPart = root,
		})
	end

	local function setEggInWorkspace(areaId: string, eggId: string?, eggInstance: any?)
		local areasFolder = mockWorkspace._children.Areas
		if not areasFolder then
			areasFolder = makeInstance("Areas", "Folder", {})
			mockWorkspace._children.Areas = areasFolder
		end
		local areaFolder = areasFolder._children[areaId]
		if not areaFolder then
			areaFolder = makeInstance(areaId, "Folder", {})
			areasFolder._children[areaId] = areaFolder
		end
		local eggsFolder = areaFolder._children.Eggs
		if not eggsFolder then
			eggsFolder = makeInstance("Eggs", "Folder", {})
			areaFolder._children.Eggs = eggsFolder
		end
		if eggId ~= nil then
			eggsFolder._children[eggId] = eggInstance
		end
	end

	local function clearWorkspaceAreas()
		mockWorkspace._children.Areas = nil
	end

	local mockHttpService = {
		GenerateGUID = function(_, wrapBraces: boolean)
			guidCounter += 1
			local raw = string.format("00000000-0000-4000-8000-%012d", guidCounter)
			return if wrapBraces then `\{{raw}\}` else raw
		end,
	}

	local dataStore = {}
	local loadedSignal = makeSignal()
	local changedSignal = makeSignal()

	local mockDataService = {
		Loaded = loadedSignal,
		Changed = changedSignal,
		Get = function(player)
			return dataStore[player]
		end,
		IsLoaded = function(player)
			return dataStore[player] ~= nil
		end,
		Set = function(player, key, value)
			local data = dataStore[player]
			if data == nil then
				return false
			end
			data[key] = value
			changedSignal:Fire(player, key, value)
			return true
		end,
		Update = function(player, key, modifier)
			local data = dataStore[player]
			if data == nil then
				return nil
			end
			local newValue = modifier(data[key])
			data[key] = newValue
			changedSignal:Fire(player, key, newValue)
			return newValue
		end,
		Save = function()
			saveCount += 1
		end,
	}

	local registeredInvokes = {}
	local mockNetServer = {
		OnInvoke = function(name, handler, invokeOptions)
			local rate = (invokeOptions and invokeOptions.rate) or 5
			local burst = (invokeOptions and invokeOptions.burst) or rate
			registeredInvokes[name] = {
				handler = handler,
				options = invokeOptions,
				limiter = RateLimiter.new(rate, burst),
			}
		end,
	}

	local function invokeRemote(name, player, ...)
		local entry = registeredInvokes[name]
		assert(entry ~= nil, `Remote {name} não registrado`)
		if not entry.limiter:Allow(player, nowClock) then
			return { ok = false, err = "RATE_LIMITED" }
		end
		return entry.handler(player, ...)
	end

	local function makeNode(name, path)
		return { Name = name, _path = path }
	end

	local sharedNode = makeNode("Shared")
	local configNode = makeNode("Config")
	local logicNode = makeNode("Logic")
	local utilNode = makeNode("Util")
	local typesNode = makeNode("Types", "src/shared/Types.luau")
	local errorCodesNode = makeNode("ErrorCodes", "src/shared/ErrorCodes.luau")
	local gameConfigNode = makeNode("Game", "src/shared/Config/Game.luau")
	local petsConfigNode = makeNode("Pets", "src/shared/Config/Pets.luau")
	local eggsConfigNode = makeNode("Eggs", "src/shared/Config/Eggs.luau")
	local economyLogicNode = makeNode("Economy", "src/shared/Logic/Economy.luau")
	local inventoryNode = makeNode("Inventory", "src/shared/Logic/Inventory.luau")
	local requestIdempotencyNode = makeNode("RequestIdempotency", "src/shared/Logic/RequestIdempotency.luau")
	local weightedRollNode = makeNode("WeightedRoll", "src/shared/Logic/WeightedRoll.luau")
	local signalNode = makeNode("Signal", "src/shared/Util/Signal.luau")

	sharedNode.Config = configNode
	sharedNode.Logic = logicNode
	sharedNode.Util = utilNode
	sharedNode.Types = typesNode
	sharedNode.ErrorCodes = errorCodesNode

	configNode.Parent = sharedNode
	configNode.Game = gameConfigNode
	configNode.Pets = petsConfigNode
	configNode.Eggs = eggsConfigNode

	logicNode.Parent = sharedNode
	logicNode.Economy = economyLogicNode
	logicNode.Inventory = inventoryNode
	logicNode.RequestIdempotency = requestIdempotencyNode
	logicNode.WeightedRoll = weightedRollNode

	utilNode.Parent = sharedNode
	utilNode.Signal = signalNode

	typesNode.Parent = sharedNode
	errorCodesNode.Parent = sharedNode
	gameConfigNode.Parent = configNode
	petsConfigNode.Parent = configNode
	eggsConfigNode.Parent = configNode
	economyLogicNode.Parent = logicNode
	inventoryNode.Parent = logicNode
	requestIdempotencyNode.Parent = logicNode
	weightedRollNode.Parent = logicNode
	signalNode.Parent = utilNode

	local serverNode = makeNode("Server")
	local servicesNode = makeNode("Services")
	local netNode = makeNode("Net")
	local dataServiceNode = makeNode("DataService")
	local economyServiceNode = makeNode("EconomyService", "src/server/Services/EconomyService.luau")
	local petServiceNode = makeNode("PetService", "src/server/Services/PetService.luau")
	local eggServiceNode = makeNode("EggService", "src/server/Services/EggService.luau")
	local netServerNode = makeNode("NetServer")

	serverNode.Services = servicesNode
	serverNode.Net = netNode
	servicesNode.Parent = serverNode
	servicesNode.DataService = dataServiceNode
	servicesNode.EconomyService = economyServiceNode
	servicesNode.PetService = petServiceNode
	servicesNode.EggService = eggServiceNode
	netNode.Parent = serverNode
	netNode.NetServer = netServerNode
	dataServiceNode.Parent = servicesNode
	economyServiceNode.Parent = servicesNode
	petServiceNode.Parent = servicesNode
	eggServiceNode.Parent = servicesNode
	netServerNode.Parent = netNode

	moduleCache[dataServiceNode] = mockDataService
	moduleCache[netServerNode] = mockNetServer
	if opts.overrideEggs ~= nil then
		moduleCache[eggsConfigNode] = opts.overrideEggs
	end

	local mockReplicatedStorage = {
		Shared = sharedNode,
	}

	local mockGame = {
		GetService = function(_, serviceName)
			if serviceName == "Players" then
				return mockPlayers
			elseif serviceName == "ReplicatedStorage" then
				return mockReplicatedStorage
			elseif serviceName == "HttpService" then
				return mockHttpService
			elseif serviceName == "Workspace" then
				return mockWorkspace
			end
			error(`Serviço não mockado: {serviceName}`)
		end,
	}

	local mockRandom = {
		new = function()
			return {
				NextNumber = function()
					randomIndex += 1
					return randomQueue[((randomIndex - 1) % #randomQueue) + 1]
				end,
			}
		end,
	}

	local function loadModule(node)
		if moduleCache[node] ~= nil then
			return moduleCache[node]
		end
		assert(node._path ~= nil, `Módulo sem caminho: {node.Name}`)
		local source = fs.readFile(node._path)
		local bytecode = luau.compile(source)
		local env = {
			game = mockGame,
			script = node,
			typeof = type,
			warn = function() end,
			task = task,
			Random = mockRandom,
			Vector3 = { new = makeVector3 },
			require = loadModule,
		}
		setmetatable(env, { __index = _G })
		local fn = luau.load(bytecode, { debugName = node._path, environment = env })
		local result = fn()
		moduleCache[node] = result
		return result
	end

	local PetService = loadModule(petServiceNode)
	local EconomyService = loadModule(economyServiceNode)

	if opts.failAddPetWith ~= nil then
		PetService.AddPet = function()
			return nil, opts.failAddPetWith
		end
	end

	local EggService = loadModule(eggServiceNode)

	return {
		EggService = EggService,
		PetService = PetService,
		EconomyService = EconomyService,
		makePlayer = makePlayer,
		setCharacterAt = setCharacterAt,
		setEggInWorkspace = setEggInWorkspace,
		clearWorkspaceAreas = clearWorkspaceAreas,
		setLoadedData = function(player, data)
			dataStore[player] = data
			loadedSignal:Fire(player, data)
		end,
		getData = function(player)
			return dataStore[player]
		end,
		invokeRemote = invokeRemote,
		getRegisteredInvokes = function()
			return registeredInvokes
		end,
		getSaveCount = function()
			return saveCount
		end,
		advanceClock = function(seconds)
			nowClock += seconds
		end,
		firePlayerRemoving = function(player)
			playerRemovingSignal:Fire(player)
		end,
	}
end

return function(t)
	t.test("PurchaseEgg valida argumentos, item desconhecido, perfil carregado e área liberada", function()
		local h = loadEggServiceHarness()
		h.PetService.Init()
		h.EggService.Init()

		local p1 = h.makePlayer(1, "Alice")

		-- Argumentos inválidos antes mesmo do perfil carregar
		for _, bad in { "", 123, string.rep("a", 65), {} } do
			local res = h.invokeRemote("PurchaseEgg", p1, bad)
			t.eq(res.ok, false)
			t.eq(res.err, "INVALID_ARGS")
		end
		local nilRes = h.invokeRemote("PurchaseEgg", p1, nil)
		t.eq(nilRes.ok, false)
		t.eq(nilRes.err, "INVALID_ARGS")

		-- Ovo desconhecido
		h.advanceClock(2)
		local unknownRes = h.invokeRemote("PurchaseEgg", p1, "DiamondEgg")
		t.eq(unknownRes.ok, false)
		t.eq(unknownRes.err, "UNKNOWN_ITEM")

		-- Perfil não carregado
		local unloadedRes = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
		t.eq(unloadedRes.ok, false)
		t.eq(unloadedRes.err, "DATA_NOT_LOADED")

		h.setLoadedData(p1, {
			Version = 1,
			Coins = 5000,
			Gems = 0,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {},
			Equipped = {},
		})

		-- Área bloqueada não cobra moedas nem entrega pet
		local lockedRes = h.invokeRemote("PurchaseEgg", p1, "ChocolateEgg")
		t.eq(lockedRes.ok, false)
		t.eq(lockedRes.err, "AREA_LOCKED")
		t.eq(h.getData(p1).Coins, 5000)
		t.eq(next(h.getData(p1).Inventory), nil)
		t.eq(h.getSaveCount(), 0)
	end)

	t.test(
		"PurchaseEgg checa distância server-side quando o ovo existe no Workspace e aceita modo headless",
		function()
			local h = loadEggServiceHarness({ randomValues = { 0.3 } })
			h.PetService.Init()
			h.EggService.Init()

			local p1 = h.makePlayer(1, "Alice")
			h.setLoadedData(p1, {
				Version = 1,
				Coins = 1000,
				Gems = 0,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza" },
				Inventory = {},
				Equipped = {},
			})

			-- Model com PrimaryPart em (0, 3, -28)
			local eggPart = makeInstance("Primary", "Part", nil, { Position = makeVector3(0, 3, -28) })
			local eggModel = makeInstance("CandyEgg", "Model", { Primary = eggPart }, { PrimaryPart = eggPart })
			h.setEggInWorkspace("CandyPlaza", "CandyEgg", eggModel)

			-- Sem Character -> TOO_FAR sem cobrar
			local res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 1000)

			-- Character morto -> TOO_FAR sem cobrar
			h.setCharacterAt(p1, makeVector3(0, 3, -20), 0)
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 1000)

			-- Longe demais (25 studs > 24) -> TOO_FAR sem cobrar
			h.setCharacterAt(p1, makeVector3(0, 3, -3), 100)
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 1000)

			-- Perto (14 studs <= 24) -> sucesso
			h.advanceClock(2)
			h.setCharacterAt(p1, makeVector3(0, 3, -14), 100)
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, true)
			t.eq(res.data.petId, "CottonCat")
			t.eq(h.getData(p1).Coins, 900)

			-- Model sem PrimaryPart e sem Core, com BasePart física, usa GetBoundingBox().Position e ignora GetPivot() na origem
			local bboxEgg = makeInstance("CandyEgg", "Model", {
				Body = makeInstance("Body", "Part", nil, { Position = makeVector3(100, 3, 0) }),
			}, {
				GetPivot = function()
					return { Position = makeVector3(0, 0, 0) }
				end,
			})
			h.setEggInWorkspace("CandyPlaza", "CandyEgg", bboxEgg)
			h.setCharacterAt(p1, makeVector3(0, 0, 0), 100)
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 900)

			h.setCharacterAt(p1, makeVector3(120, 3, 0), 100) -- 20 studs <= 24
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, true)
			t.eq(h.getData(p1).Coins, 800)

			-- Sem mapa no Workspace (headless) não quebra mesmo sem Character
			h.clearWorkspaceAreas()
			p1.Character = nil
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, true)
			t.eq(h.getData(p1).Coins, 700)
		end
	)

	t.test(
		"PurchaseEgg aplica fallback canônico quando Eggs existe vazia e falha fechado em instância inválida",
		function()
			local h = loadEggServiceHarness({ randomValues = { 0.3 } })
			h.PetService.Init()
			h.EggService.Init()

			local p1 = h.makePlayer(1, "Alice")
			h.setLoadedData(p1, {
				Version = 1,
				Coins = 10000,
				Gems = 0,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza", "ChocolateFalls" },
				Inventory = {},
				Equipped = {},
			})

			-- Pasta CandyPlaza.Eggs existe, mas está vazia (cenário pré-B6)
			h.setEggInWorkspace("CandyPlaza")

			-- Sem Character -> TOO_FAR (não é fail-open)
			local res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 10000)

			-- Character morto perto do pedestal -> TOO_FAR
			h.setCharacterAt(p1, makeVector3(0, 2.6, -28), 0)
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 10000)

			-- Character longe do pedestal (0, 2.6, -28) -> TOO_FAR (> 24 studs)
			h.setCharacterAt(p1, makeVector3(0, 3, -3), 100)
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 10000)

			-- Character vivo perto do pedestal (0, 2.6, -28) -> sucesso
			h.advanceClock(2)
			h.setCharacterAt(p1, makeVector3(0, 3, -14), 100)
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, true)
			t.eq(h.getData(p1).Coins, 9900)

			-- Character usando PrimaryPart (sem HumanoidRootPart) perto do pedestal -> sucesso
			local humanoid = makeInstance("Humanoid", "Humanoid", nil, { Health = 100 })
			local primary = makeInstance("Torso", "Part", nil, { Position = makeVector3(0, 3, -20) })
			p1.Character = makeInstance("Character", "Model", {
				Humanoid = humanoid,
				Torso = primary,
			}, { PrimaryPart = primary })
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, true)
			t.eq(h.getData(p1).Coins, 9800)

			-- ChocolateEgg também usa fallback canônico (140, 2.6, -28) quando ChocolateFalls ainda não está no mapa
			res = h.invokeRemote("PurchaseEgg", p1, "ChocolateEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 9800)

			h.setCharacterAt(p1, makeVector3(140, 3, -20), 100)
			res = h.invokeRemote("PurchaseEgg", p1, "ChocolateEgg")
			t.eq(res.ok, true)
			t.eq(h.getData(p1).Coins, 7300)

			-- Model vazio (com GetPivot padrão em 0,0,0, simulando PVInstance real) -> fail-closed mesmo com jogador em (0,0,0)
			h.advanceClock(2)
			h.setCharacterAt(p1, makeVector3(0, 0, 0), 100)
			local emptyModelEgg = makeInstance("CandyEgg", "Model", {})
			h.setEggInWorkspace("CandyPlaza", "CandyEgg", emptyModelEgg)
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 7300)

			-- Model sem PrimaryPart e apenas com Folder/Attachment (sem BasePart) -> também fail-closed em (0,0,0)
			local nonPhysicalModelEgg = makeInstance("CandyEgg", "Model", {
				Fx = makeInstance("Fx", "Folder", {}),
			})
			h.setEggInWorkspace("CandyPlaza", "CandyEgg", nonPhysicalModelEgg)
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 7300)

			-- Model sem PrimaryPart contendo BasePart física descendente -> ignora GetPivot() na origem, usa GetBoundingBox()
			local physicalChildModelEgg = makeInstance("CandyEgg", "Model", {
				Parts = makeInstance("Parts", "Folder", {
					Shell = makeInstance("Shell", "Part", nil, { Position = makeVector3(60, 2, 10) }),
				}),
			}, {
				GetPivot = function()
					return { Position = makeVector3(0, 0, 0) }
				end,
			})
			h.setEggInWorkspace("CandyPlaza", "CandyEgg", physicalChildModelEgg)
			-- Jogador na origem (onde GetPivot aponta) ainda recebe TOO_FAR
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 7300)

			h.setCharacterAt(p1, makeVector3(85, 2, 10), 100) -- 25 studs > 24
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 7300)

			h.setCharacterAt(p1, makeVector3(80, 2, 10), 100) -- 20 studs <= 24
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, true)
			t.eq(h.getData(p1).Coins, 7200)

			-- Model sem PrimaryPart com Core em (140, 5, -28) e GetPivot na origem (cenário sync ao vivo Rojo)
			h.advanceClock(2)
			local coreEgg = makeInstance("ChocolateEgg", "Model", {
				Core = makeInstance("Core", "Part", nil, { Position = makeVector3(140, 5, -28) }),
			}, {
				GetPivot = function()
					return { Position = makeVector3(0, 0, 0) }
				end,
				GetBoundingBox = function()
					return { Position = makeVector3(0, 0, 0) }, makeVector3(4, 4, 4)
				end,
			})
			h.setEggInWorkspace("ChocolateFalls", "ChocolateEgg", coreEgg)
			h.setCharacterAt(p1, makeVector3(0, 5, 0), 100) -- perto da origem, longe de (140, 5, -28)
			res = h.invokeRemote("PurchaseEgg", p1, "ChocolateEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 7200)

			h.setCharacterAt(p1, makeVector3(140, 5, -20), 100) -- 8 studs <= 24 do Core
			res = h.invokeRemote("PurchaseEgg", p1, "ChocolateEgg")
			t.eq(res.ok, true)
			t.eq(h.getData(p1).Coins, 4700)

			local folderEgg = makeInstance("CandyEgg", "Folder", {})
			h.setEggInWorkspace("CandyPlaza", "CandyEgg", folderEgg)
			res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, false)
			t.eq(res.err, "TOO_FAR")
			t.eq(h.getData(p1).Coins, 4700)

			-- Ovo sem instância e sem fallback canônico conhecido com Areas presente -> fail-closed
			local hCustom = loadEggServiceHarness({
				overrideEggs = {
					UnknownPosEgg = {
						Name = "Ovo Sem Posição",
						Price = 10,
						Currency = "Coins",
						Area = "CandyPlaza",
						Weights = { CottonCat = 100 },
					},
				},
			})
			hCustom.PetService.Init()
			hCustom.EggService.Init()
			local pCustom = hCustom.makePlayer(2, "Bob")
			hCustom.setLoadedData(pCustom, {
				Version = 1,
				Coins = 100,
				Gems = 0,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza" },
				Inventory = {},
				Equipped = {},
			})
			hCustom.setEggInWorkspace("CandyPlaza")
			hCustom.setCharacterAt(pCustom, makeVector3(0, 2.6, -28), 100)
			local customRes = hCustom.invokeRemote("PurchaseEgg", pCustom, "UnknownPosEgg")
			t.eq(customRes.ok, false)
			t.eq(customRes.err, "TOO_FAR")
			t.eq(hCustom.getData(pCustom).Coins, 100)

			-- Exceção headless mantida quando Workspace.Areas inteiro está ausente
			hCustom.clearWorkspaceAreas()
			pCustom.Character = nil
			customRes = hCustom.invokeRemote("PurchaseEgg", pCustom, "UnknownPosEgg")
			t.eq(customRes.ok, true)
			t.eq(hCustom.getData(pCustom).Coins, 90)
		end
	)

	t.test("PurchaseEgg recusa inventário cheio e saldo insuficiente sem cobrar", function()
		local h = loadEggServiceHarness()
		h.PetService.Init()
		h.EggService.Init()

		local p1 = h.makePlayer(1, "Alice")
		local fullInventory = {}
		for i = 1, 50 do
			fullInventory[`pet-{i}`] = { Id = "CottonCat" }
		end
		h.setLoadedData(p1, {
			Version = 1,
			Coins = 500,
			Gems = 0,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza", "ChocolateFalls" },
			Inventory = fullInventory,
			Equipped = {},
		})

		-- Inventário cheio recusa ANTES de cobrar
		local fullRes = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
		t.eq(fullRes.ok, false)
		t.eq(fullRes.err, "INVENTORY_FULL")
		t.eq(h.getData(p1).Coins, 500)
		t.eq(h.getSaveCount(), 0)

		-- Abre 1 vaga, mas saldo insuficiente para CandyEgg (99 < 100)
		h.getData(p1).Inventory["pet-50"] = nil
		h.getData(p1).Coins = 99
		local poorRes = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
		t.eq(poorRes.ok, false)
		t.eq(poorRes.err, "NOT_ENOUGH_COINS")
		t.eq(h.getData(p1).Coins, 99)
		t.eq(h.getData(p1).Inventory["pet-50"], nil)
		t.eq(h.getSaveCount(), 0)

		-- ChocolateEgg exige 2500
		h.getData(p1).Coins = 2499
		local poorChoco = h.invokeRemote("PurchaseEgg", p1, "ChocolateEgg")
		t.eq(poorChoco.ok, false)
		t.eq(poorChoco.err, "NOT_ENOUGH_COINS")
		t.eq(h.getData(p1).Coins, 2499)
	end)

	t.test("PurchaseEgg sorteia por peso, entrega pet, salva perfil e atualiza inventário", function()
		-- Ordem alfabética CandyEgg: BearGummy (30), CottonCat (60), LollipopBunny (10)
		local h = loadEggServiceHarness({ randomValues = { 0.0, 0.3, 0.9 } })
		h.PetService.Init()
		h.EggService.Init()

		local p1 = h.makePlayer(1, "Alice")
		h.setLoadedData(p1, {
			Version = 1,
			Coins = 3000,
			Gems = 0,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza", "ChocolateFalls" },
			Inventory = {},
			Equipped = {},
		})

		local expected = { "BearGummy", "CottonCat", "LollipopBunny" }
		for i, expectedPet in expected do
			local res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, true)
			t.ok(type(res.data.uuid) == "string" and #res.data.uuid > 0)
			t.eq(res.data.petId, expectedPet)
			t.eq(h.getData(p1).Inventory[res.data.uuid].Id, expectedPet)
			t.eq(h.getData(p1).Coins, 3000 - i * 100)
			t.eq(h.getSaveCount(), i)
		end

		-- ChocolateEgg cobra 2500 e sorteia BearGummy com r = 0.0
		local chocoRes = h.invokeRemote("PurchaseEgg", p1, "ChocolateEgg")
		t.eq(chocoRes.ok, true)
		t.eq(chocoRes.data.petId, "BearGummy")
		t.eq(h.getData(p1).Coins, 200)
		t.eq(h.getSaveCount(), 4)
	end)

	t.test("PurchaseEgg faz rollback exato da moeda quando AddPet falha após Spend", function()
		-- Caso 1: Rebirths = 0
		local h0 = loadEggServiceHarness({ failAddPetWith = "INTERNAL" })
		h0.PetService.Init()
		h0.EggService.Init()

		local p0 = h0.makePlayer(1, "Alice")
		h0.setLoadedData(p0, {
			Version = 1,
			Coins = 500,
			Gems = 0,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {},
			Equipped = {},
		})
		local res0 = h0.invokeRemote("PurchaseEgg", p0, "CandyEgg")
		t.eq(res0.ok, false)
		t.eq(res0.err, "INTERNAL")
		t.eq(h0.getData(p0).Coins, 500)
		t.eq(h0.getSaveCount(), 0)

		-- Caso 2: Rebirths = 2 não deve inflar o refund pelo bônus de rebirth
		local h2 = loadEggServiceHarness({ failAddPetWith = "INTERNAL" })
		h2.PetService.Init()
		h2.EggService.Init()

		local p2 = h2.makePlayer(2, "Bob")
		h2.setLoadedData(p2, {
			Version = 1,
			Coins = 500,
			Gems = 0,
			Rebirths = 2,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {},
			Equipped = {},
		})
		local res2 = h2.invokeRemote("PurchaseEgg", p2, "CandyEgg")
		t.eq(res2.ok, false)
		t.eq(res2.err, "INTERNAL")
		t.eq(h2.getData(p2).Coins, 500)
		t.eq(h2.getSaveCount(), 0)

		-- Caso 2b: Multiplicador de moedas registrado (ex.: DoubleCoins 2x) com Rebirths = 0 não pode dobrar o estorno
		local hMult = loadEggServiceHarness({ failAddPetWith = "INTERNAL" })
		hMult.PetService.Init()
		hMult.EggService.Init()
		hMult.EconomyService.RegisterCoinMultiplier("DoubleCoins", function()
			return 2
		end)

		local pMult = hMult.makePlayer(4, "Davi")
		hMult.setLoadedData(pMult, {
			Version = 1,
			Coins = 500,
			Gems = 0,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {},
			Equipped = {},
		})
		local resMult = hMult.invokeRemote("PurchaseEgg", pMult, "CandyEgg")
		t.eq(resMult.ok, false)
		t.eq(resMult.err, "INTERNAL")
		t.eq(hMult.getData(pMult).Coins, 500)
		t.eq(hMult.getSaveCount(), 0)

		-- Caso 3: Ovo em Gems faz rollback de Gems e retorna NOT_ENOUGH_GEMS quando falta saldo
		local hGems = loadEggServiceHarness({
			failAddPetWith = "INTERNAL",
			overrideEggs = {
				GemEgg = {
					Name = "Ovo de Gema",
					Price = 10,
					Currency = "Gems",
					Area = "CandyPlaza",
					Weights = { JellyUnicorn = 100 },
				},
			},
		})
		hGems.PetService.Init()
		hGems.EggService.Init()

		local p3 = hGems.makePlayer(3, "Carol")
		hGems.setLoadedData(p3, {
			Version = 1,
			Coins = 0,
			Gems = 5,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {},
			Equipped = {},
		})
		local noGemsRes = hGems.invokeRemote("PurchaseEgg", p3, "GemEgg")
		t.eq(noGemsRes.ok, false)
		t.eq(noGemsRes.err, "NOT_ENOUGH_GEMS")
		t.eq(hGems.getData(p3).Gems, 5)

		hGems.getData(p3).Gems = 15
		local rollbackGemRes = hGems.invokeRemote("PurchaseEgg", p3, "GemEgg")
		t.eq(rollbackGemRes.ok, false)
		t.eq(rollbackGemRes.err, "INTERNAL")
		t.eq(hGems.getData(p3).Gems, 15)
	end)

	t.test("PurchaseEgg aplica rate limit de 4/s (burst 6)", function()
		local h = loadEggServiceHarness()
		h.PetService.Init()
		h.EggService.Init()

		local invokes = h.getRegisteredInvokes()
		t.eq(invokes.PurchaseEgg.options.rate, 4)
		t.eq(invokes.PurchaseEgg.options.burst, 6)

		local p1 = h.makePlayer(1, "Alice")
		h.setLoadedData(p1, {
			Version = 1,
			Coins = 1000,
			Gems = 0,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {},
			Equipped = {},
		})

		for i = 1, 6 do
			local res = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
			t.eq(res.ok, true, `chamada {i} dentro do burst deve passar`)
		end

		local limited = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
		t.eq(limited.ok, false)
		t.eq(limited.err, "RATE_LIMITED")
		t.eq(h.getData(p1).Coins, 400)

		-- Após 0.25s recupera 1 token (rate = 4/s)
		h.advanceClock(0.25)
		local recovered = h.invokeRemote("PurchaseEgg", p1, "CandyEgg")
		t.eq(recovered.ok, true)
		t.eq(h.getData(p1).Coins, 300)
	end)

	t.test(
		"PurchaseEgg é idempotente por requestId: bloqueia inFlight, devolve cache e limpa no PlayerRemoving",
		function()
			local h = loadEggServiceHarness({ randomValues = { 0.3 } })
			h.PetService.Init()
			h.EggService.Init()

			local p1 = h.makePlayer(1, "Alice")
			h.setLoadedData(p1, {
				Version = 1,
				Coins = 1000,
				Gems = 0,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza" },
				Inventory = {},
				Equipped = {},
			})

			-- requestId inválido é rejeitado sem cobrar
			local badReq = h.invokeRemote("PurchaseEgg", p1, "CandyEgg", "")
			t.eq(badReq.ok, false)
			t.eq(badReq.err, "INVALID_ARGS")
			t.eq(h.getData(p1).Coins, 1000)

			-- Simula execução lenta (inFlight) para testar retry concorrente com mesmo requestId
			local originalAddPet = h.PetService.AddPet
			local resumeSlowAdd = nil
			h.PetService.AddPet = function(player, petId)
				local co = coroutine.running()
				resumeSlowAdd = function()
					task.spawn(co)
				end
				coroutine.yield()
				return originalAddPet(player, petId)
			end

			local firstRes = nil
			task.spawn(function()
				firstRes = h.invokeRemote("PurchaseEgg", p1, "CandyEgg", "req-egg-1")
			end)
			t.ok(resumeSlowAdd ~= nil)

			-- Retry concorrente enquanto a primeira ainda está em voo no servidor -> RATE_LIMITED sem cobrar de novo
			local dupInFlight = h.invokeRemote("PurchaseEgg", p1, "CandyEgg", "req-egg-1")
			t.eq(dupInFlight.ok, false)
			t.eq(dupInFlight.err, "RATE_LIMITED")
			t.eq(h.getData(p1).Coins, 900)

			h.PetService.AddPet = originalAddPet
			resumeSlowAdd()
			t.ok(firstRes ~= nil and firstRes.ok == true)
			t.eq(h.getData(p1).Coins, 900)
			t.eq(h.getSaveCount(), 1)

			-- Retry após conclusão devolve o mesmo resultado cacheado sem cobrar nem criar novo pet
			local cachedRetry = h.invokeRemote("PurchaseEgg", p1, "CandyEgg", "req-egg-1")
			t.eq(cachedRetry.ok, true)
			t.eq(cachedRetry.data.uuid, firstRes.data.uuid)
			t.eq(cachedRetry.data.petId, firstRes.data.petId)
			t.eq(h.getData(p1).Coins, 900)
			t.eq(h.getSaveCount(), 1)

			-- PlayerRemoving limpa cache do jogador
			h.firePlayerRemoving(p1)
			local afterReconnect = h.invokeRemote("PurchaseEgg", p1, "CandyEgg", "req-egg-1")
			t.eq(afterReconnect.ok, true)
			t.eq(h.getData(p1).Coins, 800)
		end
	)
end
