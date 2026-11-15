# Lições aprendidas

Leia este documento antes de iniciar qualquer tarefa. Só o líder da squad (ou um PR de docs) edita este arquivo; agentes workers não editam. Se descobrir uma lição nova, escreva no resumo final: "Lição nova: sintoma -> causa -> o que fazer" e o líder acrescenta.

## Rojo 7.7
- Erro `did not match any variant of untagged enum UnresolvedValue` em `.model.json` -> CFrame sem tipo explícito -> Declarar no formato explícito `{"CFrame": {"CFrame": {"position": [...], "orientation": [[...]]}}}`. (14/11/2026)
- Atributos ignorados silenciosamente no Studio -> Chave declarada como `"Attributes"` (maiúscula) -> Usar sempre a chave em minúsculo: `"attributes"`. (14/11/2026)
- `PrimaryPart` do Model não vincula no sync ao vivo -> `Rojo_Target_PrimaryPart` e `Rojo_Id` só resolvem no `rojo build` -> Manter atributos no JSON para build e usar uma Part de reserva (ex.: `Core`) no código. (14/11/2026)
- Novos nós raiz (Workspace, ServerStorage) não aparecem ou `rojo serve` encerra ao trocar de branch -> Servidor não recarrega nós raiz dinamicamente e cai na troca de branch -> Reiniciar o processo do `rojo serve` no terminal e clicar em Connect no plugin do Studio (reconectar só o plugin não basta). (14/11/2026)
- Erro `Failed to find tool 'rojo' in any project manifest` -> Comando executado fora da pasta de configuração -> Executar o `rojo` sempre na pasta raiz onde está o `rokit.toml`. (14/11/2026)
- Chão do mapa piscando (z-fighting) -> Chão no mesmo Y do Baseplate do Studio -> Subir o chão 0.1 stud. (14/11/2026)

## MCP do Roblox Studio
- `execute_luau` com `require` de Service roda isolado sem dados de jogadores -> MCP instancia cópia separada do módulo no runtime -> Testar pelo datamodel do Client disparando `FireServer` / `InvokeServer` como um jogador real. (14/11/2026)
- Interface 3D invisível em capturas ou impossibilidade de clicar em botões -> `screen_capture` não desenha `BillboardGui` e o MCP não clica na viewport -> Validar interface via código medindo `AbsoluteSize` / `AbsolutePosition` e disparar eventos via script. (14/11/2026)
- Falha de conexão ou comandos executados no lugar errado -> Servidor MCP suporta apenas uma sessão ativa por vez -> Manter apenas uma sessão do Roblox Studio aberta durante os testes. (14/11/2026)

## Luau e Roblox
- `BillboardGui` minúsculo ou ilegível à distância -> Configuração feita apenas com escala do mundo (`UDim2.fromScale`) -> Usar escala combinada com um mínimo em pixels, ex.: `UDim2.new(6, 40, 1.2, 24)`. (14/11/2026)
- Interface no canto superior esquerdo sobreposta ou inacessível -> Chat nativo do Roblox ocupa a região superior esquerda -> Posicionar a HUD fora do canto superior esquerdo ou respeitar margem segura. (14/11/2026)
- Raycast a partir do mouse desalinhado em relação ao cursor -> `UserInputService:GetMouseLocation()` inclui a barra superior, mas `ScreenPointToRay` não -> Subtrair `GuiService:GetGuiInset()` das coordenadas do mouse antes do cálculo. (14/11/2026)
- Chamada `InvokeServer` no cliente trava indefinidamente -> `RemoteFunction` no servidor sem callback atribuído em `OnServerInvoke` -> Sempre registrar um handler padrão no servidor (ex.: retornando código de erro `NOT_IMPLEMENTED`). (14/11/2026)

## Agentes de IA
- Processo em segundo plano do `codex exec` trava em "Reading additional input from stdin" -> Processo aguarda entrada interativa do terminal -> Executar com redirecionamento de entrada: `< /dev/null`. (14/11/2026)
- Ferramenta MCP (`execute_luau`) bloqueada com "approval policy is never" -> Política padrão de aprovação do Codex bloqueia ferramentas MCP -> Adicionar a flag `-c 'mcp_servers.Roblox_Studio.default_tools_approval_mode="approve"'`. (14/11/2026)
- Agente em `agy -p` não edita ou falha ao buscar arquivos -> Modo headless aborta ao negar comandos de terminal e não lê fora do diretório de trabalho -> Proibir terminal explicitamente no prompt e entregar arquivos de entrada dentro da raiz do repositório (`cwd`). (14/11/2026)
- Falha com "home directory not found" ao rodar `lune run check` no sandbox do worker -> Sandbox bloqueia o home directory e o `.git` do repositório principal -> Só quando o sandbox impedir (esse erro), o worker apenas edita código e avisa no resumo; o líder da squad roda o `lune run check`, branch e commit. Fora disso, o worker entrega com `lune run check` passando, como manda o `AGENTS.md`. (14/11/2026)
- Inconsistência de horários nos registros do diário -> Modelos leves (ex.: Flash Low) tendem a alucinar timestamps -> Conferir os horários antes de realizar o commit. (14/11/2026)
- No Git Bash do Windows, `git show origin/x:caminho` ou argumentos `/c` `/d` saem estragados -> Conversão automática de caminhos do MSYS -> Prefixar o comando com `MSYS_NO_PATHCONV=1`. (14/11/2026)
- Agente bate o limite de uso no meio da tarefa -> Cota da conta esgotada -> Delegar com `tools/ia/delegar.sh <nivel> <prompt>`, que troca para o modelo reserva. (15/11/2026)

## Como acrescentar uma lição
Editado apenas pelo líder da squad ou via PR de documentação. Agentes workers não editam este arquivo; se descobrirem uma lição nova durante uma tarefa, devem relatar no resumo final como `Lição nova: sintoma -> causa -> o que fazer` para o líder acrescentar.
1. Escolha a seção correta (Rojo 7.7, MCP do Roblox Studio, Luau e Roblox ou Agentes de IA).
2. Adicione no fim da seção seguindo o formato: `Sintoma -> causa -> o que fazer. (DD/MM/AAAA)`.
3. Generalize: nunca inclua caminhos locais/pessoais, ferramentas proprietárias de uso individual ou segredos.
