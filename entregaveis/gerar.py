#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gerador de entregaveis na marca (relatorio PDF e deck 16:9).

Separa CONTEUDO (arquivos em exemplos/, ou os que voce passar) de FORMA
(templates Jinja2 + CSS que so consomem os tokens de marca). E o motor que o
agente `criador-de-documentos-e-apresentacoes` (/criar-documento) orquestra.

Ancoras (MemoryCode):
  - conhecimento/engenharia-de-software/geracao-de-documentos-e-apresentacoes.md
    (WeasyPrint para PDF via HTML/CSS, CSS Paged Media, conteudo x forma)
  - conhecimento/engenharia-de-software/design-de-apresentacoes-e-marca.md
    (paleta 60-30-10, par tipografico, hierarquia, uma ideia por slide)
  - conhecimento/engenharia-de-software/publicacao-sharepoint-microsoft-graph.md
    (passo seguinte: publicar via Graph - fora do escopo deste script)

Uso:
  python3 gerar.py relatorio [--dados exemplos/relatorio.md] [--saida saida/relatorio.pdf]
  python3 gerar.py deck       [--dados exemplos/deck.json]    [--saida saida/deck.pdf]
  python3 gerar.py demo            # gera os dois exemplos em saida/
  python3 gerar.py sincronizar-tokens   # regenera marca/tokens.css a partir do JSON

Dependencias (requirements.txt): weasyprint, markdown, jinja2. Se faltarem,
o script renderiza o HTML intermediario e avisa com clareza, sem quebrar -
util para inspecionar a forma offline e para o check.sh.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
DIR_MARCA = RAIZ / "marca"
DIR_TEMPLATES = RAIZ / "templates"
DIR_SAIDA = RAIZ / "saida"

TOKENS_JSON = DIR_MARCA / "tokens.json"
TOKENS_CSS = DIR_MARCA / "tokens.css"


# ---------------------------------------------------------------------------
# Carga de marca e dados
# ---------------------------------------------------------------------------
def carregar_marca() -> dict:
    """Le o bloco `marca` de tokens.json (nome, assinatura de rodape)."""
    tokens = json.loads(TOKENS_JSON.read_text(encoding="utf-8"))
    return tokens.get("marca", {})


def ler_front_matter_md(caminho: Path) -> tuple[dict, str]:
    """Separa o front-matter (YAML simples chave: valor) do corpo Markdown.

    Evita dependencia de PyYAML: o front-matter aqui e um mapa raso de strings,
    entao um parser de 'chave: valor' por linha basta e mantem o scaffold leve.
    """
    texto = caminho.read_text(encoding="utf-8")
    meta: dict[str, str] = {}
    corpo = texto

    linhas = texto.splitlines()
    # Tolera linhas em branco antes do front-matter; o '---' deve ser a primeira
    # linha nao vazia para o bloco ser reconhecido.
    inicio = next((i for i, l in enumerate(linhas) if l.strip()), len(linhas))
    if inicio < len(linhas) and linhas[inicio].strip() == "---":
        fim = next((i for i in range(inicio + 1, len(linhas)) if linhas[i].strip() == "---"), None)
        if fim is not None:
            for linha in linhas[inicio + 1:fim]:
                if ":" in linha:
                    chave, valor = linha.split(":", 1)
                    meta[chave.strip()] = valor.strip().strip('"').strip("'")
            corpo = "\n".join(linhas[fim + 1:])
    return meta, corpo


def markdown_para_secoes(corpo_md: str) -> list[dict]:
    """Converte o corpo Markdown em secoes {titulo, html}, quebrando em cada '## '.

    Usa a lib `markdown` quando disponivel; sem ela, faz uma conversao minima
    (paragrafos) para nao travar - o conteudo continua legivel.
    """
    try:
        import markdown as _md
        render = lambda txt: _md.markdown(txt, extensions=["tables"])
    except ImportError:
        render = _render_markdown_minimo

    secoes: list[dict] = []
    titulo_atual: str | None = None
    buffer: list[str] = []

    def fechar():
        # Fecha a secao corrente. O preambulo (texto antes do primeiro '## ')
        # vira uma secao sem titulo em vez de ser descartado: o template omite
        # o <h2> quando 'titulo' e vazio, entao nada se perde silenciosamente.
        corpo = "\n".join(buffer).strip()
        if titulo_atual is not None or corpo:
            secoes.append({"titulo": titulo_atual or "", "html": render(corpo)})

    for linha in corpo_md.splitlines():
        if linha.startswith("## "):
            fechar()
            titulo_atual = linha[3:].strip()
            buffer = []
        else:
            buffer.append(linha)
    fechar()
    return secoes


