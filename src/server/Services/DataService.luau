--!strict
-- DataService.luau (ServerScriptService.Server.Services.DataService)
-- O "DataManager" do prompt original. Dono: fundação (mudanças passam pelas duas squads).
--
-- Usa ProfileStore (loleris), que já resolve:
--   * session lock: o mesmo jogador não fica aberto em dois servidores (evita duplicar pets);
--   * auto-save periódico (a cada ~300 s) e salvamento ao sair;
--   * BindToClose: salva todo mundo quando o servidor fecha;
--   * retry com pcall nas chamadas do DataStore;
--   * modo mock no Studio sem acesso à API (nada é salvo de verdade).
--
-- Regras para quem usa este módulo:
--   * Get() devolve a tabela viva. Só LEIA. Para mudar, use Set() ou Update(),
--     que avisam leaderstats e o cliente (DataChanged).
--   * Valores só podem ser número, string, boolean ou tabela desses (nada de Instance/Vector3).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.Game)
local ErrorCodes = require(Shared.ErrorCodes)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)
local Template = require(script.Parent.Parent.Data.Template)
local NetServer = require(script.Parent.Parent.Net.NetServer)

local LEADERSTATS = { "Coins", "Gems", "Rebirths" }

local DataService = {}

-- Disparado quando os dados do jogador terminam de carregar: (player, data)
DataService.Loaded = Signal.new() :: Signal.Signal<Player, Types.PlayerData>
-- Disparado em toda mudança via Set/Update: (player, key, newValue)
DataService.Changed = Signal.new() :: Signal.Signal<Player, string, any>

local store = ProfileStore.New(GameConfig.DataStoreName, Template)
local profiles: { [Player]: any } = {}

-- Migrações de versão. Hoje só existe a versão 1.
local function migrate(data: Types.PlayerData)
	-- Exemplo para o futuro:
	-- if data.Version < 2 then ... data.Version = 2 end
	data.Version = GameConfig.DataVersion
end

local function createLeaderstats(player: Player, data: Types.PlayerData)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	for _, key in LEADERSTATS do
		-- NumberValue (double) aguenta valores muito maiores que IntValue de simulador.
		local value = Instance.new("NumberValue")
		value.Name = key
		value.Value = (data :: any)[key]
		value.Parent = folder
	end
	folder.Parent = player
end

local function sync(player: Player, key: string, value: any)
	if table.find(LEADERSTATS, key) then
		local folder = player:FindFirstChild("leaderstats")
		local stat = folder and folder:FindFirstChild(key) :: NumberValue?
		if stat then
			stat.Value = value
		end
	end
	NetServer.Fire("DataChanged", player, key, value)
	DataService.Changed:Fire(player, key, value)
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Não foi possível carregar seus dados. Entre de novo em alguns segundos.")
		return
	end

	profile:AddUserId(player.UserId) -- exigido para pedidos de exclusão de dados (GDPR)
	profile:Reconcile()
	migrate(profile.Data)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Sua sessão foi aberta em outro servidor. Entre de novo.")
	end)

	if player.Parent ~= Players then
		profile:EndSession() -- saiu enquanto carregava
		return
	end

	profiles[player] = profile
	createLeaderstats(player, profile.Data)
	DataService.Loaded:Fire(player, profile.Data)
end

function DataService.Init()
	NetServer.OnInvoke("GetData", function(player)
		local data = DataService.WaitForData(player, 15)
		if data == nil then
			return { ok = false, err = ErrorCodes.DATA_NOT_LOADED }
		end
		return { ok = true, data = data }
	end, { rate = 2, burst = 3 })
end

function DataService.Start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:EndSession() -- salva e libera o session lock
		end
	end)
end

-- Dados vivos do jogador, ou nil se ainda não carregou. SOMENTE LEITURA.
function DataService.Get(player: Player): Types.PlayerData?
	local profile = profiles[player]
	return if profile and profile:IsActive() then profile.Data else nil
