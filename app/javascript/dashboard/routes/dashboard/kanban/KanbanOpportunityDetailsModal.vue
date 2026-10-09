<script setup>
import { onClickOutside } from '@vueuse/core';
import {
  isWhatsappAddressingAttribute,
  withoutWhatsappAddressing,
} from 'dashboard/helper/contactAttributes';
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';
import ContactAPI from 'dashboard/api/contacts';
import FinanceAPI from 'dashboard/api/finance';
import FormsAPI from 'dashboard/api/forms';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Label from 'dashboard/components-next/label/Label.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import RaevoFieldRow from 'dashboard/components-next/raevo/RaevoFieldRow.vue';
import RaevoStamp from 'dashboard/components-next/raevo/RaevoStamp.vue';
import { isRequiredFieldEmpty } from 'dashboard/helper/kanbanRequiredFields';
import RaevoTimeline from 'dashboard/components-next/raevo/RaevoTimeline.vue';
import { getRandomColor } from 'dashboard/helper/labelColor';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import {
  opportunityPanelSections,
  resolveOpportunitySectionOrder,
} from 'dashboard/helper/kanbanOpportunitySections';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import KanbanCalendarAppointmentsSection from './KanbanCalendarAppointmentsSection.vue';
import RaevoAiOpportunityPanel from './RaevoAiOpportunityPanel.vue';
import {
  displayRaevoAiFieldLabel,
  displayRaevoAiFieldValue,
  humanizeRaevoAiValue,
  RAEVO_AI_FIELD_LABEL_KEYS,
} from './raevoAiOpportunityDisplay';
import KanbanOpportunityPipelineMenu from './KanbanOpportunityPipelineMenu.vue';
import KanbanNextActionCompletion from './KanbanNextActionCompletion.vue';
import KanbanActionHistory from './KanbanActionHistory.vue';
import FinancePaymentDialog from '../finance/FinancePaymentDialog.vue';
import FinancePaymentDetailsDialog from '../finance/FinancePaymentDetailsDialog.vue';
import FormsInvitationDialog from '../forms/FormsInvitationDialog.vue';
import FormsSubmissionDetailsDialog from '../forms/FormsSubmissionDetailsDialog.vue';
import KanbanFormSubmissionRow from './KanbanFormSubmissionRow.vue';
import { useAccountCurrency } from 'dashboard/composables/useAccountCurrency';

const props = defineProps({
  boardId: {
    type: [Number, String],
    required: true,
  },
  boardName: {
    type: String,
    default: '',
  },
  boards: {
    type: Array,
    default: () => [],
  },
  stages: {
    type: Array,
    default: () => [],
  },
  cardId: {
    type: [Number, String],
    required: true,
  },
  nextActionTypes: {
    type: Array,
    default: () => [],
  },
  lostReasonOptions: {
    type: Array,
    default: () => [],
  },
  customFieldDefinitions: {
    type: Array,
    default: () => [],
  },
  customFieldSections: {
    type: Array,
    default: () => [],
  },
  /** A ordem das secções da ficha, das Configurações do funil. */
  opportunitySectionOrder: {
    type: Array,
    default: () => [],
  },
  /**
   * Atributos de contato que este board mostra, na ordem em que os mostra.
   * A definição continua a ser do Chatwoot; aqui só se decide a colocação.
   * Vazio significa "nunca configurado" — ver `visibleContactAttributes`.
   */
  contactFieldKeys: {
    type: Array,
    default: () => [],
  },
  calendarEnabled: {
    type: Boolean,
    default: false,
  },
  calendarBookingStageIds: {
    type: Array,
    default: () => [],
  },
  calendarProcedureIds: {
    type: Array,
    default: () => [],
  },
  ownerOptions: {
    type: Array,
    default: () => [],
  },
  canManageFields: {
    type: Boolean,
    default: false,
  },
  drawerMode: {
    type: Boolean,
    default: false,
  },
  /**
   * Dentro da conversa a ficha não tem para onde fechar, e «abrir conversa»
   * levaria à conversa que já está aberta. Os dois botões saem.
   */
  embedded: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'close',
  'updated',
  'openConversation',
  'sendPaymentLink',
  'sendFormLink',
  'manageFields',
  'transferred',
]);

const { t, locale } = useI18n();
const store = useStore();
const accountLabels = useMapGetter('labels/getLabels');
const currentAccount = useMapGetter('getCurrentAccount');
const getAttributesByModel = useMapGetter('attributes/getAttributesByModel');
// Mesma regra da ficha do contato: endereçamento do WhatsApp não é dado de
// quem atende. Estava só na ficha, e a aba Contato daqui continuou a mostrá-lo.
const contactAttributeDefinitions = computed(() =>
  withoutWhatsappAddressing(getAttributesByModel.value('contact_attribute'))
);

const financeStatusLabels = {
  draft: () => t('FINANCE.PAYMENTS.STATUS.DRAFT'),
  pending: () => t('FINANCE.PAYMENTS.STATUS.PENDING'),
  confirmed: () => t('FINANCE.PAYMENTS.STATUS.CONFIRMED'),
  received: () => t('FINANCE.PAYMENTS.STATUS.RECEIVED'),
  overdue: () => t('FINANCE.PAYMENTS.STATUS.OVERDUE'),
  refunded: () => t('FINANCE.PAYMENTS.STATUS.REFUNDED'),
  chargeback: () => t('FINANCE.PAYMENTS.STATUS.CHARGEBACK'),
  canceled: () => t('FINANCE.PAYMENTS.STATUS.CANCELED'),
  failed: () => t('FINANCE.PAYMENTS.STATUS.FAILED'),
};

const card = ref(null);
const subject = ref('');
const description = ref('');
const ownerId = ref('');
const stageId = ref('');
const amountValue = ref('');
const { currency: accountCurrency } = useAccountCurrency();
const amountCurrency = ref('');
const expectedCloseDate = ref('');
const customFieldValues = ref({});
const timeline = ref([]);
const financeModule = ref(null);
const financeConnections = ref([]);
const financePayments = ref([]);
const isLoadingFinance = ref(false);
const financeError = ref('');
const paymentDialog = ref(null);
const paymentDetailsDialog = ref(null);
const formsInvitationDialog = ref(null);
const formsSubmissionDialog = ref(null);
const formsContext = ref({
  invitations: [],
  submissions: [],
  contact_submissions: [],
});
const isLoadingFormsContext = ref(false);
const formsContextError = ref('');
const invitationPendingRevocation = ref(null);
const isRevokingFormInvitation = ref(false);
const formInvitationRevocationConfirmButton = ref(null);
const copiedFinancePaymentId = ref(null);
const isLoadingTimeline = ref(false);
const timelineError = ref('');
const nextActionType = ref('');
const nextActionAt = ref('');
const nextActionNote = ref('');
const lostReason = ref('');
const isLoading = ref(false);
const isSaving = ref(false);
const isLoadingLabels = ref(false);
const isSavingLabels = ref(false);
const loadError = ref('');
const saveError = ref('');
// RAEVO (09/10, 123jpnbcb5h): concluir a ação em dois passos — null | 'result' | 'next'.
const etapaConclusao = ref(null);
const conclusaoErro = ref('');
const acaoEmConclusao = ref({ label: '', note: '', type: '' });
const formSnapshot = ref('');
const showUnsavedChanges = ref(false);
const keepEditingButton = ref(null);
const headerSubjectInput = ref(null);
const isEditingSubject = ref(false);
const labelsLoadError = ref('');
const labelsSaveError = ref('');
const subjectError = ref('');
const lostReasonError = ref('');
const selectedLabelTitles = ref([]);
const savedLabelTitles = ref([]);
const showLabelsPopover = ref(false);
const labelsPopoverRef = ref(null);
const labelsTriggerRef = ref(null);
const labelQuery = ref('');

// Fechava só clicando de novo no botão que o abriu, e ficava por cima da ficha
// enquanto se tentava ler o resto. Mesmo padrão do menu de etapas aqui ao lado:
// `ignore` no gatilho, senão o clique que fecha é o mesmo que reabre.
//
// Fechar assim descarta a seleção ainda não gravada — o popover tem botão de
// guardar próprio. É o que se espera de um popover, e é o mesmo que o Esc faz.
const closeLabelsPopover = () => {
  showLabelsPopover.value = false;
  selectedLabelTitles.value = [...savedLabelTitles.value];
  labelQuery.value = '';
};
onClickOutside(labelsPopoverRef, closeLabelsPopover, {
  ignore: [labelsTriggerRef],
});
const isCreatingLabel = ref(false);
const pendingPipelineTransfer = ref(null);

// Secções da ficha: abrem e fecham. Nascem abertas a próxima ação e o Geral —
// o que se trabalha; o resto consulta-se quando é preciso (a maquete aprovada).
//
// O que fica ABERTO não é guardado — é estado do momento. A ORDEM é do funil,
// e muda-se nas Configurações, não aqui.
const openSections = ref(['next-action', 'details']);

const secoesAbertas = computed(() => openSections.value);

const isSectionOpen = key => secoesAbertas.value.includes(key);

const toggleSection = key => {
  openSections.value = isSectionOpen(key)
    ? openSections.value.filter(item => item !== key)
    : [...openSections.value, key];
};
const contactDraft = ref({
  name: '',
  phone_number: '',
  email: '',
  identifier: '',
  custom_attributes: {},
  additional_attributes: {},
});
const isSavingContact = ref(false);
const contactSaveError = ref('');
const expandedGroupKeys = ref({
  organization: false,
  labels: false,
});

const modalTitle = computed(() =>
  props.boardName
    ? t('KANBAN.OPPORTUNITY_DETAILS.TITLE_WITH_BOARD', {
        boardName: props.boardName,
      })
    : t('KANBAN.OPPORTUNITY_DETAILS.TITLE')
);
const headerTitle = computed(() => subject.value || modalTitle.value);
const cardDisplayId = computed(() => card.value?.id || props.cardId);
const hasConversation = computed(() => !!card.value?.conversationId);
const contactName = computed(
  () =>
    card.value?.contact?.name ||
    card.value?.contact?.email ||
    card.value?.contact?.phone_number ||
    t('KANBAN.OPPORTUNITY_DETAILS.NO_CONTACT')
);
const selectedStage = computed(() =>
  props.stages.find(stage => String(stage.id) === String(stageId.value))
);
const stageEnteredAt = computed(() => card.value?.stageEnteredAt || '');
const selectedStageIsLost = computed(
  () => selectedStage.value?.category === 'lost'
);
const financeEnabled = computed(() => financeModule.value?.enabled === true);
const financePermissions = computed(
  () => currentAccount.value?.permissions || []
);
const canCreateFinancePayment = computed(() =>
  ['administrator', 'agent', 'finance_create'].some(permission =>
    financePermissions.value.includes(permission)
  )
);
const canManageFinancePayments = computed(() =>
  ['administrator', 'agent', 'finance_manage'].some(permission =>
    financePermissions.value.includes(permission)
  )
);
const canRefundFinancePayments = computed(() =>
  ['administrator', 'finance_refund'].some(permission =>
    financePermissions.value.includes(permission)
  )
);
const canCreateFormInvitation = computed(() =>
  financePermissions.value.includes('administrator')
);
const connectedFinanceConnections = computed(() =>
  financeConnections.value.filter(
    connection => connection.status === 'connected'
  )
);
const financeSummary = computed(() => {
  const receivedPayments = financePayments.value.filter(
    payment => payment.status === 'received'
  );
  const latestPayment = financePayments.value[0];
  const latestReceivedAt = receivedPayments
    .map(payment => payment.paid_at)
    .filter(Boolean)
    .sort()
    .at(-1);

  return {
    status: latestPayment?.status,
    receivedCents: receivedPayments.reduce(
      (total, payment) => total + Number(payment.amount_cents || 0),
      0
    ),
    currency:
      latestPayment?.currency || amountCurrency.value || accountCurrency.value,
    latestReceivedAt,
  };
});
const contactDetails = computed(() => [
  {
    key: 'name',
    label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_NAME'),
    value: contactDraft.value.name,
  },
  {
    key: 'phone',
    label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_PHONE'),
    value: contactDraft.value.phone_number,
  },
  {
    key: 'email',
    label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_EMAIL'),
    value: contactDraft.value.email,
  },
  {
    key: 'identifier',
    label: t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_IDENTIFIER'),
    value: contactDraft.value.identifier,
  },
]);
const formatContactAttributeLabel = key =>
  String(key)
    .replace(/[_-]+/g, ' ')
    .replace(/^./, character => character.toUpperCase());

// A lista sai das definicoes da conta, nao dos valores gravados no contato:
// um atributo que este contato nunca preencheu tem de continuar alcancavel.
const contactAttributeEntries = computed(() => {
  const custom = contactDraft.value.custom_attributes || {};
  const defined = contactAttributeDefinitions.value.map(definition => ({
    key: definition.attribute_key,
    value: custom[definition.attribute_key],
    source: 'custom_attributes',
    label:
      definition.attribute_display_name ||
      formatContactAttributeLabel(definition.attribute_key),
    displayType: definition.attribute_display_type,
    options: definition.attribute_values || [],
  }));
  const definedKeys = new Set(defined.map(entry => entry.key));

  const toEntry =
    source =>
    ([key, value]) => ({
      key,
      value,
      source,
      label: formatContactAttributeLabel(key),
      displayType: typeof value === 'boolean' ? 'checkbox' : 'text',
      options: [],
    });

  return [
    ...Object.entries(contactDraft.value.additional_attributes || {}).map(
      toEntry('additional_attributes')
    ),
    ...defined,
    // valores gravados que perderam a definicao continuam visiveis
    ...Object.entries(custom)
      .filter(([key]) => !definedKeys.has(key))
      .map(toEntry('custom_attributes')),
  ].filter(
    entry => !isWhatsappAddressingAttribute({ attribute_key: entry.key })
  );
});

// As etiquetas chegam do serializador como títulos; a cor vem do vocabulário
// da conta, para o ponto colorido ser o mesmo em todo o produto.
const contactLabels = computed(() => {
  const titles = card.value?.contact?.labels || [];
  const porTitulo = new Map(
    (accountLabels.value || []).map(label => [label.title, label])
  );

  return titles.map(title => porTitulo.get(title) || { title });
});

const hasAttributeValue = value =>
  value !== '' && value !== null && value !== undefined;

// Linhas que já foram tocadas nesta sessão. Sem isto, num board ainda sem
// configuração de campos de contato, limpar um valor faria a linha desaparecer
// debaixo do cursor e não haveria como redigitar.
const revealedAttributeKeys = ref(new Set());

