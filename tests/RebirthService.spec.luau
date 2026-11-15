--!nocheck
-- tests/RebirthService.spec.luau (Lune). Dono: Squad B. Testes de integração do RebirthService com mocks de Roblox/DataService/NetServer.
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

local function loadRebirthServiceHarness()
	local moduleCache = {}
	local nowClock = 100
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
		local player = {
			UserId = userId,
			Name = name,
			Parent = mockPlayers,
		}
		table.insert(mockPlayersList, player)
		return player
	end

	local dataStore = {}
	local writeLog = {}
	local loadedSignal = makeSignal()
	local changedSignal = makeSignal()
	local changedEvents = {}
	changedSignal:Connect(function(player, key, value)
		table.insert(changedEvents, { player = player, key = key, value = value })
	end)

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
			table.insert(writeLog, { op = "Set", key = key, value = value })
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
			table.insert(writeLog, { op = "Update", key = key, value = newValue })
			changedSignal:Fire(player, key, newValue)
			return newValue
		end,
		Save = function()
			saveCount += 1
		end,
	}

	local baseUpdate = mockDataService.Update

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
	local typesNode = makeNode("Types", "src/shared/Types.luau")
	local errorCodesNode = makeNode("ErrorCodes", "src/shared/ErrorCodes.luau")
	local gameConfigNode = makeNode("Game", "src/shared/Config/Game.luau")
	local economyLogicNode = makeNode("Economy", "src/shared/Logic/Economy.luau")
	local rebirthLogicNode = makeNode("Rebirth", "src/shared/Logic/Rebirth.luau")
	local requestIdempotencyNode = makeNode("RequestIdempotency", "src/shared/Logic/RequestIdempotency.luau")

	sharedNode.Config = configNode
	sharedNode.Logic = logicNode
	sharedNode.Types = typesNode
	sharedNode.ErrorCodes = errorCodesNode

	configNode.Parent = sharedNode
	configNode.Game = gameConfigNode

	logicNode.Parent = sharedNode
	logicNode.Economy = economyLogicNode
	logicNode.Rebirth = rebirthLogicNode
	logicNode.RequestIdempotency = requestIdempotencyNode

	typesNode.Parent = sharedNode
	errorCodesNode.Parent = sharedNode
	gameConfigNode.Parent = configNode
	economyLogicNode.Parent = logicNode
	rebirthLogicNode.Parent = logicNode
	requestIdempotencyNode.Parent = logicNode

	local serverNode = makeNode("Server")
	local servicesNode = makeNode("Services")
	local netNode = makeNode("Net")
	local dataServiceNode = makeNode("DataService")
	local economyServiceNode = makeNode("EconomyService", "src/server/Services/EconomyService.luau")
	local rebirthServiceNode = makeNode("RebirthService", "src/server/Services/RebirthService.luau")
	local netServerNode = makeNode("NetServer")

	serverNode.Services = servicesNode
	serverNode.Net = netNode
	servicesNode.Parent = serverNode
	servicesNode.DataService = dataServiceNode
	servicesNode.EconomyService = economyServiceNode
	servicesNode.RebirthService = rebirthServiceNode
	netNode.Parent = serverNode
	netNode.NetServer = netServerNode
	dataServiceNode.Parent = servicesNode
	economyServiceNode.Parent = servicesNode
	rebirthServiceNode.Parent = servicesNode
	netServerNode.Parent = netNode

	moduleCache[dataServiceNode] = mockDataService
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

	local EconomyService = loadModule(economyServiceNode)
	local RebirthService = loadModule(rebirthServiceNode)

	return {
		RebirthService = RebirthService,
		EconomyService = EconomyService,
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
		getChangedEvents = function()
			return changedEvents
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
		setDataServiceUpdateHook = function(fn)
			if fn then
				mockDataService.Update = function(player, key, modifier)
					return fn(baseUpdate, player, key, modifier)
				end
			else
				mockDataService.Update = baseUpdate
			end
		end,
	}
end

