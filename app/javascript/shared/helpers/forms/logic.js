/**
 * Espelho de `Forms::Logic` (app/services/forms/logic.rb).
 *
 * A tabela precisa de existir dos dois lados: a interface tem de oferecer os
 * operadores sem ir ao servidor a cada seleção, e o servidor tem de recusar o
 * que não conhece. Os comparadores precisam de existir dos dois lados por uma
 * razão mais dura — o navegador tem de mostrar exatamente as perguntas que o
 * servidor vai aceitar. Enquanto discordarem, ou o paciente responde a algo
 * que é descartado, ou é recusado por deixar em branco algo que nunca viu.
 *
 * A defesa é `spec/services/forms/logic_catalogue_parity_spec.rb`: lê este
 * ficheiro e falha se uma lista aqui deixar de bater com a do Ruby. Ao mexer
 * numa, mexa na outra; o teste diz qual esqueceu.
 */
const COMMON_OPERATORS = ['is_empty', 'is_not_empty'];

const TEXT_OPERATORS = [
  'is',
  'is_not',
  'contains',
  'does_not_contain',
  'starts_with',
  'ends_with',
];
const SINGLE_CHOICE_OPERATORS = ['is', 'is_not'];
const MULTIPLE_CHOICE_OPERATORS = [
  'is',
  'is_not',
  'contains',
  'does_not_contain',
];
const NUMBER_OPERATORS = [
  'equal',
  'not_equal',
  'greater_than',
  'greater_or_equal_than',
  'less_or_equal_than',
];
const DATE_OPERATORS = ['is', 'is_not', 'is_before', 'is_after'];

export const OPERATORS_BY_TYPE = {
  text: TEXT_OPERATORS,
  textarea: TEXT_OPERATORS,
  email: TEXT_OPERATORS,
  phone: TEXT_OPERATORS,
  number: NUMBER_OPERATORS,
  currency: NUMBER_OPERATORS,
  date: DATE_OPERATORS,
  datetime: DATE_OPERATORS,
  select: SINGLE_CHOICE_OPERATORS,
  checkbox: SINGLE_CHOICE_OPERATORS,
  consent: SINGLE_CHOICE_OPERATORS,
  multi_select: MULTIPLE_CHOICE_OPERATORS,
};

export const ACTIONS = ['navigate', 'calculate'];
export const CALCULATE_OPERATORS = [
  'addition',
  'subtraction',
  'multiplication',
  'division',
  'assignment',
];
export const VARIABLE_KINDS = ['number', 'text'];
/** Um nível só, sem parênteses: é o que mantém a regra legível. */
export const COMBINATORS = ['all', 'any'];

/**
 * Assinatura, anexo e campo oculto ficam só com os comuns: não há «contém»
 * útil numa assinatura.
 */
export const operatorsFor = fieldType => [
  ...(OPERATORS_BY_TYPE[fieldType] || []),
  ...COMMON_OPERATORS,
];

/** Operadores que não precisam de valor: perguntam só se foi respondida. */
export const isUnaryOperator = operator => COMMON_OPERATORS.includes(operator);

const text = value =>
  value === null || value === undefined ? '' : String(value).trim();

const isBlank = value => {
  if (Array.isArray(value)) return value.every(isBlank);

  return (
    value === null ||
    value === undefined ||
    value === false ||
    text(value) === ''
  );
};

/**
 * `Float(valor, exception: false)` do Ruby: devolve nulo em vez de adivinhar.
 * `parseFloat` leria «12abc» como 12 e faria a regra disparar por engano.
 */
const toNumber = value => {
  const normalized = text(value).replaceAll(',', '.');
  if (normalized === '') return null;

  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : null;
};

const toTime = value => {
  const parsed = Date.parse(text(value));
  return Number.isNaN(parsed) ? null : parsed;
};

const compareNumbers = (answer, expected, comparator) => {
  const left = toNumber(answer);
  const right = toNumber(expected);
  if (left === null || right === null) return false;

  return comparator(left, right);
};

const compareDates = (answer, expected, comparator) => {
  const left = toTime(answer);
  const right = toTime(expected);
  if (left === null || right === null) return false;

  return comparator(left, right);
};

/**
 * Seleção múltipla responde com lista: «é» significa exatamente aquele
 * conjunto, e «contém» significa que a opção está entre as escolhidas.
 */
const isEqual = (answer, expected) => {
  if (Array.isArray(answer)) {
    const left = answer.map(text).sort();
    const right = (Array.isArray(expected) ? expected : [expected])
      .map(text)
      .sort();
    return (
      left.length === right.length &&
      left.every((item, index) => item === right[index])
    );
  }

  return text(answer) === text(expected);
};

const includesValue = (answer, expected) => {
  if (Array.isArray(answer))
    return answer.some(item => text(item) === text(expected));

  return text(answer).includes(text(expected));
};

const COMPARATORS = {
  is_empty: answer => isBlank(answer),
  is_not_empty: answer => !isBlank(answer),
  is: isEqual,
  equal: isEqual,
  // `equals` é o operador do modelo antigo. Não aparece em `operatorsFor`, por
  // isso não entra em schema novo — mas as versões publicadas são imutáveis e
  // ainda o trazem, e continuam a ser respondidas por pacientes.
  equals: isEqual,
  is_not: (answer, expected) => !isEqual(answer, expected),
  not_equal: (answer, expected) => !isEqual(answer, expected),
  contains: includesValue,
  does_not_contain: (answer, expected) => !includesValue(answer, expected),
  starts_with: (answer, expected) => text(answer).startsWith(text(expected)),
  ends_with: (answer, expected) => text(answer).endsWith(text(expected)),
  greater_than: (answer, expected) =>
    compareNumbers(answer, expected, (a, b) => a > b),
  greater_or_equal_than: (answer, expected) =>
    compareNumbers(answer, expected, (a, b) => a >= b),
  less_or_equal_than: (answer, expected) =>
    compareNumbers(answer, expected, (a, b) => a <= b),
  is_before: (answer, expected) =>
    compareDates(answer, expected, (a, b) => a < b),
  is_after: (answer, expected) =>
    compareDates(answer, expected, (a, b) => a > b),
};

/**
 * Uma comparação que não se aplica ao valor recebido devolve `false` — nunca
 * levanta, porque isto corre a cada tecla que o paciente escreve.
 */
export const matches = (comparison, answer, expected) => {
  const comparator = COMPARATORS[comparison];
  if (!comparator) return false;

  return comparator(answer, expected);
};

/**
 * Uma condição é simples — `{ref, comparison, expected}` — ou um grupo:
 * `{combinator, conditions}`. Um nível só, sem parênteses.
 */
export const satisfied = (condition, answers) => {
  if (!condition) return false;

  if (!condition.combinator) {
    return matches(
      condition.comparison,
      (answers || {})[condition.ref],
      condition.expected
    );
  }

  // Um grupo vazio nunca se cumpre: dizer que sim faria a regra disparar
  // sempre, que é o oposto do que quem a deixou por preencher esperava.
  const children = condition.conditions || [];
  if (!children.length) return false;

  return condition.combinator === 'any'
    ? children.some(child => satisfied(child, answers))
    : children.every(child => satisfied(child, answers));
};
