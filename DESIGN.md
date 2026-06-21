# DESIGN.md — Sistema de Design do ecossistema Memory

Este é o **espelho legível por humano e por agente de IA** da identidade visual do ecossistema Memory; a versão machine-readable (fonte única de cores/tipografia/espaçamento) vive em [`entregaveis/marca/tokens.json`](entregaveis/marca/tokens.json) — em caso de divergência, o JSON é a verdade e este arquivo deve ser realinhado a ele.

> **Como um agente usa este arquivo:** leia-o antes de gerar qualquer UI ou entregável (página, deck, relatório, componente). Use os hex, fontes e px abaixo exatamente como descritos. Não invente cores fora da paleta nem famílias fora do par display/corpo. Ao gerar CSS, prefira as variáveis de [`entregaveis/marca/tokens.css`](entregaveis/marca/tokens.css) (ex.: `var(--cor-primaria)`) em vez de hex soltos.
>
> Âncora de método: `MemoryCode/conhecimento/engenharia-de-software/design-de-apresentacoes-e-marca.md` (paleta 60-30-10, par display/corpo, escala, hierarquia, WCAG AA).

---

## 1. Visual Theme & Atmosphere

**Mood:** institucional, sóbrio e confiável — o tom de uma consultoria que apresenta números e decide. Azul-marinho profundo como base de autoridade, laranja-âmbar como pontuação calorosa que guia a ação. Nada de gradiente chamativo, glassmorphism ou neon.

**Densidade:** média-baixa. Espaço em branco é ativo, não desperdício — dá respiro e foco. Uma ideia/um destaque por bloco; densidade alta lê como ruído.

**Filosofia:** sistema antes de telas. A consistência (mesma paleta, mesmo par tipográfico, mesma escala) é o que separa "profissional" de "improvisado". O design serve à clareza e à conversão do entregável — forma a serviço da mensagem, nunca enfeite. O leitor deve reconhecer a marca sem ver o logo.

---

## 2. Color Palette & Roles

Paleta na proporção **60-30-10**: neutro domina (60% da área — fundos, texto), secundária estrutura (30% — barras, títulos, blocos), acento pontua (10% — CTA, destaque). Hex extraídos de `tokens.json`.

### Marca (estrutura — ~30%)

| Nome semântico | Hex | Papel funcional |
|---|---|---|
| `primaria` | `#1F3A5F` | Cor de marca; títulos de seção, cabeçalhos, barra de navegação, botão primário |
| `primaria_clara` | `#345B8C` | Hover/estado ativo da primária; faixas e blocos de apoio |
| `secundaria` | `#3E7CB1` | Links, ícones, bordas de destaque, séries de gráfico |
| `acento` | `#E08A3C` | **Reservado para a ação** — CTA principal, número-chave, realce pontual. Não use como cor de área |

### Neutros (base — ~60%)

| Nome | Hex | Papel |
|---|---|---|
| `neutro_900` | `#1A1D21` | Texto principal (= `texto`) |
| `neutro_700` | `#3A3F46` | Texto secundário forte, legendas |
| `neutro_500` | `#6B7280` | Texto suave (= `texto_suave`), placeholders, metadados |
| `neutro_300` | `#C9CED6` | Bordas, divisórias, traço de tabela |
| `neutro_100` | `#EEF1F5` | Fundo suave (= `fundo_suave`), zebra de tabela, cards |
| `neutro_000` | `#FFFFFF` | Fundo principal (= `fundo`) |

### Semânticas (feedback — pontual)

| Nome | Hex | Papel |
|---|---|---|
| `sucesso` | `#2E7D52` | Confirmação, variação positiva, "no alvo" |
| `alerta` | `#B8860B` | Atenção, pendência, variação a observar |
| `erro` | `#B23A3A` | Erro, variação negativa, validação reprovada |

### Contraste (WCAG AA — alvo ≥ 4,5:1 para texto)

- `neutro_900 #1A1D21` sobre `fundo #FFFFFF` → ~15:1. **OK** (corpo).
- `texto_suave #6B7280` sobre `#FFFFFF` → ~4,8:1. **OK** apenas para texto ≥ `base`; não usar em `xs`.
- `#FFFFFF` sobre `primaria #1F3A5F` → ~10:1. **OK** (texto claro em botão/barra escura).
- `acento #E08A3C`: passa AA como **texto grande** ou elemento gráfico sobre branco; para texto pequeno sobre branco, escureça ou use sobre fundo escuro. Acento é para área/realce, não para corpo de texto.

---

## 3. Typography Rules

Par **display (títulos, serifada) + corpo (leitura, sem serifa)** — no máximo 2 famílias. Pesos e alturas de linha de `tokens.json`.

- **Display:** `Georgia, 'Times New Roman', serif` — peso título `700`, altura de linha `1.15`.
- **Corpo:** `'Helvetica Neue', Arial, system-ui, sans-serif` — peso corpo `400`, destaque `600`, altura de linha `1.55`.
- **Mono (código/dados tabulares):** `'SFMono-Regular', Consolas, 'Liberation Mono', monospace`.

