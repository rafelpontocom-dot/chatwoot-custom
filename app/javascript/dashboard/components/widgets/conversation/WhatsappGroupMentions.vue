<script setup>
// RAEVO (08/10, 123jpnbcb4w): a lista do @ na resposta de um grupo de WhatsApp.
// Mesmo picker que o @ dos agentes na nota interna (CaretAnchoredPicker), mas o que
// se insere é o texto que o WAHA transforma em menção — `@all`, `@<dígitos>@lid`
// ou `@<dígitos>` — e não um nó de menção do Chatwoot.
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';
import CaretAnchoredPicker from 'dashboard/components-next/preview-picker/CaretAnchoredPicker.vue';

const props = defineProps({
  caretPosition: { type: Object, default: null },
  searchKey: { type: String, default: '' },
  participants: { type: Array, default: () => [] },
});

const emit = defineEmits(['select', 'close', 'removeTrigger']);

const { t } = useI18n();
const searchQuery = ref(props.searchKey);
const searchTerm = computed(() => searchQuery.value.trim().toLowerCase());

const items = computed(() => {
  const everyone = {
    id: 'all',
    label: t('CONVERSATION.WHATSAPP_GROUP_MENTION.ALL'),
    title: t('CONVERSATION.WHATSAPP_GROUP_MENTION.ALL'),
    subtitle: '@all',
    record: { mention: '@all', everyone: true },
  };
  const people = props.participants.map(participant => ({
    id: participant.id,
    label: participant.name,
    title: participant.name,
    subtitle: participant.mention.replace(/@lid$/, ''),
    record: participant,
  }));

  return [everyone, ...people].filter(
    item =>
      !searchTerm.value ||
      item.label.toLowerCase().includes(searchTerm.value) ||
      item.subtitle.includes(searchTerm.value)
  );
});
</script>

<template>
  <CaretAnchoredPicker
    v-model:search="searchQuery"
    :caret-position="caretPosition"
    :items="items"
    :search-placeholder="
      t('CONVERSATION.WHATSAPP_GROUP_MENTION.SEARCH_PLACEHOLDER')
    "
    :empty-label="t('CONVERSATION.WHATSAPP_GROUP_MENTION.EMPTY')"
    @select="item => emit('select', item.record.mention)"
    @close="emit('close')"
    @remove-trigger="emit('removeTrigger')"
  >
    <template #leading="{ item }">
      <span
        v-if="item.record.everyone"
        aria-hidden="true"
        class="i-lucide-users size-6 flex-shrink-0 text-n-slate-11"
      />
      <Avatar
        v-else
        :name="item.label"
        :size="24"
        rounded-full
        class="flex-shrink-0"
      />
    </template>
    <template #preview="{ item }">
      <div v-if="item" class="flex flex-col gap-1 px-4 py-3">
        <span class="text-sm font-medium text-n-slate-12">
          {{ item.label }}
        </span>
        <span class="text-xs text-n-slate-11">{{ item.subtitle }}</span>
        <span v-if="!item.record.everyone" class="text-xs text-n-slate-11">
          {{ t('CONVERSATION.WHATSAPP_GROUP_MENTION.FROM_HISTORY') }}
        </span>
      </div>
    </template>
  </CaretAnchoredPicker>
</template>