return function(t)
	t.test("RequestRebirth valida perfil carregado e saldo insuficiente sem alterar dados", function()
		local h = loadRebirthServiceHarness()
		h.RebirthService.Init()

		local p1 = h.makePlayer(1, "Alice")

		-- Perfil não carregado
		local res = h.invokeRemote("RequestRebirth", p1)
		t.eq(res.ok, false)
		t.eq(res.err, "DATA_NOT_LOADED")

		h.setLoadedData(p1, {
			Version = 1,
			Coins = 9999,
			Gems = 2,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza", "ChocolateFalls" },
			Inventory = { u1 = { Id = "CottonCat" } },
			Equipped = { "u1" },
		})

		-- Saldo abaixo de 10000 não altera nada
		res = h.invokeRemote("RequestRebirth", p1)
		t.eq(res.ok, false)
		t.eq(res.err, "NOT_ENOUGH_COINS")
		t.eq(h.getData(p1).Coins, 9999)
		t.eq(h.getData(p1).Gems, 2)
		t.eq(h.getData(p1).Rebirths, 0)
		t.eq(#h.getData(p1).UnlockedAreas, 2)
		t.eq(h.getSaveCount(), 0)

		-- Jogador removido -> DATA_NOT_LOADED
		p1.Parent = nil
		res = h.invokeRemote("RequestRebirth", p1)
		t.eq(res.ok, false)
		t.eq(res.err, "DATA_NOT_LOADED")
	end)

	t.test(
		"RequestRebirth reseta Coins e UnlockedAreas, incrementa Rebirths, dá Gems e preserva Inventory/Equipped",
		function()
			local h = loadRebirthServiceHarness()
			h.RebirthService.Init()

			local p1 = h.makePlayer(1, "Alice")
			local inventory = {
				u1 = { Id = "CottonCat" },
				u2 = { Id = "ChocolateDragon" },
			}
			local equipped = { "u1", "u2" }
			h.setLoadedData(p1, {
				Version = 1,
				Coins = 15000, -- sobra acima do custo 10000 deve resetar para 25
				Gems = 3,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza", "ChocolateFalls", "CottonClouds" },
				Inventory = inventory,
				Equipped = equipped,
			})

			local res = h.invokeRemote("RequestRebirth", p1)
			t.eq(res.ok, true)
			t.eq(res.data.rebirths, 1)
			t.eq(res.data.gemsReward, 5)

			local data = h.getData(p1)
			t.eq(data.Coins, 25)
			t.eq(data.Rebirths, 1)
			t.eq(data.Gems, 8)
			t.eq(#data.UnlockedAreas, 1)
			t.eq(data.UnlockedAreas[1], "CandyPlaza")
			t.eq(data.Inventory.u1.Id, "CottonCat")
			t.eq(data.Inventory.u2.Id, "ChocolateDragon")
			t.eq(#data.Equipped, 2)
			t.eq(data.Equipped[1], "u1")
			t.eq(data.Equipped[2], "u2")
			t.eq(h.getSaveCount(), 1)

			-- DataChanged foi disparado para Coins, Rebirths, UnlockedAreas e Gems
			local changedKeys = {}
			for _, ev in h.getChangedEvents() do
				changedKeys[ev.key] = ev.value
			end
			t.eq(changedKeys.Coins, 25)
			t.eq(changedKeys.Rebirths, 1)
			t.eq(changedKeys.Gems, 8)
			t.eq(changedKeys.UnlockedAreas[1], "CandyPlaza")

			-- 2º rebirth exige 25000 (10000 * 2.5^1)
			data.Coins = 24999
			local failSecond = h.invokeRemote("RequestRebirth", p1)
			t.eq(failSecond.ok, false)
			t.eq(failSecond.err, "NOT_ENOUGH_COINS")
			t.eq(data.Rebirths, 1)
			t.eq(data.Coins, 24999)

			data.Coins = 25000
			local okSecond = h.invokeRemote("RequestRebirth", p1)
			t.eq(okSecond.ok, true)
			t.eq(okSecond.data.rebirths, 2)
			t.eq(okSecond.data.gemsReward, 5)
			t.eq(data.Coins, 25)
			t.eq(data.Rebirths, 2)
			t.eq(data.Gems, 13)
			t.eq(h.getSaveCount(), 2)
		end
	)

	t.test("RequestRebirth aplica rate limit de 2/s (burst 3)", function()
		local h = loadRebirthServiceHarness()
		h.RebirthService.Init()

		local invokes = h.getRegisteredInvokes()
		t.eq(invokes.RequestRebirth.options.rate, 2)
		t.eq(invokes.RequestRebirth.options.burst, 3)

		local p1 = h.makePlayer(1, "Alice")
		h.setLoadedData(p1, {
			Version = 1,
			Coins = 10000,
			Gems = 0,
			Rebirths = 0,
			UnlockedAreas = { "CandyPlaza" },
			Inventory = {},
			Equipped = {},
		})

		-- 1º passa, 2º e 3º falham por saldo (mas consomem o burst de 3)
		local r1 = h.invokeRemote("RequestRebirth", p1)
		t.eq(r1.ok, true)
		local r2 = h.invokeRemote("RequestRebirth", p1)
		t.eq(r2.ok, false)
		t.eq(r2.err, "NOT_ENOUGH_COINS")
		local r3 = h.invokeRemote("RequestRebirth", p1)
		t.eq(r3.ok, false)
		t.eq(r3.err, "NOT_ENOUGH_COINS")

		-- 4º estoura burst 3 -> RATE_LIMITED
		local r4 = h.invokeRemote("RequestRebirth", p1)
		t.eq(r4.ok, false)
		t.eq(r4.err, "RATE_LIMITED")

		-- Após 0.5s recupera 1 token (rate = 2/s)
		h.advanceClock(0.5)
		h.getData(p1).Coins = 25000
		local r5 = h.invokeRemote("RequestRebirth", p1)
		t.eq(r5.ok, true)
		t.eq(h.getData(p1).Rebirths, 2)
	end)

	t.test(
		"RequestRebirth é idempotente por requestId: bloqueia inFlight, devolve cache, libera em falha e limpa no PlayerRemoving",
		function()
			local h = loadRebirthServiceHarness()
			h.RebirthService.Init()

			local p1 = h.makePlayer(1, "Alice")
			h.setLoadedData(p1, {
				Version = 1,
				Coins = 50000,
				Gems = 0,
				Rebirths = 0,
				UnlockedAreas = { "CandyPlaza", "ChocolateFalls" },
				Inventory = {},
				Equipped = {},
			})

			-- requestId inválido é recusado sem alterar dados
			local badReq = h.invokeRemote("RequestRebirth", p1, string.rep("r", 65))
			t.eq(badReq.ok, false)
			t.eq(badReq.err, "INVALID_ARGS")
			t.eq(h.getData(p1).Rebirths, 0)
			t.eq(h.getData(p1).Coins, 50000)

			-- Simula Update lento para validar bloqueio inFlight concorrente
			local resumeSlowUpdate = nil
			h.setDataServiceUpdateHook(function(original, player, key, modifier)
				if key == "Rebirths" then
					local co = coroutine.running()
					resumeSlowUpdate = function()
						task.spawn(co)
					end
					coroutine.yield()
				end
				return original(player, key, modifier)
			end)

			local firstRes = nil
			task.spawn(function()
				firstRes = h.invokeRemote("RequestRebirth", p1, "req-rebirth-1")
			end)
			t.ok(resumeSlowUpdate ~= nil)

			local concurrentRes = h.invokeRemote("RequestRebirth", p1, "req-rebirth-1")
			t.eq(concurrentRes.ok, false)
			t.eq(concurrentRes.err, "RATE_LIMITED")
			t.eq(h.getData(p1).Rebirths, 0)

			h.setDataServiceUpdateHook(nil)
			resumeSlowUpdate()
			t.ok(firstRes ~= nil and firstRes.ok == true)
			t.eq(firstRes.data.rebirths, 1)
			t.eq(h.getData(p1).Rebirths, 1)
			t.eq(h.getData(p1).Gems, 5)
			t.eq(h.getSaveCount(), 1)

			-- Retry pós-8s com mesmo requestId após conclusão devolve cache sem duplicar rebirth ou gemas
			h.advanceClock(8)
			h.getData(p1).Coins = 50000
			local cachedRetry = h.invokeRemote("RequestRebirth", p1, "req-rebirth-1")
			t.eq(cachedRetry.ok, true)
			t.eq(cachedRetry.data.rebirths, 1)
			t.eq(cachedRetry.data.gemsReward, 5)
			t.eq(h.getData(p1).Rebirths, 1)
			t.eq(h.getData(p1).Gems, 5)
			t.eq(h.getData(p1).Coins, 50000)
			t.eq(h.getSaveCount(), 1)

			-- Falha de DataService.Update libera inFlight e não cacheia resultado
			h.advanceClock(2)
			h.setDataServiceUpdateHook(function()
				error("falha simulada no Update")
			end)
			local failRes = h.invokeRemote("RequestRebirth", p1, "req-rebirth-2")
			t.eq(failRes.ok, false)
			t.eq(failRes.err, "INTERNAL")

			h.setDataServiceUpdateHook(nil)
			local recoveredRes = h.invokeRemote("RequestRebirth", p1, "req-rebirth-2")
			t.eq(recoveredRes.ok, true)
			t.eq(recoveredRes.data.rebirths, 2)
			t.eq(h.getData(p1).Rebirths, 2)

			-- PlayerRemoving limpa cache do jogador
			h.firePlayerRemoving(p1)
			h.advanceClock(2)
			h.getData(p1).Coins = 100000
			local afterReconnect = h.invokeRemote("RequestRebirth", p1, "req-rebirth-1")
			t.eq(afterReconnect.ok, true)
			t.eq(afterReconnect.data.rebirths, 3)
		end
	)

	t.test(
		"RequestRebirth reembolsa cost exato (sem multiplicadores) se DataService.Update de Rebirths retornar nil após Spend",
		function()
			local h = loadRebirthServiceHarness()
			h.RebirthService.Init()
			-- Registra multiplicador 2x para provar que o estorno não passa por EconomyService.AddCoins
			h.EconomyService.RegisterCoinMultiplier("DoubleCoins", function()
				return 2
			end)

			local p1 = h.makePlayer(1, "Alice")
			h.setLoadedData(p1, {
				Version = 1,
				Coins = 50000,
				Gems = 5,
				Rebirths = 1, -- custo do 2º rebirth = 25000
				UnlockedAreas = { "CandyPlaza", "ChocolateFalls" },
				Inventory = {},
				Equipped = {},
			})

			local rebirthUpdateAttempted = false
			h.setDataServiceUpdateHook(function(original, player, key, modifier)
				if key == "Rebirths" then
					rebirthUpdateAttempted = true
					return nil
				end
				return original(player, key, modifier)
			end)

			local failRes = h.invokeRemote("RequestRebirth", p1, "req-refund-1")
			t.eq(rebirthUpdateAttempted, true)
			t.eq(failRes.ok, false)
			t.eq(failRes.err, "DATA_NOT_LOADED")
			t.eq(h.getData(p1).Coins, 50000, "Coins deve ser restaurado exatamente para 50000 após Spend")
			t.eq(h.getData(p1).Rebirths, 1)
			t.eq(h.getData(p1).Gems, 5)
			t.eq(h.getSaveCount(), 0)

			-- Retry sem reposição manual de moedas conclui normalmente com o mesmo requestId
			h.setDataServiceUpdateHook(nil)
			local retryRes = h.invokeRemote("RequestRebirth", p1, "req-refund-1")
			t.eq(retryRes.ok, true)
			t.eq(retryRes.data.rebirths, 2)
			t.eq(h.getData(p1).Rebirths, 2)
			t.eq(h.getData(p1).Coins, 25)
			t.eq(h.getData(p1).Gems, 10)
			t.eq(h.getSaveCount(), 1)
		end
	)
end
