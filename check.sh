#!/usr/bin/env bash
# Vigia da Camila — checa o endpoint e avisa no Telegram. Nada sensível aqui:
# URL e credenciais vêm de variáveis de ambiente (GitHub Secrets).
set -u

URL="${VIGIA_URL:?}"
TOK="${VIGIA_TG_TOKEN:?}"
CID="${VIGIA_TG_CHAT:?}"
OK_CODES="${VIGIA_OK_CODES:-200,404}"   # códigos que significam "vivo"
MODE="${VIGIA_MODE:-check}"             # check | daily
TRIES="${VIGIA_TRIES:-3}"

tg() {  # envia texto ao Telegram
  curl -s -m 15 -X POST "https://api.telegram.org/bot${TOK}/sendMessage" \
    --data-urlencode chat_id="${CID}" --data-urlencode text="$1" -o /dev/null
}

is_ok() { case ",$OK_CODES," in *,"$1",*) return 0;; *) return 1;; esac; }

# Tenta algumas vezes antes de cravar que caiu (filtra piscada de internet)
alive=0; last="000"
for i in $(seq 1 "$TRIES"); do
  code=$(curl -s -m 10 -o /dev/null -w "%{http_code}" "$URL" || echo 000)
  last="$code"
  if is_ok "$code"; then alive=1; break; fi
  [ "$i" -lt "$TRIES" ] && sleep 15
done

agora=$(TZ=America/Sao_Paulo date '+%H:%M')

if [ "$alive" = "1" ]; then
  echo "VIVO (http $last) às $agora"
  if [ "$MODE" = "daily" ]; then
    tg "✅ Camila funcionando normalmente — sem pendências. (resumo das ${agora})"
  fi
  exit 0
else
  echo "CAIU (último http $last) às $agora"
  tg "🔴 ATENÇÃO: a Camila parou de responder os clientes. Verificar o computador de casa e a internet. (teste das ${agora} sem resposta)"
  exit 1
fi
