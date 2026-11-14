--!strict
-- Main.server.luau (ServerScriptService.Server.Main)
-- Único Script do servidor. Liga a rede e todos os ModuleScripts de Services/:
--   1. NetServer.Init()  -> cria ReplicatedStorage.Remotes
--   2. Service.Init()    -> registra handlers de remotes (sem yield)
--   3. Service.Start()   -> começa a rodar (pode fazer yield; cada um na sua thread)
-- Service novo: basta criar o arquivo em Services/ com Init e Start. Não edite este arquivo.

local NetServer = require(script.Parent.Net.NetServer)

type Service = { Init: () -> (), Start: () -> () }

local services: { [string]: Service } = {}
local names: { string } = {}
for _, module in script.Parent.Services:GetChildren() do
	if module:IsA("ModuleScript") then
		services[module.Name] = (require :: any)(module)
		table.insert(names, module.Name)
	end
end
table.sort(names) -- ordem estável entre execuções

NetServer.Init()

for _, name in names do
	services[name].Init()
end

for _, name in names do
	task.spawn(services[name].Start)
end

print(`[Server] Candy Smash Simulator iniciado ({#names} services)`)
