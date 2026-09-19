#!/usr/bin/env node
/**
 * Raevo — mockup de uma direção: componentes e telas.
 *
 * Um conjunto de tokens não é um design system. Cor, forma e tipografia são as
 * peças; o sistema é o que se constrói com elas — botão, campo, selo, cartão,
 * tabela, diálogo — e as telas onde isso vive.
 *
 * Esta página é a mesma marcação para qualquer direção: muda o conjunto de
 * tokens, muda a cara, e nenhum componente é reescrito. É essa a prova de que a
 * regra 1 (nunca escrever cor literal) paga o que promete.
 *
 *   node scripts/design-mockup.mjs <tokens.json> <saida.html>
 *
 * Nenhuma regra abaixo escreve cor, raio ou sombra literal: tudo sai de var().
 * Os rótulos e estados vêm do produto real — FinancePayment::STATUSES e os
 * catálogos de i18n — para a tela não ser ficção.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const esc = s => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;');

// --- ícones (traço Lucide, herdam currentColor) --------------------------------

const ico = (d, extra = '') =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
     stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${d}${extra}</svg>`;
const I = {
  check: ico('<path d="M20 6 9 17l-5-5"/>'),
  alerta: ico('<circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/>'),
  relogio: ico('<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>'),
  rascunho: ico('<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>'),
  utilizador: ico('<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>'),
  calendario: ico('<rect x="3" y="4" width="18" height="18" rx="2"/><path d="M16 2v4M8 2v4M3 10h18"/>'),
  mais: ico('<path d="M12 5v14M5 12h14"/>'),
  busca: ico('<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>'),
  filtro: ico('<path d="M22 3H2l8 9.46V19l4 2v-8.54L22 3z"/>'),
  vazio: ico('<path d="M3 7v10a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7"/><path d="M3 7l9-4 9 4-9 4-9-4Z"/>'),
  x: ico('<path d="M18 6 6 18M6 6l12 12"/>'),
};

// --- dados reais do produto ----------------------------------------------------

const ETAPAS = [
  { nome: 'Novo lead', n: 1, total: 6 },
  { nome: 'Em contacto', n: 2, total: 4 },
  { nome: 'Avaliação marcada', n: 3, total: 3 },
  { nome: 'Proposta enviada', n: 4, total: 2 },
];

const CARTOES = [
  [
    ['Ana Beatriz Mendes', 'Implante unitário', 'R$ 4.800', 'hoje 14:30'],
    ['Carlos Nogueira', 'Clareamento', 'R$ 1.200', 'amanhã 09:00'],
    ['Helena Vaz', 'Ortodontia', 'R$ 8.400', 'qui 16:00'],
  ],
  [
    ['Marta Ribeiro', 'Prótese', 'R$ 6.100', 'hoje 11:00'],
    ['João Peixoto', 'Limpeza', 'R$ 320', 'sex 10:30'],
  ],
  [['Rui Salgado', 'Implante múltiplo', 'R$ 12.900', 'seg 08:30']],
  [['Sofia Antunes', 'Faceta', 'R$ 3.400', 'qua 15:00']],
];

// FinancePayment::STATUSES — rótulos do catálogo pt-BR.
const ESTADOS = [
  ['recebido', 'Recebido', 'teal', I.check],
  ['a-vencer', 'A vencer', 'amber', I.relogio],
  ['vencido', 'Vencido', 'ruby', I.alerta],
  ['rascunho', 'Rascunho', 'slate', I.rascunho],
];

const COBRANCAS = [
  ['Ana Beatriz Mendes', 'Implante unitário', 'R$ 4.800,00', '12/09', 0],
  ['Marta Ribeiro', 'Prótese — 2ª parcela', 'R$ 2.050,00', '20/09', 1],
  ['Rui Salgado', 'Implante múltiplo', 'R$ 12.900,00', '02/09', 2],
  ['Sofia Antunes', 'Faceta', 'R$ 3.400,00', '—', 3],
];

// --- blocos --------------------------------------------------------------------

const selo = ([, rotulo, cor, icone]) =>
  `<span class="selo selo--${cor}">${icone}${rotulo}</span>`;

const cartao = ([nome, proc, valor, quando], etapa) => `
  <article class="cartao" tabindex="0">
    <span class="cartao__faixa" style="background:rgb(var(--raevo-stage-${etapa}))"></span>
    <h4>${esc(nome)}</h4>
    <p class="cartao__proc">${esc(proc)}</p>
    <div class="cartao__pe">
      <strong>${esc(valor)}</strong>
      <span class="cartao__quando">${I.calendario}${esc(quando)}</span>
    </div>
  </article>`;

const coluna = (e, i) => `
  <section class="coluna" aria-label="${esc(e.nome)}">
    <header class="coluna__cab">
      <span class="etapa">
        <span class="etapa__ponto" style="background:rgb(var(--raevo-stage-${e.n}))"></span>
        ${esc(e.nome)}
      </span>
      <span class="conta">${e.total}</span>
    </header>
    ${CARTOES[i].map(c => cartao(c, e.n)).join('')}
    <button class="btn btn--fantasma btn--bloco">${I.mais} Nova oportunidade</button>
  </section>`;

const campo = (rotulo, corpo, dica = '', erro = '') => `
  <div class="campo">
    <label class="campo__rotulo">${esc(rotulo)}</label>
    ${corpo}
    ${dica ? `<p class="campo__dica">${esc(dica)}</p>` : ''}
    ${erro ? `<p class="campo__erro">${I.alerta}${esc(erro)}</p>` : ''}
  </div>`;

/**
 * A página de uma direção: os mesmos componentes e as mesmas telas,
 * desenhados com o conjunto de tokens que receber.
 */
