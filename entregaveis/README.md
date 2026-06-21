# entregaveis - gerador de PDF/deck na marca

Pacote reproduzivel que produz **relatorio (PDF)** e **apresentacao (deck 16:9)**
on-brand a partir de conteudo estruturado. E o scaffold que o agente
`criador-de-documentos-e-apresentacoes` (`/criar-documento`) usa para entregar
documentos formatados, versionados e consistentes.

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
  gerar.py             # motor: injeta conteudo nos templates e renderiza PDF (WeasyPrint)
  requirements.txt     # weasyprint, jinja2, markdown (minimo)
  check.sh             # rede de seguranca offline + render de fumaca (tolerante a falha)
  saida/               # PDFs gerados (nao versionado)
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
```

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

Valida offline (sintaxe de `gerar.py`, JSON dos tokens e exemplos, HTML/CSS
bem-formados) e, se as libs existirem, faz um render de fumaca. Tolerante a
falha: pula o que depende de dependencia/rede sem derrubar. Idempotente.

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
