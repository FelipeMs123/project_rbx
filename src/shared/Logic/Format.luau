--!strict
-- ReplicatedStorage.Shared.Logic.Format | Dono: Squad A. Formatação pura de valores do HUD.
local Format = {}
local suffixes = { "", "K", "M", "B", "T" }

function Format.abbreviate(n: number): string
	if n ~= n or math.abs(n) == math.huge then
		return "0"
	end
	local value = math.abs(n)
	local index = 1
	while value >= 1000 and index < #suffixes do
		value /= 1000
		index += 1
	end
	value = math.floor(value * 10 + 0.5) / 10
	if value >= 1000 and index < #suffixes then
		value /= 1000
		index += 1
	end
	local digits = string.gsub(string.format("%.1f", value), "%.0$", "")
	return (if n < 0 and value > 0 then "-" else "") .. digits .. suffixes[index]
end

return Format
