/**
 * Espelho de `Forms::VisiblePath` (app/services/forms/visible_path.rb).
 *
 * Que perguntas o respondente viu, de facto. Esconder e saltar não são a mesma
 * coisa, e é por isso que isto é um percurso e não um predicado por campo.
 * `visible_when` respondia «este campo aparece?» olhando só para ele. Uma
 * regra de salto responde «depois desta, qual é a próxima?» — e tudo o que
 * fica pelo caminho não foi visto, mesmo que nenhuma condição o mencione.
 *
 * O servidor volta a correr o mesmo percurso no envio. Se os dois discordarem,
 * o paciente responde a perguntas que são descartadas em silêncio, ou é
 * recusado por deixar em branco uma pergunta que nunca lhe foi mostrada.
 */
import { satisfied, matches } from './logic';

const schemaFields = schema =>
  (schema?.sections || []).flatMap(section => section.fields || []);

/**
 * Compatibilidade com versões já publicadas, que são imutáveis: elas trazem
 * `visible_when` e continuam a ser respondidas por pacientes.
 */
const legacyVisible = (field, answers) => {
  const condition = field?.visible_when;
  if (!condition) return true;

  return matches(condition.operator, answers[condition.field], condition.value);
};

const navigateTarget = (logicsByField, key, answers) => {
  const payloads = logicsByField[key]?.payloads;
  if (!payloads?.length) return null;

  // A primeira regra que se cumpre é a que vale; as seguintes não correm.
  const matched = payloads.find(payload => {
    const condition = payload?.condition;
    return (
      condition &&
      Object.keys(condition).length > 0 &&
      satisfied(condition, answers)
    );
  });
  const action = matched?.action;

  return action?.kind === 'navigate' ? String(action.field_key || '') : null;
};

/** As chaves efetivamente percorridas, em ordem. */
export const visiblePathKeys = (schema, answers = {}) => {
  const fields = schemaFields(schema);
  const orderedKeys = fields.map(field => String(field.key));
  const fieldByKey = Object.fromEntries(
    fields.map(field => [String(field.key), field])
  );
  const logicsByField = Object.fromEntries(
    (schema?.logics || []).map(logic => [String(logic.field_key), logic])
  );

  const visited = [];
  let index = 0;
  // Um formulário não pode ter mais passos do que perguntas: se contar mais,
  // há um ciclo e paramos em vez de prender a página.
  const limit = orderedKeys.length + 1;

  while (index < orderedKeys.length && visited.length < limit) {
    const key = orderedKeys[index];

    if (!legacyVisible(fieldByKey[key], answers)) {
      index += 1;
      // eslint-disable-next-line no-continue
      continue;
    }

    visited.push(key);
    const target = navigateTarget(logicsByField, key, answers);
    if (!target) {
      index += 1;
      // eslint-disable-next-line no-continue
      continue;
    }

    // Um salto para um final termina o percurso.
    if (!orderedKeys.includes(target)) break;

    const destination = orderedKeys.indexOf(target);
    // Só para a frente. Saltar para trás repetiria perguntas já respondidas e,
    // com duas regras a apontar uma para a outra, nunca terminaria.
    index = destination > index ? destination : index + 1;
  }

  return visited;
};