### Hierarquia (escala de `tokens.json`)

| Nível | Token | Tamanho | Família | Peso | Uso |
|---|---|---|---|---|---|
| Display / H1 | `3xl` | `3.5rem` (56px) | display | 700 | Título de capa, hero |
| H2 | `2xl` | `2.5rem` (40px) | display | 700 | Título de seção |
| H3 | `xl` | `1.75rem` (28px) | display | 700 | Subtítulo |
| Destaque / lead | `lg` | `1.25rem` (20px) | corpo | 600 | Parágrafo de abertura, rótulo grande |
| Corpo | `base` | `1rem` (16px) | corpo | 400 | Texto padrão |
| Apoio | `sm` | `0.875rem` (14px) | corpo | 400 | Legenda, nota, metadado |
| Micro | `xs` | `0.75rem` (12px) | corpo | 400 | Rodapé, selo — nunca em cinza suave |

Medida de leitura confortável: ~50–75 caracteres por linha. Máximo 2 famílias por entregável — quatro fontes "para animar" são ruído, não identidade.

---

## 4. Component Stylings

Raio de borda padrão: `4px` (`--raio-borda`). Transições suaves (~150ms) em hover/foco.

**Botão primário** — fundo `primaria #1F3A5F`, texto `#FFFFFF`, padding `8px 24px` (`sm`/`lg`), peso `600`.
- *Hover:* fundo `primaria_clara #345B8C`. *Foco:* anel visível `2px` em `secundaria #3E7CB1` (foco nunca invisível). *Desabilitado:* `neutro_300` com texto `neutro_500`.
- **CTA de ação principal:** fundo `acento #E08A3C`, texto `neutro_900`. Um único acento por tela.

**Botão secundário** — fundo transparente, borda `1px` `primaria`, texto `primaria`. *Hover:* fundo `neutro_100`.

**Card** — fundo `#FFFFFF`, borda `1px` `neutro_300` ou sombra nível 1, raio `4px`, padding interno `24px` (`lg`). Título em display `xl`, corpo em `base`.

**Input / campo** — fundo `#FFFFFF`, borda `1px` `neutro_300`, raio `4px`, padding `8px 16px`, texto `base`. Placeholder em `neutro_500`.
- *Foco:* borda `secundaria` + anel `2px`. *Erro:* borda `erro #B23A3A` + mensagem em `erro` abaixo. *Label* sempre presente e associada (semântica antes de ARIA).

**Navegação** — barra fundo `primaria #1F3A5F`, itens texto `#FFFFFF`, item ativo sublinhado/realçado em `acento`. Em mobile, colapsa para menu de hambúrguer com alvos de toque ≥ 44×44px.

Todos os estados — `default`, `hover`, `focus`, `active`, `disabled`, `error` — são obrigatórios; estados vazio/carregando/erro previstos no design.

---

## 5. Layout Principles

**Escala de espaçamento base-8** (`tokens.json` → ritmo vertical e margens consistentes):

| Token | Valor | Uso típico |
|---|---|---|
| `xs` | `4px` | Espaço entre ícone e rótulo |
| `sm` | `8px` | Padding interno compacto |
| `md` | `16px` | Gutter de grid, espaço entre elementos |
| `lg` | `24px` | Padding de card, espaço entre blocos |
| `xl` | `40px` | Espaço entre seções |
| `2xl` | `64px` | Respiro de seção principal / topo de página |

**Grid:** alinhe tudo a uma grade (colunas + margens) — alinhamento inconsistente é o que faz um layout parecer amador. Web: grid de 12 colunas, gutter `16px`. Documento A4: margem `20mm`, coluna de leitura `165mm` (`tokens.json` → `layout`). Deck: proporção `16/9`.

**Espaço em branco** é estrutural: respiro entre seções (`xl`/`2xl`) cria foco e hierarquia. Não preencha o vazio — ele trabalha.

---

## 6. Depth & Elevation

Elevação discreta e funcional — esta é uma marca sóbria; sombra comunica camada, não decora.

| Nível | Sombra | Superfície |
|---|---|---|
| 0 | nenhuma | Fundo de página (`#FFFFFF` / `neutro_100`), conteúdo em fluxo |
| 1 | `0 1px 2px rgba(26,29,33,.08)` | Card, input em repouso, tabela |
| 2 | `0 2px 8px rgba(26,29,33,.12)` | Card em hover, dropdown, popover |
| 3 | `0 8px 24px rgba(26,29,33,.16)` | Modal, menu flutuante |

Hierarquia de superfície: página (`#FFFFFF`) → bloco suave (`neutro_100`) → card (`#FFFFFF` + sombra 1). Sombras sempre em `neutro_900` translúcido (nunca preto puro nem colorido). Bordas `neutro_300` são alternativa à sombra para separar — não use os dois com força ao mesmo tempo.

---

## 7. Do's and Don'ts

