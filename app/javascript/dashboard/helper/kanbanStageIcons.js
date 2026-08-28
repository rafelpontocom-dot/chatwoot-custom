export const DEFAULT_KANBAN_STAGE_ICON = 'circle-dot';

export const KANBAN_STAGE_ICON_OPTIONS = [
  {
    value: 'circle-dot',
    iconClass: 'i-lucide-circle-dot',
    labelKey: 'KANBAN.SETTINGS.STAGES.ICON_OPTIONS.DEFAULT',
  },
  {
    value: 'search',
    iconClass: 'i-lucide-search',
    labelKey: 'KANBAN.SETTINGS.STAGES.ICON_OPTIONS.QUALIFY',
  },
  {
    value: 'clipboard-list',
    iconClass: 'i-lucide-clipboard-list',
    labelKey: 'KANBAN.SETTINGS.STAGES.ICON_OPTIONS.QUALIFY',
  },
  {
    value: 'message-circle',
    iconClass: 'i-lucide-message-circle',
    labelKey: 'KANBAN.SETTINGS.STAGES.ICON_OPTIONS.CONTACT',
  },
  {
    value: 'calendar-check',
    iconClass: 'i-lucide-calendar-check',
    labelKey: 'KANBAN.SETTINGS.STAGES.ICON_OPTIONS.SCHEDULE',
  },
  {
    value: 'file-text',
    iconClass: 'i-lucide-file-text',
    labelKey: 'KANBAN.SETTINGS.STAGES.ICON_OPTIONS.PROPOSAL',
  },
  {
    value: 'send',
    iconClass: 'i-lucide-send',
    labelKey: 'KANBAN.SETTINGS.STAGES.ICON_OPTIONS.FOLLOW_UP',
  },
  {
    value: 'handshake',
    iconClass: 'i-lucide-handshake',
    labelKey: 'KANBAN.SETTINGS.STAGES.ICON_OPTIONS.NEGOTIATE',
  },
  {
    value: 'circle-dollar-sign',
    iconClass: 'i-lucide-circle-dollar-sign',
    labelKey: 'KANBAN.SETTINGS.STAGES.ICON_OPTIONS.PAYMENT',
  },
  {
    value: 'trophy',
    iconClass: 'i-lucide-trophy',
    labelKey: 'KANBAN.SETTINGS.STAGES.ICON_OPTIONS.WON',
  },
  {
    value: 'circle-x',
    iconClass: 'i-lucide-circle-x',
    labelKey: 'KANBAN.SETTINGS.STAGES.ICON_OPTIONS.LOST',
  },
];

export const getKanbanStageIconOption = value =>
  KANBAN_STAGE_ICON_OPTIONS.find(option => option.value === value) ||
  KANBAN_STAGE_ICON_OPTIONS[0];
