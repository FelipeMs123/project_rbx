--!strict
-- NetClient.luau (StarterPlayerScripts.Client.Net.NetClient)
-- Lado cliente da rede. Nenhum controller acessa ReplicatedStorage.Remotes direto.
-- Lembrete: o cliente só PEDE; quem decide moedas, dano e pets é sempre o servidor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Types = require(Shared.Types)

local folder = ReplicatedStorage:WaitForChild("Remotes")

local NetClient = {}

local function getRemote(name: string): Instance
	assert(Remotes[name], `NetClient: remote "{name}" não existe em Shared.Net.Remotes`)
	return folder:WaitForChild(name)
end

function NetClient.Fire(name: string, ...: any)
	(getRemote(name) :: RemoteEvent):FireServer(...)
end

function NetClient.Invoke(name: string, ...: any): Types.Result
	local remote = getRemote(name) :: RemoteFunction
	local ok, result = pcall(remote.InvokeServer, remote :: any, ...)
	if not ok or type(result) ~= "table" then
		return { ok = false, err = "INTERNAL" }
	end
	return result
end

function NetClient.On(name: string, handler: (...any) -> ()): RBXScriptConnection
	local remote = getRemote(name)
	return ((remote :: any).OnClientEvent :: RBXScriptSignal):Connect(handler)
end

return NetClient
