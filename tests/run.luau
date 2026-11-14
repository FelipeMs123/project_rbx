--!nocheck
-- run.luau: roda todos os tests/*.spec.luau. Use `lune run tests/run`.
-- Só módulos PUROS (sem game:GetService) são testados aqui: ficam em src/shared/Logic.
-- Cada spec devolve uma função que recebe `t` com t.test(nome, fn) e t.eq(atual, esperado).

local fs = require("@lune/fs")
local process = require("@lune/process")

local passed, failures = 0, {}

local t = {}
function t.eq(actual, expected, message)
	if actual ~= expected then
		error(`{message or "valor errado"}: esperado {tostring(expected)}, veio {tostring(actual)}`, 2)
	end
end
function t.ok(value, message)
	if not value then
		error(message or "esperava verdadeiro", 2)
	end
end

local files = fs.readDir("tests")
table.sort(files)
for _, file in files do
	if string.match(file, "%.spec%.luau$") then
		local current = file
		t.test = function(name, fn)
			local ok, err = pcall(fn)
			if ok then
				passed += 1
			else
				table.insert(failures, `{current} > {name}: {err}`)
			end
		end
		require(`./{string.gsub(file, "%.luau$", "")}`)(t)
	end
end

print(`{passed} testes passaram, {#failures} falharam`)
for _, failure in failures do
	print("  FALHOU " .. failure)
end
if #failures > 0 then
	process.exit(1)
end