end

function DataService.IsLoaded(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile:IsActive()
end

-- Espera os dados carregarem (ou o jogador sair / estourar o tempo).
function DataService.WaitForData(player: Player, timeout: number?): Types.PlayerData?
	local deadline = os.clock() + (timeout or 30)
	while profiles[player] == nil and player.Parent == Players and os.clock() < deadline do
		task.wait(0.1)
	end
	return DataService.Get(player)
end

-- Troca o valor de um campo. Devolve false se os dados não estão carregados.
function DataService.Set(player: Player, key: string, value: any): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	assert(Template[key] ~= nil, `DataService.Set: campo "{key}" não existe no Template`)
	profile.Data[key] = value
	sync(player, key, value)
	return true
end

-- Atualiza um campo a partir do valor atual. Para tabelas, modifier pode alterar
-- a tabela recebida e devolvê-la. Devolve o novo valor, ou nil se não carregado.
function DataService.Update(player: Player, key: string, modifier: (any) -> any): any
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return nil
	end
	assert(Template[key] ~= nil, `DataService.Update: campo "{key}" não existe no Template`)
	local newValue = modifier(profile.Data[key])
	assert(newValue ~= nil, `DataService.Update: modifier de "{key}" devolveu nil`)
	profile.Data[key] = newValue
	sync(player, key, newValue)
	return newValue
end

-- Pede um salvamento agora (use depois de compras importantes; o auto-save cobre o resto).
function DataService.Save(player: Player)
	local profile = profiles[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

local function matchesSavedData(lastSavedData: any, isSaved: (lastSavedData: any) -> boolean): boolean
	local ok, result = pcall(isSaved, lastSavedData)
	return ok and result == true
end

-- Sem yield. No ProcessReceipt, confira o PurchaseId em LastSavedData.Receipts
-- antes de confirmar uma compra que já aparece nos dados vivos.
function DataService.IsSaved(player: Player, isSaved: (lastSavedData: any) -> boolean): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	return matchesSavedData(profile.LastSavedData, isSaved)
end

-- Pede um salvamento e espera o OnAfterSave, por até 15 segundos por padrão.
-- No ProcessReceipt, passe isSaved conferindo o PurchaseId em LastSavedData.Receipts:
-- um auto-save iniciado antes da compra pode terminar sem conter esse recibo.
-- Pode fazer yield: não chamar de dentro de código que precisa ser sem yield.
function DataService.SaveAndWait(player: Player, timeout: number?, isSaved: ((lastSavedData: any) -> boolean)?): boolean
	local profile = profiles[player]
	if profile == nil or not profile:IsActive() then
		return false
	end
	local duration = timeout or 15
	if duration ~= duration or duration < 0 or duration == math.huge then
		return false
	end
	if isSaved and matchesSavedData(profile.LastSavedData, isSaved) then
		return true
	end
	local deadline = os.clock() + duration
	local saved = false
	local retryRequested = false
	local retryPending = false
	local connection = profile.OnAfterSave:Connect(function(lastSavedData: any)
		if saved or os.clock() > deadline then
			return
		end
		if isSaved == nil or matchesSavedData(lastSavedData, isSaved) then
			saved = true
		elseif not retryRequested then
			-- Só repete uma vez; snapshots antigos continuam sem confirmar a compra.
			retryRequested = true
			retryPending = true
		end
	end)
	local ok = pcall(function()
		profile:Save()
	end)
	if not ok then
		connection:Disconnect()
		return false
	end
	while not saved and profile:IsActive() and os.clock() < deadline do
		if retryPending then
			retryPending = false
			local retryOk = pcall(function()
				profile:Save()
			end)
			if not retryOk then
				connection:Disconnect()
				return false
			end
		end
		task.wait(math.clamp(deadline - os.clock(), 0, 0.1))
	end
	connection:Disconnect()
	return saved and profile:IsActive()
end

return DataService
