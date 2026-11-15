--!strict
-- Workspace.Areas.CandyPlaza e ServerStorage.BlockTemplates | Squad A | Gera modelos Rojo 7.
-- Execute na raiz: lune run tools/map/build
-- PrimaryPart via atributos Rojo_Id / Rojo_Target_PrimaryPart (resolvidos pelo Rojo no build).
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local plaza = require("./CandyPlaza")
local templates = require("./BlockTemplates")

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
	for _, key in { "CanQuery", "CanTouch", "Neutral" } do
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
		result.attributes = data.Attributes
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

local candyPlaza = folder("CandyPlaza", {
	makePart(plaza.SpawnLocation),
	folder("BlockSpawns", makeParts(plaza.BlockSpawns)),
	folder("Eggs", {}),
	folder("Scenery", makeParts(plaza.Scenery)),
})
assert(#plaza.Scenery == 54 and #plaza.BlockSpawns == 10 and partCount == 65, "Contagem da praça incorreta")

local models = {}
local expectedCounts: { [string]: number } = { GummyBlock = 6, LollipopBlock = 6, ChocoBlock = 7, CloudBlock = 6 }
for _, template in templates do
	assert(#template.Parts == expectedCounts[template.Name], "Contagem do template incorreta")
	assert(template.Parts[1].Name == "Core", "Template sem Core")
	local children = makeParts(template.Parts)
	local coreId = template.Name .. "Core"
	children[1].attributes = children[1].attributes or {}
	children[1].attributes.Rojo_Id = coreId
	table.insert(models, {
		ClassName = "Model",
		Name = template.Name,
		Children = children,
		attributes = { Rojo_Target_PrimaryPart = coreId },
	})
end
assert(#models == 4 and partCount == 90, "Contagem total incorreta")

fs.writeDir("assets/map")
fs.writeFile("assets/map/CandyPlaza.model.json", serde.encode("json", candyPlaza, true) .. "\n")
fs.writeFile("assets/BlockTemplates.model.json", serde.encode("json", folder("BlockTemplates", models), true) .. "\n")
print("Geradas 90 Parts: CandyPlaza = 65 (54 cenário + 10 marcadores + 1 spawn); templates = 25.")
print("PrimaryPart definida nos 4 templates (Core).")
