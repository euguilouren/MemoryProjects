# entregaveis - gerador de PDF/deck na marca

Pacote reproduzivel que produz **relatorio (PDF)**, **apresentacao (deck 16:9)** em
**PDF**, **.pptx nativo** e **deck web interativo (reveal.js)** on-brand a partir do
**mesmo** conteudo estruturado. E o scaffold que o agente
`criador-de-documentos-e-apresentacoes` (`/criar-documento`) usa para entregar
documentos formatados, versionados e consistentes.

O `slides.json` e o contrato unico: gera **PDF** (`gerar.py`), **.pptx**
(`gerar-pptx.py`) e **.html web** (`gerar-web.py`) sem reescrever conteudo.

## Principio central: separar CONTEUDO de FORMA

O erro mais caro em geracao de documentos e misturar texto com formatacao. Aqui
a pipeline tem duas camadas independentes:

1. **Conteudo** - o texto/dados, em estrutura neutra (`exemplos/relatorio.md`,
   `exemplos/deck.json`). Idealmente vem do cerebro via a skill `redigir-da-rede`.
2. **Forma** - os templates (`templates/*.html` + `*.css`) que so consomem os
   **tokens de marca**. A marca mora no template, nunca espalhada no codigo.

Ganho: **um conteudo, varias saidas**. O mesmo material vira relatorio ou deck
trocando so a camada de forma. (Ancora: `geracao-de-documentos-e-apresentacoes.md`.)

## Estrutura

```
entregaveis/
  marca/
    tokens.json        # FONTE UNICA da identidade (paleta 60-30-10, tipografia, espacamento)
    tokens.css         # espelho dos tokens como custom properties CSS (derivado do JSON)
  templates/
    relatorio.html     # template Jinja2 do relatorio
    relatorio.css      # CSS Paged Media (capa, grid, cabecalho/rodape, paginacao)
    deck.html          # template Jinja2 do deck
    deck.css           # slides 16:9, uma ideia por slide, hierarquia
  exemplos/
    relatorio.md       # conteudo de demonstracao (front-matter + Markdown)
    deck.json          # conteudo de demonstracao (slides estruturados)
  vendor/
    reveal.js/         # reveal.js vendorizado (MIT): reveal.js + reveal.css + LICENSE + VERSION
  gerar.py             # motor PDF: injeta conteudo nos templates e renderiza (WeasyPrint)
  gerar-pptx.py        # motor PPTX: mesmo slides.json em .pptx NATIVO (python-pptx)
  gerar-web.py         # motor WEB: mesmo slides.json em .html AUTOCONTIDO (reveal.js inline)
  requirements.txt     # weasyprint, jinja2, markdown, python-pptx (gerar-web nao tem dep externa)
  check.sh             # rede de seguranca offline + render de fumaca (tolerante a falha)
  saida/               # PDFs/PPTX/HTML gerados (nao versionado)
```

## Como usar

Instale as dependencias (uma vez):

```bash
pip install -r entregaveis/requirements.txt
```

Gere os entregaveis:

```bash
# relatorio PDF a partir do exemplo
python3 entregaveis/gerar.py relatorio

# deck PDF (16:9) a partir do exemplo
python3 entregaveis/gerar.py deck

# os dois exemplos de uma vez (saida/relatorio.pdf e saida/deck.pdf)
python3 entregaveis/gerar.py demo

# usando seu proprio conteudo e destino
python3 entregaveis/gerar.py relatorio --dados meu-conteudo.md --saida saida/meu.pdf

# deck WEB interativo (reveal.js) - um .html AUTOCONTIDO do mesmo slides.json
python3 entregaveis/gerar-web.py                       # saida/deck.html
python3 entregaveis/gerar-web.py --dados meu-deck.json --saida saida/meu-deck.html
```

### Temas (restyle por cor)

Os 3 motores aceitam `--tema NOME` para trocar SO o **visual** (cores), sem tocar
no conteudo nem no layout/contrato `slides.json` (paridade "restyle" do Gamma). A
paleta vem de `marca/tokens.json` (bloco `temas`):

- **`claro`** (default; tambem o comportamento sem `--tema`): navy `#1F3A5F` +
  ambar `#E08A3C` sobre fundo claro - a marca de hoje, **byte-a-byte**.
- **`escuro`**: fundo escuro acessivel (texto principal >= 4,5:1 WCAG AA), ambar
  mantido como acento, navy "subido" para azul claro legivel sobre o escuro.

```bash
python3 entregaveis/gerar.py deck       --tema escuro --saida saida/deck-escuro.pdf
python3 entregaveis/gerar-pptx.py       --tema escuro --saida saida/deck-escuro.pptx
python3 entregaveis/gerar-web.py        --tema escuro --saida saida/deck-escuro.html
python3 entregaveis/gerar.py relatorio  --tema escuro --saida saida/relatorio-escuro.pdf
```

Tema inexistente falha com erro claro listando os disponiveis (nunca silencioso).
Para criar um tema novo, basta adicionar uma entrada em `temas` no `tokens.json`
com as cores que diferem do default - nenhum codigo muda.

O **deck web** (`gerar-web.py`) emite **um unico .html autocontido**: o reveal.js
(`vendor/reveal.js/`, MIT) e o tema da marca ficam **embutidos inline** no arquivo.
Por que vendorizado e inline, nao CDN: o deck abre **offline** (`file://`), nao
depende de rede em runtime e e trivial de hospedar - basta jogar o `.html` no
GitHub Pages (ou abrir no navegador). Setas/espaco navegam; `?print-pdf` no fim da
URL ativa o modo de impressao do reveal. Diferente dos outros motores, **nao tem
dependencia Python externa** (so a stdlib).

