<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';

import CalendarSettingsDialog from './CalendarSettingsDialog.vue';
import ProceduresSection from './setup/ProceduresSection.vue';
import ResourcesSection from './setup/ResourcesSection.vue';
import SchedulesSection from './setup/SchedulesSection.vue';
import TeamsSection from './setup/TeamsSection.vue';
import SetupHead from './setup/shared/SetupHead.vue';
import { useCalendarSetup } from './setup/useCalendarSetup';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const currentAccountId = useMapGetter('getCurrentAccountId');
const { loadAll } = useCalendarSetup();

// Configurações da agenda no padrão do mockup aprovado: barra lateral de 196px
// e uma secção de cada vez, cada uma com endereço próprio. Página de
// agendamento e Integrações continuam no painel que já existia.
const SECTIONS = [
  {
    id: 'procedures',
    icon: 'i-lucide-stethoscope',
    component: ProceduresSection,
  },
  { id: 'availability', icon: 'i-lucide-clock', component: SchedulesSection },
  {
    id: 'resources',
    icon: 'i-lucide-calendar-days',
    component: ResourcesSection,
  },
  { id: 'teams', icon: 'i-lucide-users', component: TeamsSection },
  { id: 'booking-page', icon: 'i-lucide-globe', legacy: 'booking-page' },
  { id: 'integrations', icon: 'i-lucide-plug', legacy: 'integrations' },
];

const activeSection = computed(() => {
  const asked = route.params.section;
  return SECTIONS.find(section => section.id === asked) || SECTIONS[0];
});

const baseUrl = computed(() =>
  frontendURL(`accounts/${currentAccountId.value}/calendar`)
);

const goTo = (
  section,
  { itemId = '', tab = '', replace = false, query = {} } = {}
) => {
  const path = [baseUrl.value, 'settings', section, itemId, itemId && tab]
    .filter(Boolean)
    .join('/');
  if (replace) router.replace({ path, query });
  else router.push({ path, query });
};

// Atalho da página de agendamento: abre o procedimento com o autoagendamento
// já ligado; gravar continua a ser decisão de quem está na tela.
const openProcedureToPublish = id =>
  goTo('procedures', {
    itemId: String(id),
    tab: 'setup',
    query: { publicar: '1' },
  });

onMounted(loadAll);
</script>

<template>
  <div
    class="raevo-compact flex h-full min-h-0 w-full bg-n-background"
    data-testid="calendar-settings-view"
  >
    <nav
      class="hidden w-[196px] shrink-0 content-start gap-0.5 overflow-y-auto border-r border-solid border-n-weak bg-n-surface-2 px-2.5 py-3 md:grid"
      :aria-label="t('CALENDAR_SETUP.NAV_LABEL')"
      data-testid="calendar-settings-nav"
    >
      <router-link
        :to="baseUrl"
        class="mb-1 flex items-center gap-2 rounded-md px-2.5 py-2 text-ui text-n-slate-11 outline-none hover:bg-n-alpha-1 focus-visible:ring-2 focus-visible:ring-n-brand/40"
        data-testid="calendar-settings-back"
      >
        <i class="i-lucide-arrow-left size-4" aria-hidden="true" />
        {{ t('CALENDAR_SETUP.BACK') }}
      </router-link>
      <p
        class="mb-1 ml-2 mt-2 text-micro font-bold uppercase tracking-wider text-n-slate-10"
      >
        {{ t('CALENDAR_SETUP.RAIL_LABEL') }}
      </p>
      <button
        v-for="section in SECTIONS"
        :key="section.id"
        type="button"
        class="flex items-center gap-2 rounded-md border border-solid px-2.5 py-2 text-left text-ui outline-none transition-colors focus-visible:ring-2 focus-visible:ring-n-brand/40"
        :class="
          activeSection.id === section.id
            ? 'border-n-weak bg-n-solid-1 font-semibold text-n-slate-12'
            : 'border-transparent text-n-slate-11 hover:bg-n-alpha-1'
        "
        :aria-current="activeSection.id === section.id ? 'page' : undefined"
        :data-testid="`calendar-settings-nav-${section.id}`"
        @click="goTo(section.id)"
      >
        <i :class="section.icon" class="size-4 shrink-0" aria-hidden="true" />
        {{
          t(`CALENDAR_SETUP.NAV.${section.id.toUpperCase().replace('-', '_')}`)
        }}
      </button>
    </nav>

    <div
      class="min-w-0 flex-1 overflow-y-auto bg-n-solid-1"
      data-testid="calendar-settings-content"
    >
      <label
        class="grid gap-1 border-b border-solid border-n-weak px-5 py-3 md:hidden"
      >
        <span class="text-xs font-medium text-n-slate-11">{{
          t('CALENDAR_SETUP.NAV_LABEL')
        }}</span>
        <select
          :value="activeSection.id"
          class="reset-base mb-0 h-9 w-full appearance-none rounded-lg border border-solid border-n-strong bg-n-solid-1 px-3 text-ui text-n-slate-12"
          @change="goTo($event.target.value)"
        >
          <option
            v-for="section in SECTIONS"
            :key="section.id"
            :value="section.id"
          >
            {{
              t(
                `CALENDAR_SETUP.NAV.${section.id.toUpperCase().replace('-', '_')}`
              )
            }}
          </option>
        </select>
      </label>

      <component
        :is="activeSection.component"
        v-if="activeSection.component"
        :item-id="String(route.params.itemId || '')"
        :tab="String(route.params.tab || 'setup')"
        @navigate="options => goTo(activeSection.id, options)"
        @section="section => goTo(section)"
      />

      <section v-else class="grid content-start gap-4 px-5 py-[18px]">
        <SetupHead
          :title="
            t(
              `CALENDAR_SETUP.NAV.${activeSection.id.toUpperCase().replace('-', '_')}`
            )
          "
          :description="
            t(
              `CALENDAR_SETUP.LEGACY_DESCRIPTIONS.${activeSection.id.toUpperCase().replace('-', '_')}`
            )
          "
        />
        <CalendarSettingsDialog
          :key="activeSection.legacy"
          :tab="activeSection.legacy"
          @open-procedure="openProcedureToPublish"
        />
      </section>
    </div>
  </div>
</template>
