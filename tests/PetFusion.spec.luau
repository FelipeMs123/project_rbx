--!nocheck
-- tests/PetFusion.spec.luau (Lune). Dono: Squad B. Testes completos da B7 (Fusão de pets 5->1 Dourado).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local FusionConfig = require("../src/shared/Config/Fusion")
local Inventory = require("../src/shared/Logic/Inventory")
local RateLimiter = require("../src/shared/Logic/RateLimiter")

local function loadPetsConfig(): { [string]: any }
	local env = {
		script = {
			Parent = {
				Parent = {},
			},
		},
		require = function()
			return nil
		end,
	}
	setmetatable(env, { __index = _G })
	local fn = luau.load(luau.compile(fs.readFile("src/shared/Config/Pets.luau")), {
		debugName = "src/shared/Config/Pets.luau",
		environment = env,
	})
	return fn()
end

local PetsConfig = loadPetsConfig()

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

local function loadFusionHarness()
	local moduleCache = {}
	local guidCounter = 0
	local nowClock = 200
	local saveCount = 0

	local playerRemovingSignal = makeSignal()
	local mockPlayersList = {}
	local mockPlayers = {
		PlayerRemoving = playerRemovingSignal,
		GetPlayers = function()
			return mockPlayersList
		end,
	}

	local function makePlayer(userId: number, name: string)
		local attributes = {}
		local player = {
			UserId = userId,
			Name = name,
			Parent = mockPlayers,
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

	local mockHttpService = {
		GenerateGUID = function(_, wrapBraces: boolean)
			guidCounter += 1
			local raw = string.format("00000000-0000-4000-9000-%012d", guidCounter)
			return if wrapBraces then `\{{raw}\}` else raw
		end,
	}

	local dataStore = {}
	local loadedSignal = makeSignal()
	local changedSignal = makeSignal()
	local failNextInventoryUpdate = false

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
			if key == "Inventory" and failNextInventoryUpdate then
				failNextInventoryUpdate = false
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
		OnInvoke = function(name, handler, options)
			local rate = (options and options.rate) or 5
			local burst = (options and options.burst) or rate
			registeredInvokes[name] = {
				handler = handler,
				options = options,
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
	local fusionConfigNode = makeNode("Fusion", "src/shared/Config/Fusion.luau")
	local monetizationConfigNode = makeNode("Monetization", "src/shared/Config/Monetization.luau")
	local petsConfigNode = makeNode("Pets", "src/shared/Config/Pets.luau")
	local economyLogicNode = makeNode("Economy", "src/shared/Logic/Economy.luau")
	local inventoryNode = makeNode("Inventory", "src/shared/Logic/Inventory.luau")
	local signalNode = makeNode("Signal", "src/shared/Util/Signal.luau")

	sharedNode.Config = configNode
	sharedNode.Logic = logicNode
	sharedNode.Util = utilNode
	sharedNode.Types = typesNode
	sharedNode.ErrorCodes = errorCodesNode

	configNode.Parent = sharedNode
	configNode.Game = gameConfigNode
	configNode.Fusion = fusionConfigNode
	configNode.Monetization = monetizationConfigNode
	configNode.Pets = petsConfigNode

	logicNode.Parent = sharedNode
	logicNode.Economy = economyLogicNode
	logicNode.Inventory = inventoryNode

	utilNode.Parent = sharedNode
	utilNode.Signal = signalNode

	typesNode.Parent = sharedNode
	errorCodesNode.Parent = sharedNode
	gameConfigNode.Parent = configNode
	fusionConfigNode.Parent = configNode
	monetizationConfigNode.Parent = configNode
	petsConfigNode.Parent = configNode
	economyLogicNode.Parent = logicNode
	inventoryNode.Parent = logicNode
	signalNode.Parent = utilNode

	local serverNode = makeNode("Server")
	local servicesNode = makeNode("Services")
	local netNode = makeNode("Net")
	local petServiceNode = makeNode("PetService", "src/server/Services/PetService.luau")
	local dataServiceNode = makeNode("DataService")
	local economyServiceNode = makeNode("EconomyService", "src/server/Services/EconomyService.luau")
	local monetizationServiceNode = makeNode("MonetizationService")
	local netServerNode = makeNode("NetServer")

	serverNode.Services = servicesNode
	serverNode.Net = netNode
	servicesNode.Parent = serverNode
	servicesNode.PetService = petServiceNode
	servicesNode.DataService = dataServiceNode
	servicesNode.EconomyService = economyServiceNode
	servicesNode.MonetizationService = monetizationServiceNode
	netNode.Parent = serverNode
	netNode.NetServer = netServerNode
	petServiceNode.Parent = servicesNode
	dataServiceNode.Parent = servicesNode
	economyServiceNode.Parent = servicesNode
	monetizationServiceNode.Parent = servicesNode
	netServerNode.Parent = netNode

	local clientNode = makeNode("Client")
	local uiNode = makeNode("UI")
	local uiPetsNode = makeNode("Pets")
	local petInventoryUINode = makeNode("PetInventoryUI", "src/client/UI/Pets/PetInventoryUI.luau")
	clientNode.UI = uiNode
	uiNode.Parent = clientNode
	uiNode.Pets = uiPetsNode
	uiPetsNode.Parent = uiNode
	uiPetsNode.PetInventoryUI = petInventoryUINode
	petInventoryUINode.Parent = uiPetsNode

	local playerPasses: { [any]: { [string]: boolean } } = {}
	local mockMonetizationService = {
		HasPass = function(player, passKey)
			local passes = playerPasses[player]
			return passes ~= nil and passes[passKey] == true
		end,
	}

	moduleCache[dataServiceNode] = mockDataService
	moduleCache[monetizationServiceNode] = mockMonetizationService
	moduleCache[netServerNode] = mockNetServer

	local mockReplicatedStorage = {
		Shared = sharedNode,
		WaitForChild = function(_, name)
			if name == "Shared" then
				return sharedNode
			end
			error(`Filho não mockado: {name}`)
		end,
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
				return {}
			end
			error(`Serviço não mockado: {serviceName}`)
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
			Color3 = {
				fromRGB = function(r, g, b)
					return { r = r, g = g, b = b }
				end,
			},
			require = loadModule,
		}
		setmetatable(env, { __index = _G })
		local fn = luau.load(bytecode, { debugName = node._path, environment = env })
		local result = fn()
		moduleCache[node] = result
		return result
	end

	local PetService = loadModule(petServiceNode)
	local PetInventoryUI = loadModule(petInventoryUINode)

	return {
		PetService = PetService,
		PetInventoryUI = PetInventoryUI,
		makePlayer = makePlayer,
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
		setPass = function(player, passKey, owned)
			playerPasses[player] = playerPasses[player] or {}
			playerPasses[player][passKey] = owned
		end,
		setFailNextInventoryUpdate = function(shouldFail)
			failNextInventoryUpdate = shouldFail
		end,
	}
end

return function(t)
	t.test("Inventory.bonus aplica multiplicador 2x para Golden mantendo compatibilidade de 2 argumentos", function()
		local data = {
			Inventory = {
				g1 = { Id = "CottonCat", Variant = "Golden" }, -- 1.5 * 2 = 3.0
				n1 = { Id = "BearGummy" }, -- 2.0
				u1 = { Id = "LollipopBunny", Variant = "UnknownVariant" }, -- ignorado -> 3.0
			},
			Equipped = { "g1", "n1", "u1" },
		}

		t.eq(Inventory.bonus(data, PetsConfig), 8.0)
		t.eq(Inventory.bonus(data, PetsConfig, FusionConfig), 8.0)
		t.eq(Inventory.petMultiplier(data.Inventory.g1, PetsConfig, FusionConfig), 3.0)
		t.eq(Inventory.petMultiplier(data.Inventory.n1, PetsConfig, FusionConfig), 2.0)
	end)

	t.test("Inventory.canFuse valida array estrito, 5 distintos, não equipados, mesmo Id e sem Variant", function()
		local data = {
			Inventory = {
				c1 = { Id = "CottonCat" },
				c2 = { Id = "CottonCat" },
				c3 = { Id = "CottonCat" },
				c4 = { Id = "CottonCat" },
				c5 = { Id = "CottonCat" },
				c6 = { Id = "CottonCat" },
				b1 = { Id = "BearGummy" },
				g1 = { Id = "CottonCat", Variant = "Golden" },
				eq = { Id = "CottonCat" },
			},
			Equipped = { "eq" },
		}

		local ok, err, petId, def = Inventory.canFuse(data, { "c1", "c2", "c3", "c4", "c5" }, PetsConfig, FusionConfig)
		t.eq(ok, true)
		t.eq(err, nil)
		t.eq(petId, "CottonCat")
		t.eq(def.Rarity, "Common")

		-- Não-tabela ou contagem incorreta
		local badInputs = {
			nil,
			"c1",
			123,
			{ "c1", "c2", "c3", "c4" },
			{ "c1", "c2", "c3", "c4", "c5", "c6" },
			{ "c1", "c2", "c3", "c4", "c5", extra = "c6" }, -- chave string
			{ [1] = "c1", [2] = "c2", [3] = "c3", [4] = "c4", [6] = "c5" }, -- buraco no índice 5
			{ [1] = "c1", [2] = "c2", [3] = "c3", [5] = "c5" }, -- buraco no índice 4
			{ [0] = "c1", [1] = "c2", [2] = "c3", [3] = "c4", [4] = "c5" }, -- índice 0
			{ "c1", "c2", "c3", "c4", "c4" }, -- duplicado
			{ "c1", "c2", "c3", "c4", "eq" }, -- equipado
			{ "c1", "c2", "c3", "c4", "g1" }, -- já Golden
			{ "c1", "c2", "c3", "c4", "b1" }, -- Id misto
			{ "c1", "c2", "c3", "c4", "missing-uuid" }, -- não pertence ao inventário
			{ "c1", "c2", "c3", "c4", "" }, -- UUID vazio
			{ "c1", "c2", "c3", "c4", string.rep("x", 65) }, -- UUID > 64 chars
		}

		for idx, bad in badInputs do
			local fOk, fErr, fPetId, fDef = Inventory.canFuse(data, bad, PetsConfig, FusionConfig)
			t.eq(fOk, false, `caso inválido #{idx} deveria falhar`)
			t.eq(fErr, "FUSE_INVALID")
			t.eq(fPetId, nil)
			t.eq(fDef, nil)
		end
	end)

	t.test(
		"Helpers de cliente: parseEquippedAttribute (>3 pets e variante desconhecida ignorada) e getFusableGroups",
		function()
			local parsed = Inventory.parseEquippedAttribute(
				" BearGummy:Golden , CottonCat , LollipopBunny:Rainbow , JellyUnicorn:Golden , GhostPet:Golden ",
				PetsConfig
			)
			t.eq(#parsed, 4, "não deve cortar a lista em 3 e deve pular PetId inexistente")
			t.eq(parsed[1].petId, "BearGummy")
			t.eq(parsed[1].variant, "Golden")
			t.eq(parsed[2].petId, "CottonCat")
			t.eq(parsed[2].variant, nil)
			t.eq(parsed[3].petId, "LollipopBunny")
			t.eq(parsed[3].variant, nil, "variante desconhecida deve ser ignorada")
			t.eq(parsed[4].petId, "JellyUnicorn")
			t.eq(parsed[4].variant, "Golden")

			t.eq(#Inventory.parseEquippedAttribute("", PetsConfig), 0)
			t.eq(#Inventory.parseEquippedAttribute(nil, PetsConfig), 0)

			local data = {
				Inventory = {
					c1 = { Id = "CottonCat" },
					c2 = { Id = "CottonCat" },
					c3 = { Id = "CottonCat" },
					c4 = { Id = "CottonCat" },
					c5 = { Id = "CottonCat" },
					c6 = { Id = "CottonCat" },
					c7 = { Id = "CottonCat" }, -- equipado -> não conta para fusão
					c8 = { Id = "CottonCat", Variant = "Golden" }, -- já Golden -> não conta
					d1 = { Id = "ChocolateDragon" },
					d2 = { Id = "ChocolateDragon" },
					d3 = { Id = "ChocolateDragon" },
					d4 = { Id = "ChocolateDragon" },
					d5 = { Id = "ChocolateDragon" },
					b1 = { Id = "BearGummy" }, -- só 1 -> não elegível
				},
				Equipped = { "c7" },
			}

			local groups = Inventory.getFusableGroups(data, PetsConfig, FusionConfig)
			t.eq(#groups, 2)
			-- Ordenado por Multiplier decrescente: ChocolateDragon (10) antes de CottonCat (1.5)
			t.eq(groups[1].petId, "ChocolateDragon")
			t.eq(groups[1].count, 5)
			t.eq(#groups[1].batchUuids, 5)
			t.eq(groups[1].gemCost, 50)

			t.eq(groups[2].petId, "CottonCat")
			t.eq(groups[2].count, 6)
			t.eq(#groups[2].batchUuids, 5)
			t.eq(groups[2].gemCost, 5)
		end
	)

	t.test("FusePets valida tudo antes de cobrar gemas e recusa saldo insuficiente", function()
		local h = loadFusionHarness()
		h.PetService.Init()

		local p1 = h.makePlayer(1, "Alice")

		-- Sem dados carregados
		local res = h.invokeRemote("FusePets", p1, { "a", "b", "c", "d", "e" })
		t.eq(res.ok, false)
		t.eq(res.err, "DATA_NOT_LOADED")

		h.setLoadedData(p1, {
			Version = 1,
			Coins = 100,
			Gems = 4, -- insuficiente até para Common (5 gemas)
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {
				c1 = { Id = "CottonCat" },
				c2 = { Id = "CottonCat" },
				c3 = { Id = "CottonCat" },
				c4 = { Id = "CottonCat" },
				c5 = { Id = "CottonCat" },
				eq = { Id = "CottonCat" },
				g1 = { Id = "CottonCat", Variant = "Golden" },
				b1 = { Id = "BearGummy" },
			},
			Equipped = { "eq" },
		})

		-- Todas as falhas FUSE_INVALID antes de cobrar gemas (Gems permanece 4)
		local invalidPayloads = {
			{ "c1", "c2", "c3", "c4", "c5", extra = "b1" },
			{ [1] = "c1", [2] = "c2", [3] = "c3", [4] = "c4", [6] = "c5" },
			{ "c1", "c2", "c3", "c4", "c4" },
			{ "c1", "c2", "c3", "c4", "eq" },
			{ "c1", "c2", "c3", "c4", "g1" },
			{ "c1", "c2", "c3", "c4", "b1" },
		}
		for _, payload in invalidPayloads do
			h.advanceClock(2)
			local r = h.invokeRemote("FusePets", p1, payload)
			t.eq(r.ok, false)
			t.eq(r.err, "FUSE_INVALID")
			t.eq(h.getData(p1).Gems, 4)
		end

		-- Válido porém sem gemas -> NOT_ENOUGH_GEMS sem alterar inventário nem gemas
		h.advanceClock(2)
		res = h.invokeRemote("FusePets", p1, { "c1", "c2", "c3", "c4", "c5" })
		t.eq(res.ok, false)
		t.eq(res.err, "NOT_ENOUGH_GEMS")
		t.eq(h.getData(p1).Gems, 4)
		t.ok(h.getData(p1).Inventory.c1 ~= nil)
		t.ok(h.getData(p1).Inventory.c5 ~= nil)
		t.eq(h.getSaveCount(), 0)
	end)

	t.test(
		"FusePets executa fusão atômica 5->1 cobrando gemas exatas, criando Golden e atualizando bônus",
		function()
			local h = loadFusionHarness()
			h.PetService.Init()

			local p1 = h.makePlayer(1, "Alice")
			h.setLoadedData(p1, {
				Version = 1,
				Coins = 100,
				Gems = 25,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza" },
				Inventory = {
					j1 = { Id = "JellyUnicorn" }, -- Rare -> custo 20 gemas
					j2 = { Id = "JellyUnicorn" },
					j3 = { Id = "JellyUnicorn" },
					j4 = { Id = "JellyUnicorn" },
					j5 = { Id = "JellyUnicorn" },
					j6 = { Id = "JellyUnicorn" }, -- 6º pet deve permanecer intacto
				},
				Equipped = {},
			})

			local res = h.invokeRemote("FusePets", p1, { "j1", "j2", "j3", "j4", "j5" })
			t.eq(res.ok, true)
			t.ok(type(res.data) == "table")
			t.ok(type(res.data.uuid) == "string" and #res.data.uuid > 0)
			t.eq(res.data.petId, "JellyUnicorn")
			t.eq(res.data.variant, "Golden")

			local data = h.getData(p1)
			t.eq(data.Gems, 5, "25 - 20 (Rare) = 5")
			t.eq(h.getSaveCount(), 1)

			-- Exatos 5 removidos, 6º preservado, 1 novo Golden inserido
			for _, oldUuid in { "j1", "j2", "j3", "j4", "j5" } do
				t.eq(data.Inventory[oldUuid], nil)
			end
			t.ok(data.Inventory.j6 ~= nil)
			t.eq(data.Inventory.j6.Variant, nil)
			local golden = data.Inventory[res.data.uuid]
			t.ok(golden ~= nil)
			t.eq(golden.Id, "JellyUnicorn")
			t.eq(golden.Variant, "Golden")
			t.eq(Inventory.count(data), 2)

			-- Equipar o Golden aplica 2x no bônus (5 * 2 = 10) e formata EquippedPets com :Golden
			local eqRes = h.invokeRemote("EquipPet", p1, res.data.uuid)
			t.eq(eqRes.ok, true)
			t.eq(p1:GetAttribute("EquippedPets"), "JellyUnicorn:Golden")
			t.eq(h.PetService.GetDamageBonus(p1), 10)

			-- UI helpers refletem bônus 2x e tradução de erro FUSE_INVALID
			local entries, totalBonus, eqCount, invCount = h.PetInventoryUI.BuildSortedEntries(data)
			t.eq(#entries, 2)
			t.eq(totalBonus, 10)
			t.eq(eqCount, 1)
			t.eq(invCount, 2)
			t.eq(entries[1].variant, "Golden")
			t.eq(entries[1].multiplier, 10)
			t.eq(entries[2].variant, nil)
			t.eq(entries[2].multiplier, 5)
			t.ok(#h.PetInventoryUI.TranslateError("FUSE_INVALID") > 0)
		end
	)

	t.test("FusePets aplica rate limit de 2/s", function()
		local h = loadFusionHarness()
		h.PetService.Init()

		local invokes = h.getRegisteredInvokes()
		t.eq(invokes.FusePets.options.rate, 2)
		t.eq(invokes.FusePets.options.burst, 3)

		local p1 = h.makePlayer(1, "Alice")
		h.setLoadedData(p1, {
			Version = 1,
			Coins = 0,
			Gems = 50,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {},
			Equipped = {},
		})

		-- Consome burst de 3
		for _ = 1, 3 do
			local r = h.invokeRemote("FusePets", p1, {})
			t.eq(r.ok, false)
			t.eq(r.err, "FUSE_INVALID")
		end

		-- 4ª chamada imediata sofre RATE_LIMITED
		local limited = h.invokeRemote("FusePets", p1, {})
		t.eq(limited.ok, false)
		t.eq(limited.err, "RATE_LIMITED")

		-- Após 0.5s (1/rate), libera 1 token
		h.advanceClock(0.5)
		local recovered = h.invokeRemote("FusePets", p1, {})
		t.eq(recovered.ok, false)
		t.eq(recovered.err, "FUSE_INVALID")
	end)

	t.test(
		"PetController.RequestFuse e handleTogglePet cancelam timer ao responder, mantêm lock em voo e nunca disparam timeout falso pós-resposta",
		function()
			local moduleCache = {}
			local scheduledDelays = {}
			local cancelledThreads = {}
			local toastLog = {}
			local invokeCalls = {}
			local refreshCount = 0
			local currentData = {
				Gems = 50,
				Inventory = {},
				Equipped = {},
			}
			local invokeBehavior: ((string, any) -> any)? = nil

			local mockTask = {
				delay = function(seconds, callback)
					local handle = {
						seconds = seconds,
						callback = callback,
						cancelled = false,
						eventsAtCancel = nil,
					}
					table.insert(scheduledDelays, handle)
					return handle
				end,
				cancel = function(handle)
					assert(type(handle) == "table", "task.cancel esperava handle de timer")
					handle.cancelled = true
					handle.eventsAtCancel = {
						toasts = #toastLog,
						refreshes = refreshCount,
					}
					table.insert(cancelledThreads, handle)
				end,
				spawn = function(fn, ...)
					local co = coroutine.create(fn)
					local ok, err = coroutine.resume(co, ...)
					if not ok then
						error(err)
					end
					return co
				end,
			}

			local function makeNode(name, path)
				return { Name = name, _path = path }
			end

			local sharedNode = makeNode("Shared")
			local configNode = makeNode("Config")
			local logicNode = makeNode("Logic")
			local typesNode = makeNode("Types", "src/shared/Types.luau")
			local errorCodesNode = makeNode("ErrorCodes", "src/shared/ErrorCodes.luau")
			local gameConfigNode = makeNode("Game", "src/shared/Config/Game.luau")
			local fusionConfigNode = makeNode("Fusion", "src/shared/Config/Fusion.luau")
			local monetizationConfigNode = makeNode("Monetization", "src/shared/Config/Monetization.luau")
			local petsConfigNode = makeNode("Pets", "src/shared/Config/Pets.luau")
			local inventoryNode = makeNode("Inventory", "src/shared/Logic/Inventory.luau")

			sharedNode.Config = configNode
			sharedNode.Logic = logicNode
			sharedNode.Types = typesNode
			sharedNode.ErrorCodes = errorCodesNode
			configNode.Parent = sharedNode
			configNode.Game = gameConfigNode
			configNode.Fusion = fusionConfigNode
			configNode.Monetization = monetizationConfigNode
			configNode.Pets = petsConfigNode
			logicNode.Parent = sharedNode
			logicNode.Inventory = inventoryNode
			typesNode.Parent = sharedNode
			errorCodesNode.Parent = sharedNode
			gameConfigNode.Parent = configNode
			fusionConfigNode.Parent = configNode
			monetizationConfigNode.Parent = configNode
			petsConfigNode.Parent = configNode
			inventoryNode.Parent = logicNode

			local clientNode = makeNode("Client")
			local controllersNode = makeNode("Controllers")
			local netNode = makeNode("Net")
			local uiNode = makeNode("UI")
			local uiPetsNode = makeNode("Pets")
			local dataControllerNode = makeNode("DataController")
			local hudControllerNode = makeNode("HudController")
			local netClientNode = makeNode("NetClient")
			local petInventoryUINode = makeNode("PetInventoryUI", "src/client/UI/Pets/PetInventoryUI.luau")
			local petControllerNode = makeNode("PetController", "src/client/Controllers/PetController.luau")

			clientNode.Controllers = controllersNode
			clientNode.Net = netNode
			clientNode.UI = uiNode
			controllersNode.Parent = clientNode
			controllersNode.DataController = dataControllerNode
			controllersNode.HudController = hudControllerNode
			controllersNode.PetController = petControllerNode
			controllersNode.FindFirstChild = function(_, name)
				if name == "HudController" then
					return hudControllerNode
				end
				return nil
			end
			hudControllerNode.IsA = function(_, className)
				return className == "ModuleScript"
			end
			netNode.Parent = clientNode
			netNode.NetClient = netClientNode
			uiNode.Parent = clientNode
			uiNode.Pets = uiPetsNode
			uiPetsNode.Parent = uiNode
			uiPetsNode.PetInventoryUI = petInventoryUINode
			petInventoryUINode.Parent = uiPetsNode
			petControllerNode.Parent = controllersNode

			moduleCache[dataControllerNode] = {
				Get = function()
					return currentData
				end,
				Observe = function() end,
			}

			moduleCache[hudControllerNode] = {
				Toast = function(message, kind)
					table.insert(toastLog, { message = message, kind = kind })
				end,
			}

			moduleCache[netClientNode] = {
				Invoke = function(remoteName, payload)
					table.insert(invokeCalls, { remote = remoteName, payload = payload })
					if invokeBehavior then
						return invokeBehavior(remoteName, payload)
					end
					return { ok = true, data = { uuid = "new-golden", petId = "CottonCat", variant = "Golden" } }
				end,
			}

			local mockReplicatedStorage = {
				Shared = sharedNode,
				WaitForChild = function(_, name)
					if name == "Shared" then
						return sharedNode
					end
					error(`Filho não mockado: {name}`)
				end,
			}

			local mockGame = {
				GetService = function(_, serviceName)
					if serviceName == "ReplicatedStorage" then
						return mockReplicatedStorage
					elseif serviceName == "Players" or serviceName == "RunService" or serviceName == "Workspace" then
						return {}
					end
					error(`Serviço não mockado: {serviceName}`)
				end,
			}

			local function loadModule(node)
				if moduleCache[node] ~= nil then
					return moduleCache[node]
				end
				local source = fs.readFile(node._path)
				local bytecode = luau.compile(source)
				local env = {
					game = mockGame,
					script = node,
					typeof = type,
					warn = function() end,
					task = mockTask,
					Color3 = {
						fromRGB = function(r, g, b)
							return { r = r, g = g, b = b }
						end,
					},
					require = loadModule,
				}
				setmetatable(env, { __index = _G })
				local fn = luau.load(bytecode, { debugName = node._path, environment = env })
				local result = fn()
				moduleCache[node] = result
				return result
			end

			local PetInventoryUI = loadModule(petInventoryUINode)
			local origRefresh = PetInventoryUI.Refresh
			local mountedToggle: ((string, boolean) -> ())? = nil
			PetInventoryUI.Refresh = function(data)
				refreshCount += 1
				return origRefresh(data)
			end
			PetInventoryUI.Mount = function(onToggle, _onFuse)
				mountedToggle = onToggle
			end

			local PetController = loadModule(petControllerNode)
			PetController.Start()
			t.ok(type(mountedToggle) == "function", "PetController.Start deve registrar handleTogglePet")

			-- 1) Resposta imediata de sucesso: cancela timer ANTES de toast/refresh e nunca dispara timeout depois
			local batch = { "c1", "c2", "c3", "c4", "c5" }
			PetController.RequestFuse(batch)
			t.eq(#invokeCalls, 1)
			t.eq(invokeCalls[1].remote, "FusePets")
			t.eq(#scheduledDelays, 1)
			t.eq(#cancelledThreads, 1)
			t.eq(scheduledDelays[1].cancelled, true, "timer deve ser cancelado ao receber resposta")
			t.eq(
				scheduledDelays[1].eventsAtCancel.toasts,
				0,
				"timer deve ser cancelado antes de emitir feedback de conclusão"
			)
			t.eq(
				scheduledDelays[1].eventsAtCancel.refreshes,
				1,
				"timer deve ser cancelado antes do Refresh pós-resposta (apenas o Refresh inicial do Start rodou)"
			)
			t.eq(PetInventoryUI.IsFusePending(), false)
			t.eq(#toastLog, 1)
			t.eq(toastLog[1].kind, "info")
			t.ok(string.find(toastLog[1].message, "Fusão concluída!", 1, true) ~= nil)

			-- Mesmo se o callback do timer antigo disparar depois de 8s, nada acontece
			scheduledDelays[1].callback()
			t.eq(#toastLog, 1, "callback de timeout não pode disparar após resposta de FusePets")

			-- 2) Chamada lenta (>8s em voo): mantém lock contra duplo clique, avisa sem destruir lock e conclui no retorno real
			local pendingResume: thread? = nil
			invokeBehavior = function()
				pendingResume = coroutine.running()
				return coroutine.yield()
			end

			PetController.RequestFuse(batch)
			t.eq(#invokeCalls, 2)
			t.eq(PetInventoryUI.IsFusePending(), true, "lock deve permanecer ativo enquanto Invoke está em voo")
			t.eq(#scheduledDelays, 2)
			t.eq(scheduledDelays[2].cancelled, false)

			-- Duplo clique enquanto em voo é bloqueado
			PetController.RequestFuse(batch)
			t.eq(#invokeCalls, 2, "duplo clique não deve disparar novo Invoke")

			-- Passam-se 8s com a requisição ainda em voo -> feedback não-destrutivo mantendo lock ativo
			scheduledDelays[2].callback()
			t.eq(#toastLog, 2)
			t.eq(toastLog[2].message, "Ainda aguardando resposta do servidor...")
			t.eq(toastLog[2].kind, "info")
			t.eq(PetInventoryUI.IsFusePending(), true, "lock deve continuar ativo após aviso de 8s")

			-- Tentativa de clique após os 8s (ainda em voo) continua bloqueada
			PetController.RequestFuse(batch)
			t.eq(#invokeCalls, 2, "lock não deve liberar antes do retorno real do servidor")

			-- Servidor finalmente responde com erro de negócio -> libera lock e atualiza UI
			assert(pendingResume ~= nil, "coroutine em voo deveria existir")
			local okResume, errResume = coroutine.resume(pendingResume, { ok = false, err = "NOT_ENOUGH_GEMS" })
			t.eq(okResume, true, tostring(errResume))
			t.eq(PetInventoryUI.IsFusePending(), false, "lock liberado após retorno real")
			t.eq(#toastLog, 3)
			t.eq(toastLog[3].kind, "error")

			-- 3) Exceção em NetClient.Invoke (capturada por pcall): cancela timer, libera lock e trata como INTERNAL
			invokeBehavior = function()
				error("falha de rede simulada")
			end
			PetController.RequestFuse(batch)
			t.eq(#invokeCalls, 3)
			t.eq(scheduledDelays[3].cancelled, true, "timer deve ser cancelado mesmo quando Invoke lança erro")
			t.eq(PetInventoryUI.IsFusePending(), false, "lock deve ser liberado após erro em pcall")
			t.eq(#toastLog, 4)
			t.eq(toastLog[4].kind, "error")
			scheduledDelays[3].callback()
			t.eq(#toastLog, 4, "timer pós-erro nunca deve disparar")

			-- 4) EquipPet / UnequipPet (handleTogglePet) também cancela timer na resposta e não dispara timeout falso
			invokeBehavior = function()
				return { ok = true }
			end
			local toggleFn = mountedToggle :: (string, boolean) -> ()
			toggleFn("u-1", false)
			t.eq(#invokeCalls, 4)
			t.eq(invokeCalls[4].remote, "EquipPet")
			t.eq(scheduledDelays[4].cancelled, true)
			t.eq(PetInventoryUI.IsPending("u-1"), false)
			scheduledDelays[4].callback()
			t.eq(#toastLog, 4, "EquipPet não deve mostrar timeout falso após resposta")
		end
	)

	t.test("FusePets funciona com inventário cheio (50 -> 46, sem INVENTORY_FULL)", function()
		local h = loadFusionHarness()
		h.PetService.Init()

		local p1 = h.makePlayer(1, "Alice")
		local inv = {}
		local batch = {}
		for i = 1, 5 do
			local id = `cat_{i}`
			inv[id] = { Id = "CottonCat" }
			table.insert(batch, id)
		end
		for i = 1, 45 do
			inv[`bear_{i}`] = { Id = "BearGummy" }
		end
		t.eq(Inventory.count({ Inventory = inv, Equipped = {} }), 50)

		h.setLoadedData(p1, {
			Version = 1,
			Coins = 0,
			Gems = 10,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = inv,
			Equipped = {},
		})

		local res = h.invokeRemote("FusePets", p1, batch)
		t.eq(res.ok, true)
		t.eq(res.err, nil)
		t.eq(res.data.petId, "CottonCat")
		t.eq(res.data.variant, "Golden")
		local data = h.getData(p1)
		t.eq(Inventory.count(data), 46)
		t.eq(data.Gems, 5)
	end)

	t.test("FusePets recusa UUID de outro jogador (misto ou total) sem cobrar gemas", function()
		local h = loadFusionHarness()
		h.PetService.Init()

		local p1 = h.makePlayer(1, "Alice")
		local p2 = h.makePlayer(2, "Bob")
		h.setLoadedData(p1, {
			Version = 1,
			Coins = 0,
			Gems = 50,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {
				a1 = { Id = "CottonCat" },
				a2 = { Id = "CottonCat" },
				a3 = { Id = "CottonCat" },
				a4 = { Id = "CottonCat" },
			},
			Equipped = {},
		})
		h.setLoadedData(p2, {
			Version = 1,
			Coins = 0,
			Gems = 50,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {
				b1 = { Id = "CottonCat" },
				b2 = { Id = "CottonCat" },
				b3 = { Id = "CottonCat" },
				b4 = { Id = "CottonCat" },
				b5 = { Id = "CottonCat" },
			},
			Equipped = {},
		})

		-- Mistura 4 da Alice + 1 do Bob
		local mixed = h.invokeRemote("FusePets", p1, { "a1", "a2", "a3", "a4", "b1" })
		t.eq(mixed.ok, false)
		t.eq(mixed.err, "FUSE_INVALID")
		t.eq(h.getData(p1).Gems, 50)
		t.ok(h.getData(p2).Inventory.b1 ~= nil)

		-- Todos do Bob
		local stolen = h.invokeRemote("FusePets", p1, { "b1", "b2", "b3", "b4", "b5" })
		t.eq(stolen.ok, false)
		t.eq(stolen.err, "FUSE_INVALID")
		t.eq(h.getData(p1).Gems, 50)
		t.eq(Inventory.count(h.getData(p2)), 5)
	end)

	t.test("FusePets cobra custo exato de cada raridade (Common..Legendary)", function()
		local h = loadFusionHarness()
		h.PetService.Init()

		local p1 = h.makePlayer(1, "Alice")
		h.setLoadedData(p1, {
			Version = 1,
			Coins = 0,
			Gems = 100,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {
				c1 = { Id = "CottonCat" },
				c2 = { Id = "CottonCat" },
				c3 = { Id = "CottonCat" },
				c4 = { Id = "CottonCat" },
				c5 = { Id = "CottonCat" },
				u1 = { Id = "LollipopBunny" },
				u2 = { Id = "LollipopBunny" },
				u3 = { Id = "LollipopBunny" },
				u4 = { Id = "LollipopBunny" },
				u5 = { Id = "LollipopBunny" },
				r1 = { Id = "JellyUnicorn" },
				r2 = { Id = "JellyUnicorn" },
				r3 = { Id = "JellyUnicorn" },
				r4 = { Id = "JellyUnicorn" },
				r5 = { Id = "JellyUnicorn" },
				l1 = { Id = "ChocolateDragon" },
				l2 = { Id = "ChocolateDragon" },
				l3 = { Id = "ChocolateDragon" },
				l4 = { Id = "ChocolateDragon" },
				l5 = { Id = "ChocolateDragon" },
			},
			Equipped = {},
		})

		-- Common = 5 (100 -> 95)
		local rCommon = h.invokeRemote("FusePets", p1, { "c1", "c2", "c3", "c4", "c5" })
		t.eq(rCommon.ok, true)
		t.eq(h.getData(p1).Gems, 95)

		-- Uncommon = 10 (95 -> 85)
		h.advanceClock(2)
		local rUncommon = h.invokeRemote("FusePets", p1, { "u1", "u2", "u3", "u4", "u5" })
		t.eq(rUncommon.ok, true)
		t.eq(h.getData(p1).Gems, 85)

		-- Rare = 20 (85 -> 65)
		h.advanceClock(2)
		local rRare = h.invokeRemote("FusePets", p1, { "r1", "r2", "r3", "r4", "r5" })
		t.eq(rRare.ok, true)
		t.eq(h.getData(p1).Gems, 65)

		-- Legendary = 50 (65 -> 15)
		h.advanceClock(2)
		local rLegend = h.invokeRemote("FusePets", p1, { "l1", "l2", "l3", "l4", "l5" })
		t.eq(rLegend.ok, true)
		t.eq(h.getData(p1).Gems, 15)

		-- Epic = 35 no config e getFusableGroups
		t.eq(FusionConfig.GemCostByRarity.Epic, 35)
		local epicPets = {
			EpicCandy = { Name = "Doce Épico", Rarity = "Epic", Multiplier = 7 },
		}
		local epicData = {
			Inventory = {
				e1 = { Id = "EpicCandy" },
				e2 = { Id = "EpicCandy" },
				e3 = { Id = "EpicCandy" },
				e4 = { Id = "EpicCandy" },
				e5 = { Id = "EpicCandy" },
			},
			Equipped = {},
		}
		local epicGroups = Inventory.getFusableGroups(epicData, epicPets, FusionConfig)
		t.eq(#epicGroups, 1)
		t.eq(epicGroups[1].gemCost, 35)
	end)

	t.test(
		"FusePets rejeita payloads hostis (NaN, math.huge, chaves negativas/fracionárias, tabelas aninhadas)",
		function()
			local h = loadFusionHarness()
			h.PetService.Init()

			local p1 = h.makePlayer(1, "Alice")
			h.setLoadedData(p1, {
				Version = 1,
				Coins = 0,
				Gems = 60,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza" },
				Inventory = {
					c1 = { Id = "CottonCat" },
					c2 = { Id = "CottonCat" },
					c3 = { Id = "CottonCat" },
					c4 = { Id = "CottonCat" },
					c5 = { Id = "CottonCat" },
				},
				Equipped = {},
			})

			local hostilePayloads = {
				0 / 0, -- NaN
				math.huge,
				-math.huge,
				-1,
				1.5,
				true,
				"c1",
				{},
				{ [-1] = "c1", [1] = "c2", [2] = "c3", [3] = "c4", [4] = "c5" },
				{ [1.5] = "c1", [1] = "c2", [2] = "c3", [3] = "c4", [4] = "c5" },
				{ [math.huge] = "c1", [1] = "c2", [2] = "c3", [3] = "c4", [4] = "c5" },
				{ { "c1" }, "c2", "c3", "c4", "c5" }, -- tabela aninhada no índice 1
				{ "c1", "c2", "c3", "c4", { id = "c5" } }, -- tabela aninhada no índice 5
				{ 0 / 0, "c2", "c3", "c4", "c5" }, -- NaN dentro do array
				{ math.huge, "c2", "c3", "c4", "c5" }, -- math.huge dentro do array
			}

			for idx, payload in hostilePayloads do
				h.advanceClock(2)
				local res = h.invokeRemote("FusePets", p1, payload)
				t.eq(res.ok, false, `payload hostil #{idx} deveria falhar`)
				t.eq(res.err, "FUSE_INVALID", `payload hostil #{idx} deveria retornar FUSE_INVALID`)
				t.eq(h.getData(p1).Gems, 60)
				t.eq(Inventory.count(h.getData(p1)), 5)
			end
		end
	)

	t.test("FusePets devolve gemas exatas e preserva inventário quando DataService.Update retorna nil", function()
		local h = loadFusionHarness()
		h.PetService.Init()

		local p1 = h.makePlayer(1, "Alice")
		h.setLoadedData(p1, {
			Version = 1,
			Coins = 0,
			Gems = 75,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {
				l1 = { Id = "ChocolateDragon" }, -- Legendary = 50 gemas
				l2 = { Id = "ChocolateDragon" },
				l3 = { Id = "ChocolateDragon" },
				l4 = { Id = "ChocolateDragon" },
				l5 = { Id = "ChocolateDragon" },
			},
			Equipped = {},
		})

		h.setFailNextInventoryUpdate(true)
		local res = h.invokeRemote("FusePets", p1, { "l1", "l2", "l3", "l4", "l5" })
		t.eq(res.ok, false)
		t.eq(res.err, "DATA_NOT_LOADED")
		t.eq(h.getData(p1).Gems, 75, "gemas gastas (50) devem ser reembolsadas integralmente")
		t.eq(Inventory.count(h.getData(p1)), 5, "nenhum pet deve ser removido se Update falhar")
		t.eq(h.getSaveCount(), 0, "Save não deve rodar quando Update falha")
	end)

	t.test(
		"PetInventoryUI calcula métricas responsivas sem transbordar abas nem esmagar conteúdo em telas baixas",
		function()
			local h = loadFusionHarness()
			local UI = h.PetInventoryUI

			-- 667x375 (iPhone SE/8 deitado) e 720x360 (Android deitado)
			for _, vp in { { 667, 375 }, { 720, 360 } } do
				local m = UI.ComputeResponsiveMetrics(vp[1], vp[2])
				t.ok(m.tabsHeightPx >= m.minTouchLocal, `abas precisam acompanhar minTouchLocal em {vp[1]}x{vp[2]}`)
				t.ok(m.headerHeightPx >= m.minTouchLocal, `header precisa comportar CloseButton em {vp[1]}x{vp[2]}`)
				t.ok(m.tabsHeightPx * m.scale >= 44, `área real de toque das abas >= 44px em {vp[1]}x{vp[2]}`)
				t.ok(m.modalHeightScale >= 0.88, `modal cresce em tela baixa ({vp[1]}x{vp[2]})`)

				local modalLocalH = (vp[2] * m.modalHeightScale) / m.scale
				local innerH = modalLocalH - (m.modalPaddingPx * 2)
				local gridH = innerH - m.contentTopOffsetPx
				local fusionListH = gridH - (m.fusionPanelPadPx * 2) - m.fusionListTopOffsetPx
				t.ok(gridH >= 140, `grade deve caber ao menos 1 card inteiro em {vp[1]}x{vp[2]} (veio {gridH})`)
				t.ok(
					fusionListH >= 110,
					`FusionList deve caber ao menos 1 card inteiro em {vp[1]}x{vp[2]} (veio {fusionListH})`
				)
			end

			-- Desktop 1920x1080
			local desktop = UI.ComputeResponsiveMetrics(1920, 1080)
			t.eq(desktop.isCompactHeight, false)
			t.eq(desktop.modalHeightScale, 0.78)
			t.ok(desktop.tabsHeightPx >= desktop.minTouchLocal)
		end
	)

	t.test(
		"PetInventoryUI bloqueia fusão sem gemas, exige confirmação com Active=true, respeita ExtraPetSlot e não trava botão",
		function()
			local moduleCache = {}
			local scheduledDelays = {}
			local mockTask = {
				delay = function(seconds, fn)
					local handle = { seconds = seconds, callback = fn }
					table.insert(scheduledDelays, handle)
					return handle
				end,
				cancel = function() end,
				spawn = function(fn, ...)
					return fn(...)
				end,
			}

			local function makeUINode(className)
				local children = {}
				local attributes = {}
				local propSignals = {}
				local inst = {
					ClassName = className,
					Name = className,
					Visible = true,
					Active = false,
					Text = "",
					Scale = 1,
					AutoButtonColor = true,
					AbsoluteSize = { X = 600, Y = 300 },
					MinSize = { X = 0, Y = 0 },
					MaxSize = { X = 0, Y = 0 },
					Activated = makeSignal(),
					IsA = function(self, target)
						if target == "GuiObject" then
							return self.ClassName == "Frame"
								or self.ClassName == "TextButton"
								or self.ClassName == "TextLabel"
								or self.ClassName == "ScrollingFrame"
						end
						return self.ClassName == target
					end,
					FindFirstChild = function(self, name)
						for _, child in children do
							if child.Name == name then
								return child
							end
						end
						return nil
					end,
					FindFirstChildOfClass = function(self, targetClass)
						for _, child in children do
							if child.ClassName == targetClass then
								return child
							end
						end
						return nil
					end,
					GetChildren = function()
						local copy = {}
						for _, child in children do
							table.insert(copy, child)
						end
						return copy
					end,
					SetAttribute = function(_, key, value)
						attributes[key] = value
					end,
					GetAttribute = function(_, key)
						return attributes[key]
					end,
					GetPropertyChangedSignal = function(_, prop)
						if not propSignals[prop] then
							propSignals[prop] = makeSignal()
						end
						return propSignals[prop]
					end,
					Destroy = function(self)
						self.Parent = nil
						table.clear(children)
					end,
				}
				local parentRef = nil
				setmetatable(inst, {
					__index = function(_, key)
						if key == "Parent" then
							return parentRef
						end
						return nil
					end,
					__newindex = function(self, key, value)
						if key == "Parent" then
							if parentRef and parentRef._removeChild then
								parentRef._removeChild(self)
							end
							parentRef = value
							if value and value._addChild then
								value._addChild(self)
							end
							return
						end
						rawset(self, key, value)
					end,
				})
				inst._addChild = function(child)
					table.insert(children, child)
				end
				inst._removeChild = function(child)
					for i = #children, 1, -1 do
						if children[i] == child then
							table.remove(children, i)
						end
					end
				end
				return inst
			end

			local playerGui = makeUINode("PlayerGui")
			local playerAttrs = {}
			local passSignal = makeSignal()
			local localPlayer = {
				Name = "Alice",
				GetAttribute = function(_, key)
					return playerAttrs[key]
				end,
				SetAttribute = function(_, key, value)
					playerAttrs[key] = value
					if key == "Passes" then
						passSignal:Fire()
					end
				end,
				GetAttributeChangedSignal = function(_, key)
					if key == "Passes" then
						return passSignal
					end
					return makeSignal()
				end,
				WaitForChild = function(_, name)
					if name == "PlayerGui" then
						return playerGui
					end
					error(`WaitForChild inesperado: {name}`)
				end,
			}

			local cameraPropSignal = makeSignal()
			local mockCamera = {
				ViewportSize = { X = 720, Y = 360 },
				GetPropertyChangedSignal = function()
					return cameraPropSignal
				end,
			}
			local mockWorkspace = {
				CurrentCamera = mockCamera,
				GetPropertyChangedSignal = function()
					return makeSignal()
				end,
			}
			local mockPlayers = {
				LocalPlayer = localPlayer,
			}

			local function makeNode(name, path)
				return { Name = name, _path = path }
			end

			local sharedNode = makeNode("Shared")
			local configNode = makeNode("Config")
			local logicNode = makeNode("Logic")
			local typesNode = makeNode("Types", "src/shared/Types.luau")
			local errorCodesNode = makeNode("ErrorCodes", "src/shared/ErrorCodes.luau")
			local gameConfigNode = makeNode("Game", "src/shared/Config/Game.luau")
			local fusionConfigNode = makeNode("Fusion", "src/shared/Config/Fusion.luau")
			local monetizationConfigNode = makeNode("Monetization", "src/shared/Config/Monetization.luau")
			local petsConfigNode = makeNode("Pets", "src/shared/Config/Pets.luau")
			local inventoryNode = makeNode("Inventory", "src/shared/Logic/Inventory.luau")

			sharedNode.Config = configNode
			sharedNode.Logic = logicNode
			sharedNode.Types = typesNode
			sharedNode.ErrorCodes = errorCodesNode
			configNode.Parent = sharedNode
			configNode.Game = gameConfigNode
			configNode.Fusion = fusionConfigNode
			configNode.Monetization = monetizationConfigNode
			configNode.Pets = petsConfigNode
			logicNode.Parent = sharedNode
			logicNode.Inventory = inventoryNode
			typesNode.Parent = sharedNode
			errorCodesNode.Parent = sharedNode
			gameConfigNode.Parent = configNode
			fusionConfigNode.Parent = configNode
			monetizationConfigNode.Parent = configNode
			petsConfigNode.Parent = configNode
			inventoryNode.Parent = logicNode

			local mockReplicatedStorage = {
				Shared = sharedNode,
				WaitForChild = function(_, name)
					if name == "Shared" then
						return sharedNode
					end
					error(`WaitForChild inesperado: {name}`)
				end,
			}
			local mockGame = {
				GetService = function(_, serviceName)
					if serviceName == "Players" then
						return mockPlayers
					elseif serviceName == "ReplicatedStorage" then
						return mockReplicatedStorage
					elseif serviceName == "Workspace" then
						return mockWorkspace
					end
					error(`Serviço não mockado: {serviceName}`)
				end,
			}
			local mockEnum = {
				ZIndexBehavior = { Sibling = "Sibling" },
				ApplyStrokeMode = { Border = "Border" },
				Font = { GothamBold = "GothamBold", GothamMedium = "GothamMedium" },
				TextXAlignment = { Left = "Left", Right = "Right" },
				AutomaticSize = { Y = "Y" },
				ScrollingDirection = { Y = "Y" },
				SortOrder = { LayoutOrder = "LayoutOrder" },
			}

			local function loadModule(node)
				if moduleCache[node] ~= nil then
					return moduleCache[node]
				end
				local source = fs.readFile(node._path)
				local bytecode = luau.compile(source)
				local env = {
					game = mockGame,
					script = node,
					typeof = type,
					warn = function() end,
					task = mockTask,
					Instance = { new = makeUINode },
					Vector2 = {
						new = function(x, y)
							return { X = x or 0, Y = y or 0 }
						end,
					},
					UDim = {
						new = function(s, o)
							return { Scale = s or 0, Offset = o or 0 }
						end,
					},
					UDim2 = {
						fromScale = function(xs, ys)
							return { X = { Scale = xs, Offset = 0 }, Y = { Scale = ys, Offset = 0 } }
						end,
						fromOffset = function(xo, yo)
							return { X = { Scale = 0, Offset = xo }, Y = { Scale = 0, Offset = yo } }
						end,
						new = function(xs, xo, ys, yo)
							return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
						end,
					},
					Color3 = {
						fromRGB = function(r, g, b)
							return { r = r, g = g, b = b }
						end,
					},
					Enum = mockEnum,
					require = loadModule,
				}
				setmetatable(env, { __index = _G })
				local fn = luau.load(bytecode, { debugName = node._path, environment = env })
				local result = fn()
				moduleCache[node] = result
				return result
			end

			local PetInventoryUI = loadModule(makeNode("PetInventoryUI", "src/client/UI/Pets/PetInventoryUI.luau"))
			local fuseCalls = {}
			PetInventoryUI.Mount(function() end, function(uuids)
				table.insert(fuseCalls, uuids)
			end)

			local gui = playerGui:FindFirstChild("PetInventoryGui")
			t.ok(gui ~= nil, "ScreenGui deve ser montado em PlayerGui")
			local modal = gui:FindFirstChild("PetsModal")
			local statsBar = modal:FindFirstChild("StatsBar")
			local eqLabel = statsBar:FindFirstChild("EquippedCountLabel")
			local toggleBtn = gui:FindFirstChild("PetsToggleButton")
			local tabsBar = modal:FindFirstChild("TabsBar")
			local fusionPanel = modal:FindFirstChild("FusionPanel")
			local fusionList = fusionPanel:FindFirstChild("FusionList")
			local toastBanner = modal:FindFirstChild("ToastBanner")
			local confirmOverlay = gui:FindFirstChild("FusionConfirmOverlay")
			local confirmModal = confirmOverlay:FindFirstChild("FusionConfirmModal")
			local confirmSummary = confirmModal:FindFirstChild("ConfirmSummary")
			local confirmCost = confirmModal:FindFirstChild("ConfirmCost")
			local confirmActions = confirmModal:FindFirstChild("ConfirmActions")
			local cancelBtn = confirmActions:FindFirstChild("CancelFuseButton")
			local confirmBtn = confirmActions:FindFirstChild("ConfirmFuseButton")

			-- Altura da TabsBar acompanha minTouchLocal no viewport 720x360
			t.ok(tabsBar.Size.Y.Offset >= 58, "TabsBar deve ter altura >= 58 em viewport 720x360")

			-- Sem passe: limite 3; com ExtraPetSlot: limite 4
			local sampleData = {
				Gems = 10, -- insuficiente para JellyUnicorn (20 gemas)
				Inventory = {
					j1 = { Id = "JellyUnicorn" },
					j2 = { Id = "JellyUnicorn" },
					j3 = { Id = "JellyUnicorn" },
					j4 = { Id = "JellyUnicorn" },
					j5 = { Id = "JellyUnicorn" },
				},
				Equipped = {},
			}
			PetInventoryUI.Refresh(sampleData)
			t.eq(eqLabel.Text, "Equipados: 0/3")
			t.eq(toggleBtn.Text, "Pets (0/3)")
			t.ok(string.find(PetInventoryUI.TranslateError("MAX_EQUIPPED"), "3", 1, true) ~= nil)

			localPlayer:SetAttribute("Passes", "AutoClicker,ExtraPetSlot")
			PetInventoryUI.Refresh(sampleData)
			t.eq(eqLabel.Text, "Equipados: 0/4")
			t.eq(toggleBtn.Text, "Pets (0/4)")
			t.ok(string.find(PetInventoryUI.TranslateError("MAX_EQUIPPED"), "4", 1, true) ~= nil)

			-- Sem gemas suficientes: clique no FuseButton bloqueia envio, não abre confirmação e mostra aviso
			local card = fusionList:FindFirstChild("FusionCard_JellyUnicorn")
			t.ok(card ~= nil)
			local fuseBtn = card:FindFirstChild("FuseButton")
			t.eq(fuseBtn.AutoButtonColor, false)
			fuseBtn.Activated:Fire()
			t.eq(#fuseCalls, 0, "não deve chamar onFuse sem gemas suficientes")
			t.eq(confirmOverlay.Visible, false, "não deve abrir confirmação sem gemas suficientes")
			t.eq(toastBanner.Visible, true, "deve exibir aviso de gemas insuficientes")

			-- Com gemas suficientes: abre confirmação com Active=true, pet, RequiredCount e custo; Cancelar não envia
			sampleData.Gems = 25
			PetInventoryUI.Refresh(sampleData)
			card = fusionList:FindFirstChild("FusionCard_JellyUnicorn")
			fuseBtn = card:FindFirstChild("FuseButton")
			t.eq(fuseBtn.AutoButtonColor, true)
			fuseBtn.Activated:Fire()

			t.eq(#fuseCalls, 0, "clique em Fundir não deve enviar direto sem confirmar")
			t.eq(confirmOverlay.Visible, true, "deve abrir overlay de confirmação")
			t.eq(confirmOverlay.Active, true, "overlay de confirmação deve ter Active=true")
			t.eq(confirmModal.Active, true, "modal de confirmação deve ter Active=true")
			t.ok(string.find(confirmSummary.Text, "Unicórnio de Gelatina", 1, true) ~= nil)
			t.ok(string.find(confirmSummary.Text, tostring(FusionConfig.RequiredCount), 1, true) ~= nil)
			t.ok(string.find(confirmCost.Text, "20 Gemas", 1, true) ~= nil)
			t.eq(confirmBtn.Text, "Fundir!")
			t.eq(cancelBtn.Text, "Cancelar")

			cancelBtn.Activated:Fire()
			t.eq(confirmOverlay.Visible, false)
			t.eq(#fuseCalls, 0, "Cancelar não pode disparar fusão")

			-- Reabre e confirma com "Fundir!"
			fuseBtn.Activated:Fire()
			t.eq(confirmOverlay.Visible, true)
			confirmBtn.Activated:Fire()
			t.eq(confirmOverlay.Visible, false)
			t.eq(#fuseCalls, 1, "Fundir! deve disparar fusão uma vez")
			t.eq(#fuseCalls[1], FusionConfig.RequiredCount)

			-- SetFusePending(true) -> "Fundindo..." e SetFusePending(false) -> restaura "Fundir"
			PetInventoryUI.SetFusePending(true)
			t.eq(fuseBtn.Text, "Fundindo...")
			t.eq(fuseBtn.AutoButtonColor, false)
			PetInventoryUI.SetFusePending(false)
			t.eq(fuseBtn.Text, "Fundir")
			t.eq(fuseBtn.AutoButtonColor, true)

			PetInventoryUI.Destroy()
		end
	)
end
