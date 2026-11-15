--!strict
-- WeightedRoll.luau (ReplicatedStorage.Shared.Logic.WeightedRoll)
-- Dono: Squad B. Escolhe um item por peso com entrada aleatória injetada.

local WeightedRoll = {}

function WeightedRoll.pick(weights: { [string]: number }, r: number): string
	assert(type(r) == "number" and r == r and r >= 0 and r < 1, "WeightedRoll: r deve estar em [0, 1)")

	local keys: { string } = {}
	local total = 0
	for key, weight in weights do
		assert(
			type(weight) == "number" and weight == weight and weight >= 0 and weight < math.huge,
			"WeightedRoll: peso inválido"
		)
		if weight > 0 then
			table.insert(keys, key)
			total += weight
		end
	end
	assert(#keys > 0 and total > 0 and total < math.huge, "WeightedRoll: pesos precisam ter total finito positivo")
	table.sort(keys)

	local target = r * total
	local accumulated = 0
	for _, key in keys do
		accumulated += weights[key]
		if target < accumulated then
			return key
		end
	end
	return keys[#keys]
end

return WeightedRoll
