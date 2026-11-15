--!strict
-- RequestGuard.luau (ReplicatedStorage.Shared.Logic.RequestGuard)
-- Dono: Squad B. Máquina de estado pura para requisições em voo com timeout recuperável (UI libera após 8s),
-- preservação de requestId por chave para retries idempotentes e liquidação no máximo uma vez.

local RequestGuard = {}
RequestGuard.__index = RequestGuard

local MAX_REQUEST_ID_LENGTH = 64
local MAX_SETTLED_HISTORY = 64
local DEFAULT_KEY = "default"

export type ScheduleFn = (seconds: number, callback: () -> ()) -> any
export type CancelFn = (handle: any) -> ()
export type IdGeneratorFn = () -> string

type RequestGuardData = {
	_isBusy: boolean,
	_timedOut: boolean,
	_attemptSeq: number,
	_idSeq: number,
	_resetGeneration: number,
	_activeToken: number?,
	_activeKey: string?,
	_activeRequestId: string?,
	_timeoutHandle: any,
	_cancelFn: CancelFn?,
	_idGenerator: IdGeneratorFn?,
	_pendingByKey: { [string]: string },
	_requestKeyById: { [string]: string },
	_requestGenById: { [string]: number },
	_settled: { [string]: boolean },
	_settledOrder: { string },
}

export type RequestGuard = typeof(setmetatable({} :: RequestGuardData, RequestGuard))

local function normalizeKey(key: string?): string
	if type(key) == "string" and #key > 0 then
		return key
	end
	return DEFAULT_KEY
end

function RequestGuard.new(cancelFn: CancelFn?, idGenerator: IdGeneratorFn?): RequestGuard
	local self: RequestGuardData = {
		_isBusy = false,
		_timedOut = false,
		_attemptSeq = 0,
		_idSeq = 0,
		_resetGeneration = 0,
		_activeToken = nil,
		_activeKey = nil,
		_activeRequestId = nil,
		_timeoutHandle = nil,
		_cancelFn = cancelFn,
		_idGenerator = idGenerator,
		_pendingByKey = {},
		_requestKeyById = {},
		_requestGenById = {},
		_settled = {},
		_settledOrder = {},
	}
	return setmetatable(self, RequestGuard)
end

function RequestGuard._nextRequestId(self: RequestGuard): string
	if self._idGenerator then
		local ok, generated = pcall(self._idGenerator)
		if ok and type(generated) == "string" and #generated >= 1 and #generated <= MAX_REQUEST_ID_LENGTH then
			if self._requestKeyById[generated] == nil and not self._settled[generated] then
				return generated
			end
		end
	end
	self._idSeq += 1
	return `req-{self._idSeq}`
end

function RequestGuard._markSettled(self: RequestGuard, requestId: string)
	if self._settled[requestId] then
		return
	end
	self._settled[requestId] = true
	table.insert(self._settledOrder, requestId)
	while #self._settledOrder > MAX_SETTLED_HISTORY do
		local oldest = table.remove(self._settledOrder, 1)
		if oldest ~= nil then
			self._settled[oldest] = nil
		end
	end
end

function RequestGuard._clearActiveAttempt(self: RequestGuard, cancelTimer: boolean)
	local handle = self._timeoutHandle
	self._isBusy = false
	self._activeToken = nil
	self._activeKey = nil
	self._activeRequestId = nil
	self._timeoutHandle = nil
	if cancelTimer and handle ~= nil and self._cancelFn then
		self._cancelFn(handle)
	end
end

function RequestGuard.IsBusy(self: RequestGuard): boolean
	return self._isBusy
end

-- Alias mantido para clareza semântica em chamadas existentes.
function RequestGuard.IsInFlight(self: RequestGuard): boolean
	return self._isBusy
end

function RequestGuard.HasTimedOut(self: RequestGuard): boolean
	return self._timedOut
end

function RequestGuard.HasPending(self: RequestGuard, key: string?): boolean
	return self._pendingByKey[normalizeKey(key)] ~= nil
end

function RequestGuard.GetPendingRequestId(self: RequestGuard, key: string?): string?
	return self._pendingByKey[normalizeKey(key)]
end