// Quem decide o que aparece é a configuração de campos do board, não o valor
// gravado no contato: campo previsto aparece sempre, vazio desenha traço, como
// já acontece com os campos da oportunidade. Preencher deixa de ser um gesto em
// dois tempos ("adicionar" e depois escrever).
//
// Board ainda não configurado cai no comportamento anterior — mostra o que tem
// valor — para nenhuma ficha existente esvaziar de um dia para o outro.
const contactFieldsConfigured = computed(
  () => props.contactFieldKeys.length > 0
);
const visibleContactAttributes = computed(() => {
  if (!contactFieldsConfigured.value) {
    return contactAttributeEntries.value.filter(
      entry =>
        hasAttributeValue(entry.value) ||
        revealedAttributeKeys.value.has(entry.key)
    );
  }

  const byKey = new Map(
    contactAttributeEntries.value.map(entry => [entry.key, entry])
  );

  return props.contactFieldKeys
    .map(key => byKey.get(key))
    .filter(entry => entry !== undefined);
});
const formatContactAttributeValue = value => {
  // Um campo aberto e ainda vazio desenhava a string "undefined" na linha em
  // repouso. Vazio é ausência de valor, e quem desenha ausência é o RaevoFieldRow.
  if (!hasAttributeValue(value)) return '';
  if (Array.isArray(value)) return value.join(', ');
  if (typeof value === 'boolean') {
    return value
      ? t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_VALUE_TRUE')
      : t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_VALUE_FALSE');
  }

  return String(value);
};
const setContactAttributeValue = (entry, value) => {
  revealedAttributeKeys.value = new Set(revealedAttributeKeys.value).add(
    entry.key
  );
  contactDraft.value = {
    ...contactDraft.value,
    [entry.source]: {
      ...contactDraft.value[entry.source],
      [entry.key]: value,
    },
  };
};
// Espelha o servidor: o título fica em minúsculas e não aceita espaço, então
// «Paciente VIP» vira «paciente-vip» em vez de ser recusado.
const LABEL_TITLE_FORMAT = /^[\p{L}\p{N}][\p{L}\p{N}_-]+$/u;
const normalizedLabelQuery = computed(() =>
  labelQuery.value.trim().toLowerCase().replace(/\s+/g, '-')
);
const filteredAccountLabels = computed(() => {
  const query = normalizedLabelQuery.value;
  if (!query) return accountLabels.value || [];
  return (accountLabels.value || []).filter(label =>
    String(label.title || '')
      .toLowerCase()
      .includes(query)
  );
});
const labelQueryHasExactMatch = computed(() =>
  (accountLabels.value || []).some(
    label =>
      String(label.title || '').toLowerCase() === normalizedLabelQuery.value
  )
);
const canCreateLabels = computed(() =>
  (currentAccount.value?.permissions || []).includes('administrator')
);
const labelQueryIsNew = computed(
  () => !!normalizedLabelQuery.value && !labelQueryHasExactMatch.value
);
const labelTitleToCreate = computed(() =>
  labelQueryIsNew.value && LABEL_TITLE_FORMAT.test(normalizedLabelQuery.value)
    ? normalizedLabelQuery.value
    : ''
);
const selectedLabelTitleSet = computed(
  () => new Set(selectedLabelTitles.value)
);
const defaultNextActionTypes = computed(() => [
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.CALL_BACK'),
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.SEND_PROPOSAL'),
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.SEND_PAYMENT_LINK'),
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.FOLLOW_UP'),
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.CONFIRM_PAYMENT'),
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.SEND_CONTRACT'),
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.OTHER'),
]);
const selectableNextActionTypes = computed(() => {
  const configuredOptions = props.nextActionTypes.length
    ? props.nextActionTypes
    : defaultNextActionTypes.value;
  const options = [...configuredOptions];

  if (nextActionType.value && !options.includes(nextActionType.value)) {
    options.unshift(nextActionType.value);
  }

  return options;
});
const nextActionTypeOptions = computed(() => [
  {
    value: '',
    label: t('KANBAN.OPPORTUNITY_DETAILS.ACTION_TYPES.NONE'),
  },
  ...selectableNextActionTypes.value.map(option => ({
    value: option,
    label: option,
  })),
]);

// Valores de exibição da linha em repouso: o utilizador lê o rótulo da opção,
// nunca o id guardado. Data em formato local, valor com moeda.
const rotuloDaOpcao = (opcoes, valor) =>
  opcoes.find(opcao => String(opcao.value) === String(valor))?.label || '';

const ownerDisplay = computed(() =>
  rotuloDaOpcao(props.ownerOptions || [], ownerId.value)
);
// Sem tipo, a linha diz «—» como as outras; o rótulo da opção vazia
// («Selecionar ação») lia-se como um valor.
const nextActionTypeDisplay = computed(() =>
  nextActionType.value
    ? rotuloDaOpcao(nextActionTypeOptions.value, nextActionType.value)
    : ''
);
const dataLocal = valor => {
  if (!valor) return '';
  const d = new Date(valor);
  if (Number.isNaN(d.getTime())) return valor;
  // 123jpnbcb5d: uma data sem hora («2026-10-23») é lida como meia-noite UTC;
  // no fuso do browser, em São Paulo, virava 22/10. Sem hora, mostra-se em UTC,
  // que é o dia gravado.
  return new Intl.DateTimeFormat(undefined, {
    dateStyle: 'short',
    ...(String(valor).includes('T')
      ? { timeStyle: 'short' }
      : { timeZone: 'UTC' }),
  }).format(d);
};
const nextActionAtDisplay = computed(() => dataLocal(nextActionAt.value));
const expectedCloseDateDisplay = computed(() =>
  dataLocal(expectedCloseDate.value)
);
const amountDisplay = computed(() => {
  const bruto = String(amountValue.value ?? '').trim();
  if (!bruto) return '';
  const n = Number(bruto);
  if (Number.isNaN(n)) return bruto;
  return new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: amountCurrency.value || accountCurrency.value,
  }).format(n);
});

const selectableLostReasonOptions = computed(() => {
  const options = [...props.lostReasonOptions];

  if (lostReason.value && !options.includes(lostReason.value)) {
    options.unshift(lostReason.value);
  }

  return options;
});
const normalizedCustomFieldDefinitions = computed(() =>
  props.customFieldDefinitions
    .map(definition => ({
      ...definition,
      fieldType: definition.fieldType || definition.field_type,
      requiredStageIds:
        definition.requiredStageIds || definition.required_stage_ids || [],
    }))
    .sort(
      (firstDefinition, secondDefinition) =>
        (firstDefinition.layout?.position || 0) -
        (secondDefinition.layout?.position || 0)
    )
);
const canonicalFieldLayoutKey = value =>
  String(value || '')
    .trim()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
const customFieldSectionKey = definition => {
  const key = canonicalFieldLayoutKey(definition.layout?.section);

  return (
    {
      detail: 'details',
      details: 'details',
      general: 'details',
      geral: 'details',
      marketing: 'marketing',
      mkt: 'marketing',
      ai: 'ai',
    }[key] ||
    key ||
    'details'
  );
};
const customFieldGroupKey = definition =>
  canonicalFieldLayoutKey(definition.layout?.group);
const customFieldSectionLabel = sectionKey => {
  if (sectionKey === 'details') {
    return t('KANBAN.OPPORTUNITY_DETAILS.TABS.GENERAL');
  }
  if (sectionKey === 'marketing') {
    return t('KANBAN.OPPORTUNITY_DETAILS.TABS.MARKETING');
  }

  return sectionKey
    .replace(/[_-]+/g, ' ')
    .replace(/^./, character => character.toUpperCase());
};
const customFieldGroupLabel = groupKey =>
  groupKey
    .replace(/[_-]+/g, ' ')
    .replace(/^./, character => character.toUpperCase());
const customFieldTabs = computed(() => {
  const sections = new Map([
    [
      'details',
      { key: 'details', label: customFieldSectionLabel('details'), groups: [] },
    ],
    [
      'marketing',
      {
        key: 'marketing',
        label: customFieldSectionLabel('marketing'),
        groups: [],
      },
    ],
  ]);

  props.customFieldSections.forEach(section => {
    const key = customFieldSectionKey({ layout: { section: section.key } });
    const existingSection = sections.get(key);
    sections.set(key, {
      ...section,
      ...existingSection,
      key,
      groups: section.groups || existingSection?.groups || [],
    });
  });

  normalizedCustomFieldDefinitions.value.forEach(definition => {
    const key = customFieldSectionKey(definition);
    if (sections.has(key)) return;

    sections.set(key, {
      key,
      label: customFieldSectionLabel(key),
      groups: [],
    });
  });

  return [...sections.values()];
});
/**
 * As secções da ficha, pela ordem do funil.
 *
 * A ordem vem das Configurações do funil (`opportunity_section_order`) e é a
 * mesma para toda a equipa — decisão do Pedro na noite de 07/10: «reordenar
 * somente nas configurações». A regra de reconciliação está em
 * `helper/kanbanOpportunitySections.js`, com testes: uma ordem gravada tem de
 * aguentar secções que se criaram ou apagaram depois.
 */
const SECTION_LABEL_KEYS = {
  'next-action': 'KANBAN.OPPORTUNITY_DETAILS.QUESTIONS.NEXT_ACTION',
  'contact-details': 'KANBAN.OPPORTUNITY_DETAILS.CONTACT',
  calendar: 'KANBAN.OPPORTUNITY_DETAILS.TABS.CALENDAR',
  finance: 'FINANCE.TITLE',
  forms: 'FORMS.TITLE',
  timeline: 'KANBAN.OPPORTUNITY_DETAILS.TABS.TIMELINE',
};

const fieldSectionKeys = computed(() =>
  customFieldTabs.value.map(section => section.key)
);
const isFieldSection = key => fieldSectionKeys.value.includes(key);

const sectionLabel = key =>
  isFieldSection(key)
    ? customFieldTabs.value.find(section => section.key === key)?.label
    : t(SECTION_LABEL_KEYS[key]);

const sectionOrder = computed(() =>
  resolveOpportunitySectionOrder(
    props.opportunitySectionOrder,
    opportunityPanelSections(fieldSectionKeys.value)
  )
);

const hasFieldsInSection = key =>
  normalizedCustomFieldDefinitions.value.some(
    definition => customFieldSectionKey(definition) === key
  );

// Uma secção desligada não é escondida com CSS: sai da lista. Uma secção de
// campos sem nenhum campo também sai — o Geral fica sempre, porque tem os
// campos comerciais de raiz.
const visibleSections = computed(() =>
  sectionOrder.value.filter(key => {
    if (key === 'calendar') return Boolean(props.calendarEnabled);
    if (key === 'finance') return financeEnabled.value;
    if (key === 'forms') return canCreateFormInvitation.value;
    if (isFieldSection(key) && key !== 'details')
      return hasFieldsInSection(key);

    return true;
  })
);

const normalizeCard = payload =>
  Object.fromEntries(
    Object.entries({
      ...payload,
      accountId: payload.accountId ?? payload.account_id,
      kanbanBoardId: payload.kanbanBoardId ?? payload.kanban_board_id,
      kanbanStageId: payload.kanbanStageId ?? payload.kanban_stage_id,
      conversationId: payload.conversationId ?? payload.conversation_id,
      ownerId: payload.ownerId ?? payload.owner_id,
      amountCents: payload.amountCents ?? payload.amount_cents,
      amountCurrency: payload.amountCurrency ?? payload.amount_currency,
      expectedCloseDate:
        payload.expectedCloseDate ?? payload.expected_close_date,
      customFieldValues:
        payload.customFieldValues ?? payload.custom_field_values,
      nextActionType: payload.nextActionType ?? payload.next_action_type,
      nextActionAt: payload.nextActionAt ?? payload.next_action_at,
      nextActionNote: payload.nextActionNote ?? payload.next_action_note,
      nextActionCompletedAt:
        payload.nextActionCompletedAt ??
        payload.next_action_completed_at ??
        null,
      nextActionHistory:
        payload.nextActionHistory ?? payload.next_action_history ?? [],
      lostReason: payload.lostReason ?? payload.lost_reason,
    }).filter(([, value]) => value !== undefined)
  );

const formatDateTimeInput = value => {
  if (!value) return '';

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value).slice(0, 16);

  const offset = date.getTimezoneOffset();
  const localDate = new Date(date.getTime() - offset * 60000);
  return localDate.toISOString().slice(0, 16);
};

const toIso8601 = value => (value ? new Date(value).toISOString() : null);
const formatAmountInput = amountCents =>
  amountCents === null || amountCents === undefined
    ? ''
    : (Number(amountCents) / 100).toFixed(2);
const toAmountCents = value => {
  const normalizedValue = String(value || '')
    .replace(',', '.')
    .trim();
  if (!normalizedValue) return null;

  const amount = Number(normalizedValue);
  return Number.isNaN(amount) ? null : Math.round(amount * 100);
};
function isCustomFieldVisible(definition) {
  const condition = definition.condition || {};
  if (!condition.fieldKey && !condition.field_key) return true;

  const fieldKey = condition.fieldKey || condition.field_key;
  return (
    String(customFieldValues.value[fieldKey] ?? '') === String(condition.equals)
  );
}
const visibleCustomFieldDefinitions = computed(() =>
  normalizedCustomFieldDefinitions.value.filter(definition =>
    isCustomFieldVisible(definition)
  )
);
const sectionDefinitions = key =>
  visibleCustomFieldDefinitions.value.filter(
    definition => customFieldSectionKey(definition) === key
  );
const buildSectionGroups = section => {
  const definitions = sectionDefinitions(section.key);
  const seenGroupKeys = new Set();
  const groups = (section.groups || []).flatMap(group => {
    const key = canonicalFieldLayoutKey(group.key);
    if (!key || seenGroupKeys.has(key)) return [];

    seenGroupKeys.add(key);
    return [
      {
        ...group,
        key,
        definitions: definitions.filter(
          definition => customFieldGroupKey(definition) === key
        ),
      },
    ];
  });
  const ungrouped = definitions.filter(
    definition => !customFieldGroupKey(definition)
  );

  if (ungrouped.length) {
    // Quando a aba não tem grupos, os seus campos são a aba — não «outros».
    // Estavam a ser empurrados para debaixo de um cabeçalho genérico, abaixo
    // dos campos nativos, como se fossem sobras.
    groups.push({
      key: 'ungrouped',
      label: groups.length
        ? t('KANBAN.OPPORTUNITY_DETAILS.UNGROUPED_FIELDS')
        : '',
      color: 'slate',
      definitions: ungrouped,
    });
  }

  definitions
    .filter(definition => {
      const groupKey = customFieldGroupKey(definition);
      return groupKey && !seenGroupKeys.has(groupKey);
    })
    .forEach(definition => {
      const key = customFieldGroupKey(definition);
      if (seenGroupKeys.has(key)) return;

      seenGroupKeys.add(key);
      groups.push({
        key,
        label: customFieldGroupLabel(key),
        color: 'slate',
        definitions: definitions.filter(
          groupedDefinition => customFieldGroupKey(groupedDefinition) === key
        ),
      });
    });

  return groups.filter(group => group.definitions.length);
};
const groupsBySection = computed(
  () =>
    new Map(
      customFieldTabs.value.map(section => [
        section.key,
        buildSectionGroups(section),
      ])
    )
);
const sectionGroups = key => groupsBySection.value.get(key) || [];

