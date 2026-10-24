<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SearchResultContactsList from 'dashboard/modules/search/components/SearchResultContactsList.vue';
import SearchResultMessagesList from 'dashboard/modules/search/components/SearchResultMessagesList.vue';

// RAEVO (24/10, 123jpnbd8y6) — a busca vive na própria lista, como no WhatsApp,
// em vez de levar para a tela de pesquisa. Proposta B: campo e botão de nova
// conversa lado a lado, dois alvos separados — começar uma conversa não obriga
// a escrever nada primeiro.
//
// **Contactos primeiro, sempre.** Quem procura «Maria» ou um telefone quer a
// pessoa, não a frase onde o nome calhou de aparecer. O conteúdo das mensagens
// vem a seguir, com o trecho em destaque.

const emit = defineEmits(['update:searching']);

const MIN_LENGTH = 2;
const DEBOUNCE_MS = 300;

const { t } = useI18n();
const store = useStore();

const query = ref('');
const debounced = ref('');
let timer = null;

const contactRecords = useMapGetter('conversationSearch/getContactRecords');
const messageRecords = useMapGetter('conversationSearch/getMessageRecords');
const uiFlags = useMapGetter('conversationSearch/getUIFlags');

const searching = computed(() => debounced.value.length >= MIN_LENGTH);

const camelCased = records =>
  records.value.map(record => useCamelCase(record, { deep: true }));

const contacts = computed(() => camelCased(contactRecords));
const messages = computed(() => camelCased(messageRecords));

const isFetchingContacts = computed(
  () => uiFlags.value?.contact?.isFetching ?? false
);
const isFetchingMessages = computed(
  () => uiFlags.value?.message?.isFetching ?? false
);
const isFetching = computed(
  () => isFetchingContacts.value || isFetchingMessages.value
);

const resultCount = computed(
  () => contacts.value.length + messages.value.length
);

const hasNothing = computed(
  () => searching.value && !isFetching.value && resultCount.value === 0
);

const runSearch = q => {
  store.dispatch('conversationSearch/contactSearch', { q, page: 1 });
  store.dispatch('conversationSearch/messageSearch', { q, page: 1 });
};

const clear = () => {
  query.value = '';
  debounced.value = '';
  store.dispatch('conversationSearch/clearSearchResults');
};

watch(query, value => {
  clearTimeout(timer);
  const trimmed = value.trim();

  if (trimmed.length < MIN_LENGTH) {
    debounced.value = '';
    return;
  }

  timer = setTimeout(() => {
    debounced.value = trimmed;
    runSearch(trimmed);
  }, DEBOUNCE_MS);
});

watch(searching, value => emit('update:searching', value), { immediate: true });

onBeforeUnmount(() => clearTimeout(timer));
</script>

<template>
  <div class="flex flex-col min-h-0">
    <div class="flex items-center gap-2 px-3 pb-2">
      <!--
        A caixa é um flex, não um `relative` com ícones absolutos: há uma regra
        global de `padding` em `input` neste produto (foi ela que cortou os
        selects em 28/09) e ela vencia o `ps-9` — o ícone ficava por baixo do
        texto. E o `type` é `text`: com `search`, o browser desenha o seu
        próprio ✕ ao lado do nosso.
      -->
      <div
        class="flex items-center flex-grow min-w-0 h-8 gap-2 px-3 rounded-lg bg-n-alpha-black2 outline outline-1 outline-n-weak focus-within:outline-2 focus-within:outline-n-brand"
      >
        <i
          class="i-lucide-search size-4 shrink-0 text-n-slate-11"
          aria-hidden="true"
        />
        <input
          v-model="query"
          type="text"
          data-testid="raevo-conversation-search-input"
          class="flex-grow min-w-0 !h-full !p-0 text-sm !bg-transparent !border-0 !outline-none text-n-slate-12 placeholder:text-n-slate-10"
          :placeholder="t('RAEVO_CONVERSATION.SEARCH.PLACEHOLDER')"
          :aria-label="t('RAEVO_CONVERSATION.SEARCH.PLACEHOLDER')"
          @keydown.esc="clear"
        />
        <button
          v-if="query"
          type="button"
          data-testid="raevo-conversation-search-clear"
          class="flex items-center shrink-0 text-n-slate-11 hover:text-n-slate-12"
          :aria-label="t('RAEVO_CONVERSATION.SEARCH.CLEAR')"
          :title="t('RAEVO_CONVERSATION.SEARCH.CLEAR')"
          @click="clear"
        >
          <i class="i-lucide-x size-4" aria-hidden="true" />
        </button>
      </div>
      <ComposeConversation align="start">
        <template #trigger="{ isOpen }">
          <Button
            icon="i-lucide-pen-line"
            color="slate"
            size="sm"
            data-testid="raevo-conversation-search-compose"
            :aria-label="t('RAEVO_CONVERSATION.SEARCH.NEW')"
            :title="t('RAEVO_CONVERSATION.SEARCH.NEW')"
            class="!size-8 !outline-n-weak !text-n-slate-11"
            :class="{ '!bg-n-alpha-2': isOpen }"
          />
        </template>
      </ComposeConversation>
    </div>

    <div
      v-if="searching"
      data-testid="raevo-conversation-search-results"
      class="flex flex-col flex-grow gap-4 px-3 pb-3 overflow-y-auto"
    >
      <!--
        Nome e telefone primeiro: é a pessoa que se procura. Cada secção só
        aparece quando tem o que mostrar — o vazio de cada uma é dito uma vez
        só, em baixo, em vez de duas caixas a dizer que não há nada.
      -->
      <SearchResultContactsList
        v-if="contacts.length || isFetchingContacts"
        :contacts="contacts"
        :query="debounced"
        :is-fetching="isFetchingContacts"
      />
      <SearchResultMessagesList
        v-if="messages.length || isFetchingMessages"
        :messages="messages"
        :query="debounced"
        :is-fetching="isFetchingMessages"
      />
      <p
        v-if="hasNothing"
        class="flex items-center gap-2 px-1 text-sm text-n-slate-11"
        role="status"
      >
        <i class="i-lucide-search-x size-4 shrink-0" aria-hidden="true" />
        {{ t('RAEVO_CONVERSATION.SEARCH.EMPTY', { query: debounced }) }}
      </p>
    </div>
  </div>
</template>
