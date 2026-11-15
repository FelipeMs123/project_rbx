# Arte 3D

Fontes do BearGummy em `blender/`: `BearGummy.blend`, `BearGummy_Body.png`,
`BearGummy_Details.png` e `BearGummy_preview_textura.png`.

Pipeline: referência -> Blender via MCP -> bake de textura -> Import 3D no
Studio com Upload -> Save to File em `assets/pets/BearGummy.rbxm` ->
`lune run tools/art/prepare_pet` (na raiz do projeto).

O script sobrescreve o `.rbxm`, preserva `BearBody` como PrimaryPart e acrescenta
um `Core` invisível de reserva. O Rojo combina esse arquivo com os quatro pets
de Parts gerados por `lune run tools/map/build` em `assets/PetModels.model.json`.

Pegadinhas:

- O importador multiplicou a escala por 6: corrigir para a altura alvo de 4 studs.
- A cor cinza 0.639 do importador escurece a textura: usar Color branco nas meshes.
- As bochechas precisam ficar dentro da silhueta da cabeça.
- Exportar com a frente para -Z e preservar essa orientação na importação.

Validação no Studio: conferir um único `ReplicatedStorage.PetModels.BearGummy`,
com seis MeshParts, `PrimaryPart = BearBody` e `Core` invisível. Equipar o pet,
andar e girar para conferir textura, orientação e movimento do conjunto.
