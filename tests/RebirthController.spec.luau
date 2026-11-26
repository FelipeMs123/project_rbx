--!nocheck
-- tests/RebirthController.spec.luau (Lune). Dono: Squad B.
-- Testa integração RebirthController + RebirthUI para timeout, retry acessível e liquidação via DataChanged.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local function makeMockSignal()
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

local function makeGuiObject(className: string)
	local children = {}
	local propSignals = {}
	local obj = {
		ClassName = className,
		Name = className,
		Parent = nil,
		Visible = true,
		Enabled = true,
		Text = "",
		Scale = 1,
		Size = {},
		Position = {},
		AnchorPoint = {},
		BackgroundColor3 = {},
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		TextColor3 = {},
		TextScaled = false,
		TextWrapped = false,
		TextStrokeTransparency = 0,
		TextXAlignment = nil,
		Font = nil,
		AutoButtonColor = true,
		Active = true,
		ClipsDescendants = false,
		LayoutOrder = 0,
		ZIndex = 1,
		DisplayOrder = 0,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ScreenInsets = nil,
		ZIndexBehavior = nil,
		SortOrder = nil,
		Padding = nil,
		PaddingTop = nil,
		PaddingBottom = nil,
		PaddingLeft = nil,
		PaddingRight = nil,
		CornerRadius = nil,
		Color = nil,
		Thickness = 0,
		Transparency = 0,
		ApplyStrokeMode = nil,
		MinSize = nil,
		MaxSize = nil,
		MaxTextSize = 0,
		MinTextSize = 0,
		AspectRatio = 1,
		Activated = makeMockSignal(),
		ChildAdded = makeMockSignal(),
		ChildRemoved = makeMockSignal(),
		DescendantAdded = makeMockSignal(),
		Destroying = makeMockSignal(),
		AncestryChanged = makeMockSignal(),
	}

	local meta = {}
	meta.__newindex = function(t, k, v)
		if k == "Parent" then
			local oldParent = rawget(t, "Parent")
			if oldParent and oldParent._children then
				local idx = table.find(oldParent._children, t)
				if idx then
					table.remove(oldParent._children, idx)
					oldParent.ChildRemoved:Fire(t)
				end
			end
			rawset(t, "Parent", v)
			if v and v._children then
				table.insert(v._children, t)
				v.ChildAdded:Fire(t)
				local cur = v
				while cur do
					if cur.DescendantAdded then
						cur.DescendantAdded:Fire(t)
					end
					cur = rawget(cur, "Parent")
				end
			end
			t.AncestryChanged:Fire(t, v)
			return
		end
		local prev = rawget(t, k)
		rawset(t, k, v)
		if prev ~= v and propSignals[k] then
			propSignals[k]:Fire()
		end
	end
	obj._children = children
	setmetatable(obj, meta)

	function obj:IsA(target: string)
		if self.ClassName == target then
			return true
		end
		if
			target == "GuiObject"
			and (self.ClassName == "Frame" or self.ClassName == "TextButton" or self.ClassName == "TextLabel")
		then
			return true
		end
		return false
	end

	function obj:GetPropertyChangedSignal(prop: string)
		if not propSignals[prop] then
			propSignals[prop] = makeMockSignal()
		end
		return propSignals[prop]
	end

	function obj:FindFirstChild(name: string, recursive: boolean?)
		for _, child in self._children do
			if child.Name == name then
				return child
			end
			if recursive then
				local found = child:FindFirstChild(name, true)
				if found then
					return found
				end
			end
		end
		return nil
	end

	function obj:FindFirstChildOfClass(cls: string)
		for _, child in self._children do
			if child.ClassName == cls then
				return child
			end
		end
		return nil
	end

	function obj:WaitForChild(name: string)
		return self:FindFirstChild(name)
	end

	function obj:GetDescendants()
		local out = {}
		local function visit(node)
			for _, child in node._children do
				table.insert(out, child)
				visit(child)
			end
		end
		visit(self)
		return out
	end

	function obj:IsDescendantOf(ancestor)
		local cur = self.Parent
		while cur do
			if cur == ancestor then
				return true
			end
			cur = cur.Parent
		end
		return false
	end

	function obj:Destroy()
		self.Destroying:Fire()
		self.Parent = nil
	end

	return obj
end

