--!strict
-- Tutorial.luau (ReplicatedStorage.Shared.Config.Tutorial)
-- Dono: Squad A. 5 passos curtos sem teclado.

export type TutorialStep = { Id: string, Text: string, TargetCoins: number?, BlockId: string? }

local Tutorial: { TutorialStep } = {
	{ Id = "BreakFirstBlock", Text = "Toque num bloco de doce para bater!" },
	{ Id = "Reach100Coins", Text = "Quebre blocos até juntar 100 moedas!", TargetCoins = 100 },
	{ Id = "BuyCandyEgg", Text = "Compre seu primeiro Ovo de Doce!" },
	{ Id = "EquipPet", Text = "Abra Pets e equipe seu novo amigo!" },
	{ Id = "BreakLollipop", Text = "Agora quebre um Bloco Pirulito!", BlockId = "LollipopBlock" },
}

return table.freeze(Tutorial)
