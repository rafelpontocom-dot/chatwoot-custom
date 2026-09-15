import { computed, ref, watch } from 'vue';

/**
 * Raevo — que recursos uma consulta ocupa, e quais é preciso escolher.
 *
 * O agendamento escolhia um único «profissional ou recurso», e uma consulta que
 * precisa de profissional e de sala não tinha como ocupar as duas. A API já
 * aceitava vários (`resource_ids`); faltava a escolha, separada por tipo.
 *
 * A regra é a do procedimento, que já diz em «Recursos elegíveis» o que aceita:
 * - lista recursos → só aparecem os tipos que ele aceita, e cada um é
 *   obrigatório; o tipo que só tem uma opção já vem escolhido;
 * - não lista nada → qualquer recurso serve, nenhum tipo é obrigatório e nada é
 *   pré-escolhido, só é preciso escolher pelo menos um. Obrigar e pré-preencher
 *   aqui marcava o único laser da clínica em cada consulta.
 *
 * Os três sítios onde se escolhe recurso — o balão de criação rápida, o diálogo
 * completo e remarcar — usam isto, para a regra não divergir entre eles.
 */
export const RESOURCE_KINDS = [
  { key: 'professional', types: ['user'] },
  { key: 'room', types: ['room'] },
  { key: 'equipment', types: ['equipment'] },
  { key: 'other', types: ['generic'] },
];

const selecaoVazia = () =>
  Object.fromEntries(RESOURCE_KINDS.map(kind => [kind.key, '']));

export function useAppointmentResources({
  procedure,
  resources,
  preferredResourceIds = ref([]),
}) {
  const selection = ref(selecaoVazia());

  const allowedIds = computed(() => procedure.value?.resource_ids || []);
  const procedureDecides = computed(() => allowedIds.value.length > 0);

  const eligible = computed(() => {
    const ativos = resources.value.filter(
      resource => resource.active !== false
    );
    if (!procedureDecides.value) return ativos;
    return ativos.filter(resource => allowedIds.value.includes(resource.id));
  });

  const fields = computed(() =>
    RESOURCE_KINDS.map(kind => ({
      key: kind.key,
      options: eligible.value.filter(resource =>
        kind.types.includes(resource.resource_type)
      ),
      required: procedureDecides.value,
    })).filter(field => field.options.length)
  );

  // Uma só opção num procedimento que decide: escolhe-se sozinha. Senão, se só
  // uma das opções está à vista na agenda, é essa — estar na agenda de uma
  // profissional e abrir uma consulta traz a profissional já escolhida.
  const escolhaInicial = field => {
    if (procedureDecides.value && field.options.length === 1) {
      return String(field.options[0].id);
    }
    const aVista = field.options.filter(option =>
      preferredResourceIds.value.includes(option.id)
    );
    return aVista.length === 1 ? String(aVista[0].id) : '';
  };

  // Quando o procedimento muda, guarda-se o que ainda é válido e larga-se o
  // resto: uma escolha que o novo procedimento não aceita seria recusada ao
  // gravar, sem ninguém perceber porquê.
  watch(
    fields,
    lista => {
      const nova = selecaoVazia();
      lista.forEach(field => {
        const atual = selection.value[field.key];
        const aindaValida = field.options.some(
          option => String(option.id) === atual
        );
        nova[field.key] = aindaValida ? atual : escolhaInicial(field);
      });
      selection.value = nova;
    },
    { immediate: true }
  );

  const resourceIds = computed(() =>
    fields.value
      .map(field => selection.value[field.key])
      .filter(Boolean)
      .map(Number)
  );

  const missingKinds = computed(() =>
    fields.value
      .filter(field => field.required && !selection.value[field.key])
      .map(field => field.key)
  );

  const isComplete = computed(
    () => !missingKinds.value.length && resourceIds.value.length > 0
  );

  // Remarcar parte dos recursos que a consulta já ocupa — todos, um por tipo.
  // Antes gravava só o primeiro, e a sala caía em silêncio.
  const selectResourceIds = ids => {
    const nova = selecaoVazia();
    fields.value.forEach(field => {
      const escolhida = field.options.find(option => ids.includes(option.id));
      nova[field.key] = escolhida ? String(escolhida.id) : '';
    });
    selection.value = nova;
  };

  return {
    selection,
    fields,
    resourceIds,
    missingKinds,
    isComplete,
    selectResourceIds,
  };
}
