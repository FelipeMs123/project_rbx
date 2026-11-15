#!/bin/sh
# Testa a delegação com ferramentas simuladas em uma cópia temporária.

origem=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 1
teste=$(mktemp -d "${TMPDIR:-/tmp}/teste-delegar.XXXXXXXX") || exit 1
trap 'rm -rf "$teste"' 0
trap 'exit 1' HUP INT TERM
mkdir -p "$teste/repo/tools/ia" || exit 1
cp "$origem/delegar.sh" "$teste/repo/tools/ia/delegar.sh" || exit 1
printf 'prompt de teste\n' > "$teste/prompt"
cat > "$teste/stub" <<'EOF'
#!/bin/sh
nome=${0##*/}
printf '%s\n' "$nome" >> "$CHAMADAS"
printf '%s\n' "$@" >> "$ARGUMENTOS"
if [ "$nome" = codex ]; then
    [ "${ALTERAR_ARVORE:-0}" -eq 0 ] || printf alterado > arquivo-criado
    printf '%s\n' "$CODEX_SAIDA"
    exit "$CODEX_CODIGO"
fi
printf '%s\n' "$AGY_SAIDA"
exit "$AGY_CODIGO"
EOF
cp "$teste/stub" "$teste/codex"
cp "$teste/stub" "$teste/agy"
CODEX_BIN=$teste/codex AGY_BIN=$teste/agy CHAMADAS=$teste/chamadas ARGUMENTOS=$teste/argumentos
export CODEX_BIN AGY_BIN CHAMADAS ARGUMENTOS
falhas=0
preparar() {
    : > "$CHAMADAS"; : > "$ARGUMENTOS"
    CODEX_SAIDA=ok CODEX_CODIGO=0 AGY_SAIDA=ok AGY_CODIGO=0 ALTERAR_ARVORE=0
    export CODEX_SAIDA CODEX_CODIGO AGY_SAIDA AGY_CODIGO ALTERAR_ARVORE
}
resultado() {
    if [ "$1" -eq 0 ]; then printf 'OK: %s\n' "$2"; else printf 'FALHOU: %s\n' "$2"; falhas=$((falhas + 1)); fi
}
rodar() {
    sh "$teste/repo/tools/ia/delegar.sh" "$@" > "$teste/captura" 2>&1
    status=$?
}

preparar
rodar simples "$teste/prompt" --saida "$teste/saida"
if [ "$status" -eq 0 ] && [ "$(cat "$CHAMADAS")" = codex ] && cmp -s "$teste/captura" "$teste/saida"; then resultado 0 'primário ok'; else resultado 1 'primário ok'; fi

preparar
CODEX_SAIDA='429 Too Many Requests' CODEX_CODIGO=1
rodar simples "$teste/prompt"
if [ "$status" -eq 0 ] && [ "$(cat "$CHAMADAS")" = "$(printf 'codex\nagy')" ] && grep -q ' reserva$' "$teste/repo/.alethe/delegar.log"; then resultado 0 'cota e reserva'; else resultado 1 'cota e reserva'; fi

preparar
CODEX_SAIDA='erro comum' CODEX_CODIGO=7
rodar simples "$teste/prompt"
if [ "$status" -eq 7 ] && [ "$(cat "$CHAMADAS")" = codex ]; then resultado 0 'erro comum'; else resultado 1 'erro comum'; fi

preparar
rodar invalido "$teste/prompt"
if [ "$status" -eq 2 ] && [ ! -s "$CHAMADAS" ]; then resultado 0 'nível inválido'; else resultado 1 'nível inválido'; fi

preparar
CODEX_SAIDA='429 Too Many Requests' CODEX_CODIGO=1
rodar simples "$teste/prompt" --mcp
if [ "$status" -eq 3 ] && [ "$(cat "$CHAMADAS")" = codex ]; then resultado 0 'reserva agy com MCP'; else resultado 1 'reserva agy com MCP'; fi

preparar
rodar simples "$teste/prompt" --mcp
if [ "$status" -eq 0 ] && grep -Fx -- '-c' "$ARGUMENTOS" >/dev/null && grep -Fx 'mcp_servers.Roblox_Studio.default_tools_approval_mode="approve"' "$ARGUMENTOS" >/dev/null; then resultado 0 'flag MCP do codex'; else resultado 1 'flag MCP do codex'; fi

# O repositório temporário permite verificar alterações reais feitas pelo primário.
git -C "$teste/repo" init -q || exit 1
git -C "$teste/repo" -c user.name=Teste -c user.email=teste@example.invalid commit --allow-empty -qm inicial || exit 1
preparar
CODEX_SAIDA='429 Too Many Requests' CODEX_CODIGO=1 ALTERAR_ARVORE=1
rodar simples "$teste/prompt"
if [ "$status" -eq 4 ] && [ "$(cat "$CHAMADAS")" = codex ]; then resultado 0 'cota com árvore alterada'; else resultado 1 'cota com árvore alterada'; fi
rm -f "$teste/repo/arquivo-criado"

preparar
CODEX_SAIDA=$(printf 'quota\n'; i=0; while [ "$i" -lt 31 ]; do printf 'linha comum\n'; i=$((i + 1)); done; printf 'código: rate limit = valor\n')
CODEX_CODIGO=7
rodar simples "$teste/prompt"
if [ "$status" -eq 7 ] && [ "$(cat "$CHAMADAS")" = codex ]; then resultado 0 'termos genéricos não indicam cota'; else resultado 1 'termos genéricos não indicam cota'; fi

preparar
rodar critico "$teste/prompt" --mcp
if [ "$status" -eq 0 ] && [ "$(cat "$CHAMADAS")" = codex ] && grep -Fx 'gpt-6.1-sol' "$ARGUMENTOS" >/dev/null && grep -Fx -- '-c' "$ARGUMENTOS" >/dev/null; then resultado 0 'crítico com MCP usa codex'; else resultado 1 'crítico com MCP usa codex'; fi

preparar
CODEX_SAIDA='429 Too Many Requests' CODEX_CODIGO=1
rodar critico "$teste/prompt" --mcp
if [ "$status" -eq 3 ] && [ "$(cat "$CHAMADAS")" = codex ]; then resultado 0 'cota com MCP sem agy'; else resultado 1 'cota com MCP sem agy'; fi

[ "$falhas" -eq 0 ]
