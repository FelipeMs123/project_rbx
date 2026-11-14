--!strict
-- Types.luau (ReplicatedStorage.Shared.Types)
-- Tipos compartilhados entre servidor e cliente. Faz parte do CONTRATO:
-- mudar aqui exige PR aprovado pelas duas squads (ver docs/CONTRATO.md).

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

-- Pet salvo no inventário. A chave do inventário é o UUID do pet.
-- Raridade e multiplicador NÃO são salvos: vêm de Config/Pets pelo Id,
-- assim dá para rebalancear sem migrar dados.
export type PetInstance = {
	Id: string,
}

export type PlayerData = {
	Version: number,
	Coins: number,
	Gems: number,
	Rebirths: number,
	UnlockedAreas: { string },
	Inventory: { [string]: PetInstance }, -- [UUID] = PetInstance
	Equipped: { string }, -- lista de UUIDs
}

-- Resposta padrão de toda RemoteFunction.
-- err é um código estável (ver ErrorCodes) que o cliente traduz para texto.
export type Result = {
	ok: boolean,
	err: string?,
	data: any?,
}

export type PetDef = {
	Name: string,
	Rarity: Rarity,
	Multiplier: number,
}

export type EggDef = {
	Name: string,
	Price: number,
	Currency: "Coins" | "Gems",
	Area: string,
	Weights: { [string]: number }, -- [PetId] = peso
}

export type BlockDef = {
	Name: string,
	MaxHP: number,
	Coins: number,
	Gems: number,
	RespawnSeconds: number,
}

export type AreaDef = {
	Name: string,
	Order: number,
	Price: number, -- em Coins; 0 = liberada desde o início
	Blocks: { string }, -- BlockIds que nascem nesta área
}

return nil