function RequestGuard.GetActiveToken(self: RequestGuard): number?
	return self._activeToken
end

function RequestGuard.GetActiveRequestId(self: RequestGuard): string?
	return self._activeRequestId
end

function RequestGuard.IsSettled(self: RequestGuard, requestId: string): boolean
	return type(requestId) == "string" and self._settled[requestId] == true
end

function RequestGuard.Begin(self: RequestGuard, key: string?): (number?, string?)
	if self._isBusy then
		return nil, nil
	end

	local targetKey = normalizeKey(key)
	local requestId = self._pendingByKey[targetKey]
	if requestId == nil then
		requestId = self:_nextRequestId()
		self._pendingByKey[targetKey] = requestId
		self._requestKeyById[requestId] = targetKey
		self._requestGenById[requestId] = self._resetGeneration
	end

	self._attemptSeq += 1
	local token = self._attemptSeq

	self._isBusy = true
	self._timedOut = false
	self._activeToken = token
	self._activeKey = targetKey
	self._activeRequestId = requestId
	self._timeoutHandle = nil

	return token, requestId
end

function RequestGuard.ScheduleTimeout(
	self: RequestGuard,
	token: number,
	seconds: number,
	scheduleFn: ScheduleFn,
	onTimeout: () -> ()
): any?
	if not self._isBusy or self._activeToken ~= token then
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
		if self._isBusy and self._activeToken == token then
			self._timeoutHandle = handle
		elseif handle ~= nil and self._cancelFn then
			self._cancelFn(handle)
		end
	end

	return handle
end

function RequestGuard.OnTimeout(self: RequestGuard, token: number): boolean
	if not self._isBusy or self._activeToken ~= token then
		return false
	end

	-- Libera a UI (IsBusy = false), mas preserva _pendingByKey[key] para que retry ou resposta tardia use o mesmo requestId.
	self._timedOut = true
	self:_clearActiveAttempt(false)
	return true
end

-- Resposta transitória (ex.: RATE_LIMITED porque a tentativa anterior ainda executa no servidor):
-- libera a UI se esta for a tentativa ativa, mantendo o requestId pendente para novo retry.
function RequestGuard.ResolveTransient(self: RequestGuard, token: number, requestId: string): boolean
	if type(requestId) ~= "string" then
		return false
	end
	if self._requestGenById[requestId] ~= self._resetGeneration or self._settled[requestId] then
		return false
	end
	if self._requestKeyById[requestId] == nil then
		return false
	end

	if self._isBusy then
		if self._activeToken ~= token then
			-- Existe outra tentativa mais nova aguardando resposta na UI; não interromper o estado dela.
			return false
		end
		self._timedOut = false
		self:_clearActiveAttempt(true)
		return true
	end

	return true
end

-- Resposta definitiva (ok = true ou erro definitivo): liquida o requestId no máximo uma vez,
-- limpa o pendente da chave e cancela o timer da tentativa ativa desse requestId.
function RequestGuard.ResolveDefinitive(self: RequestGuard, token: number, requestId: string): (boolean, boolean)
	if type(requestId) ~= "string" then
		return false, false
	end
	if self._requestGenById[requestId] ~= self._resetGeneration or self._settled[requestId] then
		return false, false
	end

	local key = self._requestKeyById[requestId]
	if key == nil then
		return false, false
	end

	local wasTimedOut = self._timedOut
	self:_markSettled(requestId)
	if self._pendingByKey[key] == requestId then
		self._pendingByKey[key] = nil
	end
	self._requestKeyById[requestId] = nil
	self._requestGenById[requestId] = nil

	if self._isBusy and (self._activeRequestId == requestId or self._activeToken == token) then
		self._timedOut = false
		self:_clearActiveAttempt(true)
	elseif not self._isBusy then
		self._timedOut = false
	end

	return true, wasTimedOut
end

function RequestGuard.Reset(self: RequestGuard)
	self._timedOut = false
	self._resetGeneration += 1
	self:_clearActiveAttempt(true)
	table.clear(self._pendingByKey)
	table.clear(self._requestKeyById)
	table.clear(self._requestGenById)
	table.clear(self._settled)
	table.clear(self._settledOrder)
end

return RequestGuard
