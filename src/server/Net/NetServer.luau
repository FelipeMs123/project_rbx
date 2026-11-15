--!strict
-- NetServer.luau (ServerScriptService.Server.Net.NetServer)
-- Dono: fundação.
-- Camada única de rede do servidor (o "NetworkHandler" do prompt original).
-- 1. Cria ReplicatedStorage.Remotes a partir de Shared.Net.Remotes.
-- 2. Todo handler passa por: rate limit por jogador + pcall (erro de um handler
--    nunca derruba o servidor nem vaza mensagem interna para o cliente).
-- 3. RemoteFunctions sempre devolvem Types.Result.
-- Regra: nenhum Service cria ou acessa RemoteEvent direto; tudo passa por aqui.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local RateLimiter = require(Shared.Logic.RateLimiter)
local ErrorCodes = require(Shared.ErrorCodes)
local Types = require(Shared.Types)

local NetServer = {}

export type Options = {
	rate: number?, -- chamadas por segundo aceitas por jogador (padrão 5)
	burst: number?, -- rajada máxima (padrão = rate)
}

local folder: Folder
local instances: { [string]: Instance } = {}
local limiters: { RateLimiter.RateLimiter } = {}

local function getRemote(name: string): Instance
	local remote = instances[name]
	assert(remote, `NetServer: remote "{name}" não existe em Shared.Net.Remotes`)
	return remote
end

local function makeLimiter(options: Options?): RateLimiter.RateLimiter
	local rate = (options and options.rate) or 5
	local burst = (options and options.burst) or rate
	local limiter = RateLimiter.new(rate, burst)
	table.insert(limiters, limiter)
	return limiter
end

-- Cria todos os remotes. Chamado uma vez pelo Main.server antes dos Services.
function NetServer.Init()
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for name, kind in Remotes do
		local className = if kind == "Function"
			then "RemoteFunction"
			elseif kind == "UnreliableEvent" then "UnreliableRemoteEvent"
			else "RemoteEvent"
		local remote = Instance.new(className)
		remote.Name = name
		if remote:IsA("RemoteFunction") then
			-- Sem callback, o InvokeServer do cliente ficaria travado para sempre.
			-- OnInvoke substitui esta resposta padrão.
			local limiter = makeLimiter({ rate = 2, burst = 3 })
			remote.OnServerInvoke = function(player)
				if not limiter:Allow(player, os.clock()) then
					return { ok = false, err = ErrorCodes.RATE_LIMITED }
				end
				return { ok = false, err = ErrorCodes.NOT_IMPLEMENTED }
			end
		end
		remote.Parent = folder
		instances[name] = remote
	end
	folder.Parent = ReplicatedStorage

	Players.PlayerRemoving:Connect(function(player)
		for _, limiter in limiters do
			limiter:Remove(player)
		end
	end)
end

-- Escuta um RemoteEvent vindo do cliente. Chamadas acima do limite são descartadas em silêncio.
-- O handler DEVE validar o tipo de cada argumento: o cliente pode mandar qualquer coisa.
function NetServer.OnEvent(name: string, handler: (Player, ...any) -> (), options: Options?)
	local remote = getRemote(name) :: RemoteEvent
	assert(remote:IsA("RemoteEvent"), `NetServer.OnEvent: "{name}" não é RemoteEvent`)
	local limiter = makeLimiter(options)
	remote.OnServerEvent:Connect(function(player, ...)
		if not limiter:Allow(player, os.clock()) then
			return
		end
		local ok, err = pcall(handler :: any, player, ...)
		if not ok then
			warn(`[NetServer] {name} falhou para {player.Name}: {err}`)
		end
	end)
end

-- Responde a uma RemoteFunction. O handler devolve Types.Result.
function NetServer.OnInvoke(name: string, handler: (Player, ...any) -> Types.Result, options: Options?)
	local remote = getRemote(name) :: RemoteFunction
	assert(remote:IsA("RemoteFunction"), `NetServer.OnInvoke: "{name}" não é RemoteFunction`)
	local limiter = makeLimiter(options)
	remote.OnServerInvoke = function(player, ...)
		if not limiter:Allow(player, os.clock()) then
			return { ok = false, err = ErrorCodes.RATE_LIMITED }
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(`[NetServer] {name} falhou para {player.Name}: {result}`)
			return { ok = false, err = ErrorCodes.INTERNAL }
		end
		return result
	end
end

function NetServer.Fire(name: string, player: Player, ...: any)
	(getRemote(name) :: RemoteEvent):FireClient(player, ...)
end

function NetServer.FireAll(name: string, ...: any)
	(getRemote(name) :: RemoteEvent):FireAllClients(...)
end

-- Envia só para jogadores perto de `position` (ex.: VFX de um bloco).
function NetServer.FireNearby(name: string, position: Vector3, radius: number, ...: any)
	local remote = getRemote(name) :: RemoteEvent
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - position).Magnitude <= radius then
			remote:FireClient(player, ...)
		end
	end
end

return NetServer