local function loadRebirthClientHarness()
	local moduleCache = {}
	local guidSeq = 0
	local pendingTimers = {}
	local toasts = {}
	local invokeCalls = {}
	local invokeResolver = nil

	local playerGui = makeGuiObject("PlayerGui")
	local localPlayer = makeGuiObject("Player")
	localPlayer.Name = "Alice"
	playerGui.Parent = localPlayer

	local camera = makeGuiObject("Camera")
	camera.ViewportSize = { X = 1280, Y = 720 }

	local mockPlayers = {
		LocalPlayer = localPlayer,
	}
	local mockWorkspace = {
		CurrentCamera = camera,
		GetPropertyChangedSignal = function(_, prop)
			return camera:GetPropertyChangedSignal(prop)
		end,
	}
	local mockHttpService = {
		GenerateGUID = function()
			guidSeq += 1
			return `guid-{guidSeq}`
		end,
	}

	local snapshot = nil
	local changedSignal = makeMockSignal()
	local mockDataController = {
		Changed = changedSignal,
		Get = function()
			return snapshot
		end,
		Observe = function(key: string, fn: (any) -> ())
			if snapshot ~= nil then
				task.spawn(fn, snapshot[key])
			end
			return changedSignal:Connect(function(changedKey, val)
				if changedKey == key then
					fn(val)
				end
			end)
		end,
	}

	local mockHudController = {
		Toast = function(msg: string, kind: string?)
			table.insert(toasts, { message = msg, kind = kind })
		end,
	}
	local mockMenuCoordinator = {
		Register = function(_key, _setter)
			return function() end
		end,
	}

	local mockNetClient = {
		Invoke = function(name: string, ...)
			local args = { ... }
			local call = { name = name, args = args, requestId = args[1] }
			table.insert(invokeCalls, call)
			if invokeResolver then
				return invokeResolver(call)
			end
			-- Por padrão simula resposta pendente/perdida até ser resolvida manualmente ou nunca retornar
			local co = coroutine.running()
			call.resolve = function(res)
				task.spawn(co, res)
			end
			return coroutine.yield()
		end,
	}

	local function makeNode(name, path)
		return { Name = name, _path = path }
	end

	local sharedNode = makeNode("Shared")
	local configNode = makeNode("Config")
	local logicNode = makeNode("Logic")
	local errorCodesNode = makeNode("ErrorCodes", "src/shared/ErrorCodes.luau")
	local gameConfigNode = makeNode("Game", "src/shared/Config/Game.luau")
	local economyLogicNode = makeNode("Economy", "src/shared/Logic/Economy.luau")
	local rebirthLogicNode = makeNode("Rebirth", "src/shared/Logic/Rebirth.luau")
	local requestGuardNode = makeNode("RequestGuard", "src/shared/Logic/RequestGuard.luau")

	sharedNode.Config = configNode
	sharedNode.Logic = logicNode
	sharedNode.ErrorCodes = errorCodesNode
	configNode.Parent = sharedNode
	configNode.Game = gameConfigNode
	logicNode.Parent = sharedNode
	logicNode.Economy = economyLogicNode
	logicNode.Rebirth = rebirthLogicNode
	logicNode.RequestGuard = requestGuardNode

	local clientNode = makeNode("Client")
	local controllersNode = makeNode("Controllers")
	local netNode = makeNode("Net")
	local uiNode = makeNode("UI")
	local rebirthUiDir = makeNode("Rebirth")
	local hudUiDir = makeNode("Hud")
	local menuCoordinatorNode = makeNode("MenuCoordinator")

	local netClientNode = makeNode("NetClient")
	local dataControllerNode = makeNode("DataController")
	local hudControllerNode = makeNode("HudController")
	local rebirthControllerNode = makeNode("RebirthController", "src/client/Controllers/RebirthController.luau")
	local rebirthHelpersNode = makeNode("RebirthHelpers", "src/client/UI/Rebirth/RebirthHelpers.luau")
	local rebirthUiNode = makeNode("RebirthUI", "src/client/UI/Rebirth/RebirthUI.luau")

	clientNode.Controllers = controllersNode
	clientNode.Net = netNode
	clientNode.UI = uiNode
	controllersNode.Parent = clientNode
	netNode.Parent = clientNode
	uiNode.Parent = clientNode
	uiNode.Rebirth = rebirthUiDir
	rebirthUiDir.Parent = uiNode
	uiNode.Hud = hudUiDir
	hudUiDir.Parent = uiNode
	hudUiDir.MenuCoordinator = menuCoordinatorNode
	menuCoordinatorNode.Parent = hudUiDir

	controllersNode.DataController = dataControllerNode
	controllersNode.HudController = hudControllerNode
	controllersNode.RebirthController = rebirthControllerNode
	netNode.NetClient = netClientNode
	rebirthUiDir.RebirthHelpers = rebirthHelpersNode
	rebirthUiDir.RebirthUI = rebirthUiNode

	dataControllerNode.Parent = controllersNode
	hudControllerNode.Parent = controllersNode
	rebirthControllerNode.Parent = controllersNode
	netClientNode.Parent = netNode
	rebirthHelpersNode.Parent = rebirthUiDir
	rebirthUiNode.Parent = rebirthUiDir

	moduleCache[dataControllerNode] = mockDataController
	moduleCache[hudControllerNode] = mockHudController
	moduleCache[menuCoordinatorNode] = mockMenuCoordinator
	moduleCache[netClientNode] = mockNetClient

	local mockReplicatedStorage = {
		Shared = sharedNode,
		WaitForChild = function(_, childName)
			if childName == "Shared" then
				return sharedNode
			end
			return nil
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
			elseif serviceName == "HttpService" then
				return mockHttpService
			end
			error(`Serviço não mockado: {serviceName}`)
		end,
	}

	local fakeTask = {
		spawn = task.spawn,
		wait = task.wait,
		delay = function(seconds, callback)
			local handle = {
				seconds = seconds,
				callback = callback,
				cancelled = false,
				fired = false,
			}
			table.insert(pendingTimers, handle)
			return handle
		end,
		cancel = function(handle)
			if handle then
				handle.cancelled = true
			end
		end,
	}

	local mockEnum = setmetatable({}, {
		__index = function(_, enumName)
			return setmetatable({}, {
				__index = function(_, itemName)
					return `{enumName}.{itemName}`
				end,
			})
		end,
	})

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
			typeof = function(v)
				if type(v) == "table" and v.callback and v.cancelled ~= nil then
					return "thread"
				end
				return type(v)
			end,
			warn = function() end,
			task = fakeTask,
			Instance = { new = makeGuiObject },
			Color3 = {
				fromRGB = function(r, g, b)
					return { r = r, g = g, b = b }
				end,
			},
			UDim2 = {
				fromScale = function(x, y)
					return { x = x, y = y }
				end,
			},
			UDim = {
				new = function(s, o)
					return { s = s, o = o }
				end,
			},
			Vector2 = {
				new = function(x, y)
					return { X = x, Y = y }
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

	local RebirthUI = loadModule(rebirthUiNode)
	local RebirthController = loadModule(rebirthControllerNode)

	local function getGuiElements()
		local gui = playerGui:FindFirstChild("RebirthGui")
		assert(gui ~= nil, "RebirthGui não montada")
		local modal = gui:FindFirstChild("RebirthModal")
		local stepOne = modal:FindFirstChild("StepOnePanel")
		local stepTwo = modal:FindFirstChild("StepTwoPanel")
		return {
			gui = gui,
			modal = modal,
			stepOne = stepOne,
			stepTwo = stepTwo,
			startBtn = stepOne:FindFirstChild("StartRebirthButton"),
			confirmBtn = stepTwo:FindFirstChild("ConfirmButton"),
			cancelBtn = stepTwo:FindFirstChild("CancelButton"),
			closeBtn = modal:FindFirstChild("Header"):FindFirstChild("CloseButton"),
		}
	end

	return {
		RebirthUI = RebirthUI,
		RebirthController = RebirthController,
		setSnapshot = function(data)
			snapshot = data
		end,
		fireDataChanged = function(key, value)
			if snapshot then
				snapshot[key] = value
			end
			changedSignal:Fire(key, value)
		end,
		fireAllPendingTimeouts = function()
			local copy = table.clone(pendingTimers)
			table.clear(pendingTimers)
			for _, timer in copy do
				if not timer.cancelled and not timer.fired then
					timer.fired = true
					timer.callback()
				end
			end
		end,
		getInvokeCalls = function()
			return invokeCalls
		end,
		getToasts = function()
			return toasts
		end,
		getGuiElements = getGuiElements,
	}
end

return function(t)
	t.test("retry pós-timeout continua acessível na UI mesmo sem saldo ou ao reabrir o modal", function()
		local h = loadRebirthClientHarness()
		h.setSnapshot({
			Coins = 10000,
			Rebirths = 0,
			Gems = 0,
		})

		h.RebirthController.Init()
		h.RebirthController.Start()

		local ui = h.getGuiElements()
		h.RebirthUI.SetModalOpen(true)
		t.eq(ui.modal.Visible, true)
		t.eq(ui.stepOne.Visible, true)
		t.eq(ui.stepTwo.Visible, false)

		-- Etapa 1 -> Etapa 2 -> Confirmar dispara RequestRebirth com requestId guid-1
		ui.startBtn.Activated:Fire()
		t.eq(ui.stepTwo.Visible, true)
		ui.confirmBtn.Activated:Fire()

		local calls = h.getInvokeCalls()
		t.eq(#calls, 1)
		local firstReqId = calls[1].requestId
		t.ok(type(firstReqId) == "string" and #firstReqId > 0)

		-- Simula gasto/queda de Coins antes do timeout sem Rebirths ter aumentado
		h.fireDataChanged("Coins", 500)

		-- Dispara timeout de 8s
		h.fireAllPendingTimeouts()
		t.eq(ui.stepOne.Visible, true)

		-- Caso A: clicando no botão da etapa 1 com Coins < custo, deve permitir ir ao retry na etapa 2
		ui.startBtn.Activated:Fire()
		t.eq(ui.stepTwo.Visible, true, "etapa 1 deve permitir alcançar confirmação durante pendência de retry")

		-- Caso B: fechando e reabrindo o modal, deve abrir pronto para o retry na etapa 2
		h.RebirthUI.SetModalOpen(false)
		t.eq(ui.modal.Visible, false)
		h.RebirthUI.SetModalOpen(true)
		t.eq(ui.modal.Visible, true)
		t.eq(ui.stepTwo.Visible, true, "reabrir modal com pendência de retry deve abrir na etapa de confirmação")

		-- Clica Confirmar para fazer o retry usando exatamente o mesmo requestId
		ui.confirmBtn.Activated:Fire()
		t.eq(#calls, 2)
		t.eq(calls[2].requestId, firstReqId, "retry pós-timeout deve reutilizar o mesmo requestId")

		-- Conclusão do retry liquida a pendência
		calls[2].resolve({ ok = true, data = { rebirths = 1, gemsReward = 5 } })
		t.eq(ui.modal.Visible, false)
		h.RebirthController.Destroy()
	end)

	t.test("aumento de Rebirths via DataChanged pós-timeout liquida requestId pendente e reseta UI", function()
		local h = loadRebirthClientHarness()
		h.setSnapshot({
			Coins = 10000,
			Rebirths = 0,
			Gems = 0,
		})

		h.RebirthController.Init()
		h.RebirthController.Start()

		local ui = h.getGuiElements()
		h.RebirthUI.SetModalOpen(true)
		ui.startBtn.Activated:Fire()
		ui.confirmBtn.Activated:Fire()

		local calls = h.getInvokeCalls()
		t.eq(#calls, 1)
		local lostReqId = calls[1].requestId

		-- Timeout de 8s dispara (resposta do InvokeServer se perdeu)
		h.fireAllPendingTimeouts()

		-- Usuário reabre o modal: ainda havia pendência antes da replicação
		h.RebirthUI.SetModalOpen(true)
		t.eq(ui.stepTwo.Visible, true)

		-- Servidor na verdade concluiu e replicou Rebirths = 1 via DataChanged
		h.fireDataChanged("Rebirths", 1)
		h.fireDataChanged("Coins", 25)

		-- Confirmação deve ter sido resetada e não deve mais abrir em etapa 2 por pendência
		t.eq(ui.stepTwo.Visible, false, "aumento de Rebirths deve resetar confirmação")
		h.RebirthUI.SetModalOpen(true)
		t.eq(ui.stepTwo.Visible, false, "pendência liquidada não deve reabrir em etapa 2")
		t.eq(ui.stepOne.Visible, true)

		-- Mesmo se a resposta perdida chegar muito depois, não deve reprocessar nem duplicar toast
		local toastsBeforeLate = #h.getToasts()
		calls[1].resolve({ ok = true, data = { rebirths = 1, gemsReward = 5 } })
		t.eq(#h.getToasts(), toastsBeforeLate, "resposta tardia após liquidação por DataChanged deve ser ignorada")

		-- Próximo rebirth com saldo suficiente deve gerar novo requestId
		h.fireDataChanged("Coins", 25000)
		ui.startBtn.Activated:Fire()
		t.eq(ui.stepTwo.Visible, true)
		ui.confirmBtn.Activated:Fire()
		t.eq(#calls, 2)
		t.ok(calls[2].requestId ~= lostReqId, "nova tentativa após liquidação deve gerar novo requestId")

		h.RebirthController.Destroy()
	end)
end
