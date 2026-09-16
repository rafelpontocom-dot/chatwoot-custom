<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import CalendarAPI from 'dashboard/api/calendar';
import ProcedurePanel from './procedure/ProcedurePanel.vue';
import SetupButton from './shared/SetupButton.vue';
import SetupGroup from './shared/SetupGroup.vue';
import SetupHead from './shared/SetupHead.vue';
import SetupPill from './shared/SetupPill.vue';
import SetupRow from './shared/SetupRow.vue';
import { useCalendarSetup } from './useCalendarSetup';

const props = defineProps({
  itemId: { type: String, default: '' },
  tab: { type: String, default: 'setup' },
});

const emit = defineEmits(['navigate', 'section']);
const { t } = useI18n();
const {
  procedures,
  loadProcedures,
  loadResources,
  loadSchedules,
  loadTeams,
  resources,
} = useCalendarSetup();

const bookingPageUrl = ref('');
const panel = ref(null);

const activeProcedures = computed(() =>
  procedures.value.filter(procedure => procedure.active)
);
const archivedProcedures = computed(() =>
  procedures.value.filter(procedure => !procedure.active)
);

const current = computed(() =>
  props.itemId === 'new'
    ? null
    : procedures.value.find(procedure => String(procedure.id) === props.itemId)
);

const isOpen = computed(() => props.itemId === 'new' || Boolean(current.value));

const hintFor = procedure =>
  [
    t('CALENDAR_SETUP.COMMON.MINUTES', { count: procedure.duration_minutes }),
    t(
      `CALENDAR_SETUP.PROCEDURE.LOCATIONS_LOWER.${(procedure.location_type || 'in_person').toUpperCase()}`
    ),
  ].join(' · ');

const open = procedure =>
  emit('navigate', { itemId: String(procedure.id), tab: 'setup' });

onMounted(async () => {
  await Promise.all([
    procedures.value.length ? null : loadProcedures(),
    resources.value.length ? null : loadResources(),
    loadSchedules(),
    loadTeams(),
  ]);
  try {
    const { data } = await CalendarAPI.getBookingPage();
    if (data?.public_token)
      bookingPageUrl.value = `${window.location.origin}/agendar/${data.public_token}`;
  } catch {
    bookingPageUrl.value = '';
  }
});

defineExpose({ isDirty: computed(() => panel.value?.isDirty) });
</script>

<template>
  <ProcedurePanel
    v-if="isOpen"
    ref="panel"
    :key="itemId"
    :procedure="current"
    :tab="tab"
    :booking-page-url="bookingPageUrl"
    @update:tab="nextTab => emit('navigate', { itemId, tab: nextTab })"
    @saved="
      procedure =>
        emit('navigate', { itemId: String(procedure.id), tab, replace: true })
    "
    @back="emit('navigate', { itemId: '' })"
    @section="section => emit('section', section)"
  />

  <section
    v-else
    class="grid content-start gap-4 px-5 py-[18px]"
    data-testid="calendar-setup-procedures"
  >
    <SetupHead
      :title="t('CALENDAR_SETUP.PROCEDURES.TITLE')"
      :description="t('CALENDAR_SETUP.PROCEDURES.DESCRIPTION')"
    >
      <SetupButton
        variant="primary"
        :label="t('CALENDAR_SETUP.PROCEDURES.NEW')"
        data-testid="calendar-procedure-new"
        @click="emit('navigate', { itemId: 'new', tab: 'setup' })"
      />
    </SetupHead>

    <SetupGroup
      :title="t('CALENDAR_SETUP.PROCEDURES.LIST_GROUP')"
      :hint="String(activeProcedures.length)"
      flush
    >
      <p
        v-if="!activeProcedures.length"
        class="mb-0 py-2.5 text-ui text-n-slate-10"
      >
        {{ t('CALENDAR_SETUP.PROCEDURES.EMPTY') }}
      </p>
      <SetupRow
        v-for="procedure in activeProcedures"
        :key="procedure.id"
        clickable
        :title="procedure.name"
        :hint="hintFor(procedure)"
        :data-testid="`calendar-procedure-row-${procedure.id}`"
        @select="open(procedure)"
      >
        <SetupPill
          v-if="procedure.public_booking_enabled"
          tone="on"
          :label="t('CALENDAR_SETUP.PROCEDURE.PUBLIC_ON')"
        />
        <SetupPill
          v-if="procedure.payment_enabled"
          :label="t('CALENDAR_SETUP.PROCEDURES.CHARGES')"
        />
        <i
          class="i-lucide-chevron-right size-4 text-n-slate-10"
          aria-hidden="true"
        />
      </SetupRow>
    </SetupGroup>

    <SetupGroup
      v-if="archivedProcedures.length"
      :title="t('CALENDAR_SETUP.PROCEDURES.ARCHIVED')"
      :hint="String(archivedProcedures.length)"
      flush
    >
      <SetupRow
        v-for="procedure in archivedProcedures"
        :key="procedure.id"
        clickable
        :title="procedure.name"
        :hint="hintFor(procedure)"
        @select="open(procedure)"
      />
    </SetupGroup>
  </section>
</template>
