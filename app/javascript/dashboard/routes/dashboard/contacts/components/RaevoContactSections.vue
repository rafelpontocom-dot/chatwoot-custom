<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useUISettings } from 'dashboard/composables/useUISettings';
import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';
import ContactNotes from 'dashboard/components-next/Contacts/ContactsSidebar/ContactNotes.vue';
import ContactHistory from 'dashboard/components-next/Contacts/ContactsSidebar/ContactHistory.vue';
import ContactMedia from 'dashboard/components-next/Contacts/ContactsSidebar/ContactMedia.vue';
import ContactKanbanCards from 'dashboard/components-next/Contacts/ContactsSidebar/ContactKanbanCards.vue';
import ContactFormSubmissions from 'dashboard/components-next/Contacts/ContactsSidebar/ContactFormSubmissions.vue';
import ContactMerge from 'dashboard/components-next/Contacts/ContactsSidebar/ContactMerge.vue';
import ContactCustomAttributes from 'dashboard/components-next/Contacts/ContactsSidebar/ContactCustomAttributes.vue';

/**
 * RAEVO (15/10, 123jpnbcxpd e 123jpnbcb54) — a coluna da ficha do contacto em
 * secções que abrem e fecham, como a lateral do contacto dentro da conversa.
 *
 * Era uma tira de sete abas que rolava na horizontal sem o dizer: «Respostas»,
 * «Notas» e «Mídia» ficavam fora da vista. Empilhadas, vê-se tudo o que existe e
 * abre-se o que interessa. Os atributos começam fechados, como no Kommo — são
 * consulta, não trabalho —, e a oportunidade e o histórico abertos. O que cada
 * pessoa abre ou fecha fica guardado nas definições dela.
 */
const props = defineProps({
  selectedContact: { type: Object, default: null },
  /** A ficha de respostas é de administração, como em `FormSubmissionPolicy`. */
  showForms: { type: Boolean, default: false },
});

const emit = defineEmits(['goToContactsList', 'openSubmission']);

const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

const SETTINGS_KEY = 'raevo_contact_sections';
const OPEN_BY_DEFAULT = { kanban: true, history: true };

const openSections = computed(() => ({
  ...OPEN_BY_DEFAULT,
  ...(uiSettings.value[SETTINGS_KEY] || {}),
}));
const isOpen = key => Boolean(openSections.value[key]);
const setOpen = (key, value) =>
  updateUISettings({
    [SETTINGS_KEY]: { ...openSections.value, [key]: value },
  });

const sections = computed(() =>
  [
    { key: 'kanban', title: t('CONTACTS_LAYOUT.SIDEBAR.TABS.KANBAN') },
    { key: 'attributes', title: t('CONTACTS_LAYOUT.SIDEBAR.TABS.ATTRIBUTES') },
    { key: 'history', title: t('CONTACTS_LAYOUT.SIDEBAR.TABS.HISTORY') },
    props.showForms && {
      key: 'forms',
      title: t('CONTACTS_LAYOUT.SIDEBAR.TABS.FORMS'),
    },
    { key: 'notes', title: t('CONTACTS_LAYOUT.SIDEBAR.TABS.NOTES') },
    { key: 'media', title: t('CONTACTS_LAYOUT.SIDEBAR.TABS.MEDIA') },
    { key: 'merge', title: t('CONTACTS_LAYOUT.SIDEBAR.TABS.MERGE') },
  ].filter(Boolean)
);
</script>

<template>
  <div class="flex flex-col gap-2 px-6 py-6">
    <AccordionItem
      v-for="section in sections"
      :key="section.key"
      :data-testid="`raevo-contact-section-${section.key}`"
      :title="section.title"
      :is-open="isOpen(section.key)"
      @toggle="setOpen(section.key, !isOpen(section.key))"
    >
      <ContactKanbanCards
        v-if="section.key === 'kanban' && selectedContact"
        :contact-id="selectedContact.id"
      />
      <ContactCustomAttributes
        v-else-if="section.key === 'attributes'"
        :selected-contact="selectedContact"
      />
      <ContactHistory v-else-if="section.key === 'history'" />
      <ContactFormSubmissions
        v-else-if="section.key === 'forms' && selectedContact"
        :contact-id="selectedContact.id"
        @open-submission="emit('openSubmission', $event)"
      />
      <ContactNotes v-else-if="section.key === 'notes'" />
      <ContactMedia v-else-if="section.key === 'media'" />
      <ContactMerge
        v-else-if="section.key === 'merge'"
        :selected-contact="selectedContact"
        @go-to-contacts-list="emit('goToContactsList')"
        @reset-tab="setOpen('merge', false)"
      />
    </AccordionItem>
  </div>
</template>
