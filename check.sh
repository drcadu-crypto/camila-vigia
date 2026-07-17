#!/usr/bin/env bash
# Vigia da Camila — chama o teste de saúde e avisa no Telegram.
# Nada sensível aqui: URL e token vêm de variáveis (GitHub Secrets).
#
# ALERTA FIEL (2026-07-17): antes bastavam 3 falhas em ~30s pra gritar
# "clientes sem resposta". Mas a ponte Kommo OSCILA por segundos (o nó de
# saúde tem timeout de 10s e o caminho casa->Kommo dá picos) — isso não é
# queda real e o envio ao paciente (amojo) não falha nesses blips.
# Agora só alerta em falha CONTÍNUA: pinga espaçado e qualquer recuperação
# ZERA o contador; só avisa se ficar caído ininterrupto por ~NEED*STEP s.
set -u
URL="${VIGIA_URL:?}"; TOK="${VIGIA_TG_TOKEN:?}"; CID="${VIGIA_TG_CHAT:?}"
MODE="${VIGIA_MODE:-check}"

# Debounce de falha contínua (defaults => ~90s ininterruptos pra confirmar queda)
STEP="${VIGIA_STEP_SECS:-15}"     # segundos entre pings
NEED="${VIGIA_NEED_FAILS:-6}"     # falhas CONSECUTIVAS pra confirmar queda (6*15s = 90s)
MAXP="${VIGIA_MAX_PINGS:-8}"      # teto de pings por rodada (não estourar o cron de 5min)
# timeout por ping tem de ficar ACIMA do timeout do nó "Kommo Account" no n8n
# (20s desde 2026-07-17) — senão abortaríamos um ping lento-porém-ok como falha.
PTMO="${VIGIA_PING_TIMEOUT:-25}"  # -m por ping (>20s do nó); connect curto p/ falha rápida de rede
JCONT="$((NEED * STEP))"          # janela contínua exigida, em segundos

tg() { curl -s -m 15 -X POST "https://api.telegram.org/bot${TOK}/sendMessage" \
       --data-urlencode chat_id="${CID}" --data-urlencode text="$1" -o /dev/null; }

# "no ar" = HTTP 200 e "ok":true no corpo (tolerante a espaços no JSON)
is_alive() { [ "$1" = "200" ] && printf '%s' "$2" | grep -qE '"ok"[[:space:]]*:[[:space:]]*true'; }

streak=0            # falhas consecutivas até agora
last_code="000"; last_body=""; pings=0
while [ "$pings" -lt "$MAXP" ]; do
  resp=$(curl -s --connect-timeout 8 -m "$PTMO" -w $'\n%{http_code}' "$URL" 2>/dev/null || printf '\n000')
  last_code=$(printf '%s' "$resp" | tail -1)
  last_body=$(printf '%s' "$resp" | sed '$d')
  pings=$((pings + 1))
  if is_alive "$last_code" "$last_body"; then
    streak=0
    break                       # está no ar (recuperou ou nunca caiu) -> não alerta
  fi
  streak=$((streak + 1))
  [ "$streak" -ge "$NEED" ] && break    # queda contínua confirmada
  sleep "$STEP"
done

agora=$(TZ=America/Sao_Paulo date '+%H:%M')

# Só é queda REAL se acumulou NEED falhas seguidas. Streak<NEED = blip transitório.
if [ "$streak" -lt "$NEED" ]; then
  echo "VIVO às $agora (streak=$streak/${NEED}, ${last_body})"
  # resumo verde diário só quando de fato saudável no último ping
  [ "$MODE" = "daily" ] && [ "$streak" -eq 0 ] && tg "✅ Camila funcionando normalmente — sem pendências. (resumo das ${agora})"
  exit 0
fi

# Chegou aqui = ~${JCONT}s de falha ININTERRUPTA. Descreve o motivo em linguagem clara.
if [ "$last_code" != "200" ] || [ -z "$last_body" ]; then
  motivo="o sistema da Camila não respondeu por mais de ${JCONT}s — provável queda do computador de casa ou da internet."
elif printf '%s' "$last_body" | grep -qE '"kommo"[[:space:]]*:[[:space:]]*false'; then
  motivo="há mais de ${JCONT}s a Camila está ligada, mas NÃO está conseguindo falar com o sistema de mensagens (Kommo). Os clientes podem não estar recebendo resposta."
elif printf '%s' "$last_body" | grep -qE '"redis"[[:space:]]*:[[:space:]]*false'; then
  motivo="a memória de trabalho da Camila está fora do ar há mais de ${JCONT}s."
else
  motivo="o teste de saúde falhou de forma contínua por mais de ${JCONT}s (resposta inesperada)."
fi
echo "CAIU às $agora (code=$last_code streak=$streak body=$last_body)"
tg "🔴 ATENÇÃO (${agora}): ${motivo}"
exit 1