def _render_markdown_minimo(texto: str) -> str:
    """Fallback sem a lib `markdown`. Cobre o basico (negrito, citacao, listas)
    para o HTML de inspecao offline ficar apresentavel; NAO e um parser Markdown
    completo (sem tabelas/links) - por isso o caminho de producao instala a lib
    `markdown`, conforme avisado no README e no check.sh."""
    import html as _html
    import re as _re

    blocos: list[str] = []
    for bruto in _re.split(r"\n\s*\n", texto):
        bloco = bruto.strip()
        if not bloco:
            continue
        bloco = _html.escape(bloco)
        bloco = _re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", bloco)  # negrito

        linhas = bloco.splitlines()
        if all(l.lstrip().startswith(("- ", "* ")) for l in linhas):       # lista
            itens = "".join(f"<li>{l.lstrip()[2:].strip()}</li>" for l in linhas)
            blocos.append(f"<ul>{itens}</ul>")
        elif all(l.lstrip().startswith("&gt;") for l in linhas):           # citacao
            corpo = " ".join(l.lstrip()[4:].strip() for l in linhas)
            blocos.append(f"<blockquote><p>{corpo}</p></blockquote>")
        else:
            blocos.append(f"<p>{bloco}</p>")
    return "\n".join(blocos)


# ---------------------------------------------------------------------------
# Renderizacao (forma)
# ---------------------------------------------------------------------------
def _ambiente_jinja():
    """Cria o ambiente Jinja2 apontado para templates/. Erro claro se faltar."""
    try:
        from jinja2 import Environment, FileSystemLoader, select_autoescape
    except ImportError:
        _abortar_dependencia("jinja2")
    return Environment(
        loader=FileSystemLoader(str(DIR_TEMPLATES)),
        autoescape=select_autoescape(["html", "xml"]),
    )


def _refs_css() -> dict:
    """URLs file:// absolutas dos CSS, para WeasyPrint resolver os <link>."""
    return {
        "tokens_css": TOKENS_CSS.resolve().as_uri(),
        "relatorio_css": (DIR_TEMPLATES / "relatorio.css").resolve().as_uri(),
        "deck_css": (DIR_TEMPLATES / "deck.css").resolve().as_uri(),
    }


def montar_html_relatorio(dados: Path) -> str:
    meta, corpo = ler_front_matter_md(dados)
    contexto = {
        "doc": {
            "titulo": meta.get("titulo", "Relatorio"),
            "subtitulo": meta.get("subtitulo", ""),
            "autor": meta.get("autor", ""),
            "data": meta.get("data", ""),
        },
        "marca": carregar_marca(),
        "secoes": markdown_para_secoes(corpo),
        **_refs_css(),
    }
    return _ambiente_jinja().get_template("relatorio.html").render(**contexto)


def montar_html_deck(dados: Path) -> str:
    bruto = json.loads(dados.read_text(encoding="utf-8"))
    contexto = {
        "deck": bruto.get("deck", {}),
        "slides": bruto.get("slides", []),
        "marca": carregar_marca(),
        **_refs_css(),
    }
    return _ambiente_jinja().get_template("deck.html").render(**contexto)


def renderizar_pdf(html: str, saida: Path) -> bool:
    """Renderiza o HTML em PDF via WeasyPrint. Retorna True se gerou o PDF;
    False (com aviso) se a lib nao estiver instalada - nesse caso grava o HTML
    intermediario ao lado, para inspecao offline."""
    saida.parent.mkdir(parents=True, exist_ok=True)
    try:
        from weasyprint import HTML
    except ImportError:
        html_fallback = saida.with_suffix(".html")
        html_fallback.write_text(html, encoding="utf-8")
        print(f"[gerar] AVISO: WeasyPrint ausente. PDF nao gerado.", file=sys.stderr)
        print(f"[gerar] HTML intermediario salvo em: {html_fallback}", file=sys.stderr)
        print(f"[gerar] Instale as deps: pip install -r {RAIZ / 'requirements.txt'}", file=sys.stderr)
        return False

    # base_url permite ao WeasyPrint resolver caminhos relativos (CSS/imagens).
    HTML(string=html, base_url=str(RAIZ)).write_pdf(str(saida))
    print(f"[gerar] PDF gerado: {saida}")
    return True


