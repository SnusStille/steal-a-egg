-- EggHeist | Server/Util/RateLimiter.lua
-- Token-bucket rate limiter per player per endpoint.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new()
	return setmetatable({ _buckets = {} }, RateLimiter)
end

function RateLimiter:Check(player, endpoint, perSecond, burst)
	perSecond = perSecond or 10
	burst = burst or perSecond
	local userId = player.UserId
	local key = endpoint .. ":" .. tostring(userId)
	local now = os.clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = burst, last = now }
		self._buckets[key] = bucket
	end
	local elapsed = now - bucket.last
	bucket.last = now
	bucket.tokens = math.min(burst, bucket.tokens + elapsed * perSecond)
	if bucket.tokens >= 1 then
		bucket.tokens = bucket.tokens - 1
		return true
	end
	return false
end

function RateLimiter:ClearPlayer(player)
	local suffix = ":" .. tostring(player.UserId)
	for key, _ in pairs(self._buckets) do
		if string.sub(key, -#suffix) == suffix then
			self._buckets[key] = nil
		end
	end
end

return RateLimiter
