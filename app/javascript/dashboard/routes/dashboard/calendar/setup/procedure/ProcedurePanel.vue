<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import CalendarAPI from 'dashboard/api/calendar';
import SetupButton from '../shared/SetupButton.vue';
import SetupHead from '../shared/SetupHead.vue';
import SetupPill from '../shared/SetupPill.vue';
import { apiErrorMessage, toSlug } from '../setupHelpers';
import { useCalendarSetup } from '../useCalendarSetup';
import ChangesTab from './ChangesTab.vue';
import FormTab from './FormTab.vue';
import LimitsTab from './LimitsTab.vue';
import PaymentTab from './PaymentTab.vue';
import ResourcesTab from './ResourcesTab.vue';
import SetupTab from './SetupTab.vue';
import WhenTab from './WhenTab.vue';
import {
  draftFrom,
  procedurePayload,
  provideProcedureDraft,
} from './procedureDraft';

const props = defineProps({
  procedure: { type: Object, default: null },
  tab: { type: String, default: 'setup' },
  bookingPageUrl: { type: String, default: '' },
});

const emit = defineEmits(['update:tab', 'saved', 'back', 'section']);
const { t } = useI18n();
const { loadProcedures } = useCalendarSetup();

const TABS = [
  { id: 'setup', component: SetupTab },
  { id: 'resources', component: ResourcesTab },
  { id: 'when', component: WhenTab },
  { id: 'form', component: FormTab },
  { id: 'limits', component: LimitsTab },
  { id: 'payment', component: PaymentTab },
  { id: 'changes', component: ChangesTab },
];

const route = useRoute();
const draft = ref(draftFrom(props.procedure));
const baseline = ref(JSON.stringify(draft.value));
const ownLoaded = ref(false);
const preview = ref(null);
const isSaving = ref(false);
const error = ref('');
const errors = ref({});
const savedAt = ref(null);

const isDirty = computed(() => JSON.stringify(draft.value) !== baseline.value);
const activeTab = computed(() =>
  TABS.some(tab => tab.id === props.tab) ? props.tab : 'setup'
);
const activeComponent = computed(
  () => TABS.find(tab => tab.id === activeTab.value).component
);

// Vindo do atalho da página de agendamento (`?publicar=1`), o procedimento abre
// com o autoagendamento ligado e por gravar.
const applyPublishRequest = () => {
  if (route.query.publicar === '1' && draft.value.id)
    draft.value.public_booking_enabled = true;
};

const reset = procedure => {
  draft.value = draftFrom(procedure);
  ownLoaded.value = false;
  baseline.value = JSON.stringify(draft.value);
  errors.value = {};
  error.value = '';
  applyPublishRequest();
};

const ownScheduleLoaded = async () => {
  if (ownLoaded.value) return;
  ownLoaded.value = true;
  const wasClean = !isDirty.value;
  if (!draft.value.id || !props.procedure?.own_schedule) {
    if (!draft.value.own_weekly.length) {
      draft.value.own_weekly = [1, 2, 3, 4, 5].map(weekday => ({
        weekday,
        ranges: [{ from: '08:00', to: '12:00' }],
      }));
    }
    return;
  }
  const { data } = await CalendarAPI.getProcedureOwnSchedule(draft.value.id);
  draft.value.own_weekly = data.weekly || [];
  draft.value.own_overrides = data.overrides || [];
  if (wasClean) baseline.value = JSON.stringify(draft.value);
};

const loadPreview = async () => {
  if (!draft.value.id) return;
  preview.value = null;
  try {
    const { data } = await CalendarAPI.getProcedureAvailabilityPreview(
      draft.value.id,
      { days: 14 }
    );
    preview.value = data;
  } catch {
    preview.value = { days: [] };
  }
};

const subtitle = computed(() => {
  const parts = [
    t('CALENDAR_SETUP.COMMON.MINUTES', { count: draft.value.duration_minutes }),
    t(
      `CALENDAR_SETUP.PROCEDURE.LOCATIONS_LOWER.${draft.value.location_type.toUpperCase()}`
    ),
    draft.value.public_booking_enabled
      ? t('CALENDAR_SETUP.PROCEDURE.SUBTITLE_PUBLIC')
      : t('CALENDAR_SETUP.PROCEDURE.SUBTITLE_PRIVATE'),
  ];
  return parts.join(' · ');
});

const headTitle = computed(() =>
  activeTab.value === 'setup'
    ? draft.value.name || t('CALENDAR_SETUP.PROCEDURES.NEW_TITLE')
    : t(`CALENDAR_SETUP.PROCEDURE.HEADS.${activeTab.value.toUpperCase()}.TITLE`)
);

