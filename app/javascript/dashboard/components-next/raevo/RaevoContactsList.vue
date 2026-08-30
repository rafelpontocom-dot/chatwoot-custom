<script setup>
/**
 * Raevo · Sereno — lista de contatos como tabela.
 *
 * Substitui `components-next/Contacts/Pages/ContactsList.vue` mantendo o mesmo
 * contrato de props e eventos, para poder ser trocada na página sem tocar em
 * mais nada. Cartão expansível virou linha de tabela: mais densidade e
 * varredura por coluna, como no mockup aprovado.
 *
 * Esta tela é NOSSA — melhorias do Chatwoot em ContactsList não chegam aqui.
 * Ver docs/raevo-design-system.md §5.
 */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter, useRoute } from 'vue-router';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
  contacts: { type: Array, required: true },
  selectedContactIds: { type: Array, default: () => [] },
});
const emit = defineEmits(['toggleContact']);

const { t } = useI18n();
const router = useRouter();
const route = useRoute();

const columns = [
  { key: 'NAME', label: t('CONTACTS_LAYOUT.TABLE.NAME') },
  { key: 'EMAIL', label: t('CONTACTS_LAYOUT.TABLE.EMAIL') },
  { key: 'PHONE', label: t('CONTACTS_LAYOUT.TABLE.PHONE') },
  { key: 'COMPANY', label: t('CONTACTS_LAYOUT.TABLE.COMPANY') },
  { key: 'LABELS', label: t('CONTACTS_LAYOUT.TABLE.LABELS') },
  {
    key: 'LAST_ACTIVITY',
    label: t('CONTACTS_LAYOUT.TABLE.LAST_ACTIVITY'),
  },
];

const selectedIds = computed(() => new Set(props.selectedContactIds || []));

// O store camelCasa o contato (phoneNumber), mas a API responde em snake_case.
// Aceitamos as duas formas para a lista não depender de qual caminho a alimentou.
const campo = (c, camel, snake) => c?.[camel] ?? c?.[snake] ?? '';

const phoneOf = c => campo(c, 'phoneNumber', 'phone_number');

const companyOf = c =>
  c.company?.name ||
  c.additionalAttributes?.companyName ||
  c.additional_attributes?.company_name ||
  '';

// dynamicTime transforma o timestamp em texto ("about 2 hours ago");
// shortTimestamp encurta esse texto ("2h ago"). A ordem importa: passar o
// timestamp direto para shortTimestamp lança e apaga a tabela inteira.
const activityOf = c => {
  const at = campo(c, 'lastActivityAt', 'last_activity_at');
  if (!at) return '—';
  try {
    return shortTimestamp(dynamicTime(at), true);
  } catch {
    return '—';
  }
};

const openContact = contact => {
  router.push({
    name: 'contacts_edit',
    params: { accountId: route.params.accountId, contactId: contact.id },
  });
};

const onRowKey = (event, contact) => {
  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault();
    openContact(contact);
  }
};
</script>

<template>
  <div
    class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
    data-testid="raevo-contacts-table"
  >
    <table class="w-full border-collapse text-xs">
      <thead>
        <tr>
          <th
            class="w-10 border-b border-n-weak bg-n-slate-1 px-3 py-2.5"
            scope="col"
          >
            <span class="sr-only">{{ t('CONTACTS_LAYOUT.CARD.SELECT') }}</span>
          </th>
          <th
            v-for="column in columns"
            :key="column.key"
            scope="col"
            class="whitespace-nowrap border-b border-n-weak bg-n-slate-1 px-3 py-2.5 text-start text-micro font-bold uppercase tracking-[0.11em] text-n-slate-10"
            :class="column.key === 'LAST_ACTIVITY' ? 'text-end' : ''"
          >
            {{ column.label }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="contact in contacts"
          :key="contact.id"
          class="cursor-pointer border-b border-n-weak last:border-b-0 hover:bg-n-slate-2 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
          :class="selectedIds.has(contact.id) ? 'bg-n-blue-3' : ''"
          tabindex="0"
          :data-testid="`raevo-contact-row-${contact.id}`"
          @click="openContact(contact)"
          @keydown="onRowKey($event, contact)"
        >
          <td class="px-3" @click.stop>
            <input
              type="checkbox"
              class="size-4 rounded border-n-strong text-n-brand focus:ring-2 focus:ring-n-brand"
              :checked="selectedIds.has(contact.id)"
              :aria-label="contact.name"
              @change="emit('toggleContact', contact.id)"
            />
          </td>
          <td class="h-[52px] px-3">
            <span class="flex min-w-0 items-center gap-2.5">
              <Avatar
                :name="contact.name"
                :src="contact.thumbnail"
                :size="28"
              />
              <span
                class="truncate text-xs font-semibold text-n-slate-12"
                :title="contact.name"
              >
                {{ contact.name }}
              </span>
            </span>
          </td>
          <td class="max-w-[15rem] truncate px-3 text-n-slate-11">
            {{ contact.email || '—' }}
          </td>
          <td class="whitespace-nowrap px-3 tabular-nums text-n-slate-11">
            {{ phoneOf(contact) || '—' }}
          </td>
          <td class="max-w-[12rem] truncate px-3 text-n-slate-11">
            {{ companyOf(contact) || '—' }}
          </td>
          <td class="px-3">
            <span class="flex flex-wrap gap-1">
              <span
                v-for="label in (contact.labels || []).slice(0, 3)"
                :key="label"
                class="rounded-full border border-n-weak bg-n-slate-3 px-2 py-0.5 text-micro font-medium text-n-slate-11"
              >
                {{ label }}
              </span>
              <span
                v-if="(contact.labels || []).length > 3"
                class="text-micro text-n-slate-10"
              >
                {{
                  t('CONTACTS_LAYOUT.TABLE.MORE_LABELS', {
                    count: contact.labels.length - 3,
                  })
                }}
              </span>
            </span>
          </td>
          <td
            class="whitespace-nowrap px-3 text-end tabular-nums text-n-slate-10"
          >
            {{ activityOf(contact) }}
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
