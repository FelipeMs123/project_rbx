--!strict
-- Economy.luau (ReplicatedStorage.Shared.Logic.Economy)
-- Dono: fundação. Regras puras de dinheiro (sem APIs do Roblox): testável no Lune.

local Economy = {}

-- Valor de dinheiro aceitável: número finito, inteiro ou não, maior que zero.
-- Recusa NaN (x ~= x), infinito e negativos, que um exploit poderia mandar.
function Economy.isValidAmount(amount: any): boolean
	return type(amount) == "number" and amount == amount and amount > 0 and amount < math.huge
end

-- Multiplicador de moedas pelo número de rebirths. Ex.: 2 rebirths, bônus 0.5 -> 2.0
function Economy.coinMultiplier(rebirths: number, bonusPerRebirth: number): number
	return 1 + math.max(0, rebirths) * bonusPerRebirth
end

-- Moedas creditadas depois do bônus, sempre inteiras.
function Economy.applyCoinBonus(amount: number, rebirths: number, bonusPerRebirth: number): number
	return math.floor(amount * Economy.coinMultiplier(rebirths, bonusPerRebirth))
end

-- Ignora multiplicadores inválidos e arredonda apenas depois de aplicar o produto.
function Economy.applyMultipliers(base: number, multipliers: { any }): number
	local product = 1
	for _, multiplier in multipliers do
		if type(multiplier) == "number" and multiplier == multiplier and multiplier >= 1 and multiplier < math.huge then
			product *= multiplier
		end
	end
	return math.floor(base * product)
end

return Economy