/**
 * «Mostrar mais», como no painel de contacto do Chatwoot.
 *
 * O Marketing tem perto de trinta campos e quase todos vazios: listados, a
 * secção ocupava o ecrã para dizer «—» trinta vezes. Fica à vista o que tem
 * valor, o que esta etapa exige e o que a clínica marcou como importante; o
 * resto fica atrás de um botão que diz quantos são. Decide-se pelo valor
 * GRAVADO, não pelo rascunho: apagar um campo enquanto se edita não o faz
 * desaparecer debaixo do cursor.
 */
const showAllFieldsIn = ref([]);
const hasSavedValue = definition => {
  const valor = (card.value?.customFieldValues || {})[definition.key];
  if (Array.isArray(valor)) return valor.length > 0;

  return valor !== undefined && valor !== null && valor !== '';
};
const isRequiredInStage = definition =>
  (definition.requiredStageIds || [])
    .map(Number)
    .includes(Number(stageId.value));
// Um campo condicional só está na lista porque uma resposta o revelou: é a
// pergunta seguinte, e escondê-lo atrás de «Mostrar mais» desfazia a condição.
const isRevealedByCondition = definition =>
  Boolean(definition.condition?.fieldKey || definition.condition?.field_key);
const isShownByDefault = definition =>
  hasSavedValue(definition) ||
  Boolean(definition.important) ||
  isRequiredInStage(definition) ||
  isRevealedByCondition(definition);
const isShowingAllFields = key => showAllFieldsIn.value.includes(key);
const toggleAllFields = key => {
  showAllFieldsIn.value = isShowingAllFields(key)
    ? showAllFieldsIn.value.filter(item => item !== key)
    : [...showAllFieldsIn.value, key];
};
const shownDefinitions = (key, group) =>
  isShowingAllFields(key)
    ? group.definitions
    : group.definitions.filter(isShownByDefault);
const hiddenFieldCount = key =>
  sectionDefinitions(key).filter(definition => !isShownByDefault(definition))
    .length;

const customFieldGroupClass = color =>
  ({
    slate: 'border-l-n-slate-7',
    blue: 'border-l-n-blue-7',
    teal: 'border-l-n-teal-7',
    green: 'border-l-green-600',
    amber: 'border-l-n-amber-7',
    orange: 'border-l-orange-600',
    ruby: 'border-l-n-ruby-7',
    rose: 'border-l-rose-600',
    violet: 'border-l-n-violet-7',
    iris: 'border-l-n-iris-7',
  })[color] || 'border-l-n-slate-7';
const groupToggleKey = (sectionKey, groupKey) => `${sectionKey}:${groupKey}`;
const isGroupExpanded = groupKey => expandedGroupKeys.value[groupKey] !== false;
const toggleGroup = groupKey => {
  expandedGroupKeys.value = {
    ...expandedGroupKeys.value,
    [groupKey]: !isGroupExpanded(groupKey),
  };
};
/**
 * Os campos que a etapa escolhida exige e estão vazios — vistos ANTES de ir ao
 * servidor. Mudar de etapa na ficha devolvia o erro cru do modelo
 * («procedimento is required»): em inglês, com a chave em vez do rótulo, e sem
 * dizer onde estava o campo. Agora a linha diz «Obrigatório nesta etapa» logo
 * que a etapa muda, e gravar sem ela abre a secção e leva o foco ao campo.
 */
const showRequiredErrors = ref(false);
const missingRequiredDefinitions = computed(() =>
  visibleCustomFieldDefinitions.value.filter(
    definition =>
      isRequiredInStage(definition) &&
      isRequiredFieldEmpty(customFieldValues.value[definition.key])
  )
);
const estaEmFalta = definition =>
  missingRequiredDefinitions.value.some(item => item.key === definition.key);
const requiredFieldHint = definition =>
  estaEmFalta(definition)
    ? t('KANBAN.OPPORTUNITY_DETAILS.REQUIRED_IN_STAGE')
    : '';
const requiredFieldError = definition =>
  showRequiredErrors.value && estaEmFalta(definition)
    ? t('KANBAN.OPPORTUNITY_DETAILS.REQUIRED_IN_STAGE')
    : '';
const revelarCamposEmFalta = async () => {
  const emFalta = missingRequiredDefinitions.value;
  const secoes = emFalta.map(customFieldSectionKey);
  openSections.value = [...new Set([...openSections.value, ...secoes])];
  expandedGroupKeys.value = {
    ...expandedGroupKeys.value,
    ...Object.fromEntries(
      emFalta.map(definition => [
        groupToggleKey(
          customFieldSectionKey(definition),
          customFieldGroupKey(definition)
        ),
        true,
      ])
    ),
  };
  await nextTick();
  // Centrado: o `focus()` sozinho rola o mínimo, e a 390px o campo ficava
  // debaixo da barra fixa de Guardar — com o foco lá, invisível.
  const linha = document.querySelector(
    `[data-testid="kanban-row-${emFalta[0].key}"]`
  );
  linha?.focus({ preventScroll: true });
  linha?.scrollIntoView({ block: 'center' });
};

const getCustomFieldValue = definition =>
  customFieldValues.value[definition.key] ?? '';

/**
 * O valor como se lê, para a linha em repouso.
 *
 * Os campos personalizados desenhavam uma linha só deles — rótulo de 9rem,
 * outro espaçamento, sempre em edição — enquanto os nativos usavam o
 * `RaevoFieldRow`. Duas linhas diferentes para a mesma coisa no mesmo painel.
 */
const customFieldDisplayValue = definition => {
  const valor = getCustomFieldValue(definition);

  // Booleano por responder era «Não»: a ausência de resposta lia-se como uma
  // resposta. Só `true` e `false` dizem alguma coisa.
  if (definition.fieldType === 'boolean') {
    if (valor === true) return t('KANBAN.OPPORTUNITY_DETAILS.BOOLEAN_YES');
    if (valor === false) return t('KANBAN.OPPORTUNITY_DETAILS.BOOLEAN_NO');
    return '';
  }
  if (Array.isArray(valor)) return valor.join(', ');

  return valor === '' || valor === null || valor === undefined
    ? ''
    : String(valor);
};

const customFieldRowVariant = definition => {
  if (['select', 'multiselect'].includes(definition.fieldType)) return 'select';
  if (definition.fieldType === 'textarea') return 'textarea';

  return 'input';
};
const setCustomFieldValue = (definition, value) => {
  customFieldValues.value = {
    ...customFieldValues.value,
    [definition.key]: value,
  };
};
const selectedMultiselectValues = event =>
  Array.from(event.target.selectedOptions).map(option => option.value);

const getErrorMessage = (error, fallback) => {
  const errors = error?.response?.data?.errors;

  if (Array.isArray(errors)) return errors.join(', ');
  if (typeof errors === 'string') return errors;
  if (errors && typeof errors === 'object') {
    return Object.values(errors).flat().join(', ');
  }

  return error?.response?.data?.message || error?.message || fallback;
};

const currentFormState = () => ({
  subject: subject.value,
  description: description.value,
  ownerId: ownerId.value,
  stageId: stageId.value,
  amountValue: amountValue.value,
  amountCurrency: amountCurrency.value,
  expectedCloseDate: expectedCloseDate.value,
  // Campo vazio e campo ausente são o mesmo valor: escrever e apagar não é alteração.
  customFieldValues: Object.fromEntries(
    Object.entries(customFieldValues.value || {}).filter(
      ([, value]) =>
        value !== '' &&
        value !== null &&
        value !== undefined &&
        !(Array.isArray(value) && !value.length)
    )
  ),
  nextActionType: nextActionType.value,
  nextActionAt: nextActionAt.value,
  nextActionNote: nextActionNote.value,
  lostReason: lostReason.value,
});
const serializeFormState = () => JSON.stringify(currentFormState());
const isFormDirty = computed(
  () => !!formSnapshot.value && formSnapshot.value !== serializeFormState()
);

// Ir para a conversa fecha a ficha (KanbanView). Com alterações por gravar
// pergunta antes, como o X e o Esc — senão o que se escreveu perdia-se sem aviso.
// Embutida na conversa, a ficha não fecha, e não há o que perguntar.
const pendingLeave = ref(null);
const leaveFor = action => {
  if (props.embedded || !isFormDirty.value) {
    action();
    return;
  }

  pendingLeave.value = action;
  showUnsavedChanges.value = true;
};

const setFormState = payload => {
  card.value = normalizeCard(payload);
  showRequiredErrors.value = false;
  contactDraft.value = {
    name: card.value.contact?.name || '',
    phone_number: card.value.contact?.phone_number || '',
    email: card.value.contact?.email || '',
    identifier: card.value.contact?.identifier || '',
    custom_attributes: { ...(card.value.contact?.custom_attributes || {}) },
    additional_attributes: {
      ...(card.value.contact?.additional_attributes || {}),
    },
  };
  revealedAttributeKeys.value = new Set();
  subject.value = card.value.subject || '';
  description.value = card.value.description || '';
  ownerId.value = card.value.ownerId ? String(card.value.ownerId) : '';
  stageId.value = card.value.kanbanStageId
    ? String(card.value.kanbanStageId)
    : '';
  amountValue.value = formatAmountInput(card.value.amountCents);
  amountCurrency.value = card.value.amountCurrency || accountCurrency.value;
  expectedCloseDate.value = card.value.expectedCloseDate || '';
  customFieldValues.value = card.value.customFieldValues || {};
  nextActionType.value = card.value.nextActionType || '';
  nextActionAt.value = formatDateTimeInput(card.value.nextActionAt);
  nextActionNote.value = card.value.nextActionNote || '';
  lostReason.value = card.value.lostReason || '';
  formSnapshot.value = serializeFormState();
};

const getLabelsPayload = response =>
  response?.data?.payload || response?.data || [];

const loadLabels = async () => {
  isLoadingLabels.value = true;
  labelsLoadError.value = '';

  try {
    const [assignedLabelsResponse] = await Promise.all([
      KanbanBoardsAPI.getCardLabels(props.boardId, props.cardId),
      store.dispatch('labels/get'),
    ]);
    selectedLabelTitles.value = getLabelsPayload(assignedLabelsResponse).map(
      label => label.title || label
    );
    savedLabelTitles.value = [...selectedLabelTitles.value];
  } catch (error) {
    labelsLoadError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.LOAD_LABELS_ERROR')
    );
  } finally {
    isLoadingLabels.value = false;
  }
};

const loadCard = async () => {
  isLoading.value = true;
  loadError.value = '';

  try {
    const response = await KanbanBoardsAPI.showCardById(
      props.boardId,
      props.cardId
    );
    setFormState(response.data || {});
  } catch (error) {
    loadError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.LOAD_ERROR')
    );
  } finally {
    isLoading.value = false;
  }
};

const loadTimeline = async () => {
  isLoadingTimeline.value = true;
  timelineError.value = '';

  try {
    const response = await KanbanBoardsAPI.getCardTimeline(
      props.boardId,
      props.cardId
    );
    timeline.value = response?.data || [];
  } catch (error) {
    timelineError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.LOAD_ERROR')
    );
  } finally {
    isLoadingTimeline.value = false;
  }
};

const loadFinanceModule = async () => {
  try {
    const { data } = await FinanceAPI.getModule();
    financeModule.value = data;
    if (data.enabled) {
      const connectionsResponse = await FinanceAPI.getProviderConnections();
      financeConnections.value = connectionsResponse.data;
    }
  } catch {
    financeModule.value = null;
    financeConnections.value = [];
  }
};

const loadFinancePayments = async () => {
  if (!financeEnabled.value || isLoadingFinance.value) return;

  isLoadingFinance.value = true;
  financeError.value = '';
  try {
    const { data } = await FinanceAPI.getPayments({
      kanban_card_id: props.cardId,
    });
    financePayments.value = data;
  } catch {
    financeError.value = t('FINANCE.ERROR.LOAD');
  } finally {
    isLoadingFinance.value = false;
  }
};

const openFinancePaymentDialog = () => {
  paymentDialog.value?.open();
};

const openFormsInvitationDialog = () => {
  formsInvitationDialog.value?.open();
};

/**
 * Resolve o que o formulário propôs mas não aplicou.
 *
 * Uma ação em modo «deixar para confirmar» ficou à espera de quem conhece o
 * caso. Confirmar aplica-a; descartar tira-a da frente. Nos dois casos ela sai
 * da lista, porque proposta que fica para sempre deixa de ser lida.
 */
const resolvingAction = ref(null);
const pendingActionError = ref('');

const resolvePendingAction = async (submission, action, decision) => {
  if (resolvingAction.value) return;

  resolvingAction.value = `${submission.id}-${action.index}`;
  pendingActionError.value = '';
  try {
    const { data } = await FormsAPI.resolvePendingAction(
      submission.id,
      action.index,
      decision
    );
    submission.pending_actions = (data.pending_actions || []).map(
      (pendente, index) => ({ index, kind: pendente.kind })
    );
    // Confirmar pode ter movido a etapa: o card tem de ser relido.
    // Confirmar pode ter movido a etapa: quem abriu o card tem de reler.
    if (decision === 'confirm') emit('updated');
  } catch (error) {
    pendingActionError.value = getErrorMessage(
      error,
      t('FORMS.SUBMISSION_ACTIONS.RESOLVE_ERROR')
    );
  } finally {
    resolvingAction.value = null;
  }
};

// A linha emite um evento só; quem resolve continua a ser esta função.
const onResolvePendingAction = ({ submission, action, decision }) =>
  resolvePendingAction(submission, action, decision);

const openFormsSubmission = submission => {
  formsSubmissionDialog.value?.open(submission.id);
};

const requestFormInvitationRevocation = invitation => {
  if (invitation.status !== 'active') return;

  invitationPendingRevocation.value = invitation;
};

const revokeFormInvitation = async () => {
  const invitation = invitationPendingRevocation.value;
  if (!invitation || isRevokingFormInvitation.value) return;

  isRevokingFormInvitation.value = true;
  formsContextError.value = '';
  try {
    const { data } = await FormsAPI.revokeInvitation(invitation.id);
    formsContext.value = {
      ...formsContext.value,
      invitations: formsContext.value.invitations.map(item =>
        item.id === data.id ? { ...item, ...data } : item
      ),
    };
    invitationPendingRevocation.value = null;
  } catch {
    formsContextError.value = t('FORMS.ERROR.REVOKE');
  } finally {
    isRevokingFormInvitation.value = false;
  }
};

const loadFormsContext = async () => {
  if (!card.value?.id || isLoadingFormsContext.value) return;

  isLoadingFormsContext.value = true;
  formsContextError.value = '';
  try {
    const { data } = await FormsAPI.getCardContext(card.value.id);
    formsContext.value = data;
  } catch {
    formsContext.value = {
      invitations: [],
      submissions: [],
      contact_submissions: [],
    };
    formsContextError.value = t('FORMS.ERROR.LOAD');
  } finally {
    isLoadingFormsContext.value = false;
  }
};

