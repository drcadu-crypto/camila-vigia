# Vigia Camila

Monitor externo (GitHub Actions) que checa se a Camila (atendente da AngioGold)
está no ar e avisa no Telegram quando cai.

- Roda **fora** do PC de casa (de propósito: se o PC/internet cair, o vigia
  precisa estar vivo pra avisar).
- A cada ~5 min faz um "batimento"; 1x/dia (08h BRT) manda um resumo verde.
- **Nada sensível neste código:** a URL e o token do Telegram ficam em
  *GitHub Secrets* (cifrados), nunca no repositório.

## Alerta fiel (debounce de falha contínua)

A ponte Kommo **oscila por segundos** (o nó de saúde do n8n tem timeout de 10s
e o caminho casa→Kommo dá picos de latência ~8–11s). Isso não é queda real e o
envio ao paciente não falha nesses blips. Por isso o vigia **só alerta em falha
ININTERRUPTA**: pinga espaçado e **qualquer recuperação zera o contador**; só
avisa se ficar caído continuamente por `NEED × STEP` segundos (padrão ~90s).
Um blip de 25–45s que se recupera sozinho **não** dispara alerta.

O nó `Kommo Account` do n8n tem timeout de **20s** (subido de 10s em 2026-07-17,
porque picos de latência de 8–11s casa→Kommo estouravam o teto antigo e geravam
`kommo:false` falso). O `check.sh` pinga com `-m 25` (acima dos 20s do nó) pra
não abortar um ping lento-porém-ok.

Configuração em Secrets: `VIGIA_URL`, `VIGIA_TG_TOKEN`, `VIGIA_TG_CHAT`.
Opcionais (debounce): `VIGIA_STEP_SECS` (padrão `15`), `VIGIA_NEED_FAILS`
(padrão `6` → ~90s contínuos), `VIGIA_MAX_PINGS` (padrão `8`, teto por rodada),
`VIGIA_PING_TIMEOUT` (padrão `25`, `-m` por ping — manter > timeout do nó n8n).
