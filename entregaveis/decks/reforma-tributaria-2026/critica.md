# Red team - Reforma Tributaria 2026 na pratica

- **Projeto:** Reforma Tributaria 2026 na pratica
- **Etapa:** camada 4 do pipeline (red team / portao antes do render final)
- **Data:** 2026-06-23
- **Veredito:** APROVADO (com 2 correcoes de layout aplicadas durante o render; ver secao "Achados e correcoes").

## 1. Teste decisivo: a tese em 30s lendo SO os titulos

Sequencia dos 12 titulos (na ordem do deck):

1. Reforma Tributaria 2026 na pratica: o que a sua empresa precisa fazer agora
2. Cinco impostos viram dois: a conta fica mais simples
3. Nao e 2033: a Reforma ja entrou em vigor em janeiro de 2026
4. 2026 e fase de teste: ja vale juridicamente, mas quase nada e cobrado
5. Pense nela como um lancamento por etapas: liga, observa e so depois cobra
6. Ate cerca de agosto/2026 voce ainda erra de graca: a multa esta suspensa
7. Em 2027 a rede de protecao sai: PIS e COFINS acabam e a CBS fica cheia
8. A sua nota fiscal ja mudou: os campos novos sao obrigatorios hoje
9. No Simples Nacional puro? Em 2026 voce esta dispensado - mas a escolha chega em 2027
10. Faca isto ainda em 2026: quatro acoes que dependem de voce
11. A janela e curta: comece pela nota fiscal e pelos creditos de PIS/COFINS
12. O recado: aja em 2026 e leve estas perguntas ao seu contador

**Leitura so dos titulos:** ja vale (nao e 2033) -> 2026 e fase de teste barata, sem multa -> mas a rede sai em 2027 e a cobranca fica real -> entao faca estas acoes agora e leve as perguntas ao contador. **A tese ("em 2026 voce erra de graca; em 2027, nao") se sustenta sem ler o corpo. PASSA.**

## 2. Densidade / regra 6x6 (uma ideia por slide)

| Slide | Tipo | Ideia unica? | Densidade |
|-------|------|--------------|-----------|
| 2 | comparacao | Sim (5 -> 2) | Coluna direita 3 itens (mais longos) - OK |
| 3 | timeline | Sim (cronograma) | 4 marcos, texto curto - OK |
| 4 | destaque | Sim (aliquota simbolica) | 1 numero + legenda - OK |
| 5 | texto | Sim (analogia deploy) | 2 paragrafos curtos - OK |
| 6 | destaque | Sim (sem multa) | 1 frase + legenda - OK |
| 7 | comparacao | Sim (2026 vs 2027) | 4 itens/coluna, curtos - OK |
| 8 | topicos | Sim (NF-e mudou) | 3 bullets - OK (6x6) |
| 9 | comparacao | Sim (Unificado vs Hibrido) | 3 itens/coluna - OK |
| 10 | checklist | Sim (4 acoes) | 4 itens numerados - OK |
| 11 | texto | Sim (priorizar) | priorizacao 1-2 - OK |
| 12 | texto | Sim (call to action) | tese + 3 perguntas - OK |

Nenhum slide carrega 2 ideias. Todos os titulos sao afirmacao (mensagem), nao rotulo. PASSA.

## 3. Honestidade dos numeros (sem inventar, com fonte e ressalva)

Todos os dados sao alcados das 4 notas-fonte e marcados como referencia:

- **0,9% + 0,1%** (aliquota simbolica 2026) - reforma-tributaria.md / Ato Conjunto RFB-CGIBS no 1/2025. Marcado "valor de referencia - confirmar na fonte oficial".
- **Sem multa ate ~ago/2026** - reforma-tributaria.md (periodo educativo; RFB reafirmou abr/2026 "90 dias apos o regulamento"). O deck usa "~ago/2026" e "cerca de", fiel a ressalva da nota ("Confirmar a data-limite exata na fonte oficial"). HONESTO: nao crava data.
- **CBS ~8,8% em 2027** - reforma-tributaria.md. Marcado "valor de referencia, a ser fixado pelo Senado". HONESTO: nao apresenta como definitivo.
- **Cronograma 2026/2027/2029-32/2033** - reforma-tributaria.md (tabela de transicao). Marcos sem exagero.
- **Simples: dispensado 2026, Unificado vs Hibrido 2027** - simples-nacional.md (secao Reforma). Sem afirmar qual e melhor (so o trade-off de credito ao cliente PJ).
- **Campos CBS/IBS obrigatorios na NF-e / risco de rejeicao** - obrigacoes-acessorias.md (Atencao 2026).

Nenhum numero fabricado. Toda pagina com dado tem rodape_nota citando a nota-fonte. A ressalva global ("educativo, valide com contador") aparece no slide-tese final. PASSA.

## 4. Marca e acessibilidade

- Paleta navy #1F3A5F (primaria) + amber #E08A3C (acento), na proporcao 60-30-10: neutro domina, navy estrutura titulos/colunas, amber pontua (seta, selos, regua, no da timeline). PASSA.
- Contraste: texto neutro-900 sobre fundo claro e neutro-000 sobre amber (selos do checklist) - dentro de WCAG AA. Nota de fonte em cinza-500: discreta mas legivel.
- Tipografia: par display (Georgia, titulos) + corpo (Helvetica/Arial). 16:9 confirmado (900x507 px = 1.775). PASSA.
- Sem AI-tells (sem emoji, sem bullet generico sem fonte, sem grafico decorativo/enganoso - nao ha grafico neste deck; os dados sao big-numbers honestos com legenda).

## 5. Achados e correcoes (exposicao honesta do que quebrou e foi consertado)

Durante o render real, a inspecao visual (rasterizacao via PyMuPDF) pegou **2 defeitos de layout** que foram corrigidos de verdade (nao maquiados):

1. **Sobreposicao da nota de fonte sobre as colunas/itens** (slides 2, 9, 10). Causa-raiz: `.slide__fonte--pe` era `position:absolute` com `bottom` fixo, entao nao reservava espaco no fluxo e colidia com conteudo alto. Correcao: a nota passou a ser item flex no fluxo, empurrada ao pe por `margin-top:auto`; os layouts densos ganharam `padding-bottom` para folga ate o rodape da marca.
2. **Overflow de comparacao para uma 2a pagina** (deck foi de 12 -> 14 paginas). Causa-raiz: o `padding-bottom` generoso + titulo de 2 linhas + colunas altas estouravam a altura fixa do slide 16:9, e o WeasyPrint quebrava em duas paginas. Correcao: titulo/intro mais compactos nos layouts densos e padding das colunas reduzido, de modo que cada slide fita em UMA pagina. Deck voltou a **12 paginas** (capa + 11 slides).

Apos as correcoes, re-render confirmou 12 paginas, proporcao 16:9, e inspecao visual das paginas densas (2, 3, 7, 9, 10) sem colisao.

## Veredito final

**APROVADO para render final.** A tese passa no teste dos titulos; 1 ideia/slide; numeros ancorados e com ressalva; marca e acessibilidade OK; os 2 defeitos de layout do primeiro render foram expostos e corrigidos na raiz (nao mascarados). Limite mantido: conteudo educativo, nao substitui contador.
