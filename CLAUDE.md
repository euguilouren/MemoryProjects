# Instruções para o Claude Code — MemoryProjects (repo de PROJETOS)

Este é o repositório de **projetos, código e apps**. O conhecimento, as decisões e as definições dos agentes vivem no repo-irmão **`euguilouren/MemoryCode`** (o "segundo cérebro") — a **ÂNCORA obrigatória** de tudo que você construir aqui.

## Regra central: consulte o cérebro ANTES de produzir

> Antes de **construir ou decidir** qualquer coisa de domínio (arquitetura, stack, fiscal, finanças, segurança, UX, dados, jurídico…), **consulte o cérebro primeiro** com o protocolo `consultar-cerebro`, **cite a nota-fonte**, e só então produza. O cérebro é âncora, não gaiola: memória local → conhecimento próprio → web (nessa ordem); nunca responda "não tenho nota" sem antes alcançar o cérebro pelos passos abaixo.

> **Produza o código/artefato AQUI** (neste repo). **Registre decisões, causa-raiz de bug e lições NO MemoryCode**, em `registros/projetos/` (e o diário do dia em `registros/diario/AAAA-MM-DD.md`). Nunca poluir os projetos com notas de conhecimento, nem o cérebro com código.

## Como alcançar o cérebro (cross-repo) — faça isto antes de buscar

O protocolo `consultar-cerebro` usa caminhos **relativos à raiz do MemoryCode**. Como aqui o cwd é outro repo, **resolva a raiz do MemoryCode primeiro** e prefixe todos os comandos com ela. Resolva nesta ordem (do mais explícito ao mais custoso) e use o **primeiro** que existir:

1. **Variável de ambiente** `MEMORYCODE_ROOT`, se definida. → `RAIZ="$MEMORYCODE_ROOT"`
2. **Diretório-irmão** `../MemoryCode` (caso comum: ambos no escopo, lado a lado). → `RAIZ="../MemoryCode"` (absoluto típico: `/home/user/MemoryCode`).
3. **Não está no escopo?** Traga-o: peça/use **`add_repo euguilouren/MemoryCode`** e então resolva a raiz pelo passo 2.

> Por que esta cascata: env var é explícita e imune ao layout; o sibling cobre o caso comum sem nenhuma config; `add_repo` é o fallback quando o cérebro não está no escopo. Os três entregam uma RAIZ absoluta que prefixa os comandos.

Com a RAIZ resolvida, os comandos de recuperação (mesma ordem da skill `consultar-cerebro`):

```
Grep "termo"  <RAIZ>/INDICE.md          # título · caminho · domínio · tags · resumo → abra o caminho
Grep "#tag"   <RAIZ>/TAGS.md            # índice reverso: tudo de um tema
python3 <RAIZ>/scripts/buscar-semantico.py "pergunta em linguagem natural"   # busca por significado (TF-IDF)
```

O `buscar-semantico.py` se auto-localiza (via `__file__`), então roda de qualquer cwd desde que você passe o caminho da RAIZ. Ao abrir uma nota, navegue por `## Relacionado` / `## Backlinks` e pelos MOCs em `<RAIZ>/conhecimento/mocs/`. **Sempre cite a nota-fonte** (`<RAIZ>/caminho/da/nota.md`) do que veio da memória.

## Roteamento: aqui se produz, o método vem do cérebro

- Os **agentes especialistas** (`criador-de-software`, `-de-sites`, `-de-apps`, `-de-excel`, `analista-de-dados`, `revisor-de-codigo`…) e as **skills** (`consultar-cerebro`, `engenheiro-de-prompt`…) vivem no MemoryCode `.claude/` — é de lá que sai o método, os limites e os auditores.
- Todo código gerado passa pelo `revisor-de-codigo` (portão de clean code, testes verdes antes/depois) antes de ser entregue.
- **Mudança de produção** (deploy, CI, artefato servido em runtime) não é "pronta" só com CI verde — exige smoke test / confirmação no ar.

## Convenções

- Idioma **pt-BR**, sem emojis; `kebab-case`; datas ISO `AAAA-MM-DD`.
- Modelo: sempre o mais avançado disponível — **Fable 5** (`claude-fable-5`); se indisponível, **Opus 4.8** (`claude-opus-4-8`). Nunca rebaixar.
- Cada projeto carrega o próprio ferramental (setup/test em sua pasta) — nada solto na raiz. Ver `README.md`.
- Não fazer `git push origin main` sem confirmação (já bloqueado em `.claude/settings.json`).
