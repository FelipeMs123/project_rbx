--!strict
-- Main.client.luau (StarterPlayerScripts.Client.Main)
-- Único LocalScript. Liga todos os ModuleScripts de Controllers/: Init() de todos, depois Start().
-- Controller novo: basta criar o arquivo em Controllers/ com Init e Start. Não edite este arquivo.

-- Espera a replicação inicial (ReplicatedStorage.Shared etc.) antes de requerer qualquer módulo.
if not game:IsLoaded() then
	game.Loaded:Wait()
end

type Controller = { Init: () -> (), Start: () -> () }

local controllers: { [string]: Controller } = {}
local names: { string } = {}
for _, module in script.Parent.Controllers:GetChildren() do
	if module:IsA("ModuleScript") then
		controllers[module.Name] = (require :: any)(module)
		table.insert(names, module.Name)
	end
end
table.sort(names)

for _, name in names do
	controllers[name].Init()
end

for _, name in names do
	task.spawn(controllers[name].Start)
end
