--!strict
-- ReplicatedStorage.Shared.Logic.SoundRules | Dono: Squad A. Regras puras de áudio e posição.
local SoundRules = {}

export type Point = { X: number, Y: number, Z: number }
export type Box = { id: string, min: Point, max: Point }

local breakSounds: { [string]: string } = {
	GummyBlock = "BlockBreakCommon",
	LollipopBlock = "BlockBreakCommon",
	ChocoBlock = "BlockBreakRare",
	CloudBlock = "BlockBreakEpic",
}

function SoundRules.breakSound(blockType: string): string?
	return breakSounds[blockType]
end

function SoundRules.breakFromReward(payload: any, alreadyPlayed: { [string]: boolean }): (string?, string?)
	if type(payload) ~= "table" or type(payload.blockId) ~= "string" or type(payload.blockType) ~= "string" then
		return nil, nil
	end
	local key = breakSounds[payload.blockType]
	if not key or alreadyPlayed[payload.blockId] then
		return nil, nil
	end
	return key, payload.blockId
end

-- A ordem das caixas resolve sobreposições de forma determinística no chamador.
function SoundRules.areaAt(boxes: { Box }, point: Point): string?
	for _, box in boxes do
		if
			point.X >= box.min.X
			and point.X <= box.max.X
			and point.Y >= box.min.Y
			and point.Y <= box.max.Y
			and point.Z >= box.min.Z
			and point.Z <= box.max.Z
		then
			return box.id
		end
	end
	return nil
end

return SoundRules
