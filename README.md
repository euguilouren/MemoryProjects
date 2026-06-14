# MemoryProjects

Repositório de **projetos, código e apps** do ecossistema Memory. O conhecimento, os dados e as definições dos agentes ficam no repositório irmão [`euguilouren/MemoryCode`](https://github.com/euguilouren/MemoryCode) (o "segundo cérebro"); aqui vivem os artefatos executáveis que esse cérebro ajuda a produzir.

A separação segue a virada de 2026-06-13: **código de projeto sai do cérebro; conhecimento e histórico ficam.** As decisões, causa-raiz de bugs e lições de cada projeto permanecem registradas no MemoryCode em `registros/projetos/`.

## Projetos

- **`sentinela/`** — app Android (Kotlin + Jetpack Compose) de privacidade e proteção: cofre AES-256 e detector de postura de segurança. Origem: MemoryCode `projetos/sentinela/`.
- **`gerador-pop/`** — app HTML standalone que gera Procedimento Operacional Padrão (POP). Pode ser servido direto pelo GitHub Pages. Origem: MemoryCode `docs/gerador-pop/`.

## CI

- `.github/workflows/android-sentinela.yml` — compila o APK do Sentinela (paths `sentinela/**`, working-directory `sentinela`).

## Histórico

A transferência inicial veio do MemoryCode em 2026-06-14 — ver [`README-TRANSFERENCIA.md`](README-TRANSFERENCIA.md) para o registro da migração.
