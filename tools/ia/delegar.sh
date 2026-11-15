#!/bin/sh
# Executa uma tarefa e usa a reserva quando a cota do primário acaba.

uso() {
    printf '%s\n' 'Uso: delegar.sh <nivel> <arquivo-prompt> [--mcp] [--saida <arquivo>]' >&2
    exit 2
}

[ "$#" -ge 2 ] || uso
nivel=$1
arquivo_prompt=$2
shift 2
case $nivel in
    trivial) primaria=agy; modelo_primario=gemini-3.8-flash-low; reserva=codex; modelo_reserva=gpt-6.1-terra ;;
    simples) primaria=codex; modelo_primario=gpt-6.1-terra; reserva=agy; modelo_reserva=gemini-3.8-flash-high ;;
    medio) primaria=codex; modelo_primario=gpt-6.1-sol; reserva=agy; modelo_reserva=gemini-4-argon-medium ;;
    critico) primaria=agy; modelo_primario=gemini-4-hydrogen-high; reserva=codex; modelo_reserva=gpt-6.1-sol ;;
    *) uso ;;
esac
[ -f "$arquivo_prompt" ] && [ -r "$arquivo_prompt" ] || uso
mcp=0
saida=
while [ "$#" -gt 0 ]; do
    case $1 in
        --mcp) [ "$mcp" -eq 0 ] || uso; mcp=1; shift ;;
        --saida) [ "$#" -ge 2 ] && [ -z "$saida" ] && [ -n "$2" ] || uso; saida=$2; shift 2 ;;
        *) uso ;;
    esac
done

# Resolve os caminhos antes de mudar para a raiz do repositório.
prompt=$(cat "$arquivo_prompt") || exit 1
if [ -n "$saida" ]; then
    case $saida in /*) ;; *) saida=$PWD/$saida ;; esac
fi
raiz=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd) || exit 1
CODEX_BIN=${CODEX_BIN:-codex}
AGY_BIN=${AGY_BIN:-agy}
temporario=$(mktemp "${TMPDIR:-/tmp}/delegar.XXXXXXXX") || exit 1
trap 'rm -f "$temporario"' 0
trap 'exit 1' HUP INT TERM
mkdir -p "$raiz/.alethe" || exit 1
cd "$raiz" || exit 1

executar() {
    ferramenta=$1
    modelo=$2
    sufixo=$3
    if [ "$ferramenta" = codex ]; then
        if [ "$mcp" -eq 1 ]; then
            "$CODEX_BIN" exec -m "$modelo" -s workspace-write -C "$raiz" -c 'mcp_servers.Roblox_Studio.default_tools_approval_mode="approve"' "$prompt" </dev/null >"$temporario" 2>&1
        else
            "$CODEX_BIN" exec -m "$modelo" -s workspace-write -C "$raiz" "$prompt" </dev/null >"$temporario" 2>&1
        fi
    else
        "$AGY_BIN" -p "$prompt" --model "$modelo" --mode accept-edits </dev/null >"$temporario" 2>&1
    fi
    codigo=$?
    cat "$temporario"
    printf '%s %s %s %s %s%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$nivel" "$ferramenta" "$modelo" "$codigo" "$sufixo" >> "$raiz/.alethe/delegar.log"
}

executar "$primaria" "$modelo_primario" ''
if [ "$codigo" -ne 0 ] && grep -Ei 'rate limit|usage limit|quota|(^|[^0-9])429([^0-9]|$)|resource_exhausted|too many requests|limit reached' "$temporario" >/dev/null; then
    printf 'Cota esgotada em %s %s; usando reserva %s %s\n' "$primaria" "$modelo_primario" "$reserva" "$modelo_reserva"
    if [ "$reserva" = agy ] && [ "$mcp" -eq 1 ]; then
        printf '%s\n' 'O agy não usa o MCP do Studio.' >&2
        [ -z "$saida" ] || cp "$temporario" "$saida"
        exit 3
    fi
    executar "$reserva" "$modelo_reserva" ' reserva'
fi
[ -z "$saida" ] || cp "$temporario" "$saida" || exit 1
exit "$codigo"