const formInvitationStatusLabel = status => {
  const labels = {
    active: t('FORMS.INVITATION.STATUS.ACTIVE'),
    abandoned: t('FORMS.INVITATION.STATUS.ABANDONED'),
    consumed: t('FORMS.INVITATION.STATUS.CONSUMED'),
    expired: t('FORMS.INVITATION.STATUS.EXPIRED'),
    revoked: t('FORMS.INVITATION.STATUS.REVOKED'),
  };
  return labels[status] || status;
};

const formatFormInvitationDate = value => {
  if (!value) return '';

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';

  return date.toLocaleString();
};

const sendFormsInvitationLink = url => {
  if (!hasConversation.value || !url) return;

  leaveFor(() => emit('sendFormLink', { card: card.value, url }));
};

const openFinancePaymentDetails = payment => {
  paymentDetailsDialog.value?.open(payment.id);
};

const addFinancePayment = payment => {
  financePayments.value = [payment, ...financePayments.value];
};

const updateFinancePayment = updatedPayment => {
  financePayments.value = financePayments.value.map(payment =>
    payment.id === updatedPayment.id ? updatedPayment : payment
  );
};

const copyFinancePaymentLink = async payment => {
  if (!payment.invoice_url) return;

  await copyTextToClipboard(payment.invoice_url);
  copiedFinancePaymentId.value = payment.id;
  window.setTimeout(() => {
    copiedFinancePaymentId.value = null;
  }, 2000);
};

const formatFinanceAmount = (amountCents, currency) =>
  new Intl.NumberFormat(undefined, {
    style: 'currency',
    currency: currency || accountCurrency.value,
  }).format(Number(amountCents || 0) / 100);

const formatFinanceDate = value => {
  if (!value) return t('FINANCE.SUMMARY.NO_PAYMENT_DATE');

  return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium' }).format(
    new Date(value)
  );
};

const financeStatusLabel = status => {
  if (!status) return t('FINANCE.SUMMARY.NO_STATUS');

  return (
    financeStatusLabels[status.toString().toLowerCase()]?.() ||
    t('FINANCE.SUMMARY.NO_STATUS')
  );
};

const sendFinancePaymentLink = payment => {
  if (!hasConversation.value || !payment.invoice_url) return;

  leaveFor(() => emit('sendPaymentLink', { card: card.value, payment }));
};

const timelineFieldDefinition = key =>
  normalizedCustomFieldDefinitions.value.find(field => field.key === key) || {
    key,
    label: humanizeRaevoAiValue(key),
  };
const timelineFieldValue = (field, value) => {
  if (RAEVO_AI_FIELD_LABEL_KEYS[field.key]) {
    return displayRaevoAiFieldValue({
      t,
      locale: locale?.value || 'en',
      field,
      value,
      emptyValue: t('KANBAN.OPPORTUNITY_DETAILS.FIELD_EMPTY'),
    });
  }
  if (value === null || value === undefined || String(value).trim() === '') {
    return t('KANBAN.OPPORTUNITY_DETAILS.FIELD_EMPTY');
  }
  return Array.isArray(value) ? value.join(', ') : String(value);
};
function timelineEventChanges(event) {
  if (event.event_type !== 'custom_fields_changed') return [];

  const [before = {}, after = {}] = event.changes?.custom_field_values || [];
  return [...new Set([...Object.keys(before), ...Object.keys(after)])]
    .filter(key => JSON.stringify(before[key]) !== JSON.stringify(after[key]))
    .map(key => {
      const field = timelineFieldDefinition(key);
      return {
        key,
        label: RAEVO_AI_FIELD_LABEL_KEYS[key]
          ? displayRaevoAiFieldLabel(t, field)
          : field.label,
        transition: t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.CHANGE_TRANSITION', {
          before: timelineFieldValue(field, before[key]),
          after: timelineFieldValue(field, after[key]),
        }),
      };
    });
}
// A cor do ponto no trilho. É redundante de propósito: o que o evento é está
// escrito no título, e a cor só acelera a leitura de uma lista longa. Azul fica
// para a mudança de etapa porque nesta direção o azul É etapa.
const TIMELINE_TONES = {
  card_won: 'success',
  next_action_completed: 'success',
  card_lost: 'danger',
  next_action_scheduled: 'warning',
  stage_changed: 'info',
};
const timelineEventTone = event =>
  TIMELINE_TONES[event.event_type] || 'neutral';

const timelineEventLabel = event => {
  const enteredStage = event.metadata?.to_stage?.name;
  const createdStage = event.metadata?.entered_stage?.name;

  if (event.event_type === 'stage_changed' && enteredStage) {
    return t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.ENTERED_STAGE', {
      stage: enteredStage,
    });
  }
  if (event.event_type === 'card_created' && createdStage) {
    return t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.CREATED_IN_STAGE', {
      stage: createdStage,
    });
  }

  const changes = timelineEventChanges(event);
  if (event.event_type === 'custom_fields_changed' && changes.length === 1) {
    return t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.CUSTOM_FIELD_CHANGED', {
      field: changes[0].label,
    });
  }
  if (event.event_type === 'custom_fields_changed' && changes.length > 1) {
    return t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.CUSTOM_FIELDS_CHANGED', {
      count: changes.length,
    });
  }

  return String(event.event_type || '')
    .replaceAll('_', ' ')
    .replace(/^./, character => character.toUpperCase());
};
const timelineEventMeta = event => {
  const actorName =
    event.actor?.name || t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.SYSTEM');
  return `${actorName} - ${new Date(event.occurred_at).toLocaleString()}`;
};
// Os dois consumidores do mesmo histórico: os últimos três ao lado do contexto
// comercial, e a lista inteira no separador. O mapeamento é um só — duas cópias
// divergiriam no dia em que alguém acrescentasse um tipo de evento.
const timelineItems = computed(() =>
  timeline.value.map(event => ({
    id: event.id,
    type: event.event_type,
    title: timelineEventLabel(event),
    meta: timelineEventMeta(event),
    tone: timelineEventTone(event),
    changes: timelineEventChanges(event),
    automations: event.automations || [],
  }))
);

// No Histórico, cada ação concluída já tem a sua linha, com quem a fez e o
// resultado (5j); o evento de conclusão repetia-a por baixo.
const alteracoesItems = computed(() =>
  timelineItems.value.filter(item => item.type !== 'next_action_completed')
);

const buildCardPayload = extraPayload => ({
  subject: subject.value.trim(),
  description: description.value.trim() ? description.value : null,
  owner_id: ownerId.value ? Number(ownerId.value) : null,
  kanban_stage_id: stageId.value ? Number(stageId.value) : null,
  amount_cents: toAmountCents(amountValue.value),
  amount_currency: amountCurrency.value || accountCurrency.value,
  expected_close_date: expectedCloseDate.value || null,
  custom_field_values: customFieldValues.value,
  next_action_type: nextActionType.value || null,
  ...(nextActionAt.value !== formatDateTimeInput(card.value?.nextActionAt)
    ? { next_action_at: toIso8601(nextActionAt.value) }
    : {}),
  next_action_note: nextActionNote.value.trim() ? nextActionNote.value : null,
  lost_reason: selectedStageIsLost.value
    ? lostReason.value.trim() || null
    : null,
  ...extraPayload,
});

const saveCardWith = async (extraPayload = {}) => {
  if (isSaving.value) return false;

  const trimmedSubject = subject.value.trim();
  subjectError.value = '';
  saveError.value = '';

  if (!trimmedSubject) {
    subjectError.value = t('KANBAN.OPPORTUNITY_DETAILS.REQUIRED_TITLE');
    return false;
  }

  if (selectedStageIsLost.value && !String(lostReason.value || '').trim()) {
    lostReasonError.value = t(
      'KANBAN.OPPORTUNITY_DETAILS.LOST_REASON_REQUIRED'
    );
    return false;
  }

  if (missingRequiredDefinitions.value.length) {
    showRequiredErrors.value = true;
    saveError.value = t('KANBAN.OPPORTUNITY_DETAILS.REQUIRED_FIELDS_MISSING', {
      fields: missingRequiredDefinitions.value
        .map(definition => definition.label || definition.key)
        .join(', '),
    });
    await revelarCamposEmFalta();
    return false;
  }

  isSaving.value = true;

  try {
    const response = await KanbanBoardsAPI.updateCardDetailsById(
      props.boardId,
      props.cardId,
      buildCardPayload({ subject: trimmedSubject, ...extraPayload })
    );
    const updatedCard = normalizeCard(response.data || {});
    setFormState(updatedCard);
    emit('updated', updatedCard);
    return true;
  } catch (error) {
    saveError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.SAVE_ERROR')
    );
    return false;
  } finally {
    isSaving.value = false;
  }
};

const saveCard = () => saveCardWith();

const iniciarConclusao = () => {
  const tipo = nextActionType.value ? nextActionTypeDisplay.value : '';
  acaoEmConclusao.value = {
    label: [tipo, nextActionAtDisplay.value].filter(Boolean).join(' · '),
    note: nextActionNote.value,
    type: tipo,
  };
  conclusaoErro.value = '';
  etapaConclusao.value = 'result';
};

// Junto do botão que falhou diz-se que o texto ficou; o motivo concreto (campo
// obrigatório, resposta do servidor) continua no rodapé da ficha, como em
// qualquer outra gravação.
const avisarFalhaNaConclusao = () => {
  conclusaoErro.value = t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.ERROR');
};

const confirmarConclusao = async resultado => {
  conclusaoErro.value = '';
  const gravou = await saveCardWith({
    complete_next_action: true,
    next_action_completed_at: new Date().toISOString(),
    ...(resultado ? { next_action_completion_note: resultado } : {}),
  });
  if (gravou) etapaConclusao.value = 'next';
  else avisarFalhaNaConclusao();
};

const salvarProximaAcao = async ({ type, at, note }) => {
  conclusaoErro.value = '';
  nextActionType.value = type;
  nextActionAt.value = at;
  nextActionNote.value = note;
  if (await saveCardWith()) {
    etapaConclusao.value = null;
    return;
  }
  // Não gravou: a ficha volta a não ter próxima ação, como o servidor a deixou.
  nextActionType.value = '';
  nextActionAt.value = '';
  nextActionNote.value = '';
  avisarFalhaNaConclusao();
};

// Estado vazio da maquete: nada marcado no que está gravado.
const semProximaAcao = computed(
  () =>
    !card.value?.nextActionAt &&
    !card.value?.nextActionType &&
    !card.value?.nextActionNote
);

const marcarProximaAcao = () => {
  conclusaoErro.value = '';
  etapaConclusao.value = 'schedule';
};

const fecharConclusao = () => {
  etapaConclusao.value = null;
  conclusaoErro.value = '';
};

const transferPipelineStage = async ({
  boardId,
  stageId: targetStageId,
  lostReason: transferLostReason,
}) => {
  isSaving.value = true;
  saveError.value = '';
  try {
    const response = await KanbanBoardsAPI.transferCardById(
      props.boardId,
      props.cardId,
      {
        kanban_board_id: boardId,
        kanban_stage_id: targetStageId,
        lock_version: card.value?.lockVersion,
        lost_reason: transferLostReason || undefined,
      }
    );
    pendingPipelineTransfer.value = null;
    emit('transferred', {
      boardId,
      card: normalizeCard(response.data || {}),
    });
  } catch (error) {
    saveError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

const selectPipelineStage = async ({
  boardId,
  stageId: targetStageId,
  stage,
}) => {
  if (isSaving.value || !targetStageId) return;

  if (Number(boardId) === Number(props.boardId)) {
    stageId.value = String(targetStageId);
    return;
  }

  if (isFormDirty.value) {
    saveError.value = t('KANBAN.OPPORTUNITY_DETAILS.SAVE_BEFORE_TRANSFER');
    return;
  }

  if (stage?.category === 'lost') {
    pendingPipelineTransfer.value = {
      boardId,
      stageId: targetStageId,
      stage,
      lostReason: '',
    };
    return;
  }

  await transferPipelineStage({ boardId, stageId: targetStageId });
};

const confirmPipelineTransfer = async () => {
  const transfer = pendingPipelineTransfer.value;
  if (!transfer || !transfer.lostReason.trim()) return;

  await transferPipelineStage({
    boardId: transfer.boardId,
    stageId: transfer.stageId,
    lostReason: transfer.lostReason.trim(),
  });
};

const toggleLabel = title => {
  labelsSaveError.value = '';

  selectedLabelTitles.value = selectedLabelTitleSet.value.has(title)
    ? selectedLabelTitles.value.filter(selectedTitle => selectedTitle !== title)
    : [...selectedLabelTitles.value, title];
};

const saveLabels = async () => {
  if (isSavingLabels.value) return;

  isSavingLabels.value = true;
  labelsSaveError.value = '';

  try {
    const response = await KanbanBoardsAPI.updateCardLabels(
      props.boardId,
      props.cardId,
      selectedLabelTitles.value
    );
    selectedLabelTitles.value = getLabelsPayload(response).map(
      label => label.title || label
    );
    savedLabelTitles.value = [...selectedLabelTitles.value];
  } catch (error) {
    labelsSaveError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.SAVE_LABELS_ERROR')
    );
  } finally {
    isSavingLabels.value = false;
  }
};

const createLabel = async () => {
  const title = labelTitleToCreate.value;
  if (!title || !canCreateLabels.value || isCreatingLabel.value) return;

  isCreatingLabel.value = true;
  labelsSaveError.value = '';
  try {
    await store.dispatch('labels/create', {
      title,
      color: getRandomColor(),
      show_on_sidebar: false,
    });
  } catch (error) {
    labelsSaveError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.CREATE_LABEL_ERROR')
    );
    return;
  } finally {
    isCreatingLabel.value = false;
  }

  labelQuery.value = '';
  if (!selectedLabelTitleSet.value.has(title)) {
    selectedLabelTitles.value = [...selectedLabelTitles.value, title];
  }
  // Criar a partir do card é para usar já: fica aplicada sem segundo clique.
  await saveLabels();
};

const saveContact = async () => {
  const contactId = card.value?.contact?.id;
  if (!contactId || isSavingContact.value) return;

  isSavingContact.value = true;
  contactSaveError.value = '';
  try {
    const response = await ContactAPI.update(contactId, {
      name: contactDraft.value.name.trim(),
      phone_number: contactDraft.value.phone_number.trim(),
      email: contactDraft.value.email.trim(),
      identifier: contactDraft.value.identifier.trim(),
      custom_attributes: contactDraft.value.custom_attributes,
      additional_attributes: contactDraft.value.additional_attributes,
    });
    const updatedContact = response.data?.payload ?? response.data ?? {};
    card.value = {
      ...card.value,
      contact: { ...card.value.contact, ...updatedContact },
    };
    contactDraft.value = {
      ...contactDraft.value,
      ...updatedContact,
      custom_attributes:
        updatedContact.custom_attributes ||
        contactDraft.value.custom_attributes,
      additional_attributes:
        updatedContact.additional_attributes ||
        contactDraft.value.additional_attributes,
    };
  } catch (error) {
    contactSaveError.value = getErrorMessage(
      error,
      t('KANBAN.OPPORTUNITY_DETAILS.SAVE_CONTACT_ERROR')
    );
  } finally {
    isSavingContact.value = false;
  }
};

