--!nocheck
-- check.luau: portão de qualidade do projeto. Rode com `lune run check`.
-- Todo agente (Claude, Codex, Antigravity) e toda pessoa roda isto antes de abrir PR.
-- Passos: sourcemap -> tipos (luau-lsp) -> lint (selene) -> formato (stylua) -> testes (lune) -> build (rojo).
-- `lune run check fix` formata o código com stylua em vez de só checar.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")

local FIX = process.args[1] == "fix"
local TYPES_URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
local failed = {}

local function step(name: string, program: string, args: { string })
	print(`\n== {name}: {program} {table.concat(args, " ")}`)
	local result = process.exec(program, args, { stdio = "inherit" })
	if not result.ok then
		table.insert(failed, name)
	end
end

-- Pré-requisitos baixados uma vez (ficam no .gitignore)
if not fs.isDir("ServerPackages") then
	step("wally", "wally", { "install" })
end
if not fs.isFile("globalTypes.d.luau") then
	print("Baixando tipos do Roblox para o luau-lsp...")
	local response = net.request(TYPES_URL)
	assert(response.ok, `falha ao baixar {TYPES_URL}`)
	fs.writeFile("globalTypes.d.luau", response.body)
end
if not fs.isFile("roblox.yml") then
	step("selene std", "selene", { "generate-roblox-std" })
end

step("sourcemap", "rojo", { "sourcemap", "default.project.json", "-o", "sourcemap.json" })
step("tipos", "luau-lsp", {
	"analyze",
	"--sourcemap=sourcemap.json",
	"--definitions=@roblox=globalTypes.d.luau",
	"--base-luaurc=.luaurc",
	"--ignore=ServerPackages/**",
	"src",
})
step("lint", "selene", { "src" })
if FIX then
	step("formato", "stylua", { "src", "tests", ".lune" })
else
	step("formato", "stylua", { "--check", "src", "tests", ".lune" })
end
step("testes", "lune", { "run", "tests/run" })
fs.writeDir("build")
step("build", "rojo", { "build", "default.project.json", "-o", "build/game.rbxl" })

if #failed > 0 then
	print(`\nFALHOU: {table.concat(failed, ", ")}`)
	process.exit(1)
end
print("\nTUDO OK")