**Do**
- Use a proporção 60-30-10: neutro domina, secundária estrutura, acento pontua.
- Reserve `acento #E08A3C` para a **única ação** que a tela/página quer gerar.
- Mantenha o par display/corpo e a escala — uma ideia/um destaque por bloco.
- Garanta contraste AA (≥ 4,5:1), foco visível e alvos de toque ≥ 44px.
- Trate espaço em branco como ativo; alinhe tudo ao grid.
- Em gráfico: maximize dado-tinta (Tufte) — o gráfico certo convence antes do número.

**Don't**
- Paleta de arco-íris ou 3–4 fontes "para animar" — ruído, não identidade.
- Acento como cor de área grande, ou dois acentos competindo na mesma tela.
- Texto em cima de imagem ruidosa; contraste fraco "porque fica elegante".
- `div` para tudo (sem semântica); ARIA tapando buraco de HTML ruim.
- Sombra/3D/grade pesada que enfeita o gráfico em vez de provar (pizza com 8 fatias, eixo cortado enganoso).
- Carrossel de banners e pop-up que atrapalha a leitura/ação.

---

## 8. Responsive Behavior

Mobile-first. Breakpoints:

| Nome | Largura | Comportamento |
|---|---|---|
| `sm` (mobile) | < 640px | Coluna única; nav colapsa para hambúrguer; padding `md` |
| `md` (tablet) | 640–1023px | 2 colunas onde fizer sentido; grid reduzido |
| `lg` (desktop) | ≥ 1024px | Grid de 12 colunas; layout completo; padding `lg`/`xl` |

- **Alvos de toque:** mínimo `44×44px`; espaçamento `sm` entre alvos adjacentes.
- **Estratégia de colapso:** o conteúdo a serviço da ação primária aparece primeiro; o secundário empilha abaixo ou some em mobile. Tabelas largas viram cards empilhados ou rolam horizontalmente com a primeira coluna fixa.
- **Tipografia:** display pode reduzir um degrau da escala em mobile (`3xl`→`2xl`) para caber sem quebrar feio; corpo permanece ≥ `base`.
- **Sem CLS:** reserve dimensão de imagem/fonte (largura/altura explícitas, `font-display: swap`); nunca lazy-load no elemento LCP (hero).

---

## 9. Agent Prompt Guide

### Referência rápida de cor (cola para o agente)

```
Marca:     primaria #1F3A5F | primaria_clara #345B8C | secundaria #3E7CB1 | acento #E08A3C
Neutros:   texto #1A1D21 | texto_suave #6B7280 | borda #C9CED6 | fundo_suave #EEF1F5 | fundo #FFFFFF
Semântica: sucesso #2E7D52 | alerta #B8860B | erro #B23A3A
Fontes:    display = Georgia serif (700) | corpo = Helvetica Neue sans (400/600) | mono = SFMono
Escala:    56/40/28/20/16/14/12px  ·  Espaço base-8: 4/8/16/24/40/64px  ·  Raio 4px
Regra:     60-30-10 · acento só na ação · contraste AA · foco visível · alvo ≥44px
```

### Prompts prontos

**Página/landing**
> "Gere uma landing page mobile-first nesta linguagem visual: fundo `#FFFFFF`, títulos em Georgia serif `#1F3A5F` na escala (H1 56px, H2 40px), corpo em Helvetica Neue 16px `#1A1D21`. Uma única ação primária com botão de acento `#E08A3C` (texto `#1A1D21`). Grid 12 colunas, espaçamento base-8, raio 4px. HTML semântico, contraste AA, foco visível, sem CLS, LCP otimizado. Use as variáveis de `entregaveis/marca/tokens.css`."

**Deck (16:9)**
> "Gere um deck 16:9 nesta marca: capa com título em Georgia 56px `#1F3A5F` sobre `#FFFFFF`; uma ideia por slide, título como afirmação. Acento `#E08A3C` só no número-chave de cada slide. Gráficos com alto dado-tinta (sem 3D/sombra), séries em `#3E7CB1`/`#1F3A5F`. Paleta 60-30-10, máximo 2 fontes."

**Relatório/PDF (A4)**
> "Gere um relatório A4 nesta identidade: margem 20mm, coluna 165mm, corpo 16px Helvetica Neue `#1A1D21` (linha 1.55), títulos Georgia `#1F3A5F`. Zebra de tabela `#EEF1F5`, bordas `#C9CED6`. Rodapé com paginação. Cores semânticas (sucesso/alerta/erro) só em variações de indicador."

**Componente**
> "Gere o componente nesta linguagem: raio 4px, padding base-8, estados default/hover/focus/disabled/error completos. Botão primário `#1F3A5F` (hover `#345B8C`), foco com anel `#3E7CB1`. Semântica antes de ARIA, alvo de toque ≥44px."

---

*Consistência com a fonte de verdade:* todos os valores acima derivam de [`entregaveis/marca/tokens.json`](entregaveis/marca/tokens.json) (v1.0.0, 2026-06-20). Para trocar a marca, edite o JSON e realinhe este espelho — nunca o contrário.
