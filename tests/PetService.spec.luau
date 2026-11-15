--!nocheck
-- tests/PetService.spec.luau (Lune). Dono: Squad B. Testes de integração do PetService com mocks de Roblox/DataService/NetServer.
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

local function loadPetServiceHarness()
	local moduleCache = {}
	local guidCounter = 0
	local nowClock = 100

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

	local function removePlayer(player)
		for i = #mockPlayersList, 1, -1 do
			if mockPlayersList[i] == player then
				table.remove(mockPlayersList, i)
			end
		end
		player.Parent = nil
		playerRemovingSignal:Fire(player)
	end

	local mockHttpService = {
		GenerateGUID = function(_, wrapBraces: boolean)
			guidCounter += 1
			local raw = string.format("00000000-0000-4000-8000-%012d", guidCounter)
			return if wrapBraces then `\{{raw}\}` else raw
		end,
	}

	local dataStore = {}
	local dataWriteLog = {}
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
			table.insert(dataWriteLog, { op = "Set", player = player, key = key })
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
			table.insert(dataWriteLog, { op = "Update", player = player, key = key })
			changedSignal:Fire(player, key, newValue)
			return newValue
		end,
		Save = function() end,
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
	}

	local mockGame = {
		GetService = function(_, serviceName)
			if serviceName == "Players" then
				return mockPlayers
			elseif serviceName == "ReplicatedStorage" then
				return mockReplicatedStorage
			elseif serviceName == "HttpService" then
				return mockHttpService
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
			require = loadModule,
		}
		setmetatable(env, { __index = _G })
		local fn = luau.load(bytecode, { debugName = node._path, environment = env })
		local result = fn()
		moduleCache[node] = result
		return result
	end

	local PetService = loadModule(petServiceNode)

	return {
		PetService = PetService,
		makePlayer = makePlayer,
		removePlayer = removePlayer,
		setLoadedData = function(player, data)
			dataStore[player] = data
			loadedSignal:Fire(player, data)
		end,
		setRawData = function(player, data)
			dataStore[player] = data
		end,
		getData = function(player)
			return dataStore[player]
		end,
		invokeRemote = invokeRemote,
		getRegisteredInvokes = function()
			return registeredInvokes
		end,
		getWriteLog = function()
			return dataWriteLog
		end,
		advanceClock = function(seconds)
			nowClock += seconds
		end,
		setPass = function(player, passKey, owned)
			playerPasses[player] = playerPasses[player] or {}
			playerPasses[player][passKey] = owned
		end,
	}
end

