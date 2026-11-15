--!strict
-- ReplicatedStorage.PetModels.BearGummy | Squad B | Prepara o modelo importado para PivotTo.
-- Execute na raiz: lune run tools/art/prepare_pet
-- Lê e sobrescreve assets/pets/BearGummy.rbxm usando @lune/roblox.
-- Preserva BearBody, meshes, texturas e orientação (-Z); cria Core de reserva
-- no centro da base das meshes, sem substituir a PrimaryPart BearBody.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

-- Altura padrão dos pets, aproximadamente na cintura do personagem.
local TARGET_HEIGHT = 3
local targetHeight = if process.args[1] then tonumber(process.args[1]) else TARGET_HEIGHT
assert(targetHeight and targetHeight > 0 and targetHeight < math.huge, "Altura deve ser um número positivo e finito")

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

-- A caixa engloba as MeshParts mesmo quando elas estão rotacionadas.
local minX, minY, minZ = math.huge, math.huge, math.huge
local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
for _, part in model:GetDescendants() do
	if part:IsA("MeshPart") then
		local cf, half = part.CFrame, part.Size / 2
		local right, up, look = cf.RightVector, cf.UpVector, cf.LookVector
		local extent = roblox.Vector3.new(
			math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z,
			math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z,
			math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
		)
		local pos = cf.Position
		minX, minY, minZ = math.min(minX, pos.X - extent.X), math.min(minY, pos.Y - extent.Y), math.min(minZ, pos.Z - extent.Z)
		maxX, maxY, maxZ = math.max(maxX, pos.X + extent.X), math.max(maxY, pos.Y + extent.Y), math.max(maxZ, pos.Z + extent.Z)
	end
end
local height = maxY - minY
assert(height > 0 and height < math.huge, "A caixa das MeshParts deve ter altura válida")
local base = roblox.Vector3.new((minX + maxX) / 2, minY, (minZ + maxZ) / 2)
if math.abs(height - targetHeight) / targetHeight > 0.01 then
	local scale = targetHeight / height
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local cf = part.CFrame
			part.Size *= scale
			part.CFrame = roblox.CFrame.new(base + (cf.Position - base) * scale) * (cf - cf.Position)
		end
	end
end
core.CFrame = roblox.CFrame.new(base) * (core.CFrame - core.CFrame.Position)

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
