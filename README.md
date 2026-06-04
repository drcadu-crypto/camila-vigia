# Vigia Camila

Monitor externo (GitHub Actions) que checa se a Camila (atendente da AngioGold)
está no ar e avisa no Telegram quando cai.

- Roda **fora** do PC de casa (de propósito: se o PC/internet cair, o vigia
  precisa estar vivo pra avisar).
- A cada ~5 min faz um "batimento"; 1x/dia (08h BRT) manda um resumo verde.
- **Nada sensível neste código:** a URL e o token do Telegram ficam em
  *GitHub Secrets* (cifrados), nunca no repositório.

Configuração em Secrets: `VIGIA_URL`, `VIGIA_TG_TOKEN`, `VIGIA_TG_CHAT`.
Opcionais: `VIGIA_OK_CODES` (padrão `200,404`), `VIGIA_TRIES` (padrão `3`).