const openConversation = () => {
  if (!hasConversation.value) return;

  leaveFor(() => emit('openConversation', card.value));
};

const requestClose = event => {
  if (!isFormDirty.value) {
    emit('close');
    return;
  }

  event?.preventDefault?.();
  showUnsavedChanges.value = true;
};
// Quem abriu a pergunta (X, Esc, conversa, link) recebe o foco de volta ao
// continuar — sem isto o foco caía no <body> e o teclado recomeçava do topo.
let unsavedChangesTrigger = null;
const keepEditing = async () => {
  pendingLeave.value = null;
  showUnsavedChanges.value = false;
  await nextTick();
  unsavedChangesTrigger?.focus?.();
};
const discardChanges = () => {
  const leave = pendingLeave.value || (() => emit('close'));
  pendingLeave.value = null;
  showUnsavedChanges.value = false;
  leave();
};
const trapModalFocus = event => {
  if (event.key !== 'Tab') return;

  const focusableElements = [
    ...event.currentTarget.querySelectorAll(
      'button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [href]'
    ),
  ];
  if (!focusableElements.length) return;

  const firstElement = focusableElements[0];
  const lastElement = focusableElements[focusableElements.length - 1];

  if (event.shiftKey && document.activeElement === firstElement) {
    event.preventDefault();
    lastElement.focus();
  } else if (!event.shiftKey && document.activeElement === lastElement) {
    event.preventDefault();
    firstElement.focus();
  }
};

const handleModalKeydown = event => {
  trapModalFocus(event);

  if (event.key !== 'Escape' || !isFormDirty.value) return;

  event.preventDefault();
  event.stopPropagation();
  showUnsavedChanges.value = true;
};

const editSubject = async () => {
  isEditingSubject.value = true;
  await nextTick();
  headerSubjectInput.value?.focus();
};

defineExpose({ requestClose });

onMounted(() => {
  loadCard();
  loadLabels();
  loadTimeline();
  loadFinanceModule();
  // sem as definicoes carregadas o bloco de contato volta a mostrar
  // apenas os atributos que ja tinham valor
  store.dispatch('attributes/get');
});

// Financeiro e Formulários pedem dados ao servidor. Antes disparavam ao clicar
// na aba; agora disparam quando a secção da coluna da direita ABRE — e só na
// transição, para abrir/fechar duas vezes não valer duas chamadas.
watch(secoesAbertas, (agora, antes = []) => {
  const abriu = key => agora.includes(key) && !antes.includes(key);
  if (abriu('finance')) loadFinancePayments();
  if (abriu('forms')) loadFormsContext();
});

watch(showUnsavedChanges, async visible => {
  if (!visible) return;

  unsavedChangesTrigger = document.activeElement;
  await nextTick();
  keepEditingButton.value?.focus();
});

watch(invitationPendingRevocation, async invitation => {
  if (!invitation) return;

  await nextTick();
  formInvitationRevocationConfirmButton.value?.focus();
});
</script>

