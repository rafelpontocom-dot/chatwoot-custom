/**
 * Raevo — definição única do controle de formulário.
 *
 * A auditoria de produção encontrou 10 alturas de botão, 4 raios e 3 tratamentos
 * de campo convivendo no mesmo diálogo. A causa não é decisão errada: é a classe
 * copiada em cada tela. Enquanto ela viver colada no template, ela volta a divergir.
 *
 * Geometria conforme docs/raevo-design-system.md §4:
 * campo de uma linha é pílula; textarea usa `rounded-lg`. Altura única de 40 px.
 */

// `reset-base` é a saída oficial do Chatwoot (`_base.scss`) para escapar do
// `field-base`, que pinta TODO input com fundo cinza, raio próprio e 16px de
// margem inferior. Sem ela, a geometria abaixo é silenciosamente sobrescrita —
// era a causa da "caixa dentro de caixa" e do espaçamento irregular dos campos.
// `mb-0` é a segunda metade da mesma defesa. `_base.scss` dá a `select` e a
// `textarea` a regra `field-base` — com 16px de margem inferior — sem oferecer
// a saída `.reset-base` que oferece aos inputs. Como não editamos ficheiro do
// upstream, a margem morre aqui, numa utilitária que ganha por especificidade.
const BASE =
  'reset-base mb-0 w-full border border-solid border-n-strong bg-n-surface-1 ' +
  'text-sm text-n-slate-12 ' +
  'outline-none transition-colors placeholder:text-n-slate-9 ' +
  'focus:border-n-brand focus:ring-2 focus:ring-n-brand/20 ' +
  'disabled:cursor-not-allowed disabled:opacity-60';

/** input, e qualquer controle de uma linha */
export const RAEVO_CONTROL_CLASS = `h-10 rounded-full px-4 ${BASE}`;

/** select — mesma casca; o chevron é desenhado pelo RaevoField */
// `bg-none` apaga a seta que uma regra global desenha como background-image no
// select. Sem isso o campo mostra dois chevrons: o global e o do RaevoField.
export const RAEVO_SELECT_CLASS = `h-10 appearance-none rounded-full bg-none px-4 pr-10 ${BASE}`;

/** select fora de um RaevoField — ninguém lhe desenha o chevron, por isso
 * mantém (sem `bg-none`) a seta que `_base.scss` já pinta em todo o produto. */
export const RAEVO_SELECT_STANDALONE_CLASS = `h-10 appearance-none rounded-full px-4 pr-8 ${BASE}`;

/** textarea — não é pílula: várias linhas pedem canto de painel */
export const RAEVO_TEXTAREA_CLASS = `min-h-20 resize-none rounded-lg px-3 py-2.5 ${BASE}`;

/** `input[type=color]` — é uma amostra de cor, não um campo de texto: o
 * conteúdo é a própria cor, por isso não leva padding horizontal de texto. */
export const RAEVO_SWATCH_CLASS = `h-10 cursor-pointer rounded-full p-1 ${BASE}`;

/**
 * Ficha densa — o controle que não desenha caixa.
 *
 * Em painel de registro, ler e preencher são o mesmo gesto repetido dezenas de
 * vezes por dia: quem edita já sabe onde está. A casca do formulário (pílula,
 * fundo próprio, contorno) aqui não informa nada que o `hover` da linha já não
 * diga, e cobra o preço de redesenhar a geometria debaixo do cursor — o campo
 * abria e o rótulo encolhia de 14px para 12px.
 *
 * Então o controle herda a tipografia da linha, não pinta fundo nem contorno em
 * repouso, e anuncia o foco por um anel. Nada se move ao abrir.
 *
 * Isto é a exceção documentada ao §3/§4 do design system, que continua a valer
 * para formulário (criar, configurar): lá o rótulo é 12px e o campo é pílula.
 */
const INLINE_BASE =
  'reset-base mb-0 w-full border-0 bg-transparent px-0 ' +
  'text-sm leading-5 text-n-slate-12 ' +
  'outline-none placeholder:text-n-slate-9 ' +
  'focus:ring-2 focus:ring-n-brand/30 focus:rounded-md ' +
  'disabled:cursor-not-allowed disabled:opacity-60';

/** input em ficha densa */
export const RAEVO_INLINE_CONTROL_CLASS = `min-h-8 ${INLINE_BASE}`;

/** select em ficha densa — o chevron continua a ser do RaevoField */
export const RAEVO_INLINE_SELECT_CLASS = `min-h-8 appearance-none bg-none pr-6 ${INLINE_BASE}`;

/** textarea em ficha densa — cresce para baixo, sem sair da coluna do valor */
export const RAEVO_INLINE_TEXTAREA_CLASS = `min-h-20 resize-y py-0.5 ${INLINE_BASE}`;
