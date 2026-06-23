# MemoryProjects

Repositório de **projetos, código e apps** do ecossistema Memory. O conhecimento, os dados e as definições dos agentes ficam no repositório irmão [`euguilouren/MemoryCode`](https://github.com/euguilouren/MemoryCode) (o "segundo cérebro"); aqui vivem os artefatos executáveis que esse cérebro ajuda a produzir.

A separação segue a virada de 2026-06-13: **código de projeto sai do cérebro; conhecimento e histórico ficam.** As decisões, causa-raiz de bugs e lições de cada projeto permanecem registradas no MemoryCode em `registros/projetos/`.

## Projetos

- **`entregaveis/`** — pipeline reproduzível de **geração de entregáveis na marca** (PDF, deck, documento), separando conteúdo (do cérebro) de forma (template/tokens). É a **camada de renderização** dos entregáveis do ecossistema e a fundação do estúdio de apresentações em construção.

## Desenvolvimento (Claude Code na web)

Cada projeto carrega o próprio ferramental (nada solto na raiz):

- **`entregaveis/setup.sh`** — prepara o ambiente do pipeline (idempotente; roda no `SessionStart` via `.claude/settings.json`): instala as dependências de geração (ver `entregaveis/requirements.txt`). Tolerante a falha — não derruba a sessão.
- **`entregaveis/check.sh`** — rede de segurança do pipeline: valida o ambiente e a geração antes de entregar.

Esses scripts são o gate que o `revisor-de-codigo` (portão de clean code do MemoryCode) roda **antes e depois** de refatorar.

## Licença

Proprietária — todos os direitos reservados. Ver [`LICENSE`](LICENSE). Código público para visualização/portfólio; uso requer autorização do autor.

## Histórico

A transferência inicial dos projetos veio do MemoryCode em 2026-06-14 (separação cérebro × projetos). Em **2026-06-23**, os projetos legados dormentes **`sentinela/`** (app Android) e **`gerador-pop/`** (gerador de POP em HTML) foram **arquivados** (removidos da árvore ativa) para abrir espaço a novos projetos — o histórico e o código permanecem recuperáveis no Git, e os registros permanentes (decisões, causa-raiz, lições) ficam no MemoryCode em `registros/projetos/` (`sentinela.md`, `gerador-pop.md`).
