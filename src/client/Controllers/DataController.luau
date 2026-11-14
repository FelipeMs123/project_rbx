--!strict
-- DataController.luau (StarterPlayerScripts.Client.Controllers.DataController)
-- Cópia local (só leitura) dos dados do jogador, mantida pelo servidor via DataChanged.
-- Use para mostrar UI. NUNCA use como prova de nada: o servidor é a fonte da verdade.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Types = require(ReplicatedStorage.Shared.Types)
local NetClient = require(script.Parent.Parent.Net.NetClient)

local DataController = {}

-- (key, newValue): disparado a cada mudança, inclusive na carga inicial (uma vez por campo).
DataController.Changed = Signal.new() :: Signal.Signal<string, any>

local data: Types.PlayerData? = nil

function DataController.Get(): Types.PlayerData?
	return data
end

-- Chama fn com o valor atual (se já carregou) e a cada mudança desse campo.
function DataController.Observe(key: string, fn: (any) -> ())
	if data then
		task.spawn(fn, (data :: any)[key])
	end
	return DataController.Changed:Connect(function(changedKey, value)
		if changedKey == key then
			fn(value)
		end
	end)
end

function DataController.Init()
	NetClient.On("DataChanged", function(key: string, value: any)
		if data then
			(data :: any)[key] = value
		end
		DataController.Changed:Fire(key, value)
	end)
end

function DataController.Start()
	-- O ProfileStore pode demorar (ou o servidor recusar por rate limit): tenta até conseguir.
	local result = NetClient.Invoke("GetData")
	while not result.ok do
		warn("[DataController] dados ainda não carregaram:", result.err, "- tentando de novo")
		task.wait(2)
		result = NetClient.Invoke("GetData")
	end
	local snapshot = result.data :: Types.PlayerData
	data = snapshot
	for key, value in snapshot :: any do
		DataController.Changed:Fire(key, value)
	end
end

return DataController