const headSubtitle = computed(() =>
  activeTab.value === 'setup'
    ? subtitle.value
    : t(
        `CALENDAR_SETUP.PROCEDURE.HEADS.${activeTab.value.toUpperCase()}.SUBTITLE`
      )
);

const validate = () => {
  const found = {};
  if (!draft.value.name.trim())
    found.name = t('CALENDAR_SETUP.PROCEDURE.ERRORS.NAME');
  if (
    draft.value.public_booking_enabled &&
    !(draft.value.public_slug || toSlug(draft.value.name))
  ) {
    found.public_slug = t('CALENDAR_SETUP.PROCEDURE.ERRORS.SLUG');
  }
  if (draft.value.when_mode === 'schedule' && !draft.value.schedule_id)
    found.schedule_id = true;
  if (
    ['first_available', 'round_robin', 'collective'].includes(
      draft.value.assignment_strategy
    ) &&
    !draft.value.team_id
  ) {
    found.team_id = true;
  }
  if (draft.value.payment_enabled && !draft.value.price_cents)
    found.price_cents = t('CALENDAR_SETUP.PROCEDURE.ERRORS.PRICE');
  if (
    draft.value.payment_enabled &&
    draft.value.payment_mode === 'deposit' &&
    !(draft.value.deposit_cents < draft.value.price_cents)
  ) {
    found.deposit_cents = t('CALENDAR_SETUP.PROCEDURE.ERRORS.DEPOSIT');
  }
  errors.value = found;
  return Object.keys(found).length === 0;
};

const TAB_OF_ERROR = {
  name: 'setup',
  public_slug: 'setup',
  schedule_id: 'when',
  team_id: 'resources',
  price_cents: 'payment',
  deposit_cents: 'payment',
};

const save = async () => {
  if (!validate()) {
    const firstTab = TAB_OF_ERROR[Object.keys(errors.value)[0]];
    if (firstTab !== activeTab.value) emit('update:tab', firstTab);
    error.value = t('CALENDAR_SETUP.PROCEDURE.ERRORS.FIX_FIELDS');
    return;
  }
  isSaving.value = true;
  error.value = '';
  const payload = procedurePayload(draft.value);
  if (!payload.public_slug && payload.public_booking_enabled)
    payload.public_slug = toSlug(payload.name);
  if (draft.value.when_mode === 'schedule')
    payload.schedule_id = draft.value.schedule_id;
  try {
    let saved;
    if (draft.value.when_mode === 'own') {
      const first = draft.value.id
        ? { data: { id: draft.value.id } }
        : await CalendarAPI.createProcedure({
            procedure: {
              ...payload,
              availability_mode: 'resources',
              schedule_id: null,
            },
          });
      const { data: schedule } = await CalendarAPI.updateProcedureOwnSchedule(
        first.data.id,
        {
          weekly: draft.value.own_weekly,
          overrides: draft.value.own_overrides,
        }
      );
      saved = await CalendarAPI.updateProcedure(first.data.id, {
        procedure: { ...payload, schedule_id: schedule.id },
      });
    } else if (draft.value.id) {
      if (draft.value.when_mode === 'resources') payload.schedule_id = null;
      saved = await CalendarAPI.updateProcedure(draft.value.id, {
        procedure: payload,
      });
    } else {
      saved = await CalendarAPI.createProcedure({ procedure: payload });
    }
    await loadProcedures();
    reset(saved.data);
    if (draft.value.when_mode === 'own') await ownScheduleLoaded();
    savedAt.value = Date.now();
    emit('saved', saved.data);
    loadPreview();
  } catch (saveError) {
    error.value = apiErrorMessage(
      saveError,
      t('CALENDAR_SETUP.COMMON.SAVE_ERROR')
    );
  } finally {
    isSaving.value = false;
  }
};

const togglePublic = () => {
  draft.value.public_booking_enabled = !draft.value.public_booking_enabled;
};

const confirmLeave = event => {
  if (!isDirty.value) return;
  event.preventDefault();
  // eslint-disable-next-line no-param-reassign
  event.returnValue = '';
};
window.addEventListener('beforeunload', confirmLeave);
onBeforeUnmount(() => window.removeEventListener('beforeunload', confirmLeave));

const back = () => {
  // eslint-disable-next-line no-alert
  if (isDirty.value && !window.confirm(t('CALENDAR_SETUP.COMMON.UNSAVED')))
    return;
  emit('back');
};

watch(
  () => props.procedure?.id,
  () => reset(props.procedure)
);

applyPublishRequest();

provideProcedureDraft({
  draft,
  errors,
  preview,
  loadPreview,
  isDirty,
  ownScheduleLoaded,
  bookingPageUrl: computed(() => props.bookingPageUrl),
  goToSection: section => emit('section', section),
});

