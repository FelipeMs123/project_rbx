--!strict
-- Tutorial.luau (ReplicatedStorage.Shared.Logic.Tutorial)
-- Dono: Squad A. Valida avanços e calcula o progresso do tutorial sem Roblox.

export type StepDefinition = { Id: string, TargetCoins: number?, BlockId: string? }
export type Snapshot = { Coins: number, InventoryCount: number, EquippedCount: number }
export type PlayerData = { TutorialStep: number, Rebirths: number, Inventory: { [string]: any } }

local Tutorial = {}

function Tutorial.rewardCompletesStep(stepDef: StepDefinition, payload: any): boolean
	if type(payload) ~= "table" or type(payload.blockType) ~= "string" then
		return false
	end
	return stepDef.Id == "BreakFirstBlock" or (stepDef.Id == "BreakLollipop" and payload.blockType == stepDef.BlockId)
end

function Tutorial.isValidAdvance(current: number, step: any, total: number): boolean
	if type(current) ~= "number" or current ~= current or current < 0 or current == math.huge or current % 1 ~= 0 then
		current = 0
	end
	return type(step) == "number"
		and step == step
		and step ~= math.huge
		and step ~= -math.huge
		and step % 1 == 0
		and step > current
		and step <= total
end

function Tutorial.shouldSkip(data: PlayerData, total: number): boolean
	return data.TutorialStep < total and (data.Rebirths > 0 or next(data.Inventory) ~= nil)
end

function Tutorial.isDone(current: number, total: number): boolean
	return current >= total
end

function Tutorial.currentIndex(current: number, total: number): number?
	return if Tutorial.isDone(current, total) then nil else current + 1
end

function Tutorial.progress(stepDef: StepDefinition, snapshot: Snapshot): (number, number)
	if stepDef.Id == "Reach100Coins" then
		local target = stepDef.TargetCoins or 0
		return math.max(0, math.min(snapshot.Coins, target)), target
	elseif stepDef.Id == "BuyCandyEgg" then
		return math.max(0, math.min(snapshot.InventoryCount, 1)), 1
	elseif stepDef.Id == "EquipPet" then
		return math.max(0, math.min(snapshot.EquippedCount, 1)), 1
	end
	return 0, 1
end

function Tutorial.isStepSatisfied(stepDef: StepDefinition, snapshot: Snapshot): boolean
	if stepDef.Id == "Reach100Coins" then
		return snapshot.Coins >= (stepDef.TargetCoins or 0)
	elseif stepDef.Id == "BuyCandyEgg" then
		return snapshot.InventoryCount >= 1
	elseif stepDef.Id == "EquipPet" then
		return snapshot.EquippedCount >= 1
	end
	return false
end

return Tutorial