export const mockup = (t, origem) => {
  // --- camada de tokens, inline -------------------------------------------------

  const props = mapa =>
    Object.entries(mapa)
      .map(([n, v]) => `    --${n}: ${v.value};`)
      .join('\n');

  const extra = mapa =>
    Object.entries(mapa ?? {})
      .map(([n, v]) => `    --raevo-${n}: ${v.value};`)
      .join('\n');

  const camada = `
    :root {
  ${props(t.color.ramp.light)}
  ${props(t.color.semantic.light)}
  ${extra(t.shape.radius.token)}
  ${extra(t.shadow.token.light)}
  ${Object.entries(t.stage.token.light).map(([n, v]) => `    --raevo-${n}: ${v.value};`).join('\n')}
      --raevo-font-sans: ${t.typography.fontStack};
    }
    [data-tema="dark"] {
  ${props(t.color.ramp.dark)}
  ${props(t.color.semantic.dark)}
  ${extra(t.shadow.token.dark)}
  ${Object.entries(t.stage.token.dark).map(([n, v]) => `    --raevo-${n}: ${v.value};`).join('\n')}
    }`;

  /** Um degrau da escala tipográfica da direção. */
  const px = nome => {
    const e = t.typography.extras?.[nome];
    if (Array.isArray(e)) return e[0];
    return { micro: '11px', xs: '12px', sm: '14px', base: '16px', xl: '20px', '3xl': '30px' }[nome];
  };


  return `<!doctype html>
<html lang="pt"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(t.name)} · ${esc(t.direction)} — componentes e telas</title>
<style>
${camada}

  /* Nada abaixo escreve cor, raio ou sombra literal. Tudo sai de var(). */
  *, *::before, *::after { box-sizing: border-box; }
  body {
    margin: 0; background: rgb(var(--background-color)); color: rgb(var(--slate-12));
    font-family: var(--raevo-font-sans); font-size: ${px('sm')}; line-height: 1.55;
  }
  .env { max-width: 1280px; margin: 0 auto; padding: 0 24px 72px; }
  header.topo {
    position: sticky; top: 0; z-index: 5; background: rgb(var(--background-color));
    border-bottom: 1px solid rgb(var(--border-weak)); padding: 14px 24px;
    display: flex; gap: 14px; align-items: center; flex-wrap: wrap;
  }
  h1 { font-size: ${px('xl')}; margin: 0; letter-spacing: -0.01em; }
  h2 { font-size: ${px('xl')}; margin: 44px 0 4px; letter-spacing: -0.01em; }
  h3 { font-size: ${px('micro')}; text-transform: uppercase; letter-spacing: .07em;
       color: rgb(var(--slate-10)); margin: 26px 0 10px; font-weight: 600; }
  h4 { font-size: ${px('sm')}; margin: 0; font-weight: 600; }
  .meta { color: rgb(var(--slate-10)); font-size: ${px('xs')}; }
  .linha { display: flex; gap: 10px; flex-wrap: wrap; align-items: center; }
  .painel {
    background: rgb(var(--card-color)); border: 1px solid rgb(var(--border-weak));
    border-radius: var(--raevo-radius-card); box-shadow: var(--raevo-shadow-rest);
    padding: 18px;
  }

  /* --- botão --- */
  .btn {
    display: inline-flex; align-items: center; gap: 7px; font: inherit; font-weight: 550;
    padding: 8px 15px; border-radius: var(--raevo-radius-control); cursor: pointer;
    border: 1px solid transparent; background: none; color: rgb(var(--slate-12));
    box-shadow: var(--raevo-shadow-rest);
  }
  .btn svg { width: 15px; height: 15px; flex: none; }
  .btn--primario { background: rgb(var(--brand-color)); color: rgb(var(--solid-1)); }
  .btn--secundario { background: rgb(var(--solid-1)); border-color: rgb(var(--border-strong)); }
  .btn--fantasma { color: rgb(var(--slate-11)); box-shadow: none; }
  .btn--perigo { background: rgb(var(--ruby-9)); color: rgb(var(--solid-1)); }
  .btn--foco { outline: 2px solid rgb(var(--brand-color)); outline-offset: 2px; }
  .btn[disabled] { opacity: .45; cursor: not-allowed; }
  .btn--bloco { width: 100%; justify-content: center; color: rgb(var(--slate-10)); }
  .btn--peq { padding: 5px 11px; font-size: ${px('xs')}; }

  /* --- campo (rótulo acima, campo abaixo — regra 7) --- */
  .campo { display: flex; flex-direction: column; gap: 5px; margin-bottom: 14px; }
  .campo__rotulo { font-size: ${px('xs')}; font-weight: 600; color: rgb(var(--slate-11)); }
  .ctrl {
    font: inherit; width: 100%; padding: 8px 11px; color: rgb(var(--slate-12));
    background: rgb(var(--solid-1)); border: 1px solid rgb(var(--border-strong));
    border-radius: var(--raevo-radius-control);
  }
  textarea.ctrl { border-radius: var(--raevo-radius-item); resize: vertical; min-height: 74px; }
  .ctrl--erro { border-color: rgb(var(--ruby-9)); }
  .ctrl[disabled] { background: rgb(var(--slate-3)); color: rgb(var(--slate-9)); }
  .campo__dica { margin: 0; font-size: ${px('xs')}; color: rgb(var(--slate-10)); }
  .campo__erro {
    margin: 0; font-size: ${px('xs')}; color: rgb(var(--ruby-11));
    display: flex; align-items: center; gap: 5px;
  }
  .campo__erro svg { width: 13px; height: 13px; flex: none; }

  /* --- selo: cor + ícone + texto (regra 5, WCAG 2.2) --- */
  .selo {
    display: inline-flex; align-items: center; gap: 5px; font-size: ${px('xs')};
    font-weight: 600; padding: 3px 9px; border-radius: var(--raevo-radius-pill, 9999px);
  }
  .selo svg { width: 13px; height: 13px; flex: none; }
  .selo--teal  { background: rgb(var(--teal-3));  color: rgb(var(--teal-11)); }
  .selo--amber { background: rgb(var(--amber-3)); color: rgb(var(--amber-11)); }
  .selo--ruby  { background: rgb(var(--ruby-3));  color: rgb(var(--ruby-11)); }
  .selo--slate { background: rgb(var(--slate-3)); color: rgb(var(--slate-11)); }

  /* --- quadro --- */
  .quadro { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; align-items: start; }
  .coluna {
    background: rgb(var(--slate-2)); border: 1px solid rgb(var(--border-weak));
    border-radius: var(--raevo-radius-card); padding: 10px; display: flex;
    flex-direction: column; gap: 8px;
  }
  .coluna__cab { display: flex; justify-content: space-between; align-items: center; padding: 2px 3px 6px; }
  .etapa { display: inline-flex; align-items: center; gap: 7px; font-weight: 600; font-size: ${px('xs')}; }
  .etapa__ponto { width: 9px; height: 9px; border-radius: 9999px; flex: none; }
  .conta {
    font-size: ${px('micro')}; font-weight: 600; color: rgb(var(--slate-10));
    background: rgb(var(--slate-4)); border-radius: 9999px; padding: 1px 7px;
  }
  .cartao {
    position: relative; background: rgb(var(--card-color)); padding: 11px 12px 11px 15px;
    border: 1px solid rgb(var(--border-weak)); border-radius: var(--raevo-radius-item);
    box-shadow: var(--raevo-shadow-rest); overflow: hidden; cursor: grab;
  }
  .cartao:focus-visible { outline: 2px solid rgb(var(--brand-color)); outline-offset: 2px; }
  .cartao__faixa { position: absolute; inset: 0 auto 0 0; width: 3px; }
  .cartao__proc { margin: 2px 0 9px; font-size: ${px('xs')}; color: rgb(var(--slate-10)); }
  .cartao__pe { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
  .cartao__pe strong { font-size: ${px('sm')}; }
  .cartao__quando {
    display: inline-flex; align-items: center; gap: 4px;
    font-size: ${px('micro')}; color: rgb(var(--slate-10));
  }
  .cartao__quando svg { width: 12px; height: 12px; }

  /* --- tabela --- */
  table { width: 100%; border-collapse: collapse; }
  th {
    text-align: left; font-size: ${px('micro')}; text-transform: uppercase;
    letter-spacing: .06em; color: rgb(var(--slate-10)); font-weight: 600;
    padding: 9px 12px; border-bottom: 1px solid rgb(var(--border-weak));
  }
  td { padding: 11px 12px; border-bottom: 1px solid rgb(var(--border-weak)); }
  tbody tr:nth-child(even) { background: rgb(var(--slate-2)); }
  .num { text-align: right; font-variant-numeric: tabular-nums; }

  /* --- abas --- */
  .abas { display: flex; gap: 3px; border-bottom: 1px solid rgb(var(--border-weak)); }
  .aba {
    font: inherit; padding: 8px 13px; border: 0; background: none; cursor: pointer;
    color: rgb(var(--slate-10)); border-bottom: 2px solid transparent; margin-bottom: -1px;
  }
  .aba[aria-selected="true"] { color: rgb(var(--slate-12)); font-weight: 600;
    border-bottom-color: rgb(var(--brand-color)); }

  /* --- diálogo / menu --- */
  .dialogo {
    background: rgb(var(--card-color)); border: 1px solid rgb(var(--border-weak));
    border-radius: var(--raevo-radius-card); box-shadow: var(--raevo-shadow-float);
    max-width: 440px; overflow: hidden;
  }
  .dialogo__cab { display: flex; justify-content: space-between; align-items: center;
    padding: 15px 18px; border-bottom: 1px solid rgb(var(--border-weak)); }
  .dialogo__corpo { padding: 18px; }
  .dialogo__pe { display: flex; justify-content: flex-end; gap: 8px; padding: 13px 18px;
    background: rgb(var(--slate-2)); border-top: 1px solid rgb(var(--border-weak)); }
  .menu {
    background: rgb(var(--card-color)); border: 1px solid rgb(var(--border-weak));
    border-radius: var(--raevo-radius-item); box-shadow: var(--raevo-shadow-float);
    padding: 5px; width: 210px;
  }
  .menu__item { display: flex; align-items: center; gap: 9px; padding: 7px 10px;
    border-radius: calc(var(--raevo-radius-item) - 3px); cursor: pointer; }
  .menu__item svg { width: 15px; height: 15px; color: rgb(var(--slate-10)); }
  .menu__item--ativo { background: rgb(var(--surface-active)); }

  /* --- estados --- */
  .estado { text-align: center; padding: 34px 18px; }
  .estado svg { width: 30px; height: 30px; color: rgb(var(--slate-9)); }
  .estado h4 { margin: 11px 0 3px; }
  .estado p { margin: 0 0 14px; color: rgb(var(--slate-10)); font-size: ${px('xs')}; }
  /* Superfície discreta SEMÂNTICA, não um degrau da rampa: --slate-3 é o fundo
     discreto no claro mas é o próprio cartão no escuro, e o esqueleto desaparecia. */
  .esqueleto { background: rgb(var(--label-background)); border-radius: var(--raevo-radius-item);
    height: 13px; margin-bottom: 8px; }

  /* align-items:start para um painel curto nao esticar ate a altura do vizinho. */
  .grade2 { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr));
            gap: 18px; align-items: start; }
  .agenda { display: grid; grid-template-columns: 62px 1fr; gap: 0; }
  .agenda__h { font-size: ${px('micro')}; color: rgb(var(--slate-10)); padding: 9px 9px 0 0;
    text-align: right; border-top: 1px solid rgb(var(--border-weak)); }
  .agenda__f { border-top: 1px solid rgb(var(--border-weak)); padding: 5px 0; min-height: 46px; }
  .marcacao { border-left: 3px solid; border-radius: var(--raevo-radius-item);
    padding: 6px 10px; margin-bottom: 4px; background: rgb(var(--solid-1));
    border-top: 1px solid rgb(var(--border-weak)); border-right: 1px solid rgb(var(--border-weak));
    border-bottom: 1px solid rgb(var(--border-weak)); box-shadow: var(--raevo-shadow-rest); }
  .marcacao b { display: block; font-size: ${px('xs')}; }
  .marcacao span { font-size: ${px('micro')}; color: rgb(var(--slate-10)); }
  @media (max-width: 900px) { .quadro, .grade2 { grid-template-columns: 1fr; }
    .env, header.topo { padding-left: 16px; padding-right: 16px; } }
</style></head>
<body>
<header class="topo">
  <h1>${esc(t.name)} · ${esc(t.direction)}</h1>
  <span class="meta">${esc(t.approved ? `aprovado ${t.approved}` : t.status ?? 'proposta')}
    · mesma marcação, tokens de <code>${esc(origem)}</code></span>
  <button class="btn btn--secundario btn--peq" id="tema" type="button">Alternar tema</button>
</header>
<div class="env">

  <h2>Componentes</h2>
  <p class="meta">Nenhuma regra desta página escreve cor, raio ou sombra literal —
  tudo sai de <code>var()</code>. É por isso que trocar a direção não reescreve componente.</p>

  <h3>Botão</h3>
  <div class="painel linha">
    <button class="btn btn--primario">${I.check} Confirmar</button>
    <button class="btn btn--secundario">Cancelar</button>
    <button class="btn btn--fantasma">${I.filtro} Filtros</button>
    <button class="btn btn--perigo">${I.x} Estornar</button>
    <button class="btn btn--secundario btn--foco">Com foco</button>
    <button class="btn btn--secundario" disabled>Desativado</button>
    <button class="btn btn--primario btn--peq">${I.mais} Pequeno</button>
  </div>

  <h3>Campo</h3>
  <div class="painel grade2">
    <div>
      ${campo('Nome do doente', '<input class="ctrl" value="Ana Beatriz Mendes">')}
      ${campo('Procedimento',
        '<select class="ctrl"><option>Implante unitário</option></select>')}
      ${campo('Valor', '<input class="ctrl" value="R$ 4.800,00">',
        'Sem imposto. O recibo é emitido à parte.')}
    </div>
    <div>
      ${campo('Telemóvel', '<input class="ctrl ctrl--erro" value="+351 91">', '',
        'Número incompleto — faltam 7 dígitos.')}
      ${campo('Observação', '<textarea class="ctrl">Prefere manhã.</textarea>')}
      ${campo('Conta', '<input class="ctrl" value="Clínica Raevo" disabled>')}
    </div>
  </div>

  <h3>Selo de estado — cor + ícone + texto</h3>
  <div class="painel linha">${ESTADOS.map(selo).join('')}
    <span class="meta">Nunca só cor: a regra 5 é requisito WCAG 2.2, não gosto.</span>
  </div>

  <h3>Abas · menu · diálogo</h3>
  <div class="grade2">
    <div class="painel" style="padding:0">
      <div class="abas" role="tablist">
        <button class="aba" role="tab" aria-selected="true">Quadro</button>
        <button class="aba" role="tab" aria-selected="false">Lista</button>
        <button class="aba" role="tab" aria-selected="false">Automações</button>
      </div>
      <div style="padding:16px">
        <div class="menu">
          <div class="menu__item menu__item--ativo">${I.utilizador} Atribuir responsável</div>
          <div class="menu__item">${I.calendario} Marcar avaliação</div>
          <div class="menu__item">${I.rascunho} Editar oportunidade</div>
        </div>
      </div>
    </div>
    <div class="dialogo">
      <div class="dialogo__cab"><h4>Nova cobrança</h4>
        <button class="btn btn--fantasma btn--peq" aria-label="Fechar">${I.x}</button></div>
      <div class="dialogo__corpo">
        ${campo('Doente', '<input class="ctrl" value="Marta Ribeiro">')}
        ${campo('Vencimento', '<input class="ctrl" value="20/09/2026">')}
      </div>
      <div class="dialogo__pe">
        <button class="btn btn--secundario">Cancelar</button>
        <button class="btn btn--primario">Criar cobrança</button>
      </div>
    </div>
  </div>

  <h3>Vazio · a carregar · erro</h3>
  <div class="grade2">
    <div class="painel estado">${I.vazio}<h4>Nenhuma oportunidade nesta etapa</h4>
      <p>Arraste um cartão para cá, ou crie a primeira.</p>
      <button class="btn btn--secundario">${I.mais} Nova oportunidade</button></div>
    <div class="painel">
      <div class="esqueleto" style="width:56%"></div>
      <div class="esqueleto" style="width:88%"></div>
      <div class="esqueleto" style="width:38%"></div>
    </div>
  </div>
  <div class="painel estado" style="margin-top:18px">
    <span style="color:rgb(var(--ruby-9))">${I.alerta}</span>
    <h4>Não foi possível carregar sua fila de trabalho</h4>
    <p>A ligação falhou. Nada foi perdido.</p>
    <button class="btn btn--secundario">Tentar novamente</button>
  </div>

  <h2>Telas</h2>
  <p class="meta">As mesmas telas do produto — Pipeline, Financeiro, Agenda — desenhadas
  com este conjunto de tokens.</p>

  <h3>Pipeline</h3>
  <div class="painel" style="padding:14px">
    <div class="linha" style="justify-content:space-between;margin-bottom:12px">
      <div class="linha">
        <strong style="font-size:${px('base')}">Comercial</strong>
        <span class="conta">15 oportunidades</span>
      </div>
      <div class="linha">
        <button class="btn btn--fantasma btn--peq">${I.busca} Procurar</button>
        <button class="btn btn--fantasma btn--peq">${I.filtro} Filtros</button>
        <button class="btn btn--primario btn--peq">${I.mais} Nova</button>
      </div>
    </div>
    <div class="quadro">${ETAPAS.map(coluna).join('')}</div>
  </div>

  <h3>Financeiro</h3>
  <div class="painel" style="padding:0;overflow:hidden">
    <table>
      <thead><tr><th>Doente</th><th>Descrição</th><th class="num">Valor</th>
        <th>Vencimento</th><th>Situação</th></tr></thead>
      <tbody>
        ${COBRANCAS.map(([n, d, v, venc, i]) => `<tr>
          <td><strong>${esc(n)}</strong></td><td class="meta">${esc(d)}</td>
          <td class="num">${esc(v)}</td><td class="meta">${esc(venc)}</td>
          <td>${selo(ESTADOS[i])}</td></tr>`).join('')}
      </tbody>
    </table>
  </div>

  <h3>Agenda</h3>
  <div class="painel">
    <div class="agenda">
      <div class="agenda__h">09:00</div>
      <div class="agenda__f">
        <div class="marcacao" style="border-left-color:rgb(var(--raevo-stage-2))">
          <b>Carlos Nogueira — Clareamento</b><span>09:00 · Dra. Elis · sala 2</span></div>
      </div>
      <div class="agenda__h">10:30</div>
      <div class="agenda__f">
        <div class="marcacao" style="border-left-color:rgb(var(--raevo-stage-1))">
          <b>Ana Beatriz Mendes — Avaliação</b><span>10:30 · Dr. Nuno · sala 1</span></div>
      </div>
      <div class="agenda__h">14:30</div>
      <div class="agenda__f">
        <div class="marcacao" style="border-left-color:rgb(var(--raevo-stage-3))">
          <b>Rui Salgado — Implante múltiplo</b><span>14:30 · Dr. Nuno · sala 1</span></div>
        <div class="marcacao" style="border-left-color:rgb(var(--raevo-stage-4))">
          <b>Sofia Antunes — Faceta</b><span>15:00 · Dra. Elis · sala 2</span></div>
      </div>
      <div class="agenda__h">16:00</div>
      <div class="agenda__f"></div>
    </div>
  </div>
</div>
<script>
  document.getElementById('tema').addEventListener('click', () => {
    const r = document.documentElement;
    r.dataset.tema = r.dataset.tema === 'dark' ? 'light' : 'dark';
  });
</script>
</body></html>
`;
};

// Só corre como comando quando é invocado diretamente; importado, é biblioteca.
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [, , origem, destino] = process.argv;
  if (!origem || !destino) {
    console.error('uso: node scripts/design-mockup.mjs <tokens.json> <saida.html>');
    process.exit(1);
  }
  writeFileSync(destino, mockup(JSON.parse(readFileSync(origem, 'utf8')), origem));
  console.log(`✓ ${destino} gerado de ${origem}.`);
}
