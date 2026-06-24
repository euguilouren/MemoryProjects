#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Resolucao de TEMA (restyle por tokens) - compartilhada pelos 3 geradores.

Frente 4 do estudio: trocar o VISUAL do deck sem tocar no CONTEUDO (paridade
'restyle' do Gamma). A troca de tema so mexe em COR; layout, tipografia de
estrutura e o contrato slides.json ficam intactos.

Modelo:
  - O bloco `cor` de topo do tokens.json e o DEFAULT (= tema 'claro').
  - O bloco `temas` mapeia nomes -> overrides de cor. Cada tema sobrescreve SO as
    chaves de cor que diferem; o resto herda do default.
  - `resolver_cor(tokens, tema)` devolve um bloco `cor` EFETIVO (default + override
    do tema). Para 'claro' (override vazio) o resultado e o proprio bloco de topo,
    sem copia de valores -> byte-a-byte identico ao comportamento de hoje.
  - `aplicar_tema(tokens, tema)` devolve uma COPIA RASA do tokens com `cor` ja
    resolvida, para os geradores consumirem como antes (eles leem tokens['cor']).

Ancora (MemoryCode):
  conhecimento/engenharia-de-software/design-de-apresentacoes-e-marca.md
  (paleta 60-30-10, WCAG AA 4,5:1 - o tema escuro foi calibrado para esse piso).
"""
from __future__ import annotations

TEMA_PADRAO = "claro"


class TemaInexistente(ValueError):
    """Tema pedido nao existe no tokens.json. Carrega a lista de disponiveis para
    a CLI montar um erro claro (nao silencioso)."""

    def __init__(self, tema: str, disponiveis: list[str]) -> None:
        self.tema = tema
        self.disponiveis = disponiveis
        super().__init__(
            f"tema '{tema}' inexistente. Disponiveis: {', '.join(disponiveis)}"
        )


def temas_disponiveis(tokens: dict) -> list[str]:
    """Nomes de tema declarados em tokens['temas'] (ignora chaves _meta como _nota).
    'claro' sempre consta (e o default), mesmo que o bloco 'temas' falte."""
    temas = tokens.get("temas", {})
    nomes = [k for k in temas.keys() if not k.startswith("_")]
    if TEMA_PADRAO not in nomes:
        nomes.insert(0, TEMA_PADRAO)
    return nomes


def resolver_cor(tokens: dict, tema: str | None = None) -> dict:
    """Bloco `cor` EFETIVO para o tema: default (cor de topo) + override do tema.

    - tema None ou 'claro' com override vazio -> retorna o MESMO objeto `cor` de
      topo (sem copia), garantindo paridade byte-a-byte com o comportamento atual.
    - tema valido com overrides -> dict novo = {**cor_topo, **override} (override
      vence chave a chave; chaves nao citadas herdam o default).
    - tema inexistente -> TemaInexistente (a CLI converte em erro claro).
    """
    nome = tema or TEMA_PADRAO
    disponiveis = temas_disponiveis(tokens)
    if nome not in disponiveis:
        raise TemaInexistente(nome, disponiveis)

    cor_topo = tokens.get("cor", {})
    override = tokens.get("temas", {}).get(nome, {}).get("cor", {})
    # Sem override (caso 'claro'): devolve o proprio bloco de topo, sem alterar
    # nada -> zero regressao. Com override: mescla, override vencendo.
    if not override:
        return cor_topo
    return {**cor_topo, **override}


def aplicar_tema(tokens: dict, tema: str | None = None) -> dict:
    """Copia rasa do tokens com `cor` ja resolvida para o tema. Os geradores
    consomem `tokens['cor']` como sempre - a unica diferenca e a paleta efetiva.

    Para 'claro'/None com override vazio, o `cor` resolvido E o objeto de topo,
    entao o tokens devolvido e equivalente ao original (mesmas cores)."""
    novo = dict(tokens)  # copia rasa: so trocamos a chave 'cor'
    novo["cor"] = resolver_cor(tokens, tema)
    return novo