<template>
  <div
    class="relative"
    :class="
      drawerMode
        ? 'flex h-full max-h-full w-full flex-col overflow-hidden bg-n-background'
        : 'mx-auto flex max-h-[94vh] w-full max-w-[calc(100vw-1rem)] flex-col overflow-hidden rounded-xl bg-n-background 2xl:max-w-[88rem]'
    "
    @keydown="handleModalKeydown"
  >
    <div
      class="flex items-start justify-between gap-4 border-b border-n-weak px-5 py-3"
    >
      <div class="min-w-0">
        <!--
          O assunto da oportunidade nunca corta: quebra de palavra. É a manchete
          da gaveta e o AGENTS.md proíbe `truncate` aqui — cortar o título obriga
          a abrir para saber o que se está a ver.
        -->
        <h2
          class="mb-0 break-words text-xl font-semibold leading-snug tracking-tight text-n-slate-12"
        >
          <input
            v-show="isEditingSubject"
            ref="headerSubjectInput"
            v-model="subject"
            data-testid="kanban-opportunity-header-subject"
            class="w-full rounded-md border border-n-weak bg-n-surface-1 px-2 py-1 text-base font-semibold text-n-slate-12 outline-none focus:border-n-brand"
            @input="subjectError = ''"
            @blur="isEditingSubject = false"
            @keydown.enter.prevent="isEditingSubject = false"
          />
          <span v-show="!isEditingSubject">{{ headerTitle }}</span>
        </h2>
        <p v-if="subjectError" class="mb-1 text-xs text-n-ruby-11" role="alert">
          {{ subjectError }}
        </p>
        <div
          v-if="cardDisplayId"
          class="mt-1 flex flex-wrap items-center gap-2"
        >
          <span
            data-testid="kanban-opportunity-card-id"
            class="text-xs text-n-slate-11"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.CARD_ID', { id: cardDisplayId }) }}
          </span>
          <KanbanOpportunityPipelineMenu
            data-testid="kanban-opportunity-header-stage"
            :board-id="boardId"
            :board-name="boardName"
            :boards="boards"
            :stages="stages"
            :selected-stage-id="stageId"
            :stage-entered-at="stageEnteredAt"
            @select-stage="selectPipelineStage"
          />
          <div class="relative">
            <button
              ref="labelsTriggerRef"
              type="button"
              data-testid="kanban-opportunity-toggle-labels"
              class="flex h-7 items-center gap-1 rounded-md border border-solid border-n-weak bg-n-surface-1 px-2 text-xs font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
              :aria-expanded="showLabelsPopover"
              aria-controls="kanban-opportunity-labels-popover"
              @click="
                showLabelsPopover
                  ? closeLabelsPopover()
                  : (showLabelsPopover = true)
              "
            >
              <i class="i-lucide-tags size-3.5" />
              {{ t('KANBAN.OPPORTUNITY_DETAILS.LABELS') }}
              <span v-if="selectedLabelTitles.length" class="text-n-slate-10">
                {{ selectedLabelTitles.length }}
              </span>
            </button>
            <div
              v-if="showLabelsPopover"
              id="kanban-opportunity-labels-popover"
              ref="labelsPopoverRef"
              class="absolute left-0 z-30 mt-2 grid w-72 gap-3 rounded-lg border border-n-weak bg-n-solid-1 p-3 shadow-lg"
              @keydown.esc.stop.prevent="
                closeLabelsPopover();
                labelsTriggerRef?.focus();
              "
            >
              <div class="flex items-center justify-between gap-3">
                <span class="text-sm font-medium text-n-slate-12">
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.LABELS') }}
                </span>
                <button
                  type="button"
                  data-testid="kanban-opportunity-save-labels"
                  class="flex p-0 size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50"
                  :aria-label="
                    isSavingLabels
                      ? t('KANBAN.OPPORTUNITY_DETAILS.SAVING_LABELS')
                      : t('KANBAN.OPPORTUNITY_DETAILS.SAVE_LABELS')
                  "
                  :disabled="isSavingLabels"
                  @click="saveLabels"
                >
                  <i class="i-lucide-save size-4" />
                </button>
              </div>
              <p
                v-if="labelsLoadError || labelsSaveError"
                class="mb-0 text-xs text-n-ruby-11"
                role="alert"
              >
                {{ labelsLoadError || labelsSaveError }}
              </p>
              <RaevoField>
                <template #default="{ controlClass, fieldId }">
                  <input
                    :id="fieldId"
                    v-model="labelQuery"
                    type="search"
                    data-testid="kanban-opportunity-label-search"
                    :class="controlClass"
                    :placeholder="
                      canCreateLabels
                        ? t('KANBAN.OPPORTUNITY_DETAILS.LABEL_SEARCH_OR_CREATE')
                        : t('KANBAN.OPPORTUNITY_DETAILS.LABEL_SEARCH')
                    "
                    :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.LABEL_SEARCH')"
                    @keydown.enter.prevent="createLabel"
                  />
                </template>
              </RaevoField>
              <div
                v-if="filteredAccountLabels.length"
                data-testid="kanban-opportunity-labels"
                class="flex max-h-48 flex-wrap gap-1.5 overflow-y-auto"
              >
                <button
                  v-for="label in filteredAccountLabels"
                  :key="label.id || label.title"
                  type="button"
                  data-testid="kanban-opportunity-label"
                  class="flex items-center gap-1.5 rounded-full border border-solid px-2 py-1 text-xs font-medium transition"
                  :class="
                    selectedLabelTitleSet.has(label.title)
                      ? 'border-n-blue-9 bg-n-blue-3 text-n-blue-12'
                      : 'border-n-weak text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12'
                  "
                  :aria-pressed="selectedLabelTitleSet.has(label.title)"
                  @click="toggleLabel(label.title)"
                >
                  <span
                    class="size-2 rounded-full"
                    :style="{ backgroundColor: label.color }"
                  />
                  <span>{{ label.title }}</span>
                  <i
                    v-if="selectedLabelTitleSet.has(label.title)"
                    class="i-lucide-check size-3"
                  />
                </button>
              </div>
              <p
                v-else-if="!isLoadingLabels && !labelQueryIsNew"
                data-testid="kanban-opportunity-no-labels"
                class="mb-0 text-xs text-n-slate-11"
              >
                {{ t('KANBAN.OPPORTUNITY_DETAILS.NO_LABELS_AVAILABLE') }}
              </p>
              <template v-if="labelQueryIsNew">
                <button
                  v-if="canCreateLabels && labelTitleToCreate"
                  type="button"
                  data-testid="kanban-opportunity-create-label"
                  class="flex min-w-0 items-center gap-1.5 rounded-md px-2 py-1.5 text-start text-xs font-medium text-n-blue-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50"
                  :disabled="isCreatingLabel || isSavingLabels"
                  @click="createLabel"
                >
                  <i class="i-lucide-plus size-3.5 flex-shrink-0" />
                  <span class="truncate">
                    {{
                      t('KANBAN.OPPORTUNITY_DETAILS.CREATE_LABEL', {
                        title: labelTitleToCreate,
                      })
                    }}
                  </span>
                </button>
                <p
                  v-else-if="canCreateLabels"
                  data-testid="kanban-opportunity-label-invalid"
                  class="mb-0 flex items-start gap-1.5 text-xs text-n-slate-11"
                >
                  <i class="i-lucide-info mt-0.5 size-3.5 flex-shrink-0" />
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.LABEL_TITLE_RULE') }}
                </p>
                <p
                  v-else
                  data-testid="kanban-opportunity-label-admin-only"
                  class="mb-0 flex items-start gap-1.5 text-xs text-n-slate-11"
                >
                  <i class="i-lucide-lock mt-0.5 size-3.5 flex-shrink-0" />
                  {{ t('KANBAN.OPPORTUNITY_DETAILS.LABEL_CREATE_ADMIN_ONLY') }}
                </p>
              </template>
            </div>
          </div>
        </div>
      </div>
      <div class="flex flex-shrink-0 items-center gap-1">
        <button
          v-if="hasConversation && !embedded"
          type="button"
          data-testid="kanban-opportunity-header-open-conversation"
          class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.OPEN_CONVERSATION')"
          :title="t('KANBAN.OPPORTUNITY_DETAILS.OPEN_CONVERSATION')"
          @click="openConversation"
        >
          <i class="i-lucide-message-square size-4" />
        </button>
        <button
          type="button"
          data-testid="kanban-opportunity-edit-subject"
          class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.EDIT_TITLE')"
          :title="t('KANBAN.OPPORTUNITY_DETAILS.EDIT_TITLE')"
          @click="editSubject"
        >
          <i class="i-lucide-pencil size-4" />
        </button>
        <button
          v-if="canManageFields"
          type="button"
          data-testid="kanban-opportunity-manage-fields"
          class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.MANAGE_FIELDS')"
          :title="t('KANBAN.OPPORTUNITY_DETAILS.MANAGE_FIELDS')"
          @click="emit('manageFields')"
        >
          <i class="i-lucide-settings-2 size-4" />
        </button>
        <button
          v-if="!embedded"
          type="button"
          data-testid="kanban-opportunity-close"
          class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
          :aria-label="t('KANBAN.OPPORTUNITY_DETAILS.CLOSE')"
          @click="requestClose"
        >
          <i class="i-lucide-x size-4" />
        </button>
      </div>
    </div>

    <div class="min-h-0 flex-1 overflow-auto px-5 py-4">
      <p
        v-if="isLoading"
        data-testid="kanban-opportunity-loading"
        class="mb-0 text-sm text-n-slate-11"
      >
        {{ t('KANBAN.OPPORTUNITY_DETAILS.LOADING') }}
      </p>

      <p
        v-else-if="loadError"
        data-testid="kanban-opportunity-load-error"
        class="mb-0 text-sm text-n-ruby-11"
        role="alert"
      >
        {{ loadError }}
      </p>

      <form
        v-else-if="card"
        data-testid="kanban-opportunity-form"
        class="flex min-h-full flex-col gap-5"
        @submit.prevent="saveCard"
      >
        <!--
          A ficha é uma lista, como o painel de contacto do Chatwoot: cada secção
          abre e fecha, todas na mesma rolagem, rótulo em cima e valor em baixo.
          Sem abas e sem segunda coluna — decisão do Pedro na noite de 07/10,
          sobre a maquete https://claude.ai/artifact/Hq4UgCxH6DMcDRwdFGXpLS.
          A ordem é a do funil (Configurações › Campos › Ordem no painel): aqui
          não se reordena.
        -->
        <div
          data-testid="kanban-opportunity-layout"
          class="grid min-w-0 content-start gap-2"
        >
          <div
            v-for="secao in visibleSections"
            :key="secao"
            :data-testid="`kanban-opportunity-panel-section-${secao}`"
            class="overflow-hidden rounded-lg border border-solid border-n-weak bg-n-surface-1"
          >
            <button
              type="button"
              :data-testid="`kanban-opportunity-section-${secao}`"
              class="flex min-h-10 w-full items-center justify-between gap-2 px-3 py-2 text-start text-sm font-medium text-n-slate-12 outline-none hover:bg-n-alpha-1 focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-n-brand"
              :aria-expanded="isSectionOpen(secao)"
              @click="toggleSection(secao)"
            >
              <span class="min-w-0 break-words">{{ sectionLabel(secao) }}</span>
              <i
                aria-hidden="true"
                class="size-4 shrink-0 text-n-slate-11"
                :class="
                  isSectionOpen(secao) ? 'i-lucide-minus' : 'i-lucide-plus'
                "
              />
            </button>
            <div
              v-if="isSectionOpen(secao)"
              class="border-t border-solid border-n-weak px-3 pb-3 pt-2"
            >
              <template v-if="secao === 'next-action'">
                <section
                  data-testid="kanban-opportunity-next-action-section"
                  class="grid gap-2"
                >
                  <KanbanNextActionCompletion
                    v-if="etapaConclusao"
                    :step="etapaConclusao"
                    :action-label="acaoEmConclusao.label"
                    :action-note="acaoEmConclusao.note"
                    :action-type="acaoEmConclusao.type"
                    :type-options="nextActionTypeOptions"
                    :saving="isSaving"
                    :error="conclusaoErro"
                    @cancel="fecharConclusao"
                    @confirm="confirmarConclusao"
                    @save-next="salvarProximaAcao"
                    @skip-next="fecharConclusao"
                  />
                  <div
                    v-else-if="semProximaAcao"
                    data-testid="kanban-opportunity-next-action-empty"
                    class="grid justify-items-start gap-2"
                  >
                    <RaevoStamp
                      variant="warning"
                      :label="
                        t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.EMPTY')
                      "
                    />
                    <p class="mb-0 text-sm text-n-slate-11">
                      {{
                        t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.EMPTY_HINT')
                      }}
                    </p>
                    <NextButton
                      type="button"
                      sm
                      data-testid="kanban-opportunity-schedule-next-action"
                      :label="
                        t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_FLOW.SCHEDULE')
                      "
                      :disabled="isSaving"
                      @click="marcarProximaAcao"
                    />
                  </div>
                  <div
                    v-else-if="nextActionAt && !card.nextActionCompletedAt"
                    class="flex items-center justify-end gap-3"
                  >
                    <NextButton
                      v-if="nextActionAt && !card.nextActionCompletedAt"
                      type="button"
                      xs
                      outline
                      emerald
                      data-testid="kanban-opportunity-complete-next-action"
                      icon="i-lucide-check-check"
                      :label="
                        t('KANBAN.OPPORTUNITY_DETAILS.COMPLETE_NEXT_ACTION')
                      "
                      :disabled="isSaving"
                      @click="iniciarConclusao"
                    />
                  </div>
                  <div v-if="!etapaConclusao && !semProximaAcao" class="grid">
                    <div class="grid">
                      <RaevoFieldRow
                        stacked
                        row-testid="kanban-row-next-action-type"
                        :label="
                          t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_TYPE')
                        "
                        :value="nextActionTypeDisplay"
                        variant="select"
                      >
                        <template #control="{ controlClass, fieldId }">
                          <select
                            :id="fieldId"
                            v-model="nextActionType"
                            data-testid="kanban-opportunity-next-action-type"
                            :class="controlClass"
                          >
                            <option
                              v-for="option in nextActionTypeOptions"
                              :key="option.value || 'none'"
                              :value="option.value"
                            >
                              {{ option.label }}
                            </option>
                          </select>
                        </template>
                      </RaevoFieldRow>
                      <RaevoFieldRow
                        stacked
                        row-testid="kanban-row-next-action-at"
                        :label="t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_AT')"
                        :value="nextActionAtDisplay"
                      >
                        <template #control="{ controlClass, fieldId }">
                          <input
                            :id="fieldId"
                            v-model="nextActionAt"
                            type="datetime-local"
                            data-testid="kanban-opportunity-next-action-at"
                            :class="controlClass"
                          />
                        </template>
                      </RaevoFieldRow>
                    </div>
                    <RaevoFieldRow
                      stacked
                      row-testid="kanban-row-next-action-note"
                      :label="t('KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_NOTE')"
                      :value="nextActionNote"
                      variant="textarea"
                    >
                      <template #control="{ controlClass, fieldId }">
                        <textarea
                          :id="fieldId"
                          v-model="nextActionNote"
                          rows="2"
                          data-testid="kanban-opportunity-next-action-note"
                          :class="controlClass"
                          :placeholder="
                            t(
                              'KANBAN.OPPORTUNITY_DETAILS.NEXT_ACTION_NOTE_PLACEHOLDER'
                            )
                          "
                        />
                      </template>
                    </RaevoFieldRow>
                  </div>
                </section>
              </template>
              <RaevoAiOpportunityPanel
                v-else-if="secao === 'ai'"
                :fields="sectionDefinitions('ai')"
                :values="customFieldValues"
              />
              <template v-else-if="isFieldSection(secao)">
                <template v-if="secao === 'details'">
                  <section
                    v-if="selectedStageIsLost"
                    class="grid gap-2 rounded-lg border border-n-ruby-4 bg-n-ruby-2 p-3"
                  >
                    <label class="grid gap-1.5">
                      <span class="text-sm font-medium text-n-slate-12">
                        {{ t('KANBAN.OPPORTUNITY_DETAILS.LOST_REASON') }}
                      </span>
                      <select
                        v-model="lostReason"
                        data-testid="kanban-opportunity-lost-reason"
                        class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
                        @change="lostReasonError = ''"
                      >
                        <option value="">
                          {{
                            t(
                              'KANBAN.OPPORTUNITY_DETAILS.LOST_REASON_PLACEHOLDER'
                            )
                          }}
                        </option>
                        <option
                          v-for="option in selectableLostReasonOptions"
                          :key="option"
                          :value="option"
                        >
                          {{ option }}
                        </option>
                      </select>
                      <span
                        v-if="lostReasonError"
                        class="text-xs text-n-ruby-11"
                        role="alert"
                      >
                        {{ lostReasonError }}
                      </span>
                    </label>
                  </section>
                  <section
                    data-testid="kanban-opportunity-commercial-group"
                    class="grid"
                  >
                    <!--
                  Bloco achatado: cada campo era uma <section> com título de
                  pergunta e borda própria, o que gastava a altura do painel e
                  transformava o separador em textura. Agora é rótulo acima do
                  campo, na mesma borda esquerda, com um separador só por grupo.
                -->
                    <div class="grid py-2 first:pt-0">
                      <RaevoFieldRow
                        stacked
                        row-testid="kanban-row-owner"
                        :label="t('KANBAN.OPPORTUNITY_DETAILS.QUESTIONS.OWNER')"
                        :value="ownerDisplay"
                        variant="select"
                      >
                        <template #control="{ controlClass, fieldId }">
                          <select
                            :id="fieldId"
                            v-model="ownerId"
                            data-testid="kanban-opportunity-owner"
                            :class="controlClass"
                          >
                            <option value="">
                              {{ t('KANBAN.OPPORTUNITY_DETAILS.OWNER_NONE') }}
                            </option>
                            <option
                              v-for="option in ownerOptions"
                              :key="option.value"
                              :value="String(option.value)"
                            >
                              {{ option.label }}
                            </option>
                          </select>
                        </template>
                      </RaevoFieldRow>

                      <RaevoFieldRow
                        stacked
                        row-testid="kanban-row-description"
                        :label="
                          t('KANBAN.OPPORTUNITY_DETAILS.QUESTIONS.AGREEMENT')
                        "
                        :value="description"
                        variant="textarea"
                      >
                        <template #control="{ controlClass, fieldId }">
                          <textarea
                            :id="fieldId"
                            v-model="description"
                            rows="3"
                            data-testid="kanban-opportunity-description"
                            :class="controlClass"
                            :placeholder="
                              t(
                                'KANBAN.OPPORTUNITY_DETAILS.DESCRIPTION_PLACEHOLDER'
                              )
                            "
                          />
                        </template>
                      </RaevoFieldRow>

                      <div class="grid">
                        <RaevoFieldRow
                          stacked
                          row-testid="kanban-row-amount"
                          :label="t('KANBAN.OPPORTUNITY_DETAILS.FIELD_AMOUNT')"
                          :value="amountDisplay"
                          :hint="
                            t('KANBAN.OPPORTUNITY_DETAILS.FIELD_AMOUNT_HINT')
                          "
                        >
                          <template #control="{ controlClass, fieldId }">
                            <input
                              :id="fieldId"
                              v-model="amountValue"
                              data-testid="kanban-opportunity-amount"
                              type="number"
                              min="0"
                              step="0.01"
                              :class="controlClass"
                            />
                          </template>
                        </RaevoFieldRow>
                        <RaevoFieldRow
                          stacked
                          row-testid="kanban-row-expected-close-date"
                          :label="
                            t('KANBAN.OPPORTUNITY_DETAILS.EXPECTED_CLOSE_DATE')
                          "
                          :value="expectedCloseDateDisplay"
                        >
                          <template #control="{ controlClass, fieldId }">
                            <input
                              :id="fieldId"
                              v-model="expectedCloseDate"
                              data-testid="kanban-opportunity-expected-close-date"
                              type="date"
                              :class="controlClass"
                            />
                          </template>
                        </RaevoFieldRow>
                      </div>
                    </div>
                  </section>
                </template>
                <section
                  v-if="sectionGroups(secao).length"
                  :data-testid="`kanban-opportunity-custom-fields-${secao}`"
                  class="grid"
                >
                  <div class="grid">
                    <section
                      v-for="group in sectionGroups(secao)"
                      v-show="shownDefinitions(secao, group).length"
                      :key="group.key"
                      class="grid gap-2 border-b border-n-weak py-3 first:pt-0 last:border-b-0 last:pb-0"
                      :class="
                        group.label
                          ? [
                              'border-l-2 pl-3',
                              customFieldGroupClass(group.color),
                            ]
                          : ''
                      "
                    >
                      <button
                        v-if="group.label"
                        type="button"
                        class="flex items-center justify-between gap-3 text-left"
                        :aria-expanded="
                          isGroupExpanded(groupToggleKey(secao, group.key))
                        "
                        @click="toggleGroup(groupToggleKey(secao, group.key))"
                      >
                        <span class="text-sm font-semibold text-n-slate-12">
                          {{ group.label }}
                        </span>
                        <i
                          class="size-4 text-n-slate-10"
                          :class="
                            isGroupExpanded(groupToggleKey(secao, group.key))
                              ? 'i-lucide-chevron-up'
                              : 'i-lucide-chevron-down'
                          "
                        />
                      </button>
                      <div
                        v-show="
                          !group.label ||
                          isGroupExpanded(groupToggleKey(secao, group.key))
                        "
                        class="grid"
                      >
                        <!--
                      Uma linha só, em todo o painel. Os campos personalizados
                      desenhavam a sua própria — rótulo de 9rem, outro
                      espaçamento, sempre em edição — enquanto os nativos usavam
                      o `RaevoFieldRow`. Passam ao mesmo componente, e com ele
                      ganham o mesmo repouso e a mesma entrada em edição.
                    -->
                        <RaevoFieldRow
                          v-for="definition in shownDefinitions(secao, group)"
                          :key="definition.key"
                          stacked
                          :row-testid="`kanban-row-${definition.key}`"
                          :label="definition.label"
                          :value="customFieldDisplayValue(definition)"
                          :hint="requiredFieldHint(definition)"
                          hint-at-rest
                          :error="requiredFieldError(definition)"
                          :variant="customFieldRowVariant(definition)"
                        >
                          <template #control="{ controlClass, fieldId }">
                            <select
                              v-if="definition.fieldType === 'select'"
                              :id="fieldId"
                              :value="getCustomFieldValue(definition)"
                              :data-testid="`kanban-custom-field-${definition.key}`"
                              :class="controlClass"
                              :aria-label="definition.label"
                              @change="
                                setCustomFieldValue(
                                  definition,
                                  $event.target.value
                                )
                              "
                            >
                              <!--
                              A opção vazia mostrava o rótulo do campo, e a linha
                              lia-se «Consulta realizada? | Consulta realizada?» —
                              impossível distinguir por preencher de preenchido.
                            -->
                              <option value="">
                                {{
                                  t('KANBAN.OPPORTUNITY_DETAILS.FIELD_EMPTY')
                                }}
                              </option>
                              <option
                                v-for="option in definition.options || []"
                                :key="option"
                                :value="option"
                              >
                                {{ option }}
                              </option>
                            </select>

                            <select
                              v-else-if="definition.fieldType === 'multiselect'"
                              :id="fieldId"
                              multiple
                              :value="getCustomFieldValue(definition)"
                              :data-testid="`kanban-custom-field-${definition.key}`"
                              :class="controlClass"
                              :aria-label="definition.label"
                              @change="
                                setCustomFieldValue(
                                  definition,
                                  selectedMultiselectValues($event)
                                )
                              "
                            >
                              <option
                                v-for="option in definition.options || []"
                                :key="option"
                                :value="option"
                              >
                                {{ option }}
                              </option>
                            </select>

                            <textarea
                              v-else-if="definition.fieldType === 'textarea'"
                              :id="fieldId"
                              :value="getCustomFieldValue(definition)"
                              rows="3"
                              :data-testid="`kanban-custom-field-${definition.key}`"
                              :class="controlClass"
                              :aria-label="definition.label"
                              @input="
                                setCustomFieldValue(
                                  definition,
                                  $event.target.value
                                )
                              "
                            />

                            <input
                              v-else-if="definition.fieldType === 'boolean'"
                              :id="fieldId"
                              type="checkbox"
                              :checked="
                                Boolean(getCustomFieldValue(definition))
                              "
                              :data-testid="`kanban-custom-field-${definition.key}`"
                              class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                              :aria-label="definition.label"
                              @change="
                                setCustomFieldValue(
                                  definition,
                                  $event.target.checked
                                )
                              "
                            />

                            <input
                              v-else
                              :id="fieldId"
                              :value="getCustomFieldValue(definition)"
                              :type="
                                definition.fieldType === 'integer' ||
                                definition.fieldType === 'decimal' ||
                                definition.fieldType === 'currency' ||
                                definition.fieldType === 'formula'
                                  ? 'number'
                                  : definition.fieldType === 'date'
                                    ? 'date'
                                    : definition.fieldType === 'datetime'
                                      ? 'datetime-local'
                                      : definition.fieldType === 'url'
                                        ? 'url'
                                        : 'text'
                              "
                              :step="
                                definition.fieldType === 'decimal'
                                  ? '0.01'
                                  : undefined
                              "
                              :disabled="definition.fieldType === 'formula'"
                              :data-testid="`kanban-custom-field-${definition.key}`"
                              :class="controlClass"
                              :aria-label="definition.label"
                              @input="
                                setCustomFieldValue(
                                  definition,
                                  $event.target.value
                                )
                              "
                            />
                          </template>
                        </RaevoFieldRow>
                      </div>
                    </section>
                  </div>
                </section>
                <button
                  v-if="hiddenFieldCount(secao)"
                  type="button"
                  :data-testid="`kanban-opportunity-show-more-${secao}`"
                  class="mt-1 h-7 rounded-lg px-2 text-xs font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand"
                  :aria-expanded="isShowingAllFields(secao)"
                  @click="toggleAllFields(secao)"
                >
                  {{
                    isShowingAllFields(secao)
                      ? t('KANBAN.OPPORTUNITY_DETAILS.SHOW_FEWER_FIELDS')
                      : t('KANBAN.OPPORTUNITY_DETAILS.SHOW_MORE_FIELDS', {
                          count: hiddenFieldCount(secao),
                        })
                  }}
                </button>
              </template>
              <template v-else-if="secao === 'contact-details'">
                <section
                  v-if="isSectionOpen('contact-details')"
                  data-testid="kanban-opportunity-contact-details"
                  class="grid gap-4"
                >
                  <section class="grid gap-3 border-b border-n-weak pb-4">
                    <div class="flex items-center justify-between gap-3">
                      <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                        {{ t('KANBAN.OPPORTUNITY_DETAILS.CONTACT') }}
                      </h3>
                      <button
                        type="button"
                        data-testid="kanban-opportunity-save-contact"
                        class="flex p-0 size-8 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40 disabled:cursor-not-allowed disabled:opacity-50"
                        :disabled="isSavingContact || !card.contact?.id"
                        :aria-label="
                          t('KANBAN.OPPORTUNITY_DETAILS.SAVE_CONTACT')
                        "
                        :title="t('KANBAN.OPPORTUNITY_DETAILS.SAVE_CONTACT')"
                        @click="saveContact"
                      >
                        <i class="i-lucide-save size-4" />
                      </button>
                    </div>
                    <div class="grid gap-1">
                      <!--
                        O rótulo vivia só no placeholder: assim que o campo era
                        preenchido, deixava de haver forma de saber o que ele era.
                        Passa à mesma linha dos campos personalizados — rótulo à
                        esquerda, controlo à direita — para o diálogo deixar de ter
                        três tratamentos de campo.
                      -->
                      <RaevoFieldRow
                        v-for="detail in contactDetails"
                        :key="detail.key"
                        stacked
                        :row-testid="`kanban-row-contact-${detail.key}`"
                        :label="detail.label"
                        :value="detail.value || ''"
                      >
                        <template #control="{ controlClass, fieldId }">
                          <input
                            v-if="detail.key === 'name'"
                            :id="fieldId"
                            v-model="contactDraft.name"
                            data-testid="kanban-opportunity-contact-name"
                            type="text"
                            :class="controlClass"
                            :aria-label="detail.label"
                          />
                          <input
                            v-else-if="detail.key === 'phone'"
                            :id="fieldId"
                            v-model="contactDraft.phone_number"
                            data-testid="kanban-opportunity-contact-phone"
                            type="tel"
                            :class="controlClass"
                            :aria-label="detail.label"
                          />
                          <input
                            v-else-if="detail.key === 'email'"
                            :id="fieldId"
                            v-model="contactDraft.email"
                            data-testid="kanban-opportunity-contact-email"
                            type="email"
                            :class="controlClass"
                            :aria-label="detail.label"
                          />
                          <input
                            v-else
                            :id="fieldId"
                            v-model="contactDraft.identifier"
                            data-testid="kanban-opportunity-contact-identifier"
                            type="text"
                            :class="controlClass"
                            :aria-label="detail.label"
                          />
                        </template>
                      </RaevoFieldRow>
                    </div>
                    <p
                      v-if="contactSaveError"
                      class="mb-0 text-xs text-n-ruby-11"
                      role="alert"
                    >
                      {{ contactSaveError }}
                    </p>
                    <!--
                      Etiquetas do contato, não da oportunidade. Chegam do WhatsApp
                      e valem para a pessoa em qualquer negócio; por isso são só de
                      leitura aqui — quem as edita é o WhatsApp ou a ficha do
                      contato. As da oportunidade vivem no botão do cabeçalho.
                    -->
                    <div v-if="contactLabels.length" class="grid gap-2">
                      <h4
                        class="mb-0 text-xs font-medium leading-4 text-n-slate-11"
                      >
                        {{ t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_LABELS') }}
                      </h4>
                      <div
                        class="flex flex-wrap gap-1.5"
                        data-testid="kanban-opportunity-contact-labels"
                      >
                        <Label
                          v-for="label in contactLabels"
                          :key="label.title"
                          :label="label"
                          compact
                        />
                      </div>
                    </div>
                  </section>
                  <section
                    v-if="visibleContactAttributes.length"
                    class="grid gap-3 border-b border-n-weak py-4 last:border-b-0"
                  >
                    <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                      {{ t('KANBAN.OPPORTUNITY_DETAILS.CONTACT_ATTRIBUTES') }}
                    </h3>
                    <div
                      v-if="visibleContactAttributes.length"
                      class="grid gap-1"
                    >
                      <RaevoFieldRow
                        v-for="entry in visibleContactAttributes"
                        :key="`${entry.source}-${entry.key}`"
                        stacked
                        :row-testid="`kanban-row-attr-${entry.key}`"
                        :label="entry.label"
                        :value="formatContactAttributeValue(entry.value)"
                      >
                        <template #control="{ controlClass, fieldId }">
                          <select
                            v-if="entry.displayType === 'list'"
                            :id="fieldId"
                            :value="entry.value ?? ''"
                            :class="controlClass"
                            :aria-label="entry.label"
                            @change="
                              setContactAttributeValue(
                                entry,
                                $event.target.value
                              )
                            "
                          >
                            <option value="">
                              {{
                                t('KANBAN.OPPORTUNITY_DETAILS.ATTRIBUTE_EMPTY')
                              }}
                            </option>
                            <option
                              v-for="option in entry.options"
                              :key="option"
                              :value="option"
                            >
                              {{ option }}
                            </option>
                          </select>
                          <!--
                            O rótulo ao lado já nomeia o campo. Repeti-lo aqui
                            desenhava o mesmo texto duas vezes na mesma linha.
                          -->
                          <span
                            v-else-if="entry.displayType === 'checkbox'"
                            class="flex h-10 items-center"
                          >
                            <input
                              :id="fieldId"
                              :checked="entry.value === true"
                              type="checkbox"
                              class="size-4 rounded border-n-weak text-n-brand focus:ring-n-brand"
                              @change="
                                setContactAttributeValue(
                                  entry,
                                  $event.target.checked
                                )
                              "
                            />
                          </span>
                          <input
                            v-else
                            :id="fieldId"
                            :value="entry.value ?? ''"
                            :type="
                              entry.displayType === 'date' ? 'date' : 'text'
                            "
                            :class="controlClass"
                            :aria-label="entry.label"
                            @input="
                              setContactAttributeValue(
                                entry,
                                $event.target.value
                              )
                            "
                          />
                        </template>
                      </RaevoFieldRow>
                    </div>
                  </section>
                </section>
              </template>
              <template v-else-if="secao === 'calendar'">
                <KanbanCalendarAppointmentsSection
                  v-if="isSectionOpen('calendar')"
                  :card-id="card.id"
                  :contact-id="card.contact?.id"
                  :contact-name="contactName"
                  :booking-stage="
                    calendarBookingStageIds
                      .map(Number)
                      .includes(Number(stageId))
                  "
                  :allowed-procedure-ids="calendarProcedureIds"
                />
              </template>
              <template v-else-if="secao === 'finance'">
                <section
                  v-if="isSectionOpen('finance')"
                  data-testid="kanban-opportunity-finance"
                  class="grid gap-3"
                >
                  <div
                    class="flex items-start justify-between gap-3 border-b border-n-weak pb-3"
                  >
                    <div>
                      <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                        {{ t('FINANCE.PAYMENTS.TITLE') }}
                      </h3>
                      <p class="mb-0 mt-1 text-xs text-n-slate-11">
                        {{ t('FINANCE.PAYMENTS.DESCRIPTION') }}
                      </p>
                    </div>
                    <NextButton
                      v-if="
                        canCreateFinancePayment &&
                        connectedFinanceConnections.length
                      "
                      type="button"
                      sm
                      :label="t('FINANCE.PAYMENTS.CREATE')"
                      data-testid="kanban-opportunity-new-payment"
                      @click="openFinancePaymentDialog"
                    />
                  </div>

                  <dl
                    class="grid gap-3 rounded-md bg-n-alpha-2 p-3 sm:grid-cols-3"
                    data-testid="kanban-opportunity-finance-summary"
                  >
                    <div class="min-w-0">
                      <dt class="text-xs font-medium text-n-slate-10">
                        {{ t('FINANCE.SUMMARY.STATUS') }}
                      </dt>
                      <dd
                        class="mb-0 mt-1 truncate text-sm font-semibold text-n-slate-12"
                      >
                        {{ financeStatusLabel(financeSummary.status) }}
                      </dd>
                    </div>
                    <div class="min-w-0">
                      <dt class="text-xs font-medium text-n-slate-10">
                        {{ t('FINANCE.SUMMARY.RECEIVED_AMOUNT') }}
                      </dt>
                      <dd
                        class="mb-0 mt-1 truncate text-sm font-semibold text-n-slate-12"
                      >
                        {{
                          formatFinanceAmount(
                            financeSummary.receivedCents,
                            financeSummary.currency
                          )
                        }}
                      </dd>
                    </div>
                    <div class="min-w-0">
                      <dt class="text-xs font-medium text-n-slate-10">
                        {{ t('FINANCE.SUMMARY.LAST_RECEIVED_AT') }}
                      </dt>
                      <dd
                        class="mb-0 mt-1 truncate text-sm font-semibold text-n-slate-12"
                      >
                        {{ formatFinanceDate(financeSummary.latestReceivedAt) }}
                      </dd>
                    </div>
                  </dl>

                  <p
                    v-if="isLoadingFinance"
                    class="mb-0 text-sm text-n-slate-11"
                  >
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.LOADING') }}
                  </p>
                  <p
                    v-else-if="financeError"
                    class="mb-0 text-sm text-n-ruby-11"
                    role="alert"
                  >
                    {{ financeError }}
                  </p>
                  <p
                    v-else-if="financePayments.length === 0"
                    class="mb-0 text-sm text-n-slate-11"
                  >
                    {{ t('FINANCE.PAYMENTS.EMPTY') }}
                  </p>
                  <div v-else class="grid divide-y divide-n-weak">
                    <article
                      v-for="payment in financePayments"
                      :key="payment.id"
                      class="grid gap-2 py-3 sm:grid-cols-[minmax(0,1fr)_auto_auto] sm:items-center sm:gap-4"
                    >
                      <div class="min-w-0">
                        <p
                          class="mb-0 break-words text-sm font-medium text-n-slate-12"
                        >
                          {{
                            payment.description || t('FINANCE.PAYMENTS.TITLE')
                          }}
                        </p>
                        <p class="mb-0 mt-1 text-xs text-n-slate-11">
                          {{
                            payment.due_on || t('FINANCE.PAYMENTS.NO_DUE_DATE')
                          }}
                        </p>
                      </div>
                      <span class="text-sm font-semibold text-n-slate-12">
                        {{ (payment.amount_cents / 100).toFixed(2) }}
                        {{ payment.currency }}
                      </span>
                      <div class="flex items-center gap-2">
                        <button
                          type="button"
                          data-testid="kanban-opportunity-payment-details"
                          class="flex p-0 size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                          :aria-label="t('FINANCE.PAYMENTS.DETAIL.OPEN')"
                          :title="t('FINANCE.PAYMENTS.DETAIL.OPEN')"
                          @click="openFinancePaymentDetails(payment)"
                        >
                          <i class="i-lucide-history size-4" />
                        </button>
                        <a
                          v-if="payment.invoice_url"
                          :href="payment.invoice_url"
                          target="_blank"
                          rel="noopener noreferrer"
                          class="text-sm font-medium text-n-brand outline-none hover:underline focus:ring-2 focus:ring-n-brand/40"
                        >
                          {{ t('FINANCE.PAYMENTS.OPEN_LINK') }}
                        </a>
                        <button
                          v-if="payment.invoice_url"
                          type="button"
                          data-testid="kanban-opportunity-copy-payment-link"
                          class="flex p-0 size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                          :aria-label="
                            copiedFinancePaymentId === payment.id
                              ? t('FINANCE.PAYMENTS.COPIED')
                              : t('FINANCE.PAYMENTS.COPY_LINK')
                          "
                          :title="
                            copiedFinancePaymentId === payment.id
                              ? t('FINANCE.PAYMENTS.COPIED')
                              : t('FINANCE.PAYMENTS.COPY_LINK')
                          "
                          @click="copyFinancePaymentLink(payment)"
                        >
                          <i
                            class="size-4"
                            :class="
                              copiedFinancePaymentId === payment.id
                                ? 'i-lucide-check'
                                : 'i-lucide-copy'
                            "
                          />
                        </button>
                        <button
                          v-if="hasConversation && payment.invoice_url"
                          type="button"
                          data-testid="kanban-opportunity-send-payment-link"
                          class="flex p-0 size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-alpha-2 hover:text-n-slate-12 focus:ring-2 focus:ring-n-brand/40"
                          :aria-label="
                            t('FINANCE.PAYMENTS.SEND_TO_CONVERSATION')
                          "
                          :title="t('FINANCE.PAYMENTS.SEND_TO_CONVERSATION')"
                          @click="sendFinancePaymentLink(payment)"
                        >
                          <i class="i-lucide-send size-4" />
                        </button>
                      </div>
                    </article>
                  </div>
                </section>
              </template>
              <template v-else-if="secao === 'forms'">
                <section
                  v-if="isSectionOpen('forms')"
                  data-testid="kanban-opportunity-forms"
                  class="grid gap-3"
                >
                  <div
                    class="flex items-start justify-between gap-3 border-b border-n-weak pb-3"
                  >
                    <div>
                      <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
                        {{ t('FORMS.TITLE') }}
                      </h3>
                      <p class="mb-0 mt-1 text-xs text-n-slate-11">
                        {{ t('FORMS.INVITATION.DESCRIPTION') }}
                      </p>
                    </div>
                    <NextButton
                      type="button"
                      sm
                      :label="t('FORMS.INVITATION.OPEN')"
                      data-testid="kanban-opportunity-send-form"
                      @click="openFormsInvitationDialog"
                    />
                  </div>
                  <p
                    v-if="formsContextError"
                    role="alert"
                    class="mb-0 rounded border border-n-ruby-6 bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
                  >
                    {{ formsContextError }}
                  </p>
                  <p
                    v-else-if="isLoadingFormsContext"
                    class="mb-0 text-sm text-n-slate-11"
                  >
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.LOADING') }}
                  </p>
                  <template v-else>
                    <section
                      v-if="formsContext.invitations.length"
                      class="grid gap-2"
                    >
                      <h4
                        class="mb-0 text-xs font-semibold uppercase tracking-wide text-n-slate-10"
                      >
                        {{ t('FORMS.INVITATION.HISTORY') }}
                      </h4>
                      <article
                        v-for="invitation in formsContext.invitations"
                        :key="invitation.id"
                        class="flex items-center justify-between gap-3 rounded border border-n-weak px-3 py-2"
                      >
                        <div class="min-w-0">
                          <p
                            class="mb-0 break-words text-sm font-medium text-n-slate-12"
                          >
                            {{ invitation.form_name }}
                          </p>
                          <p class="mb-0 mt-0.5 text-xs text-n-slate-10">
                            {{
                              t('FORMS.INVITATION.USES', {
                                used: invitation.uses_count,
                                total: invitation.max_uses,
                              })
                            }}
                          </p>
                          <p
                            v-if="invitation.created_at"
                            class="mb-0 mt-0.5 text-xs text-n-slate-10"
                          >
                            {{
                              t('FORMS.INVITATION.CREATED_AT', {
                                date: formatFormInvitationDate(
                                  invitation.created_at
                                ),
                              })
                            }}
                          </p>
                          <p
                            v-if="invitation.expires_at"
                            class="mb-0 mt-0.5 text-xs text-n-slate-10"
                          >
                            {{
                              t('FORMS.INVITATION.EXPIRES_ON', {
                                date: formatFormInvitationDate(
                                  invitation.expires_at
                                ),
                              })
                            }}
                          </p>
                          <p
                            v-if="invitation.sent_at"
                            class="mb-0 mt-0.5 text-xs text-n-slate-10"
                          >
                            {{
                              t('FORMS.INVITATION.SENT_AT', {
                                date: formatFormInvitationDate(
                                  invitation.sent_at
                                ),
                              })
                            }}
                          </p>
                          <p
                            v-if="invitation.opened_at"
                            class="mb-0 mt-0.5 text-xs text-n-slate-10"
                          >
                            {{
                              t('FORMS.INVITATION.OPENED_AT', {
                                date: formatFormInvitationDate(
                                  invitation.opened_at
                                ),
                              })
                            }}
                          </p>
                          <p
                            v-if="invitation.completed_at"
                            class="mb-0 mt-0.5 text-xs text-n-slate-10"
                          >
                            {{
                              t('FORMS.INVITATION.COMPLETED_AT', {
                                date: formatFormInvitationDate(
                                  invitation.completed_at
                                ),
                              })
                            }}
                          </p>
                        </div>
                        <div class="flex shrink-0 items-center gap-1">
                          <span
                            :data-testid="`kanban-opportunity-form-invitation-status-${invitation.id}`"
                            class="text-xs text-n-slate-11"
                          >
                            {{ formInvitationStatusLabel(invitation.status) }}
                          </span>
                          <button
                            v-if="
                              canCreateFormInvitation &&
                              invitation.status === 'active'
                            "
                            type="button"
                            :data-testid="`kanban-opportunity-revoke-form-invitation-${invitation.id}`"
                            class="flex p-0 size-7 items-center justify-center rounded-md text-n-slate-11 outline-none hover:bg-n-ruby-3 hover:text-n-ruby-11 focus:ring-2 focus:ring-n-ruby-8"
                            :aria-label="t('FORMS.INVITATION.REVOKE')"
                            :title="t('FORMS.INVITATION.REVOKE')"
                            @click="requestFormInvitationRevocation(invitation)"
                          >
                            <i class="i-lucide-ban size-3.5" />
                          </button>
                        </div>
                      </article>
                    </section>
                    <section
                      v-if="formsContext.submissions.length"
                      class="grid gap-2"
                    >
                      <h4
                        class="mb-0 text-xs font-semibold uppercase tracking-wide text-n-slate-10"
                      >
                        {{ t('FORMS.SUBMISSIONS.HISTORY') }}
                      </h4>
                      <KanbanFormSubmissionRow
                        v-for="submission in formsContext.submissions"
                        :key="submission.id"
                        :submission="submission"
                        :resolving-action="resolvingAction"
                        :pending-action-error="pendingActionError"
                        @open="openFormsSubmission"
                        @resolve="onResolvePendingAction"
                      />
                    </section>
                    <!--
                        O que a pessoa respondeu noutras oportunidades e continua a
                        valer para ela. Separado de propósito: são formulários do
                        doente, não deste negócio.
                      -->
                    <section
                      v-if="formsContext.contact_submissions?.length"
                      data-testid="kanban-opportunity-contact-forms"
                      class="grid gap-2"
                    >
                      <h4
                        class="mb-0 text-xs font-semibold uppercase tracking-wide text-n-slate-10"
                      >
                        {{ t('FORMS.SUBMISSIONS.CONTACT_HISTORY') }}
                      </h4>
                      <p class="mb-0 text-xs text-n-slate-10">
                        {{ t('FORMS.SUBMISSIONS.CONTACT_HISTORY_HINT') }}
                      </p>
                      <KanbanFormSubmissionRow
                        v-for="submission in formsContext.contact_submissions"
                        :key="submission.id"
                        :submission="submission"
                        :resolving-action="resolvingAction"
                        :pending-action-error="pendingActionError"
                        @open="openFormsSubmission"
                        @resolve="onResolvePendingAction"
                      />
                    </section>
                    <p
                      v-if="
                        !formsContext.invitations.length &&
                        !formsContext.submissions.length &&
                        !formsContext.contact_submissions?.length
                      "
                      class="mb-0 text-sm text-n-slate-10"
                    >
                      {{ t('FORMS.INVITATION.HISTORY_EMPTY') }}
                    </p>
                  </template>
                </section>
              </template>
              <template v-else-if="secao === 'timeline'">
                <section
                  v-if="isSectionOpen('timeline')"
                  data-testid="kanban-opportunity-timeline"
                  class="grid gap-3"
                >
                  <KanbanActionHistory
                    :history="card.nextActionHistory || []"
                    :created-at="card.created_at"
                    :won-at="card.won_at"
                    :lost-at="card.lost_at"
                  />
                  <h4
                    class="mb-0 border-t border-solid border-n-weak pt-3 text-xs font-medium text-n-slate-11"
                  >
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.CHANGES') }}
                  </h4>
                  <p
                    v-if="isLoadingTimeline"
                    class="mb-0 text-sm text-n-slate-11"
                  >
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.LOADING') }}
                  </p>
                  <p
                    v-else-if="timelineError"
                    class="mb-0 text-sm text-n-ruby-11"
                    role="alert"
                  >
                    {{ timelineError }}
                  </p>
                  <p
                    v-else-if="alteracoesItems.length === 0"
                    class="mb-0 text-sm text-n-slate-11"
                  >
                    {{ t('KANBAN.OPPORTUNITY_DETAILS.TIMELINE.EMPTY') }}
                  </p>
                  <template v-else>
                    <RaevoTimeline :items="alteracoesItems">
                      <template #extra="{ item }">
                        <span
                          v-for="change in item.changes"
                          :key="change.key"
                          data-testid="kanban-opportunity-timeline-change"
                          class="text-xs text-n-slate-10"
                        >
                          {{ change.transition }}
                        </span>
                        <span
                          v-for="automation in item.automations"
                          :key="automation.id"
                          class="mt-1 grid gap-1 rounded-md bg-n-surface-2 px-2 py-1.5 text-xs text-n-slate-10"
                        >
                          <span class="font-medium text-n-slate-12">
                            {{ automation.rule_name }}
                          </span>
                          <span>
                            {{ automation.status }}
                            <template v-if="automation.scheduled_at">
                              {{
                                ` - ${new Date(
                                  automation.scheduled_at
                                ).toLocaleString()}`
                              }}
                            </template>
                          </span>
                          <span
                            v-if="automation.error_message"
                            class="text-n-ruby-11"
                          >
                            {{ automation.error_message }}
                          </span>
                        </span>
                      </template>
                    </RaevoTimeline>
                  </template>
                </section>
              </template>
            </div>
          </div>
        </div>

        <p
          v-if="saveError"
          data-testid="kanban-opportunity-save-error"
          class="mb-0 text-sm text-n-ruby-11"
          role="alert"
        >
          {{ saveError }}
        </p>

        <!--
          Só aparece com alterações por salvar: desfazer a edição esconde-a de novo.
          `mt-auto` prende-a ao fundo do painel: presa ao fim do conteúdo, subia
          quando o campo em edição fechava ao perder o foco, e o clique em Salvar
          caía no vazio.
        -->
        <div
          v-if="isFormDirty || isSaving"
          data-testid="kanban-opportunity-save-bar"
          class="sticky bottom-0 z-20 -mx-1 mt-auto flex items-center justify-end gap-3 border-t border-n-weak bg-n-background px-1 pb-4 pt-4"
        >
          <NextButton
            type="button"
            outline
            slate
            sm
            data-testid="kanban-opportunity-cancel"
            :label="t('KANBAN.OPPORTUNITY_DETAILS.CANCEL')"
            @click="requestClose"
          />
          <NextButton
            type="submit"
            sm
            data-testid="kanban-opportunity-save"
            icon="i-lucide-save"
            :label="
              isSaving
                ? t('KANBAN.OPPORTUNITY_DETAILS.SAVING')
                : t('KANBAN.OPPORTUNITY_DETAILS.SAVE')
            "
            :disabled="isSaving"
            :is-loading="isSaving"
          />
        </div>
      </form>
    </div>

    <FinancePaymentDialog
      v-if="financeEnabled && card"
      ref="paymentDialog"
      :connections="financeConnections"
      :contact="card.contact"
      :kanban-card-id="card.id"
      :market="financeModule.market"
      @created="addFinancePayment"
    />
    <FinancePaymentDetailsDialog
      v-if="financeEnabled && card"
      ref="paymentDetailsDialog"
      :can-manage="canManageFinancePayments"
      :can-refund="canRefundFinancePayments"
      @canceled="updateFinancePayment"
      @received="updateFinancePayment"
      @refund-requested="updateFinancePayment"
    />
    <FormsInvitationDialog
      v-if="isSectionOpen('forms') && canCreateFormInvitation && card?.contact"
      ref="formsInvitationDialog"
      :contact="card.contact"
      :kanban-card-id="card.id"
      :can-send-to-conversation="hasConversation"
      @created="loadFormsContext"
      @send="sendFormsInvitationLink"
    />
    <FormsSubmissionDetailsDialog
      v-if="isSectionOpen('forms')"
      ref="formsSubmissionDialog"
    />
    <div
      v-if="invitationPendingRevocation"
      class="absolute inset-0 z-20 grid place-items-center bg-black/20 p-4"
      role="presentation"
    >
      <section
        class="grid w-full max-w-sm gap-4 rounded-lg border border-n-weak bg-n-solid-1 p-5 shadow-lg"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="kanban-form-invitation-revoke-title"
        @keydown.stop="trapModalFocus"
      >
        <div>
          <h3
            id="kanban-form-invitation-revoke-title"
            class="mb-1 text-base font-semibold text-n-slate-12"
          >
            {{ t('FORMS.INVITATION.REVOKE_TITLE') }}
          </h3>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t('FORMS.INVITATION.REVOKE_DESCRIPTION') }}
          </p>
        </div>
        <div class="flex justify-end gap-2">
          <button
            type="button"
            data-testid="kanban-opportunity-cancel-form-invitation-revocation"
            class="rounded-md px-3 py-2 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            :disabled="isRevokingFormInvitation"
            @click="invitationPendingRevocation = null"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.CANCEL') }}
          </button>
          <button
            ref="formInvitationRevocationConfirmButton"
            type="button"
            data-testid="form-invitation-revoke-confirm"
            class="rounded-md bg-n-ruby-9 px-3 py-2 text-sm font-medium text-n-solid-1 outline-none hover:bg-n-ruby-10 focus:ring-2 focus:ring-n-ruby-8 disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="isRevokingFormInvitation"
            @click="revokeFormInvitation"
          >
            {{ t('FORMS.INVITATION.REVOKE') }}
          </button>
        </div>
      </section>
    </div>

    <div
      v-if="showUnsavedChanges"
      data-testid="kanban-opportunity-unsaved-changes"
      class="absolute inset-0 z-20 grid place-items-center bg-black/20 p-4"
      role="presentation"
    >
      <section
        class="grid w-full max-w-sm gap-4 rounded-lg border border-n-weak bg-n-solid-1 p-5 shadow-lg"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="kanban-unsaved-title"
        @keydown.stop="trapModalFocus"
      >
        <div>
          <h3
            id="kanban-unsaved-title"
            class="mb-1 text-base font-semibold text-n-slate-12"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.UNSAVED_CHANGES.TITLE') }}
          </h3>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ t('KANBAN.OPPORTUNITY_DETAILS.UNSAVED_CHANGES.DESCRIPTION') }}
          </p>
        </div>
        <div class="flex justify-end gap-2">
          <button
            ref="keepEditingButton"
            type="button"
            data-testid="kanban-opportunity-keep-editing"
            class="rounded-md px-3 py-2 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            @click="keepEditing"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.UNSAVED_CHANGES.KEEP_EDITING') }}
          </button>
          <button
            type="button"
            data-testid="kanban-opportunity-discard-changes"
            class="rounded-md bg-n-ruby-9 px-3 py-2 text-sm font-medium text-n-solid-1 outline-none hover:bg-n-ruby-10 focus:ring-2 focus:ring-n-ruby-8"
            @click="discardChanges"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.UNSAVED_CHANGES.DISCARD') }}
          </button>
        </div>
      </section>
    </div>

    <div
      v-if="pendingPipelineTransfer"
      class="absolute inset-0 z-20 grid place-items-center bg-black/20 p-4"
      role="presentation"
    >
      <section
        class="grid w-full max-w-sm gap-4 rounded-lg border border-n-weak bg-n-solid-1 p-5 shadow-lg"
        role="dialog"
        aria-modal="true"
        aria-labelledby="kanban-transfer-loss-title"
      >
        <div>
          <h3
            id="kanban-transfer-loss-title"
            class="mb-1 text-base font-semibold text-n-slate-12"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.TRANSFER_LOSS.TITLE') }}
          </h3>
          <p class="mb-0 text-sm text-n-slate-11">
            {{
              t('KANBAN.OPPORTUNITY_DETAILS.TRANSFER_LOSS.DESCRIPTION', {
                stage: pendingPipelineTransfer.stage.name,
              })
            }}
          </p>
        </div>
        <label class="grid gap-1.5">
          <span class="text-sm font-medium text-n-slate-12">
            {{ t('KANBAN.OPPORTUNITY_DETAILS.LOST_REASON') }}
          </span>
          <select
            v-model="pendingPipelineTransfer.lostReason"
            data-testid="kanban-opportunity-transfer-lost-reason"
            class="h-10 rounded-md border border-n-weak bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
          >
            <option value="">
              {{ t('KANBAN.OPPORTUNITY_DETAILS.LOST_REASON_PLACEHOLDER') }}
            </option>
            <option
              v-for="option in selectableLostReasonOptions"
              :key="option"
              :value="option"
            >
              {{ option }}
            </option>
          </select>
        </label>
        <div class="flex justify-end gap-2">
          <button
            type="button"
            class="rounded-md px-3 py-2 text-sm font-medium text-n-slate-11 outline-none hover:bg-n-alpha-2 focus:ring-2 focus:ring-n-brand/40"
            @click="pendingPipelineTransfer = null"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.CANCEL') }}
          </button>
          <button
            type="button"
            data-testid="kanban-opportunity-confirm-transfer"
            class="rounded-md bg-n-ruby-9 px-3 py-2 text-sm font-medium text-n-solid-1 outline-none hover:bg-n-ruby-10 focus:ring-2 focus:ring-n-ruby-8 disabled:opacity-50"
            :disabled="isSaving || !pendingPipelineTransfer.lostReason.trim()"
            @click="confirmPipelineTransfer"
          >
            {{ t('KANBAN.OPPORTUNITY_DETAILS.TRANSFER_LOSS.CONFIRM') }}
          </button>
        </div>
      </section>
    </div>
  </div>
</template>