Sem WeasyPrint instalado, `gerar.py` **nao quebra**: grava o HTML intermediario
ao lado da saida e avisa como instalar a lib. Util para inspecionar a forma
offline (e e o que o `check.sh` aproveita quando nao ha rede para instalar).

## Trocar a marca: edite so os tokens

Toda a identidade (cores, fontes, escala, espacamento) vive em
`marca/tokens.json`. Para rebrandizar:

1. Edite `marca/tokens.json` (paleta, par tipografico, etc.).
2. Regenere o espelho CSS: `python3 entregaveis/gerar.py sincronizar-tokens`.
3. Gere de novo. Os templates herdam a nova marca sem nenhuma edicao.

A paleta segue a proporcao **60-30-10** (neutro-secundaria-acento) e contraste
WCAG AA, e a tipografia usa um **par display/corpo** com escala consistente -
conforme `design-de-apresentacoes-e-marca.md`.

## PDF agora, .pptx/.docx nativos depois

Este scaffold gera **PDF** via HTML/CSS + WeasyPrint - simples, versionavel e
com CSS Paged Media (paginacao, cabecalho/rodape correntes) que o navegador nao
tem. Para entregaveis **editaveis no Office**, o caminho da nota e:

- **`.pptx` nativo:** `python-pptx` com um **template mestre** (.pptx desenhado
  na marca) e substituicao de placeholders - ganha sempre que ha identidade
  visual forte. Default para deck de cliente que sera editado no PowerPoint.
- **`.docx` nativo:** `python-docx` aplicando **estilos** de um template (nao
  formatacao inline).

(Ancora: `geracao-de-documentos-e-apresentacoes.md`, secoes PPTX e DOCX.)

## Publicar no SharePoint (passo seguinte)

Gerado o arquivo, o caminho de publicacao no M365 e **gerar-e-subir** via
Microsoft Graph API: app registration no Entra ID, OAuth 2.0 (client credentials
para automacao), upload via `PUT .../content` (ou upload session para > 4 MB).
**Segredo nunca no codigo** - use secret de ambiente/cofre. E mudanca de
producao: so "publicado" apos confirmar o item no SharePoint, nao so HTTP 200.

(Ancora: `publicacao-sharepoint-microsoft-graph.md`. Fora do escopo deste
script - vira um passo de CI/publicacao quando o caso surgir.)

## Quem orquestra

O agente **`criador-de-documentos-e-apresentacoes`** (comando `/criar-documento`)
e quem usa este pacote: monta o conteudo (do cerebro via `redigir-da-rede`),
escolhe relatorio ou deck, roda `gerar.py` e entrega o PDF. Todo codigo passa
pelo portao **`revisor-de-codigo`** (clean code, testes verdes antes/depois)
antes de ser entregue.

## Rede de seguranca

```bash
bash entregaveis/check.sh
```

Valida offline (sintaxe de `gerar.py`/`gerar-pptx.py`/`gerar-web.py`, JSON dos
tokens e exemplos, HTML/CSS bem-formados) e faz render de fumaca: PDF/PPTX **se as
libs existirem** (degrada com aviso), e o **deck web sempre** (sem dep externa) -
reabrindo o `.html` para conferir HTML bem-formado, **0 byte de controle** (NUL
quebra o site), N `<section>` e a **honestidade do grafico** no DOM (rotulo de
valor em cada barra, a barra de maior valor nao toca o topo quando `maximo` > o
maior valor, e a cor ambar isolada a 1 barra). Tolerante a falha; idempotente.

## Notas-fonte (cerebro / MemoryCode)

- `conhecimento/engenharia-de-software/geracao-de-documentos-e-apresentacoes.md`
  - mecanismo (WeasyPrint, python-pptx com template mestre, python-docx) e o
  principio conteudo x forma.
- `conhecimento/engenharia-de-software/design-de-apresentacoes-e-marca.md` -
  narrativa, hierarquia, identidade (paleta 60-30-10, tipografia, brand guidelines).
- `conhecimento/engenharia-de-software/publicacao-sharepoint-microsoft-graph.md`
  - publicar o entregavel no M365 via Graph (passo seguinte).

## Ambiente sempre preparado

O `entregaveis/setup.sh` roda no **SessionStart** (`.claude/settings.json`): a cada
sessao, garante as dependencias Python do pipeline (idempotente — pula se ja
presentes; **tolerante a falha** — nunca derruba a sessao). Assim o `gerar.py`
roda "de fabrica".

Duas camadas de "preparado":
- **No repo (versionado, automatico):** este `setup.sh` + o hook de SessionStart.
- **No ambiente (config do dono, uma vez):** para o PDF real, a **politica de rede**
  do ambiente web precisa liberar `pypi.org` e `files.pythonhosted.org`, e o WeasyPrint
  exige libs de sistema (`libpango`/`cairo`). Se faltarem, o pipeline degrada para
  HTML intermediario com aviso claro (ver a saida do `setup.sh`/`check.sh`).

Padrao para um projeto NOVO: crie o `setup.sh`/`test.sh` na pasta do projeto e
adicione-os ao SessionStart, no mesmo molde (checa -> instala -> tolera -> avisa).
