<script setup>
import { reactive, ref, computed, onMounted, watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useAlert } from 'dashboard/composables';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';
import { ExceptionWithMessage } from 'shared/helpers/CustomErrors';
import { debounce } from '@chatwoot/utils';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import {
  createContactSearcher,
  createNewContact,
  fetchContactableInboxes,
  processContactableInboxes,
  mergeInboxDetails,
} from 'dashboard/components-next/NewConversation/helpers/composeConversationHelper';

import Popover from 'dashboard/components-next/popover/Popover.vue';
import ComposeNewConversationForm from 'dashboard/components-next/NewConversation/components/ComposeNewConversationForm.vue';

const props = defineProps({
  contactId: {
    type: String,
    default: null,
  },
  align: {
    type: String,
    default: 'end',
  },
});

const emit = defineEmits(['close']);

const searchContacts = createContactSearcher();
const store = useStore();
const { t } = useI18n();

const { fetchSignatureFlagFromUISettings } = useUISettings();

const popoverRef = ref(null);
const contacts = ref([]);
const selectedContact = ref(null);
const targetInbox = ref(null);
const isCreatingContact = ref(false);
const isFetchingInboxes = ref(false);
const isSearching = ref(false);

const formState = reactive({
  message: '',
  subject: '',
  ccEmails: '',
  bccEmails: '',
  attachedFiles: [],
});

const clearFormState = () => {
  Object.assign(formState, {
    subject: '',
    ccEmails: '',
    bccEmails: '',
    attachedFiles: [],
  });
};

const contactById = useMapGetter('contacts/getContactById');
const contactsUiFlags = useMapGetter('contacts/getUIFlags');
const currentUser = useMapGetter('getCurrentUser');
const globalConfig = useMapGetter('globalConfig/get');
const uiFlags = useMapGetter('contactConversations/getUIFlags');
const messageSignature = useMapGetter('getMessageSignature');
const inboxesList = useMapGetter('inboxes/getInboxes');

const sendWithSignature = computed(() =>
  fetchSignatureFlagFromUISettings(targetInbox.value?.channelType)
);

const directUploadsEnabled = computed(
  () => globalConfig.value.directUploadsEnabled
);

const activeContact = computed(() => contactById.value(props.contactId));

const onContactSearch = debounce(
  async query => {
    isSearching.value = true;
    contacts.value = [];
    try {
      const results = await searchContacts(query);
      // null means the request was aborted (a newer search is in-flight),
      if (results === null) return;
      contacts.value = results;
      isSearching.value = false;
    } catch (error) {
      isSearching.value = false;
      useAlert(t('COMPOSE_NEW_CONVERSATION.CONTACT_SEARCH.ERROR_MESSAGE'));
    }
  },
  400,
  false
);

const resetContacts = () => {
  contacts.value = [];
};

const handleSelectedContact = async ({ value, action, ...rest }) => {
  let contact;
  if (action === 'create') {
    isCreatingContact.value = true;
    try {
      contact = await createNewContact(value);
      isCreatingContact.value = false;
    } catch (error) {
      isCreatingContact.value = false;
      const message = parseAPIErrorResponse(error);
      useAlert(
        typeof message === 'string'
          ? message
          : t('COMPOSE_NEW_CONVERSATION.CONTACT_CREATE.ERROR_MESSAGE')
      );
      return;
    }
  } else {
    contact = rest;
  }
  selectedContact.value = contact;
  contacts.value = [];
  if (contact?.id) {
    isFetchingInboxes.value = true;
    try {
      const contactableInboxes = await fetchContactableInboxes(contact.id);
      // Merge the processed contactableInboxes with the inboxesList
      selectedContact.value.contactInboxes = mergeInboxDetails(
        contactableInboxes,
        inboxesList.value
      );

      isFetchingInboxes.value = false;
    } catch (error) {
      isFetchingInboxes.value = false;
    }
  }
};

const handleTargetInbox = inbox => {
  targetInbox.value = inbox;
  if (!inbox) clearFormState();
  resetContacts();
};

const clearSelectedContact = () => {
  selectedContact.value = null;
  targetInbox.value = null;
  clearFormState();
};

const closeCompose = () => {
  popoverRef.value?.hide();
  if (!props.contactId) {
    // If contactId is passed as prop
    // Then don't allow to remove the selected contact
    selectedContact.value = null;
  }
  targetInbox.value = null;
  resetContacts();
};

const discardCompose = () => {
  clearFormState();
  formState.message = '';
  closeCompose();
};

const createConversation = async ({ payload, isFromWhatsApp }) => {
  try {
    const data = await store.dispatch('contactConversations/create', {
      params: payload,
      isFromWhatsApp,
    });
    const action = {
      type: 'link',
      to: `/app/accounts/${data.account_id}/conversations/${data.id}`,
      message: t('COMPOSE_NEW_CONVERSATION.FORM.GO_TO_CONVERSATION'),
    };
    discardCompose();
    useAlert(t('COMPOSE_NEW_CONVERSATION.FORM.SUCCESS_MESSAGE'), action);
    return true; // Return success
  } catch (error) {
    useAlert(
      error instanceof ExceptionWithMessage
        ? error.data
        : t('COMPOSE_NEW_CONVERSATION.FORM.ERROR_MESSAGE')
    );
    return false; // Return failure
  }
};

