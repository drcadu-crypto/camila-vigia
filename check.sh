#!/usr/bin/env bash
# Vigia da Camila — chama o teste de saúde e avisa no Telegram.
# Nada sensível aqui: URL e token vêm de variáveis (GitHub Secrets).
set -u
URL="${VIGIA_URL:?}"; TOK="${VIGIA_TG_TOKEN:?}"; CID="${VIGIA_TG_CHAT:?}"
MODE="${VIGIA_MODE:-check}"; TRIES="${VIGIA_TRIES:-3}"

tg() { curl -s -m 15 -X POST "https://api.telegram.org/bot${TOK}/sendMessage" \
       --data-urlencode chat_id="${CID}" --data-urlencode text="$1" -o /dev/null; }

body=""; code="000"; alive=0
for i in $(seq 1 "$TRIES"); do
  resp=$(curl -s -m 12 -w $'\n%{http_code}' "$URL" 2>/dev/null || printf '\n000')
  code=$(printf '%s' "$resp" | tail -1)
  body=$(printf '%s' "$resp" | sed '$d')
  if [ "$code" = "200" ] && printf '%s' "$body" | grep -q '"ok":true'; then alive=1; break; fi
  [ "$i" -lt "$TRIES" ] && sleep 15
done

agora=$(TZ=America/Sao_Paulo date '+%H:%M')

if [ "$alive" = "1" ]; then
  echo "VIVO às $agora ($body)"
  [ "$MODE" = "daily" ] && tg "✅ Camila funcionando normalmente — sem pendências. (resumo das ${agora})"
  exit 0
fi

# Descobre o motivo pra avisar em linguagem clara
if [ "$code" != "200" ] || [ -z "$body" ]; then
  motivo="o sistema da Camila não respondeu — provável queda do computador de casa ou da internet."
elif printf '%s' "$body" | grep -q '"kommo":false'; then
  motivo="a Camila está ligada, mas NÃO está conseguindo falar com o sistema de mensagens (Kommo). Os clientes podem não estar recebendo resposta."
elif printf '%s' "$body" | grep -q '"redis":false'; then
  motivo="a memória de trabalho da Camila está fora do ar."
else
  motivo="o teste de saúde falhou (resposta inesperada)."
fi
echo "CAIU às $agora (code=$code body=$body)"
tg "🔴 ATENÇÃO (${agora}): ${motivo}"
exit 1
