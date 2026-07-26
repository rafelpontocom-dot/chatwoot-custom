/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Keys are static metadata in this registry. */

const NODE_DEFINITIONS = Object.freeze({
  trigger: {
    category: 'TRIGGER',
    icon: 'i-lucide-play',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.TRIGGER',
    addable: false,
  },
  delay: {
    category: 'TIME',
    icon: 'i-lucide-clock-3',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.DELAY',
    addable: true,
  },
  wait_until_field: {
    category: 'TIME',
    icon: 'i-lucide-calendar-clock',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.DATE_WAIT',
    addable: true,
  },
  wait_for_response: {
    category: 'TIME',
    icon: 'i-lucide-message-circle-more',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.RESPONSE_WAIT',
    addable: true,
  },
  wait_for_inactivity: {
    category: 'TIME',
    icon: 'i-lucide-timer-off',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.INACTIVITY_WAIT',
    addable: true,
  },
  wait_for_business_hours: {
    category: 'TIME',
    icon: 'i-lucide-calendar-range',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.BUSINESS_HOURS',
    addable: true,
  },
  condition: {
    category: 'DECISION',
    icon: 'i-lucide-git-branch',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.CONDITION',
    addable: true,
  },
  filter: {
    category: 'DECISION',
    icon: 'i-lucide-filter',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.FILTER',
    addable: true,
  },
  message_eligibility: {
    category: 'DECISION',
    icon: 'i-lucide-shield-check',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MESSAGE_ELIGIBILITY',
    addable: true,
  },
  round_robin: {
    category: 'DECISION',
    icon: 'i-lucide-waypoints',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.ROUND_ROBIN',
    addable: true,
  },
  human_handoff: {
    category: 'CUSTOMER',
    icon: 'i-lucide-user-round-check',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.HUMAN_HANDOFF',
    addable: true,
    terminal: true,
  },
  update_contact: {
    category: 'CUSTOMER',
    icon: 'i-lucide-contact-round',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.UPDATE_CONTACT',
    addable: true,
  },
  audit_log: {
    category: 'OPERATION',
    icon: 'i-lucide-notebook-pen',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.AUDIT_LOG',
    addable: true,
  },
  send_message: {
    category: 'CUSTOMER',
    icon: 'i-lucide-message-square-text',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MESSAGE',
    addable: true,
  },
  action: {
    category: 'OPPORTUNITY',
    icon: 'i-lucide-briefcase-business',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.ACTION',
    addable: true,
  },
  set_field: {
    category: 'OPPORTUNITY',
    icon: 'i-lucide-pencil-line',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.SET_FIELD',
    addable: true,
  },
  complete_next_action: {
    category: 'OPPORTUNITY',
    icon: 'i-lucide-circle-check-big',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.COMPLETE_NEXT_ACTION',
    addable: true,
  },
  mark_won: {
    category: 'OPPORTUNITY',
    icon: 'i-lucide-trophy',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MARK_WON',
    addable: true,
  },
  mark_lost: {
    category: 'OPPORTUNITY',
    icon: 'i-lucide-circle-x',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.MARK_LOST',
    addable: true,
  },
  webhook: {
    category: 'INTEGRATION',
    icon: 'i-lucide-webhook',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.WEBHOOK',
    addable: true,
  },
  end: {
    category: 'CONTROL',
    icon: 'i-lucide-circle-check',
    labelKey: 'KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.NODES.END',
    addable: false,
  },
});

const PALETTE_CATEGORIES = Object.freeze([
  { key: 'DECISION', icon: 'i-lucide-git-branch' },
  { key: 'TIME', icon: 'i-lucide-clock-3' },
  { key: 'CUSTOMER', icon: 'i-lucide-message-circle' },
  { key: 'OPPORTUNITY', icon: 'i-lucide-briefcase-business' },
  { key: 'OPERATION', icon: 'i-lucide-notebook-pen' },
  { key: 'INTEGRATION', icon: 'i-lucide-webhook' },
]);

export const getKanbanWorkflowNodeDefinition = type => NODE_DEFINITIONS[type];

export const getKanbanWorkflowNodeLabel = (type, t) => {
  const definition = getKanbanWorkflowNodeDefinition(type);
  return definition ? t(definition.labelKey) : type;
};

export const getKanbanWorkflowPaletteGroups = t =>
  PALETTE_CATEGORIES.map(category => ({
    ...category,
    label: t(`KANBAN.SETTINGS.AUTOMATIONS.WORKFLOW.PALETTE.${category.key}`),
    nodes: Object.entries(NODE_DEFINITIONS)
      .filter(
        ([, definition]) =>
          definition.addable && definition.category === category.key
      )
      .map(([type, definition]) => ({
        type,
        icon: definition.icon,
        label: t(definition.labelKey),
      })),
  })).filter(group => group.nodes.length);
