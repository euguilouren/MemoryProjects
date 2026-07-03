#!/usr/bin/env python3
"""
Guard de CSP do portal (docs/index.html).

O portal endurece o `script-src` da Content-Security-Policy por HASH: em vez de
`'unsafe-inline'` (que deixaria qualquer script inline injetado executar), a CSP
lista o `sha256-` de CADA <script> inline. Isso transforma a CSP num backstop
real de XSS — mas exige que os hashes acompanhem o conteúdo dos scripts.

Este guard recalcula os hashes dos <script> inline e verifica que:
  1. o `script-src` NÃO contém `'unsafe-inline'`;
  2. cada script inline tem seu `sha256-...` presente no `script-src`.
Se um <script> for editado sem atualizar a CSP, o CI falha aqui — em vez de o
portal quebrar silenciosamente no ar (script bloqueado pela CSP).

Uso:
    python3 docs/check-csp-hashes.py           # verifica (exit!=0 se divergir)
    python3 docs/check-csp-hashes.py --emit     # imprime os tokens sha256- p/ colar na CSP
"""
import base64
import hashlib
import re
import sys

HTML = "docs/index.html"
# Casa <script ...>corpo</script>. Scripts com src= (externos) não têm corpo
# inline e são ignorados (grupo vazio).
SCRIPT_RE = re.compile(r"<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>", re.S | re.I)
CSP_RE = re.compile(r'Content-Security-Policy"\s+content="([^"]*)"')


def inline_script_hashes(html):
    hashes = []
    for corpo in SCRIPT_RE.findall(html):
        if corpo == "":
            continue
        h = base64.b64encode(hashlib.sha256(corpo.encode("utf-8")).digest()).decode()
        hashes.append(f"sha256-{h}")
    return hashes


def script_src_directive(csp):
    for d in csp.split(";"):
        d = d.strip()
        if d.startswith("script-src"):
            return d
    return ""


def main():
    html = open(HTML, encoding="utf-8").read()
    hashes = inline_script_hashes(html)
    if "--emit" in sys.argv:
        print(f"script-src 'self' {' '.join(chr(39) + h + chr(39) for h in hashes)}")
        return 0

    m = CSP_RE.search(html)
    if not m:
        print("::error::CSP meta nao encontrada em docs/index.html")
        return 1
    script_src = script_src_directive(m.group(1))
    falhas = []
    if "'unsafe-inline'" in script_src:
        falhas.append("script-src ainda contem 'unsafe-inline' (use hashes)")
    for h in hashes:
        if f"'{h}'" not in script_src:
            falhas.append(f"script inline sem hash na CSP: '{h}'")
    if falhas:
        for f in falhas:
            print(f"::error::{f}")
        print(f"\nscript-src atual: {script_src}")
        print("Rode: python3 docs/check-csp-hashes.py --emit  e atualize a CSP.")
        return 1
    print(f"CSP ok: {len(hashes)} script(s) inline com hash, sem 'unsafe-inline'.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
