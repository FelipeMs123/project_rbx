--!strict
-- ReplicatedStorage.PetModels.BearGummy | Squad B | Prepara o modelo importado para PivotTo.
-- Execute na raiz: lune run tools/art/prepare_pet
-- Lê e sobrescreve assets/pets/BearGummy.rbxm usando @lune/roblox.
-- Preserva BearBody, meshes, texturas, escala e orientação (-Z); cria Core de reserva
-- no centro da face inferior do BearBody, sem substituir a PrimaryPart BearBody.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local path = "assets/pets/BearGummy.rbxm"
local roots = roblox.deserializeModel(fs.readFile(path))
assert(#roots == 1 and roots[1]:IsA("Model"), "Esperado um único Model no arquivo BearGummy.rbxm")
local model = roots[1]
local body = model:FindFirstChild("BearBody")
assert(body and body:IsA("MeshPart"), "BearBody deve ser uma MeshPart filha do Model")
model.Name = "BearGummy"

local core = model:FindFirstChild("Core")
if not core then
	core = roblox.Instance.new("Part")
	core.Name = "Core"
	core.Size = roblox.Vector3.new(1, 1, 1)
	core.CFrame = body.CFrame * roblox.CFrame.new(0, -body.Size.Y / 2, 0)
	core.Parent = model
end
assert(core:IsA("BasePart"), "Core existente deve ser uma BasePart")
core.Transparency = 1

for _, part in model:GetDescendants() do
	if part:IsA("MeshPart") or part == core then
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
	end
end
model.PrimaryPart = body

-- Serializa antes de abrir o arquivo para escrita: falhas de preparação preservam a origem.
local output = roblox.serializeModel(roots)
fs.writeFile(path, output)
print(`Preparado {path}: PrimaryPart = BearBody; Core de reserva; meshes sem física.`)
