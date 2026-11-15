--!strict
-- RequestGuard.luau (ReplicatedStorage.Shared.Logic.RequestGuard)
-- Máquina de estado pura para requisições em voo com timeout não destrutivo,
-- cancelamento de timer na resposta e suporte a resposta tardia.

local RequestGuard = {}
RequestGuard.__index = RequestGuard

export type ScheduleFn = (seconds: number, callback: () -> ()) -> any
export type CancelFn = (handle: any) -> ()

type RequestGuardData = {
	_inFlight: boolean,
	_timedOut: boolean,
	_generation: number,
	_activeToken: number?,
	_timeoutHandle: any,
	_cancelFn: CancelFn?,
}

export type RequestGuard = typeof(setmetatable({} :: RequestGuardData, RequestGuard))

function RequestGuard.new(cancelFn: CancelFn?): RequestGuard
	local self: RequestGuardData = {
		_inFlight = false,
		_timedOut = false,
		_generation = 0,
		_activeToken = nil,
		_timeoutHandle = nil,
		_cancelFn = cancelFn,
	}
	return setmetatable(self, RequestGuard)
end

function RequestGuard.IsInFlight(self: RequestGuard): boolean
	return self._inFlight
end

function RequestGuard.HasTimedOut(self: RequestGuard): boolean
	return self._timedOut
end

function RequestGuard.GetActiveToken(self: RequestGuard): number?
	return self._activeToken
end

function RequestGuard.Begin(self: RequestGuard): number?
	if self._inFlight then
		return nil
	end
	self._generation += 1
	local token = self._generation
	self._inFlight = true
	self._timedOut = false
	self._activeToken = token
	self._timeoutHandle = nil
	return token
end

function RequestGuard.ScheduleTimeout(
	self: RequestGuard,
	token: number,
	seconds: number,
	scheduleFn: ScheduleFn,
	onTimeout: () -> ()
): any?
	if not self._inFlight or self._activeToken ~= token then
		return nil
	end
	if type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 or type(scheduleFn) ~= "function" then
		return nil
	end

	if self._timeoutHandle ~= nil then
		local previousHandle = self._timeoutHandle
		self._timeoutHandle = nil
		if self._cancelFn then
			self._cancelFn(previousHandle)
		end
	end

	local firedSynchronously = false
	local handle = scheduleFn(seconds, function()
		firedSynchronously = true
		if self:OnTimeout(token) then
			onTimeout()
		end
	end)

	if not firedSynchronously then
		if self._inFlight and self._activeToken == token then
			self._timeoutHandle = handle
		elseif handle ~= nil and self._cancelFn then
			self._cancelFn(handle)
		end
	end

	return handle
end

function RequestGuard.OnTimeout(self: RequestGuard, token: number): boolean
	if not self._inFlight or self._activeToken ~= token or self._timedOut then
		return false
	end
	self._timedOut = true
	self._timeoutHandle = nil
	return true
end

function RequestGuard.Resolve(self: RequestGuard, token: number): (boolean, boolean)
	if not self._inFlight or self._activeToken ~= token then
		return false, false
	end

	local wasTimedOut = self._timedOut
	local handle = self._timeoutHandle
	self._inFlight = false
	self._timedOut = false
	self._activeToken = nil
	self._timeoutHandle = nil

	if handle ~= nil and self._cancelFn then
		self._cancelFn(handle)
	end

	return true, wasTimedOut
end

function RequestGuard.Reset(self: RequestGuard)
	local handle = self._timeoutHandle
	self._inFlight = false
	self._timedOut = false
	self._activeToken = nil
	self._timeoutHandle = nil
	self._generation += 1

	if handle ~= nil and self._cancelFn then
		self._cancelFn(handle)
	end
end

return RequestGuard
