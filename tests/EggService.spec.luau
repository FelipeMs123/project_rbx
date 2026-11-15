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

	local function setEggInWorkspace(areaId: string, eggId: string, eggInstance: any)
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
		eggsFolder._children[eggId] = eggInstance
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

			-- Model sem PrimaryPart usa GetPivot().Position
			local pivotEgg = makeInstance("CandyEgg", "Model", {}, {
				GetPivot = function()
					return { Position = makeVector3(100, 3, 0) }
				end,
			})
			h.setEggInWorkspace("CandyPlaza", "CandyEgg", pivotEgg)
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
end