# ---------------------------------------------------------------------------
# Sincronizacao de tokens (JSON -> CSS)
# ---------------------------------------------------------------------------
# Mapa explicito grupo-do-JSON -> nome da custom property CSS que os templates
# consomem. E explicito de proposito: os prefixos sao irregulares (cor -> --cor-,
# mas peso_* -> --peso-* sem o grupo 'tipografia'; layout -> sem prefixo) e os
# tokens *_nota / deck_proporcao nao viram CSS. Uma regra automatica de prefixo
# geraria nomes errados (ex.: --fonte-fonte-display) e dessincronizaria do CSS.
def _vars_css_de_tokens(tokens: dict) -> list[tuple[str, str]]:
    """Deriva os pares (nome-da-var, valor) na ordem do tokens.css, a partir do
    tokens.json. Fonte unica de verdade: estes nomes sao exatamente os que
    relatorio.css/deck.css usam via var()."""
    cor = tokens.get("cor", {})
    tipo = tokens.get("tipografia", {})
    escala = tipo.get("escala", {})
    esp = tokens.get("espacamento", {})
    layout = tokens.get("layout", {})

    def kebab(chave: str) -> str:
        return chave.replace("_", "-")

    pares: list[tuple[str, str]] = []
    # Cor: prefixo --cor-
    for chave, valor in cor.items():
        if not chave.startswith("_"):
            pares.append((f"cor-{kebab(chave)}", valor))
    # Tipografia: familias --fonte-*, pesos --peso-*, alturas --altura-*
    for chave, valor in tipo.items():
        if chave.startswith("_") or isinstance(valor, dict):
            continue
        if chave.startswith("fonte_"):
            pares.append((f"fonte-{kebab(chave[len('fonte_'):])}", valor))
        else:  # peso_*, altura_linha_*
            pares.append((kebab(chave), valor))
    # Escala tipografica: --fonte-xs ... --fonte-3xl
    for chave, valor in escala.items():
        pares.append((f"fonte-{kebab(chave)}", valor))
    # Espacamento: --esp-*
    for chave, valor in esp.items():
        if not chave.startswith("_"):
            pares.append((f"esp-{kebab(chave)}", valor))
    # Layout: sem prefixo de grupo; deck_proporcao nao e custom property usavel.
    for chave, valor in layout.items():
        if chave.startswith("_") or chave == "deck_proporcao":
            continue
        pares.append((kebab(chave), valor))
    return pares


def sincronizar_tokens() -> None:
    """Regenera marca/tokens.css a partir de marca/tokens.json, mantendo o JSON
    como fonte unica. Os nomes das custom properties batem exatamente com os que
    os templates consomem (ver _vars_css_de_tokens). Idempotente."""
    tokens = json.loads(TOKENS_JSON.read_text(encoding="utf-8"))
    linhas = [
        "/* GERADO por gerar.py sincronizar-tokens a partir de tokens.json. */",
        "/* Nao edite a mao: ajuste o JSON (fonte unica) e regenere.        */",
        ":root {",
    ]
    for nome, valor in _vars_css_de_tokens(tokens):
        linhas.append(f"  --{nome}: {valor};")
    linhas.append("}")

    TOKENS_CSS.write_text("\n".join(linhas) + "\n", encoding="utf-8")
    print(f"[gerar] tokens.css sincronizado a partir de {TOKENS_JSON.name}")


def _resolver_saida(caminho: Path) -> Path:
    """Resolve o caminho de saida e exige que ele fique dentro da raiz do
    projeto (esta pasta). Bloqueia escrita acidental fora da arvore - inclusive
    via '..' ou caminho absoluto - sem impedir o uso legitimo de --saida
    relativo (ex.: saida/meu.pdf ou exemplos/.../x.pdf). E uma CLI local, mas
    confinar a escrita evita que um caminho mal montado sobrescreva algo fora."""
    destino = (caminho if caminho.is_absolute() else RAIZ / caminho).resolve()
    try:
        destino.relative_to(RAIZ)
    except ValueError:
        print(
            f"[gerar] ERRO: --saida deve ficar dentro de {RAIZ} "
            f"(recebido: {destino}).",
            file=sys.stderr,
        )
        sys.exit(2)
    return destino


def _abortar_dependencia(nome: str) -> None:
    print(f"[gerar] ERRO: dependencia '{nome}' ausente.", file=sys.stderr)
    print(f"[gerar] Instale: pip install -r {RAIZ / 'requirements.txt'}", file=sys.stderr)
    sys.exit(2)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Gerador de entregaveis na marca.")
    parser.add_argument(
        "comando",
        choices=["relatorio", "deck", "demo", "sincronizar-tokens"],
        help="o que gerar ('demo' = os dois exemplos; "
             "'sincronizar-tokens' = regenera tokens.css a partir do JSON)",
    )
    parser.add_argument("--dados", type=Path, help="arquivo de conteudo (md/json)")
    parser.add_argument("--saida", type=Path, help="caminho do PDF de saida")
    args = parser.parse_args(argv)

    if args.comando == "sincronizar-tokens":
        sincronizar_tokens()
        return 0

    if args.comando == "relatorio":
        dados = args.dados or RAIZ / "exemplos" / "relatorio.md"
        saida = _resolver_saida(args.saida or DIR_SAIDA / "relatorio.pdf")
        renderizar_pdf(montar_html_relatorio(dados), saida)
        return 0

    if args.comando == "deck":
        dados = args.dados or RAIZ / "exemplos" / "deck.json"
        saida = _resolver_saida(args.saida or DIR_SAIDA / "deck.pdf")
        renderizar_pdf(montar_html_deck(dados), saida)
        return 0

    if args.comando == "demo":
        renderizar_pdf(montar_html_relatorio(RAIZ / "exemplos" / "relatorio.md"), DIR_SAIDA / "relatorio.pdf")
        renderizar_pdf(montar_html_deck(RAIZ / "exemplos" / "deck.json"), DIR_SAIDA / "deck.pdf")
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
