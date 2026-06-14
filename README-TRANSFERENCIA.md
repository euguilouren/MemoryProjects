# Transferência de projetos — MemoryCode → MemoryProjects

Estes artefatos saíram do repositório de conhecimento (MemoryCode) e devem viver aqui (MemoryProjects).
O histórico/decisões de cada projeto permanecem como registro no MemoryCode em `registros/projetos/`.

## Conteúdo
- `sentinela/` — app Android (Kotlin + Compose): privacidade e proteção. Cofre AES-256, detector de postura. (origem: MemoryCode `projetos/sentinela/`)
- `gerador-pop/index.html` — app HTML standalone: gerador de Procedimento Operacional Padrão. (origem: MemoryCode `docs/gerador-pop/`)

## Como publicar no MemoryProjects
1. Copie estas pastas para o clone do repositório `euguilouren/MemoryProjects`.
2. Para o Pages: `gerador-pop/index.html` pode ser servido direto pelo GitHub Pages do MemoryProjects.
3. Commit + push.

## CI incluída
- `.github/workflows/android-sentinela.yml` — workflow que compila o APK do Sentinela. JÁ AJUSTADO para o MemoryProjects (paths `sentinela/**`, working-directory `sentinela`). Era esse workflow que falhava no MemoryCode após a remoção do código.
