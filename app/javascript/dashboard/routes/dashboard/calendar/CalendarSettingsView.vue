<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { frontendURL } from 'dashboard/helper/URLHelper';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import CalendarSettingsDialog from './CalendarSettingsDialog.vue';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const currentAccountId = useMapGetter('getCurrentAccountId');

// A configuração deixa de ser um modal de 74 KB empilhado sobre a agenda e passa
// a ser destino próprio, como no Google Calendar: navegação à esquerda, uma
// secção de cada vez à direita, e cada secção com URL própria para partilhar.
const SECTIONS = [
  { id: 'procedures', icon: 'i-lucide-stethoscope' },
  { id: 'resources', icon: 'i-lucide-calendar-days' },
  { id: 'booking-page', icon: 'i-lucide-globe' },
];

const LABELS = {
  procedures: 'CALENDAR.SETTINGS.PROCEDURES',
  resources: 'CALENDAR.SETTINGS.RESOURCES',
  'booking-page': 'CALENDAR.SETTINGS.BOOKING_PAGE',
};

const DESCRIPTIONS = {
  procedures: 'CALENDAR.SETTINGS.PROCEDURES_DESCRIPTION',
  resources: 'CALENDAR.SETTINGS.RESOURCES_DESCRIPTION',
  'booking-page': 'CALENDAR.SETTINGS.BOOKING_PAGE_DESCRIPTION',
};

const activeSection = computed(() => {
  const asked = route.params.section;
  return SECTIONS.some(section => section.id === asked) ? asked : 'procedures';
});

const calendarUrl = computed(() =>
  frontendURL(`accounts/${currentAccountId.value}/calendar`)
);

const goToSection = section => {
  if (section === activeSection.value) return;
  router.replace(`${calendarUrl.value}/settings/${section}`);
};
</script>

<template>
  <div class="flex h-full min-h-0 w-full flex-col bg-n-background">
    <header
      class="flex items-center gap-3 border-b border-n-weak px-4 py-3"
      data-testid="calendar-settings-header"
    >
      <router-link
        :to="calendarUrl"
        class="flex h-8 w-8 items-center justify-center rounded-full text-n-slate-11 outline-none hover:bg-n-alpha-1 focus-visible:ring-2 focus-visible:ring-n-brand/40"
        :aria-label="t('CALENDAR.SETTINGS.BACK_TO_CALENDAR')"
        data-testid="calendar-settings-back"
      >
        <Icon icon="i-lucide-arrow-left" class="size-4" />
      </router-link>
      <h1 class="mb-0 text-base font-medium text-n-slate-12">
        {{ t('CALENDAR.SETTINGS.TITLE') }}
      </h1>
    </header>

    <div class="flex min-h-0 flex-1">
      <nav
        class="w-60 shrink-0 overflow-y-auto border-r border-n-weak p-3"
        :aria-label="t('CALENDAR.SETTINGS.TABS_LABEL')"
        data-testid="calendar-settings-nav"
      >
        <button
          v-for="section in SECTIONS"
          :key="section.id"
          type="button"
          class="flex h-10 w-full items-center gap-2.5 rounded-full px-3 text-sm outline-none transition-colors focus-visible:ring-2 focus-visible:ring-n-brand/40"
          :class="
            activeSection === section.id
              ? 'bg-n-alpha-2 font-medium text-n-slate-12'
              : 'text-n-slate-11 hover:bg-n-alpha-1'
          "
          :aria-current="activeSection === section.id ? 'page' : undefined"
          :data-testid="`calendar-settings-nav-${section.id}`"
          @click="goToSection(section.id)"
        >
          <Icon :icon="section.icon" class="size-4 shrink-0" />
          <span class="truncate">{{ t(LABELS[section.id]) }}</span>
        </button>
      </nav>

      <main class="min-w-0 flex-1 overflow-y-auto">
        <div class="grid max-w-3xl gap-4 px-6 py-6">
          <div class="grid gap-1">
            <h2 class="mb-0 text-lg font-medium text-n-slate-12">
              {{ t(LABELS[activeSection]) }}
            </h2>
            <p class="mb-0 text-sm text-n-slate-11">
              {{ t(DESCRIPTIONS[activeSection]) }}
            </p>
          </div>

          <CalendarSettingsDialog inline :tab="activeSection" />
        </div>
      </main>
    </div>
  </div>
</template>
