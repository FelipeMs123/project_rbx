--!strict
-- RateLimiter.luau (ReplicatedStorage.Shared.Logic.RateLimiter)
-- Token bucket puro (sem APIs do Roblox): testável no Lune.
-- Cada chave (ex.: um Player) tem um "balde" com até `burst` fichas que recarrega
-- `rate` fichas por segundo. Cada ação gasta 1 ficha; sem ficha, a ação é recusada.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, last: number }

export type RateLimiter = typeof(setmetatable(
	{} :: { rate: number, burst: number, buckets: { [any]: Bucket } },
	RateLimiter
))

function RateLimiter.new(rate: number, burst: number): RateLimiter
	assert(rate > 0 and burst >= 1, "RateLimiter: rate > 0 e burst >= 1")
	return setmetatable({ rate = rate, burst = burst, buckets = {} }, RateLimiter)
end

-- Tenta gastar uma ficha. `now` em segundos (os.clock() no Roblox).
function RateLimiter.Allow(self: RateLimiter, key: any, now: number): boolean
	local bucket = self.buckets[key]
	if bucket == nil then
		bucket = { tokens = self.burst, last = now }
		self.buckets[key] = bucket
	end
	local elapsed = math.max(0, now - bucket.last)
	bucket.tokens = math.min(self.burst, bucket.tokens + elapsed * self.rate)
	bucket.last = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

-- Libera a memória da chave (chamar no PlayerRemoving).
function RateLimiter.Remove(self: RateLimiter, key: any)
	self.buckets[key] = nil
end

return RateLimiter
