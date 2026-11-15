--!strict
-- Workspace.Areas.{CandyPlaza,ChocolateFalls,CottonClouds}, ServerStorage.BlockTemplates e ReplicatedStorage.PetModels
-- Dono: Squad A (A6/A7) / Squad B (B6) | Gera modelos Rojo 7.
-- Execute na raiz: lune run tools/map/build
-- PrimaryPart via atributos Rojo_Id / Rojo_Target_PrimaryPart (resolvidos pelo Rojo no build).
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local plaza = require("./CandyPlaza")
local falls = require("./ChocolateFalls")
local clouds = require("./CottonClouds")
local templates = require("./BlockTemplates")
local petModelsData = require("./PetModels")

local partCount = 0
local function makePart(data: any): any
	-- Equivalente a fromOrientation: Ry * Rx * Rz (ordem Y, X, Z).
	local x, y, z = math.rad(data.Rotation[1]), math.rad(data.Rotation[2]), math.rad(data.Rotation[3])
	local cx, sx = math.cos(x), math.sin(x)
	local cy, sy = math.cos(y), math.sin(y)
	local cz, sz = math.cos(z), math.sin(z)
	local properties: { [string]: any } = {
		Size = data.Size,
		CFrame = {
			CFrame = {
				position = data.Position,
				orientation = {
					{ cy * cz + sy * sx * sz, -cy * sz + sy * sx * cz, sy * cx },
					{ cx * sz, cx * cz, -sx },
					{ -sy * cz + cy * sx * sz, sy * sz + cy * sx * cz, cy * cx },
				},
			},
		},
		Color = { data.Color[1] / 255, data.Color[2] / 255, data.Color[3] / 255 },
		Material = data.Material,
		Anchored = true,
		CanCollide = data.CanCollide,
		Transparency = data.Transparency,
	}
	-- Wedge é classe nativa, não valor de Enum.PartType.
	if data.Shape ~= "Wedge" then
		properties.Shape = data.Shape
	end
	for _, key in { "CanQuery", "CanTouch", "Neutral", "Enabled" } do
		if data[key] ~= nil then
			properties[key] = data[key]
		end
	end
	local result: any = {
		ClassName = if data.Shape == "Wedge" then "WedgePart" else data.ClassName or "Part",
		Name = data.Name,
		Properties = properties,
	}
	if next(data.Attributes) ~= nil then
		result.attributes = table.clone(data.Attributes)
	end
	partCount += 1
	return result
end

local function makeParts(data: { any }): { any }
	local children = {}
	for _, part in data do
		table.insert(children, makePart(part))
	end
	return children
end

local function folder(name: string, children: { any }): any
	local result: any = { ClassName = "Folder", Name = name }
	if #children > 0 then
		result.Children = children
	end
	return result
end

local function makeModel(template: any, idPrefix: string?): any
	assert(template.Parts and #template.Parts >= 1, `Model {template.Name} sem Parts`)
	assert(template.Parts[1].Name == "Core", `Model {template.Name} sem Core na 1ª posição`)
	local children = makeParts(template.Parts)
	local coreId = (idPrefix or "") .. template.Name .. "Core"
	children[1].attributes = children[1].attributes or {}
	children[1].attributes.Rojo_Id = coreId
	return {
		ClassName = "Model",
		Name = template.Name,
		Children = children,
		attributes = { Rojo_Target_PrimaryPart = coreId },
	}
end

local function makeModels(list: { any }, idPrefix: string?): { any }
	local result = {}
	for _, item in list do
		table.insert(result, makeModel(item, idPrefix))
	end
	return result
end

local candyPlaza = folder("CandyPlaza", {
	makePart(plaza.SpawnLocation),
	folder("BlockSpawns", makeParts(plaza.BlockSpawns)),
	folder("Eggs", makeModels(plaza.Eggs)),
	folder("Scenery", makeParts(plaza.Scenery)),
})
assert(#plaza.Scenery == 54 and #plaza.BlockSpawns == 10 and #plaza.Eggs == 1, "Contagem da CandyPlaza incorreta")

local blockModels = {}
local expectedCounts: { [string]: number } = { GummyBlock = 6, LollipopBlock = 6, ChocoBlock = 7, CloudBlock = 6 }
for _, template in templates do
	assert(#template.Parts == expectedCounts[template.Name], "Contagem do template incorreta")
	table.insert(blockModels, makeModel(template))
end
assert(#blockModels == 4, "Contagem de BlockTemplates incorreta")

local chocolateFalls = folder("ChocolateFalls", {
	makePart(falls.Bounds),
	makePart(falls.SpawnLocation),
	folder("BlockSpawns", makeParts(falls.BlockSpawns)),
	makeModel(falls.Gate, "ChocolateFalls"),
	folder("Eggs", makeModels(falls.Eggs)),
	folder("Scenery", makeParts(falls.Scenery)),
})
assert(
	#falls.Scenery == 47 and #falls.BlockSpawns == 10 and #falls.Eggs == 1 and #falls.Gate.Parts == 5,
	"Contagem da ChocolateFalls incorreta"
)

local cottonClouds = folder("CottonClouds", {
	makePart(clouds.Bounds),
	makePart(clouds.SpawnLocation),
	folder("BlockSpawns", makeParts(clouds.BlockSpawns)),
	makeModel(clouds.Gate, "CottonClouds"),
	folder("Eggs", makeModels(clouds.Eggs)),
	folder("Scenery", makeParts(clouds.Scenery)),
})
assert(
	#clouds.Scenery == 50 and #clouds.BlockSpawns == 10 and #clouds.Eggs == 0 and #clouds.Gate.Parts == 5,
	"Contagem da CottonClouds incorreta"
)

local expectedPets: { [string]: number } = {
	CottonCat = 9,
	BearGummy = 9,
	LollipopBunny = 10,
	JellyUnicorn = 10,
	ChocolateDragon = 12,
}
local petModels = {}
for _, petTemplate in petModelsData do
	assert(expectedPets[petTemplate.Name] ~= nil, `Pet desconhecido: {petTemplate.Name}`)
	assert(#petTemplate.Parts == expectedPets[petTemplate.Name], `Contagem incorreta no pet {petTemplate.Name}`)
	table.insert(petModels, makeModel(petTemplate, "Pet_"))
end
assert(#petModels == 5, "Contagem de PetModels incorreta")

fs.writeDir("assets/map")
fs.writeFile("assets/map/CandyPlaza.model.json", serde.encode("json", candyPlaza, true) .. "\n")
fs.writeFile("assets/map/ChocolateFalls.model.json", serde.encode("json", chocolateFalls, true) .. "\n")
fs.writeFile("assets/map/CottonClouds.model.json", serde.encode("json", cottonClouds, true) .. "\n")
fs.writeFile(
	"assets/BlockTemplates.model.json",
	serde.encode("json", folder("BlockTemplates", blockModels), true) .. "\n"
)
fs.writeFile("assets/PetModels.model.json", serde.encode("json", folder("PetModels", petModels), true) .. "\n")
print(
	`Geradas {partCount} Parts totais: CandyPlaza (54 cenário + 10 spawns + 1 spawn + CandyEgg 8), ChocolateFalls (47 cenário + 10 spawns + 1 spawn + 1 bounds + Gate 5 + ChocolateEgg 8), CottonClouds (50 cenário + 10 spawns + 1 spawn + 1 bounds + Gate 5 = 67; Eggs vazia), BlockTemplates (4 modelos = 25), PetModels (5 modelos = 50).`
)
print("PrimaryPart definida em todos os blocos, ovos, portão e 5 pets (Core).")
