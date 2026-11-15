--!strict
-- RequestIdempotency.luau (ReplicatedStorage.Shared.Logic.RequestIdempotency)
-- Dono: Squad B. Cache/trava pura de idempotência por jogador e requestId (testável no Lune).

local RequestIdempotency = {}
RequestIdempotency.__index = RequestIdempotency

local DEFAULT_MAX_COMPLETED = 8
local MAX_REQUEST_ID_LENGTH = 64

export type ResultLike = {
	ok: boolean,
	err: string?,
	data: any?,
}

type PlayerEntry = {
	inFlight: { [string]: boolean },
	completedMap: { [string]: ResultLike },
	completedOrder: { string },
}

type RequestIdempotencyData = {
	_maxCompleted: number,
	_players: { [any]: PlayerEntry },
}

export type RequestIdempotency = typeof(setmetatable({} :: RequestIdempotencyData, RequestIdempotency))

function RequestIdempotency.IsValidRequestId(requestId: any): boolean
	return type(requestId) == "string" and #requestId >= 1 and #requestId <= MAX_REQUEST_ID_LENGTH
end

function RequestIdempotency.new(maxCompleted: number?): RequestIdempotency
	local limit = if type(maxCompleted) == "number"
			and maxCompleted == maxCompleted
			and maxCompleted >= 1
		then math.floor(maxCompleted)
		else DEFAULT_MAX_COMPLETED
	local self: RequestIdempotencyData = {
		_maxCompleted = limit,
		_players = {},
	}
	return setmetatable(self, RequestIdempotency)
end

function RequestIdempotency._getOrCreateEntry(self: RequestIdempotency, playerKey: any): PlayerEntry
	local entry = self._players[playerKey]
	if entry == nil then
		entry = {
			inFlight = {},
			completedMap = {},
			completedOrder = {},
		}
		self._players[playerKey] = entry
	end
	return entry
end

function RequestIdempotency._recordCompleted(
	self: RequestIdempotency,
	entry: PlayerEntry,
	requestId: string,
	result: ResultLike
)
	if entry.completedMap[requestId] ~= nil then
		return
	end
	entry.completedMap[requestId] = result
	table.insert(entry.completedOrder, requestId)
	while #entry.completedOrder > self._maxCompleted do
		local oldest = table.remove(entry.completedOrder, 1)
		if oldest ~= nil then
			entry.completedMap[oldest] = nil
		end
	end
end

function RequestIdempotency.IsInFlight(self: RequestIdempotency, playerKey: any, requestId: string): boolean
	local entry = self._players[playerKey]
	return entry ~= nil and entry.inFlight[requestId] == true
end

function RequestIdempotency.GetCompleted(self: RequestIdempotency, playerKey: any, requestId: string): ResultLike?
	local entry = self._players[playerKey]
	if entry == nil then
		return nil
	end
	return entry.completedMap[requestId]
end

function RequestIdempotency.Execute(
	self: RequestIdempotency,
	playerKey: any,
	requestId: any,
	executor: () -> ResultLike
): ResultLike
	if playerKey == nil then
		return { ok = false, err = "INVALID_ARGS" }
	end

	-- Mantém compatibilidade 100% com chamadores legados/testes sem requestId.
	if requestId == nil then
		local ok, result = pcall(executor)
		if not ok or type(result) ~= "table" then
			return { ok = false, err = "INTERNAL" }
		end
		return result
	end

	if not RequestIdempotency.IsValidRequestId(requestId) then
		return { ok = false, err = "INVALID_ARGS" }
	end

	local id = requestId :: string
	local entry = self:_getOrCreateEntry(playerKey)

	local cached = entry.completedMap[id]
	if cached ~= nil then
		return cached
	end

	if entry.inFlight[id] then
		return { ok = false, err = "RATE_LIMITED" }
	end

	entry.inFlight[id] = true
	local ok, result = pcall(executor)
	entry.inFlight[id] = nil

	if not ok or type(result) ~= "table" then
		return { ok = false, err = "INTERNAL" }
	end

	if result.ok == true and self._players[playerKey] == entry then
		self:_recordCompleted(entry, id, result)
	end

	return result
end

-- Libera a memória do jogador (chamar no Players.PlayerRemoving).
function RequestIdempotency.Remove(self: RequestIdempotency, playerKey: any)
	if playerKey ~= nil then
		self._players[playerKey] = nil
	end
end

return RequestIdempotency