// Com `contactId` fixo o campo de busca fica desligado: se o contato não chegar,
// o «Para:» fica em branco e não há como escolher ninguém. Quem abre o compositor
// a partir do funil não passou pela tela de Contatos, então o contato não está no
// store — é preciso ir buscá-lo.
//
// `getContactById` devolve `{}` quando não conhece o id, e `{}` é verdadeiro:
// testar o objeto dizia sempre que o contato existia, e a busca das caixas ia
// com `id` indefinido — 404, lista vazia, «Não há caixas de entrada disponíveis».
// O que se pergunta é pelo `id`, não pelo objeto.
const contactInStore = id => {
  const record = contactById.value(id);
  return record?.id ? record : null;
};

// As caixas vêm de `contactable_inboxes`, não dos vínculos que o contato já tem.
// Uma oportunidade que nunca teve conversa tem contato sem vínculo nenhum: pelos
// vínculos a lista vinha vazia e a tela dizia que não havia caixa disponível. O
// que interessa é por onde ele PODE ser alcançado — o mesmo caminho que o contato
// escolhido na busca já usava.
const withContactableInboxes = async contact => {
  isFetchingInboxes.value = true;
  try {
    const contactableInboxes = await fetchContactableInboxes(contact.id);
    return mergeInboxDetails(contactableInboxes, inboxesList.value);
  } catch (error) {
    return mergeInboxDetails(
      processContactableInboxes(contact.contactInboxes || []),
      inboxesList.value
    );
  } finally {
    isFetchingInboxes.value = false;
  }
};

// Só ao abrir. Num funil com 23 oportunidades sem conversa há 23 destes na tela,
// e buscar contato e caixas ao montar eram 46 pedidos para abrir um quadro.
const loadFixedContact = async () => {
  const id = props.contactId;
  if (!id) return;

  if (!contactInStore(id)) await store.dispatch('contacts/show', { id });
  const contact = contactInStore(id);
  if (!contact) return;

  selectedContact.value = { ...contact, contactInboxes: [] };
  const contactInboxes = await withContactableInboxes(contact);
  if (selectedContact.value?.id === contact.id) {
    selectedContact.value = { ...selectedContact.value, contactInboxes };
  }
};

const onPopoverShow = () => {
  // Flag to prevent triggering drag n drop,
  // When compose modal is active
  emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, true);
  loadFixedContact();
  // Cache-aware refetch, so newly synced WhatsApp templates show up here
  // even if the account-cache-invalidated websocket event was missed.
  store.dispatch('inboxes/get');
};

const onPopoverHide = () => {
  emitter.emit(BUS_EVENTS.NEW_CONVERSATION_MODAL, false);
  emit('close');
};

watch(
  activeContact,
  (currentContact, previousContact) => {
    if (currentContact?.id && props.contactId) {
      // Reset on contact change
      if (currentContact?.id !== previousContact?.id) {
        clearSelectedContact();
        clearFormState();
        formState.message = '';
      }

      // First process the contactable inboxes to get the right structure
      const processedInboxes = processContactableInboxes(
        currentContact.contactInboxes || []
      );
      // Then Merge processedInboxes with the inboxes list
      selectedContact.value = {
        ...currentContact,
        contactInboxes: mergeInboxDetails(processedInboxes, inboxesList.value),
      };
    }
  },
  { immediate: true, deep: true }
);

onMounted(() => resetContacts());
</script>

<template>
  <Popover
    ref="popoverRef"
    :align="align"
    :show-content-border="false"
    :close-on-scroll="false"
    @show="onPopoverShow"
    @hide="onPopoverHide"
  >
    <template #default="{ isOpen }">
      <slot name="trigger" :is-open="isOpen" />
    </template>
    <template #content>
      <ComposeNewConversationForm
        :form-state="formState"
        :contacts="contacts"
        :contact-id="contactId"
        :is-loading="isSearching"
        :current-user="currentUser"
        :selected-contact="selectedContact"
        :target-inbox="targetInbox"
        :is-creating-contact="isCreatingContact"
        :is-fetching-inboxes="isFetchingInboxes"
        :is-direct-uploads-enabled="directUploadsEnabled"
        :contact-conversations-ui-flags="uiFlags"
        :contacts-ui-flags="contactsUiFlags"
        :message-signature="messageSignature"
        :send-with-signature="sendWithSignature"
        @search-contacts="onContactSearch"
        @reset-contact-search="resetContacts"
        @update-selected-contact="handleSelectedContact"
        @update-target-inbox="handleTargetInbox"
        @clear-selected-contact="clearSelectedContact"
        @create-conversation="createConversation"
        @discard="discardCompose"
      />
    </template>
  </Popover>
</template>