return function(t)
	t.test("AddPet valida perfil, petId, capacidade e gera GUID", function()
		local h = loadPetServiceHarness()
		h.PetService.Init()
		h.PetService.Start()

		local p1 = h.makePlayer(1, "Alice")

		-- Perfil não carregado
		local uuid, err = h.PetService.AddPet(p1, "CottonCat")
		t.eq(uuid, nil)
		t.eq(err, "DATA_NOT_LOADED")

		h.setLoadedData(p1, {
			Version = 1,
			Coins = 25,
			Gems = 0,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {},
			Equipped = {},
		})

		-- petId inválido / desconhecido
		uuid, err = h.PetService.AddPet(p1, "")
		t.eq(uuid, nil)
		t.eq(err, "INVALID_ARGS")

		uuid, err = h.PetService.AddPet(p1, 123)
		t.eq(uuid, nil)
		t.eq(err, "INVALID_ARGS")

		uuid, err = h.PetService.AddPet(p1, "GhostPet")
		t.eq(uuid, nil)
		t.eq(err, "UNKNOWN_ITEM")

		-- Sucesso até encher 50 slots
		local created = {}
		for i = 1, 50 do
			local petId = if i % 2 == 0 then "BearGummy" else "CottonCat"
			local newUuid, addErr = h.PetService.AddPet(p1, petId)
			t.ok(type(newUuid) == "string" and #newUuid > 0, "uuid deve ser string não vazia")
			t.eq(addErr, nil)
			t.eq(created[newUuid], nil, "uuid único")
			created[newUuid] = true
			t.eq(h.getData(p1).Inventory[newUuid].Id, petId)
		end

		-- 51º pet deve recusar com INVENTORY_FULL
		uuid, err = h.PetService.AddPet(p1, "CottonCat")
		t.eq(uuid, nil)
		t.eq(err, "INVENTORY_FULL")
	end)

	t.test(
		"EquipPet e UnequipPet validam argumentos, posse, duplicidade, limite 3 e sincronizam EquippedPets",
		function()
			local h = loadPetServiceHarness()
			h.PetService.Init()
			h.PetService.Start()

			local p1 = h.makePlayer(1, "Alice")
			local p2 = h.makePlayer(2, "Bob")

			-- Antes de carregar, bônus é 0 e remotes devolvem DATA_NOT_LOADED
			t.eq(h.PetService.GetDamageBonus(p1), 0)
			local res = h.invokeRemote("EquipPet", p1, "any-uuid")
			t.eq(res.ok, false)
			t.eq(res.err, "DATA_NOT_LOADED")

			h.setLoadedData(p1, {
				Version = 1,
				Coins = 25,
				Gems = 0,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza" },
				Inventory = {},
				Equipped = {},
			})
			h.setLoadedData(p2, {
				Version = 1,
				Coins = 25,
				Gems = 0,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza" },
				Inventory = {},
				Equipped = {},
			})

			t.eq(p1:GetAttribute("EquippedPets"), "")

			local u1 = h.PetService.AddPet(p1, "BearGummy") -- mult 2
			local u2 = h.PetService.AddPet(p1, "CottonCat") -- mult 1.5
			local u3 = h.PetService.AddPet(p1, "LollipopBunny") -- mult 3
			local u4 = h.PetService.AddPet(p1, "ChocolateDragon") -- mult 10
			local bobPet = h.PetService.AddPet(p2, "JellyUnicorn")

			-- Argumentos inválidos
			for _, bad in { "", 123, string.rep("a", 65) } do
				res = h.invokeRemote("EquipPet", p1, bad)
				t.eq(res.ok, false)
				t.eq(res.err, "INVALID_ARGS")

				res = h.invokeRemote("UnequipPet", p1, bad)
				t.eq(res.ok, false)
				t.eq(res.err, "INVALID_ARGS")
			end

			-- UUID alheio ou inexistente
			res = h.invokeRemote("EquipPet", p1, bobPet)
			t.eq(res.ok, false)
			t.eq(res.err, "NOT_OWNED")

			res = h.invokeRemote("UnequipPet", p1, bobPet)
			t.eq(res.ok, false)
			t.eq(res.err, "NOT_OWNED")

			-- Desequipar pet que está no inventário mas não equipado
			res = h.invokeRemote("UnequipPet", p1, u1)
			t.eq(res.ok, false)
			t.eq(res.err, "NOT_EQUIPPED")

			-- Equipar 1º e 2º (avança relógio para não esgotar o burst 8/s após os testes de erro)
			h.advanceClock(2)
			res = h.invokeRemote("EquipPet", p1, u1)
			t.eq(res.ok, true)
			t.eq(p1:GetAttribute("EquippedPets"), "BearGummy")
			t.eq(h.PetService.GetDamageBonus(p1), 2)

			-- Já equipado
			res = h.invokeRemote("EquipPet", p1, u1)
			t.eq(res.ok, false)
			t.eq(res.err, "ALREADY_EQUIPPED")

			res = h.invokeRemote("EquipPet", p1, u2)
			t.eq(res.ok, true)
			t.eq(p1:GetAttribute("EquippedPets"), "BearGummy,CottonCat")
			t.eq(h.PetService.GetDamageBonus(p1), 3.5)

			-- Equipar 3º e tentar 4º
			res = h.invokeRemote("EquipPet", p1, u3)
			t.eq(res.ok, true)
			t.eq(p1:GetAttribute("EquippedPets"), "BearGummy,CottonCat,LollipopBunny")
			t.eq(h.PetService.GetDamageBonus(p1), 6.5)

			res = h.invokeRemote("EquipPet", p1, u4)
			t.eq(res.ok, false)
			t.eq(res.err, "MAX_EQUIPPED")
			t.eq(#h.getData(p1).Equipped, 3)

			-- Desequipar e equipar o 4º
			res = h.invokeRemote("UnequipPet", p1, u2)
			t.eq(res.ok, true)
			t.eq(p1:GetAttribute("EquippedPets"), "BearGummy,LollipopBunny")
			t.eq(h.PetService.GetDamageBonus(p1), 5)

			res = h.invokeRemote("EquipPet", p1, u4)
			t.eq(res.ok, true)
			t.eq(p1:GetAttribute("EquippedPets"), "BearGummy,LollipopBunny,ChocolateDragon")
			t.eq(h.PetService.GetDamageBonus(p1), 15)

			-- Desequipar todos deixa atributo "" e bônus 0
			h.advanceClock(10)
			t.eq(h.invokeRemote("UnequipPet", p1, u1).ok, true)
			t.eq(h.invokeRemote("UnequipPet", p1, u3).ok, true)
			t.eq(h.invokeRemote("UnequipPet", p1, u4).ok, true)
			t.eq(p1:GetAttribute("EquippedPets"), "")
			t.eq(h.PetService.GetDamageBonus(p1), 0)
		end
	)

	t.test("EquipPet e UnequipPet aplicam rate limit de 8/s", function()
		local h = loadPetServiceHarness()
		h.PetService.Init()
		h.PetService.Start()

		local invokes = h.getRegisteredInvokes()
		t.eq(invokes.EquipPet.options.rate, 8)
		t.eq(invokes.UnequipPet.options.rate, 8)

		local p1 = h.makePlayer(1, "Alice")
		h.setLoadedData(p1, {
			Version = 1,
			Coins = 25,
			Gems = 0,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = { u1 = { Id = "CottonCat" } },
			Equipped = {},
		})

		for i = 1, 8 do
			local res = h.invokeRemote("EquipPet", p1, "u1")
			if i == 1 then
				t.eq(res.ok, true)
			else
				t.eq(res.err, "ALREADY_EQUIPPED")
			end
		end

		local limited = h.invokeRemote("EquipPet", p1, "u1")
		t.eq(limited.ok, false)
		t.eq(limited.err, "RATE_LIMITED")

		for _ = 1, 8 do
			h.invokeRemote("UnequipPet", p1, "u1")
		end
		local limitedUnequip = h.invokeRemote("UnequipPet", p1, "u1")
		t.eq(limitedUnequip.ok, false)
		t.eq(limitedUnequip.err, "RATE_LIMITED")
	end)

	t.test(
		"Saneamento no load remove pets desconhecidos, UUIDs órfãos/duplicados, excedentes >3 e inicializa EquippedPets",
		function()
			local h = loadPetServiceHarness()
			h.PetService.Init()

			local p1 = h.makePlayer(1, "Alice")
			h.setLoadedData(p1, {
				Version = 1,
				Coins = 25,
				Gems = 0,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza" },
				Inventory = {
					valid1 = { Id = "BearGummy" },
					valid2 = { Id = "CottonCat" },
					valid3 = { Id = "LollipopBunny" },
					valid4 = { Id = "ChocolateDragon" },
					removed = { Id = "DeletedPetId" },
				},
				Equipped = {
					"missing-uuid",
					"removed",
					"valid1",
					"valid1", -- duplicado
					"valid2",
					"valid3",
					"valid4", -- 4º válido deve ser cortado pelo limite 3
				},
			})

			local data = h.getData(p1)
			t.eq(data.Inventory.removed, nil, "pet com Id inexistente removido do inventário")
			t.ok(data.Inventory.valid1 ~= nil)
			t.eq(#data.Equipped, 3)
			t.eq(data.Equipped[1], "valid1")
			t.eq(data.Equipped[2], "valid2")
			t.eq(data.Equipped[3], "valid3")
			t.eq(p1:GetAttribute("EquippedPets"), "BearGummy,CottonCat,LollipopBunny")
			t.eq(h.PetService.GetDamageBonus(p1), 6.5)

			-- Jogador que já estava carregado antes do Start() também é saneado no Start()
			local p2 = h.makePlayer(2, "Bob")
			h.setRawData(p2, {
				Version = 1,
				Coins = 25,
				Gems = 0,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza" },
				Inventory = { stale = { Id = "OldPet" } },
				Equipped = { "stale", "ghost" },
			})
			h.PetService.Start()

			local data2 = h.getData(p2)
			t.eq(data2.Inventory.stale, nil)
			t.eq(#data2.Equipped, 0)
			t.eq(p2:GetAttribute("EquippedPets"), "")
			t.eq(h.PetService.GetDamageBonus(p2), 0)

			h.removePlayer(p1)
			h.removePlayer(p2)
		end
	)

	t.test(
		"Saneamento preserva Variant Golden mesmo ao limpar outras entradas e remove variantes inválidas",
		function()
			local h = loadPetServiceHarness()
			h.PetService.Init()

			local p1 = h.makePlayer(1, "Alice")
			h.setLoadedData(p1, {
				Version = 1,
				Coins = 25,
				Gems = 0,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza" },
				Inventory = {
					golden1 = { Id = "BearGummy", Variant = "Golden" },
					normal1 = { Id = "CottonCat" },
					badVariant = { Id = "LollipopBunny", Variant = "Rainbow" },
					removed = { Id = "DeletedPetId" },
				},
				Equipped = { "golden1", "normal1", "badVariant" },
			})

			local data = h.getData(p1)
			t.eq(data.Inventory.removed, nil, "pet inexistente removido")
			t.ok(data.Inventory.golden1 ~= nil, "pet dourado preservado")
			t.eq(data.Inventory.golden1.Variant, "Golden", "Variant Golden deve ser preservada")
			t.eq(data.Inventory.normal1.Variant, nil)
			t.ok(data.Inventory.badVariant ~= nil, "pet com variante inválida mantido como normal")
			t.eq(data.Inventory.badVariant.Variant, nil, "variante inválida limpa para nil")

			-- Multiplicador 2x para BearGummy Golden (2*2=4) + CottonCat (1.5) + LollipopBunny (3) = 8.5
			t.eq(p1:GetAttribute("EquippedPets"), "BearGummy:Golden,CottonCat,LollipopBunny")
			t.eq(h.PetService.GetDamageBonus(p1), 8.5)

			-- AddPet aceita Golden opcional e recusa variante inválida
			local gUuid, gErr = h.PetService.AddPet(p1, "CottonCat", "Golden")
			t.ok(type(gUuid) == "string" and #gUuid > 0)
			t.eq(gErr, nil)
			t.eq(data.Inventory[gUuid].Variant, "Golden")

			local badUuid, badErr = h.PetService.AddPet(p1, "CottonCat", "Rainbow")
			t.eq(badUuid, nil)
			t.eq(badErr, "INVALID_ARGS")
		end
	)

	t.test(
		"ExtraPetSlot permite equipar 4o pet (incluindo :Golden) e preserva 4 equipados no sanitizePlayerData",
		function()
			local h = loadPetServiceHarness()
			h.PetService.Init()

			local p1 = h.makePlayer(1, "Alice")
			h.setPass(p1, "ExtraPetSlot", true)
			h.setLoadedData(p1, {
				Version = 1,
				Coins = 25,
				Gems = 0,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza" },
				Inventory = {
					p1 = { Id = "BearGummy" }, -- 2
					p2 = { Id = "CottonCat" }, -- 1.5
					p3 = { Id = "LollipopBunny" }, -- 3
					p4 = { Id = "ChocolateDragon", Variant = "Golden" }, -- 10 * 2 = 20
					p5 = { Id = "JellyUnicorn" }, -- 5
				},
				Equipped = { "p1", "p2", "p3", "p4", "p5" }, -- 5o deve ser cortado, 4o preservado
			})

			local data = h.getData(p1)
			t.eq(#data.Equipped, 4, "com ExtraPetSlot deve preservar 4 pets no load")
			t.eq(data.Equipped[4], "p4")
			t.eq(p1:GetAttribute("EquippedPets"), "BearGummy,CottonCat,LollipopBunny,ChocolateDragon:Golden")
			t.eq(h.PetService.GetDamageBonus(p1), 26.5)

			-- Desequipa o 4o, reequipa via remote, e tenta o 5o
			local unRes = h.invokeRemote("UnequipPet", p1, "p4")
			t.eq(unRes.ok, true)
			t.eq(#data.Equipped, 3)

			local eq4 = h.invokeRemote("EquipPet", p1, "p4")
			t.eq(eq4.ok, true)
			t.eq(#data.Equipped, 4)
			t.eq(p1:GetAttribute("EquippedPets"), "BearGummy,CottonCat,LollipopBunny,ChocolateDragon:Golden")

			local eq5 = h.invokeRemote("EquipPet", p1, "p5")
			t.eq(eq5.ok, false)
			t.eq(eq5.err, "MAX_EQUIPPED")
			t.eq(#data.Equipped, 4)
		end
	)
end
