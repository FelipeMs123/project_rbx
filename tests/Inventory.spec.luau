--!nocheck
local Inventory = require("../src/shared/Logic/Inventory")

return function(t)
	local emptyData = { Inventory = {}, Equipped = {} }

	t.test("conta inventário vazio e cheio", function()
		t.eq(Inventory.count(emptyData), 0)
		local data = { Inventory = { a = { Id = "CottonCat" }, b = { Id = "BearGummy" } }, Equipped = {} }
		t.eq(Inventory.count(data), 2)
		t.eq(Inventory.canAdd(data, 2), false)
		t.eq(Inventory.canAdd(data, 0), false)
		t.eq(Inventory.canAdd(emptyData, -1), false)
		local canAdd, err = Inventory.canAdd(data, 3)
		t.eq(canAdd, true)
		t.eq(err, nil)
	end)

	t.test("valida equipamento e precedência dos erros", function()
		local data = {
			Inventory = { a = { Id = "CottonCat" }, b = { Id = "BearGummy" }, c = { Id = "JellyUnicorn" } },
			Equipped = { "a", "b" },
		}
		t.eq(Inventory.isEquipped(data, "a"), true)
		t.eq(Inventory.isEquipped(data, "c"), false)
		local ok, err = Inventory.canEquip(data, "", 3)
		t.eq(ok, false)
		t.eq(err, "INVALID_ARGS")
		ok, err = Inventory.canEquip(data, string.rep("x", 65), 3)
		t.eq(ok, false)
		t.eq(err, "INVALID_ARGS")
		ok, err = Inventory.canEquip(data, "missing", 2)
		t.eq(err, "NOT_OWNED")
		ok, err = Inventory.canEquip(data, "a", 2)
		t.eq(err, "ALREADY_EQUIPPED")
		ok, err = Inventory.canEquip(data, "c", 2)
		t.eq(err, "MAX_EQUIPPED")
		ok, err = Inventory.canEquip(data, "c", 3)
		t.eq(ok, true)
		t.eq(err, nil)
		ok, err = Inventory.canEquip(emptyData, "a", 0)
		t.eq(err, "NOT_OWNED", "NOT_OWNED precede limite")
	end)

	t.test("valida desequipamento", function()
		local data = { Inventory = { owned = { Id = "CottonCat" } }, Equipped = { "owned" } }
		local ok, err = Inventory.canUnequip(data, "")
		t.eq(err, "INVALID_ARGS")
		ok, err = Inventory.canUnequip(data, string.rep("u", 65))
		t.eq(err, "INVALID_ARGS")
		ok, err = Inventory.canUnequip(data, "missing")
		t.eq(err, "NOT_OWNED")
		ok, err = Inventory.canUnequip(data, "owned")
		t.eq(ok, true)
		t.eq(err, nil)
		ok, err = Inventory.canUnequip({ Inventory = { owned = { Id = "x" } }, Equipped = {} }, "owned")
		t.eq(err, "NOT_EQUIPPED")
	end)

	t.test("soma apenas multiplicadores de pets equipados válidos", function()
		local data = {
			Inventory = { cat = { Id = "CottonCat" }, broken = { Id = "RemovedPet" } },
			Equipped = { "cat", "orphan", "broken" },
		}
		local pets = { CottonCat = { Multiplier = 1.5 } }
		t.eq(Inventory.bonus(data, pets), 1.5)
		t.eq(Inventory.bonus(emptyData, pets), 0)
	end)

	t.test("hasPass e maxEquipped interpretam atributo Passes com segurança", function()
		t.eq(Inventory.hasPass("ExtraPetSlot", "ExtraPetSlot"), true)
		t.eq(Inventory.hasPass("AutoClicker,ExtraPetSlot", "ExtraPetSlot"), true)
		t.eq(Inventory.hasPass(" AutoClicker , ExtraPetSlot ", "ExtraPetSlot"), true)
		t.eq(Inventory.hasPass("ExtraPetSlotPlus", "ExtraPetSlot"), false)
		t.eq(Inventory.hasPass("", "ExtraPetSlot"), false)
		t.eq(Inventory.hasPass(nil, "ExtraPetSlot"), false)
		t.eq(Inventory.hasPass(123, "ExtraPetSlot"), false)

		t.eq(Inventory.maxEquipped(3, false, 1), 3)
		t.eq(Inventory.maxEquipped(3, true, 1), 4)
		t.eq(Inventory.maxEquipped(3, true), 4)
	end)
end