defineExpose({ isDirty });
</script>

<template>
  <div
    class="grid min-h-full md:grid-cols-[210px_minmax(0,1fr)]"
    data-testid="calendar-procedure-panel"
  >
    <nav
      class="hidden content-start gap-0.5 border-r border-solid border-n-weak px-2.5 py-4 md:grid"
      :aria-label="t('CALENDAR_SETUP.PROCEDURE.TABS_LABEL')"
    >
      <button
        v-for="tab in TABS"
        :key="tab.id"
        type="button"
        class="grid gap-px rounded-md px-2.5 py-2 text-left outline-none transition-colors focus-visible:ring-2 focus-visible:ring-n-brand/40"
        :class="
          activeTab === tab.id
            ? 'bg-n-brand/10 text-n-brand'
            : 'text-n-slate-11 hover:bg-n-alpha-1'
        "
        :aria-pressed="activeTab === tab.id ? 'true' : 'false'"
        :data-testid="`calendar-procedure-tab-button-${tab.id}`"
        @click="emit('update:tab', tab.id)"
      >
        <strong class="text-ui font-semibold">{{
          t(`CALENDAR_SETUP.PROCEDURE.TABS.${tab.id.toUpperCase()}.TITLE`)
        }}</strong>
        <small
          class="text-micro"
          :class="activeTab === tab.id ? 'text-n-brand/80' : 'text-n-slate-10'"
        >
          {{ t(`CALENDAR_SETUP.PROCEDURE.TABS.${tab.id.toUpperCase()}.HINT`) }}
        </small>
      </button>
    </nav>

    <section class="grid min-w-0 content-start gap-4 px-5 py-[18px]">
      <label class="grid gap-1 md:hidden">
        <span class="text-xs font-medium text-n-slate-11">{{
          t('CALENDAR_SETUP.PROCEDURE.TABS_LABEL')
        }}</span>
        <select
          :value="activeTab"
          class="reset-base mb-0 h-9 w-full appearance-none rounded-lg border border-solid border-n-strong bg-n-solid-1 px-3 text-ui text-n-slate-12"
          @change="emit('update:tab', $event.target.value)"
        >
          <option v-for="tab in TABS" :key="tab.id" :value="tab.id">
            {{
              t(`CALENDAR_SETUP.PROCEDURE.TABS.${tab.id.toUpperCase()}.TITLE`)
            }}
          </option>
        </select>
      </label>

      <SetupHead :title="headTitle" :description="headSubtitle">
        <template #before>
          <button
            type="button"
            class="flex w-fit items-center gap-1 rounded-md text-xs text-n-slate-10 outline-none hover:text-n-slate-12 focus-visible:ring-2 focus-visible:ring-n-brand/40"
            data-testid="calendar-procedure-back"
            @click="back"
          >
            <i class="i-lucide-chevron-left size-3.5" aria-hidden="true" />
            {{ t('CALENDAR_SETUP.NAV.PROCEDURES') }}
          </button>
        </template>
        <button
          type="button"
          class="rounded-full p-0 outline-none focus-visible:ring-2 focus-visible:ring-n-brand/40"
          :aria-pressed="draft.public_booking_enabled ? 'true' : 'false'"
          :title="t('CALENDAR_SETUP.PROCEDURE.TOGGLE_PUBLIC')"
          data-testid="calendar-procedure-public-toggle"
          @click="togglePublic"
        >
          <SetupPill
            :tone="draft.public_booking_enabled ? 'on' : 'neutral'"
            :label="
              draft.public_booking_enabled
                ? t('CALENDAR_SETUP.PROCEDURE.PUBLIC_ON')
                : t('CALENDAR_SETUP.PROCEDURE.PUBLIC_OFF')
            "
          />
        </button>
        <small
          v-if="savedAt && !isDirty"
          class="flex items-center gap-1 text-xs text-n-teal-11"
          role="status"
        >
          <i class="i-lucide-check size-3.5" aria-hidden="true" />
          {{ t('CALENDAR_SETUP.COMMON.SAVED') }}
        </small>
        <SetupButton
          variant="primary"
          :label="t('CALENDAR_SETUP.COMMON.SAVE')"
          :loading="isSaving"
          :disabled="draft.id && !isDirty"
          data-testid="calendar-procedure-save"
          @click="save"
        />
      </SetupHead>

      <p
        v-if="error"
        class="mb-0 flex items-center gap-1.5 text-ui text-n-ruby-11"
        role="alert"
      >
        <i class="i-lucide-circle-alert size-4" aria-hidden="true" />
        {{ error }}
      </p>

      <component :is="activeComponent" />
    </section>
  </div>
</template>
