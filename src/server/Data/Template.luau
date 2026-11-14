--!strict
-- Template.luau (ServerScriptService.Server.Data.Template)
-- Dados iniciais de um jogador novo. CONTRATO (ver docs/CONTRATO.md).
-- Campo novo: adicione aqui com valor padrão; o Reconcile do ProfileStore preenche nos
-- jogadores antigos. Renomear ou mudar o tipo de um campo exige migração (DataService.migrate).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.Game)
local Types = require(ReplicatedStorage.Shared.Types)

local Template: Types.PlayerData = {
	Version = GameConfig.DataVersion,
	Coins = GameConfig.StartingCoins,
	Gems = 0,
	Rebirths = 0,
	UnlockedAreas = { GameConfig.StartingArea },
	Inventory = {},
	Equipped = {},
}

return Template
