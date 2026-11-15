--!nocheck
local Tutorial = require("../src/shared/Logic/Tutorial")

return function(t)
	t.test("recompensa zerada conclui os passos de participação em blocos", function()
		t.ok(
			Tutorial.rewardCompletesStep({ Id = "BreakFirstBlock" }, { coins = 0, gems = 0, blockType = "GummyBlock" })
		)
		t.ok(
			Tutorial.rewardCompletesStep(
				{ Id = "BreakLollipop", BlockId = "LollipopBlock" },
				{ coins = 0, gems = 0, blockType = "LollipopBlock" }
			)
		)
	end)
	t.test("primeiro passo aceita recompensa de qualquer tipo de bloco", function()
		for _, blockType in { "GummyBlock", "LollipopBlock", "ChocolateBlock", "CloudBlock" } do
			t.ok(Tutorial.rewardCompletesStep({ Id = "BreakFirstBlock" }, { blockType = blockType }))
		end
	end)

	t.test("passo do Pirulito exige recompensa do bloco indicado", function()
		local step = { Id = "BreakLollipop", BlockId = "LollipopBlock" }
		t.eq(Tutorial.rewardCompletesStep(step, { blockType = "GummyBlock" }), false)
		t.ok(Tutorial.rewardCompletesStep(step, { blockType = "LollipopBlock" }))
		t.eq(Tutorial.rewardCompletesStep({ Id = "Reach100Coins" }, { blockType = "LollipopBlock" }), false)
	end)

	t.test("diária e payload inválido não concluem passos de bloco", function()
		for _, step in { { Id = "BreakFirstBlock" }, { Id = "BreakLollipop", BlockId = "LollipopBlock" } } do
			t.eq(Tutorial.rewardCompletesStep(step, nil), false)
			for _, payload in
				{ false, 42, "LollipopBlock", {}, { coins = 100, gems = 5 }, { blockType = 42 }, { blockType = {} } }
			do
				t.eq(Tutorial.rewardCompletesStep(step, payload), false)
			end
		end
	end)

	t.test("valida avanço inteiro, finito e dentro do total", function()
		t.ok(Tutorial.isValidAdvance(0, 1, 5))
		t.ok(Tutorial.isValidAdvance(1, 5, 5))
		for _, step in { 0, -1, 2.5, 0 / 0, math.huge, -math.huge, 1e15, -1e15, 6, "2", false } do
			t.eq(Tutorial.isValidAdvance(1, step, 5), false)
		end
		t.eq(Tutorial.isValidAdvance(2, 2, 5), false)
		t.eq(Tutorial.isValidAdvance(2, 1, 5), false)
		t.eq(Tutorial.isValidAdvance(5, 5, 5), false)
		t.eq(Tutorial.isValidAdvance(0, nil, 5), false)
	end)

	t.test("progresso atual inválido conta como zero ao avançar", function()
		for _, current in { -1, 2.5, 0 / 0, math.huge, -math.huge, "inválido" } do
			t.ok(Tutorial.isValidAdvance(current, 1, 5))
			t.eq(Tutorial.isValidAdvance(current, 0, 5), false)
		end
	end)

	t.test("veteranos pulam somente tutorial incompleto", function()
		t.eq(Tutorial.shouldSkip({ TutorialStep = 0, Rebirths = 0, Inventory = {} }, 5), false)
		t.ok(Tutorial.shouldSkip({ TutorialStep = 0, Rebirths = 1, Inventory = {} }, 5))
		t.ok(Tutorial.shouldSkip({ TutorialStep = 4, Rebirths = 0, Inventory = { pet = {} } }, 5))
		t.eq(Tutorial.shouldSkip({ TutorialStep = 5, Rebirths = 1, Inventory = { pet = {} } }, 5), false)
		t.eq(Tutorial.shouldSkip({ TutorialStep = 6, Rebirths = 1, Inventory = {} }, 5), false)
	end)

	t.test("identifica conclusão e próximo passo", function()
		t.eq(Tutorial.isDone(0, 5), false)
		t.eq(Tutorial.currentIndex(0, 5), 1)
		t.eq(Tutorial.currentIndex(4, 5), 5)
		t.ok(Tutorial.isDone(5, 5))
		t.eq(Tutorial.currentIndex(5, 5), nil)
		t.eq(Tutorial.currentIndex(6, 5), nil)
		t.ok(Tutorial.isDone(0, 0))
	end)

	t.test("calcula progresso e satisfação dos passos por snapshot", function()
		local snapshot = { Coins = 47, InventoryCount = 0, EquippedCount = 0 }
		local coins = { Id = "Reach100Coins", TargetCoins = 100 }
		local egg = { Id = "BuyCandyEgg" }
		local equip = { Id = "EquipPet" }
		local value, target = Tutorial.progress(coins, snapshot)
		t.eq(value, 47)
		t.eq(target, 100)
		t.eq(Tutorial.isStepSatisfied(coins, snapshot), false)
		for _, step in { egg, equip } do
			value, target = Tutorial.progress(step, snapshot)
			t.eq(value, 0)
			t.eq(target, 1)
			t.eq(Tutorial.isStepSatisfied(step, snapshot), false)
		end
		snapshot = { Coins = 100, InventoryCount = 1, EquippedCount = 1 }
		for _, step in { coins, egg, equip } do
			t.ok(Tutorial.isStepSatisfied(step, snapshot))
		end
		snapshot = { Coins = 101, InventoryCount = 2, EquippedCount = 2 }
		for _, step in { coins, egg, equip } do
			value, target = Tutorial.progress(step, snapshot)
			t.eq(value, target)
			t.ok(Tutorial.isStepSatisfied(step, snapshot))
		end
	end)

	t.test("progresso nunca fica negativo", function()
		local snapshot = { Coins = -5, InventoryCount = -1, EquippedCount = -1 }
		for _, step in { { Id = "Reach100Coins", TargetCoins = 100 }, { Id = "BuyCandyEgg" }, { Id = "EquipPet" } } do
			local value, target = Tutorial.progress(step, snapshot)
			t.eq(value, 0)
			t.eq(target, if step.Id == "Reach100Coins" then 100 else 1)
			t.eq(Tutorial.isStepSatisfied(step, snapshot), false)
		end
	end)

	t.test("passos de bloco dependem de evento", function()
		local snapshot = { Coins = 100, InventoryCount = 1, EquippedCount = 1 }
		for _, id in { "BreakFirstBlock", "BreakLollipop" } do
			local step = { Id = id }
			local value, target = Tutorial.progress(step, snapshot)
			t.eq(value, 0)
			t.eq(target, 1)
			t.eq(Tutorial.isStepSatisfied(step, snapshot), false)
		end
	end)
end
