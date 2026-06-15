# MemoryProjects

Repositório de **projetos, código e apps** do ecossistema Memory. O conhecimento, os dados e as definições dos agentes ficam no repositório irmão [`euguilouren/MemoryCode`](https://github.com/euguilouren/MemoryCode) (o "segundo cérebro"); aqui vivem os artefatos executáveis que esse cérebro ajuda a produzir.

A separação segue a virada de 2026-06-13: **código de projeto sai do cérebro; conhecimento e histórico ficam.** As decisões, causa-raiz de bugs e lições de cada projeto permanecem registradas no MemoryCode em `registros/projetos/`.

## Projetos

- **`sentinela/`** — app Android (Kotlin + Jetpack Compose) de privacidade e proteção: cofre AES-256 e detector de postura de segurança. Origem: MemoryCode `projetos/sentinela/`.
- **`gerador-pop/`** — app HTML standalone que gera Procedimento Operacional Padrão (POP). Pode ser servido direto pelo GitHub Pages. Origem: MemoryCode `docs/gerador-pop/`.

## Desenvolvimento (Claude Code na web)

- **`scripts/setup.sh`** — prepara o ambiente (idempotente; roda no `SessionStart` via `.claude/settings.json`): instala o **Android SDK** (platform-34, build-tools 34), escreve `sentinela/local.properties`, aquece o Gradle e deixa o **gerador-pop** pronto. Tolerante a falha — não derruba a sessão.
- **`scripts/test.sh`** — a **rede de segurança**: compila o sentinela (`assembleDebug`) + testes unitários JVM e valida a sintaxe do JS do gerador-pop. É o gate que o `revisor-de-codigo` (portão de clean code do MemoryCode) roda **antes e depois** de refatorar.

> **Rede:** compilar o sentinela exige que a **política de rede do ambiente** libere os repositórios do Android/Gradle — `dl.google.com`, `maven.google.com`, `services.gradle.org`, `repo.maven.apache.org`, `plugins.gradle.org`. Sem isso, o `setup.sh` avisa e pula o sentinela; o check do gerador-pop roda offline.

## CI

- `.github/workflows/android-sentinela.yml` — compila o APK do Sentinela (paths `sentinela/**`, working-directory `sentinela`).

## Licença

Proprietária — todos os direitos reservados. Ver [`LICENSE`](LICENSE). Código público para visualização/portfólio; uso requer autorização do autor.

## Histórico

A transferência inicial dos projetos veio do MemoryCode em 2026-06-14 (separação cérebro × projetos). O registro permanente da migração — decisões, causa-raiz e lições — fica no MemoryCode, em `registros/projetos/` e no diário `registros/diario/2026-06-14.md`.
