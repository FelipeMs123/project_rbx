--!strict
-- Signal.luau (ReplicatedStorage.Shared.Util.Signal)
-- Evento simples entre módulos do mesmo lado (servidor ou cliente).
-- Diferente de BindableEvent, passa tabelas por referência, sem copiar.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: Connection) -> () }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _listeners = {} :: { [any]: (T...) -> () } }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal:Connect(fn)
	local key = {}
	self._listeners[key] = fn
	local listeners = self._listeners
	return {
		Disconnect = function()
			listeners[key] = nil
		end,
	}
end

function Signal:Fire(...)
	for _, fn in self._listeners do
		task.spawn(fn, ...)
	end
end

return Signal
