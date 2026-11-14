--!strict
-- PetService.luau (ServerScriptService.Server.Services.PetService)
-- O "PetManager" do prompt original. Dono: Squad B.
-- ESTADO: stub da fundação. Implementação = tarefa B2 (docs/ROADMAP.md).
-- A API pública abaixo é CONTRATO: a Squad A usa GetDamageBonus no cálculo de dano.

local PetService = {}

-- Soma dos multiplicadores dos pets equipados. Dano = BaseDamage + GetDamageBonus.
function PetService.GetDamageBonus(_player: Player): number
	return 0 -- stub: sem pets até B2
end

-- Cria um pet novo no inventário. Devolve (uuid, nil) ou (nil, ErrorCode).
function PetService.AddPet(_player: Player, _petId: string): (string?, string?)
	error("PetService.AddPet: não implementado (tarefa B2)")
end

function PetService.Init() end

function PetService.Start() end

return PetService
