#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Exporta o MESMO contrato slides.json como deck WEB interativo (reveal.js).

Frente 3 do estudio de apresentacoes: a terceira saida (alem do PDF do gerar.py
e do PPTX do gerar-pptx.py), consumindo o MESMO `slides.json` + `marca/tokens.json`.
Emite UM arquivo .html AUTOCONTIDO (reveal.js e o tema da marca embutidos inline),
apresentavel no navegador e hospedavel sem build (ex.: jogar o .html no GitHub
Pages). Aditivo: NAO toca nos caminhos PDF/PPTX.

Por que autocontido (inline) e nao <link>/<script src>: um unico arquivo abre
offline (file://), nao quebra por caminho relativo na hospedagem e e trivial de
publicar. O reveal.js vem VENDORIZADO em vendor/reveal.js/ (MIT, ver LICENSE) e e
lido do disco e injetado no HTML - sem dependencia de rede/CDN em runtime.

Mapeamento tipo -> HTML semantico na marca (os 10 tipos do contrato), reusando a
estetica do deck.css (mesma marca: navy #1F3A5F + amber #E08A3C), adaptada para
reveal.js (16:9, tema claro):
  capa       -> <section> de titulo (fundo de marca, invertido)
  topicos    -> titulo + <ul> de bullets
  destaque   -> numero/frase grande ambar + legenda
  texto      -> titulo + corpo (html injetado como HTML - e web)
  comparacao -> duas colunas lado a lado; coluna "novo" (direita) em ambar
  timeline   -> marcos horizontais (linha + nos + ano/texto)
  checklist  -> itens numerados em selo
  processo   -> etapas em sequencia com seta ambar
  grafico    -> barras HONESTAS em CSS (base no ZERO, altura = valor/maximo,
                rotulo de valor visivel em CADA barra, COR COMO EXCECAO: so a
                barra `destaque` em ambar, resto navy; sem 3D).
                Ancora: MemoryCode/conhecimento/sinteses/
                o-grafico-convence-antes-do-numero.md
  kpis       -> 2 a 4 big-numbers lado a lado
Campos comuns: intro (sob o titulo) e rodape_nota (fonte/ressalva no pe).

SEGURANCA DE CONTEUDO: o conteudo do slides.json e tratado como entrada nao
confiavel. Todo texto (titulos, rotulos, itens, legendas...) e ESCAPADO antes de
ir ao HTML, para um `<` ou `&` no dado nao quebrar a pagina nem injetar markup.
A UNICA excecao e o campo `texto.html`, que e injetado como HTML por contrato
(e a saida web; o autor controla esse campo) - documentado e isolado.

A marca vem de tokens.json (a mesma fonte do PDF/PPTX), nada cravado.

Uso:
  python3 gerar-web.py [--dados exemplos/deck.json] [--saida saida/deck.html]

Sem dependencias externas (so a stdlib): le os tokens, o JSON e o reveal.js
vendorizado e monta o HTML por f-strings. Roda em qualquer Python 3.
"""
from __future__ import annotations

import argparse
import html as _html
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
DIR_MARCA = RAIZ / "marca"
DIR_SAIDA = RAIZ / "saida"
DIR_VENDOR = RAIZ / "vendor" / "reveal.js"

TOKENS_JSON = DIR_MARCA / "tokens.json"
REVEAL_JS = DIR_VENDOR / "reveal.js"
REVEAL_CSS = DIR_VENDOR / "reveal.css"

# Altura da area de plotagem do grafico (px da area do slide reveal 16:9). A
# barra cresce A PARTIR DA BASE (zero) ate, no maximo, esta altura (= teto da
# escala). Definida aqui para a regua ser a mesma de todas as barras do deck.
GRAFICO_PLANO_ALTURA_PX = 320


# ---------------------------------------------------------------------------
# Carga de marca e dados
# ---------------------------------------------------------------------------
def carregar_tokens() -> dict:
    return json.loads(TOKENS_JSON.read_text(encoding="utf-8"))


def carregar_deck(dados: Path) -> tuple[dict, list[dict]]:
    bruto = json.loads(dados.read_text(encoding="utf-8"))
    return bruto.get("deck", {}), bruto.get("slides", [])


# ---------------------------------------------------------------------------
# Escape: tudo do JSON e entrada NAO confiavel -> escapar antes do HTML.
# ---------------------------------------------------------------------------
def esc(valor) -> str:
    """Escapa para texto/atributo HTML. Aceita nao-string (numeros do grafico)
    convertendo para str. quote=True tambem neutraliza aspas - seguro em atributo."""
    if valor is None:
        return ""
    return _html.escape(str(valor), quote=True)


# ---------------------------------------------------------------------------
# Tema da marca em CSS (derivado dos tokens; espelha o deck.css, adaptado p/ web)
# ---------------------------------------------------------------------------
def tema_css(tokens: dict) -> str:
    """Gera o CSS do tema da marca a partir dos tokens (fonte unica, igual ao
    PDF/PPTX). Reusa a estetica do deck.css (cores, hierarquia, layouts dos 10
    tipos), adaptada para o .reveal: 16:9, tema claro, base no zero no grafico."""
    cor = tokens.get("cor", {})
    tipo = tokens.get("tipografia", {})
    escala = tipo.get("escala", {})
    layout = tokens.get("layout", {})

    def c(chave: str, padrao: str) -> str:
        return cor.get(chave, padrao)

    # Familias e raio vem dos tokens; o restante usa a escala tipografica deles.
    fonte_display = tipo.get("fonte_display", "Georgia, serif")
    fonte_corpo = tipo.get("fonte_corpo", "Arial, sans-serif")
    raio = layout.get("raio_borda", "4px")

    return f"""
/* Tema da marca para reveal.js - GERADO por gerar-web.py a partir de tokens.json.
   Espelha o deck.css (mesma marca), adaptado ao .reveal (16:9, tema claro). */
.reveal {{
  font-family: {fonte_corpo};
  color: {c('texto', '#1A1D21')};
  font-size: 34px;
}}
.reveal .slides {{ text-align: left; }}
.reveal .slides section {{
  height: 100%;
  box-sizing: border-box;
  padding: 48px 64px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}}
.reveal h1, .reveal h2, .reveal h3 {{
  font-family: {fonte_display};
  text-transform: none;
  letter-spacing: normal;
  margin: 0;
}}
.reveal a {{ color: {c('secundaria', '#3E7CB1')}; }}

/* O titulo do slide e a AFIRMACAO (a mensagem), com o tracinho ambar da marca. */
.slide__titulo {{
  font-size: {escala.get('2xl', '2.5rem')};
  line-height: {tipo.get('altura_linha_titulo', '1.15')};
  color: {c('primaria', '#1F3A5F')};
  margin: 0 0 24px;
}}
.slide__titulo::after {{
  content: "";
  display: block;
  width: 56px;
  height: 5px;
  background: {c('acento', '#E08A3C')};
  margin-top: 16px;
}}
.slide__intro {{
  font-size: {escala.get('lg', '1.25rem')};
  line-height: {tipo.get('altura_linha_corpo', '1.55')};
  color: {c('texto', '#1A1D21')};
  max-width: 85%;
  margin: 0 0 24px;
}}
.slide__corpo {{ font-size: {escala.get('lg', '1.25rem')}; line-height: {tipo.get('altura_linha_corpo', '1.55')}; }}
.slide__corpo ul {{ margin: 0; padding-left: 24px; }}
.slide__corpo li {{ margin-bottom: 16px; }}

/* Nota de fonte/ressalva discreta (dado com fonte, sem competir com a mensagem). */
.slide__fonte {{
  font-size: {escala.get('xs', '0.75rem')};
  line-height: {tipo.get('altura_linha_corpo', '1.55')};
  color: {c('texto_suave', '#6B7280')};
  margin-top: auto;
  padding-top: 16px;
}}

/* Rodape: marca + numero do slide (identidade discreta). */
.slide__rodape {{
  position: absolute;
  bottom: 18px;
  left: 64px;
  right: 64px;
  display: flex;
  justify-content: space-between;
  font-size: {escala.get('xs', '0.75rem')};
  color: {c('texto_suave', '#6B7280')};
}}

/* --- Capa (invertido: fundo de marca) --- */
.slide--capa {{ background: {c('primaria', '#1F3A5F')}; color: {c('neutro_000', '#FFFFFF')}; text-align: center; align-items: center; }}
.slide--capa .slide__marca {{
  font-size: {escala.get('sm', '0.875rem')};
  letter-spacing: 0.15em;
  text-transform: uppercase;
  opacity: 0.85;
  margin-bottom: 40px;
}}
.slide--capa .slide__titulo {{ color: {c('neutro_000', '#FFFFFF')}; font-size: {escala.get('3xl', '3.5rem')}; }}
.slide--capa .slide__titulo::after {{ margin-left: auto; margin-right: auto; }}
.slide--capa .slide__subtitulo {{ font-size: {escala.get('xl', '1.75rem')}; color: {c('neutro_100', '#EEF1F5')}; }}

/* --- Destaque (um numero grande, dado-tinta) --- */
.slide--destaque {{ background: {c('fundo_suave', '#EEF1F5')}; }}
.slide__numero {{
  font-family: {fonte_display};
  font-size: {escala.get('3xl', '3.5rem')};
  color: {c('acento', '#E08A3C')};
  line-height: 1;
}}
.slide__legenda {{
  font-size: {escala.get('xl', '1.75rem')};
  color: {c('primaria', '#1F3A5F')};
  margin-top: 16px;
  max-width: 80%;
}}

/* --- Comparacao: duas colunas (SAI->ENTRA); a direita (novo) recebe o acento --- */
.comparacao {{ display: flex; align-items: stretch; gap: 24px; }}
.comparacao__coluna {{
  flex: 1 1 0;
  background: {c('fundo_suave', '#EEF1F5')};
  border-top: 5px solid {c('secundaria', '#3E7CB1')};
  border-radius: {raio};
  padding: 16px 24px;
}}
.comparacao__coluna--direita {{ border-top-color: {c('acento', '#E08A3C')}; }}
.comparacao__titulo {{ font-family: {fonte_display}; font-size: {escala.get('lg', '1.25rem')}; color: {c('primaria', '#1F3A5F')}; margin: 0 0 16px; }}
.comparacao__coluna ul {{ margin: 0; padding-left: 24px; }}
.comparacao__coluna li {{ font-size: {escala.get('base', '1rem')}; line-height: {tipo.get('altura_linha_corpo', '1.55')}; margin-bottom: 8px; }}
.comparacao__seta {{ display: flex; align-items: center; font-family: {fonte_display}; font-size: {escala.get('2xl', '2.5rem')}; color: {c('acento', '#E08A3C')}; }}

/* --- Timeline: linha do tempo horizontal por marcos --- */
.timeline {{ display: flex; align-items: stretch; margin: 0; padding: 0; list-style: none; }}
.timeline__marco {{ flex: 1 1 0; position: relative; padding: 40px 16px 0; text-align: center; }}
.timeline__marco::before {{ content: ""; position: absolute; top: 11px; left: 0; right: 0; height: 3px; background: {c('neutro_300', '#C9CED6')}; }}
.timeline__marco:first-child::before {{ left: 50%; }}
.timeline__marco:last-child::before {{ right: 50%; }}
.timeline__marco::after {{ content: ""; position: absolute; top: 4px; left: 50%; transform: translateX(-50%); width: 17px; height: 17px; border-radius: 50%; background: {c('acento', '#E08A3C')}; border: 3px solid {c('fundo', '#FFFFFF')}; }}
.timeline__ano {{ font-family: {fonte_display}; font-size: {escala.get('xl', '1.75rem')}; font-weight: {tipo.get('peso_titulo', '700')}; color: {c('primaria', '#1F3A5F')}; margin-bottom: 8px; }}
.timeline__texto {{ font-size: {escala.get('sm', '0.875rem')}; line-height: {tipo.get('altura_linha_corpo', '1.55')}; color: {c('texto', '#1A1D21')}; }}

/* --- Checklist: itens numerados em selo (lista de acoes) --- */
.checklist {{ margin: 0; padding: 0; list-style: none; }}
.checklist__item {{ display: flex; align-items: flex-start; gap: 16px; margin-bottom: 16px; }}
.checklist__num {{ flex: 0 0 auto; width: 44px; height: 44px; border-radius: 50%; background: {c('acento', '#E08A3C')}; color: {c('neutro_000', '#FFFFFF')}; font-family: {fonte_display}; font-size: {escala.get('lg', '1.25rem')}; font-weight: {tipo.get('peso_titulo', '700')}; display: flex; align-items: center; justify-content: center; line-height: 1; }}
.checklist__texto {{ font-size: {escala.get('lg', '1.25rem')}; line-height: {tipo.get('altura_linha_corpo', '1.55')}; color: {c('texto', '#1A1D21')}; padding-top: 6px; }}

/* --- Processo: etapas LOGICAS em sequencia com seta ambar --- */
.processo {{ display: flex; align-items: stretch; gap: 8px; margin: 0; padding: 0; list-style: none; }}
.processo__etapa {{ flex: 1 1 0; background: {c('fundo_suave', '#EEF1F5')}; border-top: 5px solid {c('secundaria', '#3E7CB1')}; border-radius: {raio}; padding: 16px 16px 24px; text-align: center; }}
.processo__num {{ width: 40px; height: 40px; border-radius: 50%; background: {c('acento', '#E08A3C')}; color: {c('neutro_000', '#FFFFFF')}; font-family: {fonte_display}; font-size: {escala.get('lg', '1.25rem')}; font-weight: {tipo.get('peso_titulo', '700')}; line-height: 40px; text-align: center; margin: 0 auto 16px; }}
.processo__rotulo {{ font-family: {fonte_display}; font-size: {escala.get('lg', '1.25rem')}; font-weight: {tipo.get('peso_titulo', '700')}; color: {c('primaria', '#1F3A5F')}; margin-bottom: 8px; }}
.processo__texto {{ font-size: {escala.get('sm', '0.875rem')}; line-height: {tipo.get('altura_linha_corpo', '1.55')}; color: {c('texto', '#1A1D21')}; }}
.processo__seta {{ display: flex; align-items: center; font-family: {fonte_display}; font-size: {escala.get('2xl', '2.5rem')}; color: {c('acento', '#E08A3C')}; flex: 0 0 auto; }}

/* --- Grafico: barras HONESTAS (base no ZERO, comprimento, cor como excecao) ---
   Ancora: o-grafico-convence-antes-do-numero.md. A area de plotagem tem altura
   DEFINIDA; cada barra cresce a partir da base (align-items:flex-end) com height
   em % do TETO da escala -> 0 nao tem barra, teto toca o topo. So a barra
   .grafico__col--destaque recebe o acento; o resto fica secundario (navy). */
.grafico {{ display: flex; flex-direction: column; margin-top: 16px; }}
.grafico__plano {{ display: flex; align-items: flex-end; justify-content: space-around; gap: 24px; height: {GRAFICO_PLANO_ALTURA_PX}px; }}
.grafico__col {{ flex: 1 1 0; display: flex; align-items: flex-end; justify-content: center; height: 100%; max-width: 22%; }}
.grafico__barra {{ width: 100%; background: {c('secundaria', '#3E7CB1')}; border-radius: {raio} {raio} 0 0; position: relative; display: flex; justify-content: center; min-height: 2px; }}
.grafico__valor {{ position: absolute; top: -1.6em; font-family: {fonte_display}; font-size: {escala.get('lg', '1.25rem')}; font-weight: {tipo.get('peso_titulo', '700')}; color: {c('primaria', '#1F3A5F')}; white-space: nowrap; }}
.grafico__col--destaque .grafico__barra {{ background: {c('acento', '#E08A3C')}; }}
.grafico__col--destaque .grafico__valor {{ color: {c('acento', '#E08A3C')}; }}
.grafico__base {{ height: 3px; background: {c('neutro_300', '#C9CED6')}; }}
.grafico__rotulos {{ display: flex; justify-content: space-around; gap: 24px; margin-top: 8px; }}
.grafico__rotulo {{ flex: 1 1 0; max-width: 22%; font-size: {escala.get('sm', '0.875rem')}; line-height: {tipo.get('altura_linha_corpo', '1.55')}; color: {c('texto', '#1A1D21')}; text-align: center; }}

/* --- KPIs: big-numbers lado a lado (destaque no plural) --- */
.kpis {{ display: flex; align-items: stretch; justify-content: space-around; gap: 24px; }}
.kpis__item {{ flex: 1 1 0; background: {c('fundo_suave', '#EEF1F5')}; border-radius: {raio}; border-top: 5px solid {c('acento', '#E08A3C')}; padding: 24px 16px; text-align: center; display: flex; flex-direction: column; justify-content: center; }}
.kpis__numero {{ font-family: {fonte_display}; font-size: {escala.get('3xl', '3.5rem')}; line-height: 1; color: {c('acento', '#E08A3C')}; }}
.kpis__legenda {{ font-size: {escala.get('base', '1rem')}; line-height: {tipo.get('altura_linha_corpo', '1.55')}; color: {c('primaria', '#1F3A5F')}; margin-top: 16px; }}
""".strip()


# ---------------------------------------------------------------------------
# Renderizacao de cada tipo de slide -> HTML (<section> reveal.js)
# ---------------------------------------------------------------------------
def _titulo_intro(slide: dict) -> str:
    """Cabecalho comum (titulo + intro opcional). Titulo escapado (entrada nao
    confiavel); intro idem."""
    partes = [f'<h2 class="slide__titulo">{esc(slide.get("titulo"))}</h2>']
    if slide.get("intro"):
        partes.append(f'<p class="slide__intro">{esc(slide["intro"])}</p>')
    return "".join(partes)


def _rodape_nota(slide: dict) -> str:
    nota = slide.get("rodape_nota")
    return f'<p class="slide__fonte">{esc(nota)}</p>' if nota else ""


def _rodape_marca(marca_nome: str, indice: int) -> str:
    return (
        f'<div class="slide__rodape"><span>{esc(marca_nome)}</span>'
        f"<span>{indice}</span></div>"
    )


def _corpo_topicos(slide: dict) -> str:
    itens = "".join(f"<li>{esc(p)}</li>" for p in slide.get("pontos", []))
    return f'<div class="slide__corpo"><ul>{itens}</ul></div>'


def _corpo_texto(slide: dict) -> str:
    # UNICA excecao ao escape: `texto.html` e injetado como HTML por contrato (e
    # a saida web; o autor controla esse campo). O resto do deck e escapado.
    return f'<div class="slide__corpo">{slide.get("html", "")}</div>'


def _corpo_comparacao(slide: dict) -> str:
    def coluna(lado: dict, classe: str) -> str:
        titulo = (
            f'<h3 class="comparacao__titulo">{esc(lado.get("titulo"))}</h3>'
            if lado.get("titulo")
            else ""
        )
        itens = "".join(f"<li>{esc(i)}</li>" for i in lado.get("itens", []))
        return (
            f'<div class="comparacao__coluna {classe}">{titulo}'
            f"<ul>{itens}</ul></div>"
        )

    esquerda = coluna(slide.get("esquerda", {}), "comparacao__coluna--esquerda")
    direita = coluna(slide.get("direita", {}), "comparacao__coluna--direita")
    return (
        '<div class="slide__corpo"><div class="comparacao">'
        f'{esquerda}<div class="comparacao__seta" aria-hidden="true">&rarr;</div>'
        f"{direita}</div></div>"
    )


def _corpo_timeline(slide: dict) -> str:
    marcos = "".join(
        f'<li class="timeline__marco"><div class="timeline__ano">{esc(m.get("ano"))}</div>'
        f'<div class="timeline__texto">{esc(m.get("texto"))}</div></li>'
        for m in slide.get("marcos", [])
    )
    return f'<div class="slide__corpo"><ol class="timeline">{marcos}</ol></div>'


def _corpo_checklist(slide: dict) -> str:
    itens = "".join(
        f'<li class="checklist__item"><span class="checklist__num">{i}</span>'
        f'<span class="checklist__texto">{esc(item)}</span></li>'
        for i, item in enumerate(slide.get("itens", []), start=1)
    )
    return f'<div class="slide__corpo"><ol class="checklist">{itens}</ol></div>'


def _corpo_processo(slide: dict) -> str:
    etapas = slide.get("etapas", [])
    pecas: list[str] = []
    for i, etapa in enumerate(etapas, start=1):
        texto = (
            f'<div class="processo__texto">{esc(etapa.get("texto"))}</div>'
            if etapa.get("texto")
            else ""
        )
        pecas.append(
            f'<li class="processo__etapa"><div class="processo__num">{i}</div>'
            f'<div class="processo__rotulo">{esc(etapa.get("rotulo"))}</div>{texto}</li>'
        )
        if i < len(etapas):
            pecas.append('<li class="processo__seta" aria-hidden="true">&rarr;</li>')
    return f'<div class="slide__corpo"><ol class="processo">{"".join(pecas)}</ol></div>'


def _corpo_grafico(slide: dict) -> str:
    """Barras honestas. Teto da escala = slide.maximo quando presente (escala com
    maximo de dominio, ex.: 5 numa nota 0-5), senao o maior valor do conjunto.
    Altura de cada barra = valor/teto, limitada a 100% (um valor acima do teto nao
    estoura a area, o que distorceria a comparacao). Rotulo do valor SEMPRE no DOM.
    Ancora: o-grafico-convence-antes-do-numero.md (base no zero, cor como excecao)."""
    barras = slide.get("barras", [])
    valores = [b.get("valor", 0) for b in barras]
    teto = slide.get("maximo") or (max(valores) if valores else 0)
    unidade = slide.get("unidade", "")

    cols: list[str] = []
    rotulos: list[str] = []
    for barra in barras:
        valor = barra.get("valor", 0)
        bruto = (valor / teto * 100) if teto else 0
        altura = min(bruto, 100)
        destaque = " grafico__col--destaque" if barra.get("destaque") else ""
        rotulo_valor = f"{esc(valor)}{esc(unidade)}" if unidade else esc(valor)
        cols.append(
            f'<div class="grafico__col{destaque}">'
            f'<div class="grafico__barra" style="height: {altura:.1f}%;">'
            f'<span class="grafico__valor">{rotulo_valor}</span></div></div>'
        )
        rotulos.append(f'<div class="grafico__rotulo">{esc(barra.get("rotulo"))}</div>')

    return (
        '<div class="slide__corpo"><div class="grafico">'
        f'<div class="grafico__plano">{"".join(cols)}</div>'
        '<div class="grafico__base" aria-hidden="true"></div>'
        f'<div class="grafico__rotulos">{"".join(rotulos)}</div>'
        "</div></div>"
    )


def _corpo_kpis(slide: dict) -> str:
    itens = "".join(
        f'<div class="kpis__item"><div class="kpis__numero">{esc(k.get("numero"))}</div>'
        f'<div class="kpis__legenda">{esc(k.get("legenda"))}</div></div>'
        for k in slide.get("itens", [])
    )
    return f'<div class="slide__corpo"><div class="kpis">{itens}</div></div>'


# Registro tipo -> funcao de corpo. Mantem o render dirigido por dados e fecha o
# rol dos tipos suportados num lugar so (espelha os 10 tipos do contrato).
_CORPOS = {
    "topicos": _corpo_topicos,
    "texto": _corpo_texto,
    "comparacao": _corpo_comparacao,
    "timeline": _corpo_timeline,
    "checklist": _corpo_checklist,
    "processo": _corpo_processo,
    "grafico": _corpo_grafico,
    "kpis": _corpo_kpis,
}


def render_slide(slide: dict, indice: int, marca_nome: str) -> str:
    """Renderiza um <section> reveal.js para o slide. `indice` numera o rodape
    (1-based, ja somado pela capa)."""
    tipo = slide.get("tipo", "")

    if tipo == "destaque":
        return (
            '<section class="slide--destaque">'
            f'<div class="slide__numero">{esc(slide.get("numero"))}</div>'
            f'<div class="slide__legenda">{esc(slide.get("legenda"))}</div>'
            f"{_rodape_marca(marca_nome, indice)}</section>"
        )

    corpo_fn = _CORPOS.get(tipo)
    if corpo_fn is None:
        # Tipo desconhecido: nao maquiar. Mostra o titulo e um aviso visivel em
        # vez de engolir o slide silenciosamente.
        corpo = (
            '<div class="slide__corpo"><p class="slide__fonte">'
            f"[tipo de slide nao suportado: {esc(tipo)}]</p></div>"
        )
    else:
        corpo = corpo_fn(slide)

    return (
        f'<section class="slide--{esc(tipo)}">'
        f"{_titulo_intro(slide)}{corpo}{_rodape_nota(slide)}"
        f"{_rodape_marca(marca_nome, indice)}</section>"
    )


# ---------------------------------------------------------------------------
# Montagem do HTML autocontido (reveal.js + tema inline)
# ---------------------------------------------------------------------------
def montar_html(deck: dict, slides: list[dict], tokens: dict) -> str:
    if not REVEAL_JS.exists() or not REVEAL_CSS.exists():
        print(
            f"[gerar-web] ERRO: reveal.js vendorizado ausente em {DIR_VENDOR}. "
            "Veja vendor/reveal.js/VERSION (esperado o bundle MIT).",
            file=sys.stderr,
        )
        sys.exit(2)

    reveal_css = REVEAL_CSS.read_text(encoding="utf-8")
    reveal_js = REVEAL_JS.read_text(encoding="utf-8")
    marca = tokens.get("marca", {})
    marca_nome = marca.get("nome", "")

    # Capa primeiro (slide 1); demais slides numerados a partir de 2.
    capa = (
        '<section class="slide--capa">'
        f'<div class="slide__marca">{esc(marca_nome)}</div>'
        f'<h1 class="slide__titulo">{esc(deck.get("titulo"))}</h1>'
    )
    if deck.get("subtitulo"):
        capa += f'<p class="slide__subtitulo">{esc(deck["subtitulo"])}</p>'
    capa += "</section>"

    secoes = [capa]
    for i, slide in enumerate(slides, start=2):
        secoes.append(render_slide(slide, i, marca_nome))

    titulo_doc = esc(deck.get("titulo", "Apresentacao"))
    tema = tema_css(tokens)
    secoes_html = "\n".join(secoes)

    # </script> dentro do bundle JS quebraria o <script> que o envolve; o reveal
    # nao contem essa sequencia, mas neutralizamos por seguranca (defensivo).
    reveal_js_seguro = reveal_js.replace("</script>", "<\\/script>")

    return f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{titulo_doc}</title>
<!-- reveal.js {esc((DIR_VENDOR / 'VERSION').read_text(encoding='utf-8').strip()) if (DIR_VENDOR / 'VERSION').exists() else 'vendorizado'} (MIT, ver vendor/reveal.js/LICENSE), embutido inline: deck AUTOCONTIDO, sem rede. -->
<style>
{reveal_css}
</style>
<style>
{tema}
</style>
</head>
<body>
<div class="reveal">
<div class="slides">
{secoes_html}
</div>
</div>
<script>
{reveal_js_seguro}
</script>
<script>
// Inicializa o reveal em 16:9, com a area do slide fixa para o layout (grafico,
// colunas) ter a mesma regua de tamanho do PDF. center:false para o conteudo
// alinhar ao topo como nos templates densos.
Reveal.initialize({{
  width: 1280,
  height: 720,
  margin: 0.04,
  center: false,
  hash: true,
  controls: true,
  progress: true
}});
</script>
</body>
</html>
"""


def _resolver_saida(caminho: Path) -> Path:
    """Confina a escrita a esta arvore (mesma regra do gerar.py): bloqueia
    --saida fora da raiz, inclusive via '..' ou caminho absoluto."""
    destino = (caminho if caminho.is_absolute() else RAIZ / caminho).resolve()
    try:
        destino.relative_to(RAIZ)
    except ValueError:
        print(
            f"[gerar-web] ERRO: --saida deve ficar dentro de {RAIZ} "
            f"(recebido: {destino}).",
            file=sys.stderr,
        )
        sys.exit(2)
    return destino


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Gera o deck WEB (reveal.js) autocontido a partir de slides.json."
    )
    parser.add_argument(
        "--dados",
        type=Path,
        default=RAIZ / "exemplos" / "deck.json",
        help="arquivo de conteudo (slides.json). Padrao: exemplos/deck.json",
    )
    parser.add_argument(
        "--saida",
        type=Path,
        default=DIR_SAIDA / "deck.html",
        help="caminho do .html de saida. Padrao: saida/deck.html",
    )
    args = parser.parse_args(argv)

    tokens = carregar_tokens()
    deck, slides = carregar_deck(args.dados)
    html = montar_html(deck, slides, tokens)

    saida = _resolver_saida(args.saida)
    saida.parent.mkdir(parents=True, exist_ok=True)
    saida.write_text(html, encoding="utf-8")
    print(f"[gerar-web] deck web gerado: {saida} ({len(slides) + 1} slides)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
