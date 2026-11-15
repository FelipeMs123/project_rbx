--!strict
-- Remotes.luau (ReplicatedStorage.Shared.Net.Remotes)
-- Dono: fundação.
-- CONTRATO de rede: lista única de todos os remotes do jogo.
-- O servidor cria as instâncias em ReplicatedStorage.Remotes ao iniciar; o cliente só espera por elas.
-- Assinaturas e regras de validação de cada um estão em docs/CONTRATO.md.
-- Adicionar remote = PR aprovado pelas duas squads.

export type Kind = "Event" | "UnreliableEvent" | "Function"

local Remotes: { [string]: Kind } = {
	-- Cliente -> Servidor
	RequestClick = "Event", -- (blockId: string)
	EquipPet = "Function", -- (uuid: string) -> Result
	UnequipPet = "Function", -- (uuid: string) -> Result
	PurchaseEgg = "Function", -- (eggId: string) -> Result { data = { uuid, petId } }
	RequestRebirth = "Function", -- () -> Result
	UnlockArea = "Function", -- (areaId: string) -> Result
	ClaimDaily = "Function", -- () -> Result { data = { day, streak, coins, gems } }
	SetTutorialStep = "Function", -- (step: number) -> Result
	SetSetting = "Function", -- (key: string, value: boolean) -> Result
	FusePets = "Function", -- (uuids: {string}) -> Result { data = { uuid, petId, variant } }
	GetData = "Function", -- () -> Result { data = PlayerData }

	-- Servidor -> Cliente
	DataChanged = "Event", -- (key: string, value: any)
	BlockHit = "UnreliableEvent", -- (blockId: string, hp: number, maxHp: number, damage: number, attacker: Player)
	BlockBroken = "Event", -- (blockId: string, position: Vector3, blockType: string)
	Notify = "Event", -- (code: string, payload: any?)
}

return table.freeze(Remotes)
