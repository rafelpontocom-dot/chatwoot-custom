import { inject, provide } from 'vue';
import { RAEVO_DEFAULT_PROCEDURE_COLOR } from 'dashboard/constants/raevoPalette';

// O rascunho do procedimento aberto, partilhado pelas sete abas. As abas editam
// o mesmo objeto; o painel compara com o que veio do servidor e grava tudo junto.
const KEY = Symbol('calendarProcedureDraft');

export const DEFAULT_QUESTIONS = [
  {
    key: 'full_name',
    label: 'Nome completo',
    kind: 'text',
    required: true,
    locked: true,
  },
  { key: 'whatsapp', label: 'WhatsApp', kind: 'phone', required: true },
  { key: 'cpf', label: 'CPF', kind: 'cpf', required: 'feegow' },
  { key: 'email', label: 'E-mail', kind: 'email', required: false },
  {
    key: 'notes',
    label: 'Algo que a equipe deva saber?',
    kind: 'textarea',
    required: false,
  },
];

const whenModeOf = procedure => {
  if (procedure?.availability_mode !== 'schedule') return 'resources';
  return procedure.own_schedule ? 'own' : 'schedule';
};

export const draftFrom = procedure => ({
  id: procedure?.id || null,
  name: procedure?.name || '',
  public_slug: procedure?.public_slug || '',
  public_description: procedure?.public_description || '',
  duration_minutes: procedure?.duration_minutes || 50,
  location_type: procedure?.location_type || 'in_person',
  color: procedure?.color || RAEVO_DEFAULT_PROCEDURE_COLOR,
  public_booking_enabled: procedure?.public_booking_enabled || false,
  recurrence_allowed: procedure?.recurrence_allowed || false,
  max_sessions: procedure?.max_sessions || 10,
  resource_ids: [...(procedure?.resource_ids || [])],
  assignment_strategy: procedure?.assignment_strategy || 'patient_choice',
  team_id: procedure?.team_id || null,
  when_mode: whenModeOf(procedure),
  schedule_id: procedure?.own_schedule ? null : procedure?.schedule_id || null,
  own_weekly: [],
  own_overrides: [],
  minimum_notice_minutes: procedure?.minimum_notice_minutes ?? null,
  maximum_notice_days: procedure?.maximum_notice_days ?? null,
  slot_interval_minutes: procedure?.slot_interval_minutes ?? null,
  buffer_before_minutes: procedure?.buffer_before_minutes || 0,
  buffer_after_minutes: procedure?.buffer_after_minutes || 0,
  daily_limit: procedure?.daily_limit ?? null,
  payment_enabled: procedure?.payment_enabled || false,
  price_cents: procedure?.price_cents ?? null,
  payment_mode: procedure?.payment_mode || 'full',
  deposit_cents: procedure?.deposit_cents ?? null,
  payment_methods: [
    ...(procedure?.payment_methods || ['pix', 'card', 'on_site']),
  ],
  hold_minutes: procedure?.hold_minutes || 10,
  reschedule_allowed: procedure?.reschedule_allowed ?? true,
  cancel_allowed: procedure?.cancel_allowed ?? true,
  change_deadline_hours: procedure?.change_deadline_hours ?? 12,
  cancel_reason_required: procedure?.cancel_reason_required ?? true,
  on_cancel_stage_action:
    procedure?.on_cancel_stage_action || 'back_to_scheduling',
  questions: JSON.parse(
    JSON.stringify(procedure?.booking_questions || DEFAULT_QUESTIONS)
  ),
  mirrors_feegow: procedure?.mirrors_feegow || false,
});

export const procedurePayload = draft => ({
  name: draft.name.trim(),
  public_slug: draft.public_slug || null,
  public_description: draft.public_description || null,
  duration_minutes: Number(draft.duration_minutes),
  location_type: draft.location_type,
  color: draft.color,
  public_booking_enabled: draft.public_booking_enabled,
  recurrence_allowed: draft.recurrence_allowed,
  max_sessions: draft.recurrence_allowed ? Number(draft.max_sessions) : null,
  resource_ids: draft.resource_ids,
  assignment_strategy: draft.assignment_strategy,
  team_id: ['first_available', 'round_robin', 'collective'].includes(
    draft.assignment_strategy
  )
    ? draft.team_id
    : null,
  availability_mode: draft.when_mode === 'resources' ? 'resources' : 'schedule',
  minimum_notice_minutes: draft.minimum_notice_minutes,
  maximum_notice_days: draft.maximum_notice_days,
  slot_interval_minutes: draft.slot_interval_minutes,
  buffer_before_minutes: Number(draft.buffer_before_minutes),
  buffer_after_minutes: Number(draft.buffer_after_minutes),
  daily_limit: draft.daily_limit,
  payment_enabled: draft.payment_enabled,
  price_cents: draft.price_cents,
  payment_mode: draft.payment_mode,
  deposit_cents: draft.payment_mode === 'deposit' ? draft.deposit_cents : null,
  payment_methods: draft.payment_methods,
  hold_minutes: Number(draft.hold_minutes),
  reschedule_allowed: draft.reschedule_allowed,
  cancel_allowed: draft.cancel_allowed,
  change_deadline_hours: Number(draft.change_deadline_hours),
  cancel_reason_required: draft.cancel_reason_required,
  on_cancel_stage_action: draft.on_cancel_stage_action,
  public_booking_config: { questions: draft.questions },
});

export const provideProcedureDraft = context => provide(KEY, context);

export const useProcedureDraft = () => inject(KEY);
