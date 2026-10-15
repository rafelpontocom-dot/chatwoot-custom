<script setup>
import { onMounted, computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useRoute, useRouter } from 'vue-router';

import ContactsDetailsLayout from 'dashboard/components-next/Contacts/ContactsDetailsLayout.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ContactDetails from 'dashboard/components-next/Contacts/Pages/ContactDetails.vue';
import FormsSubmissionDetailsDialog from 'dashboard/routes/dashboard/forms/FormsSubmissionDetailsDialog.vue';
// RAEVO (15/10, 123jpnbcxpd): secções que abrem e fecham em vez de abas.
import RaevoContactSections from '../components/RaevoContactSections.vue';

const store = useStore();
const { isAdmin } = useAdmin();
const route = useRoute();
const router = useRouter();

const contact = useMapGetter('contacts/getContactById');
const uiFlags = useMapGetter('contacts/getUIFlags');

const submissionDialogRef = ref(null);

// Ler a resposta é o que faz a série servir para alguma coisa: sem isto fica
// uma lista de nomes e datas sem porta de entrada.
const openSubmission = submissionId =>
  submissionDialogRef.value?.open(submissionId);

const isFetchingItem = computed(() => uiFlags.value.isFetchingItem);
const isMergingContact = computed(() => uiFlags.value.isMerging);
const isUpdatingContact = computed(() => uiFlags.value.isUpdating);

const selectedContact = computed(() => contact.value(route.params.contactId));

const showSpinner = computed(
  () => isFetchingItem.value || isMergingContact.value
);

const { t } = useI18n();

const goToContactsList = () => {
  if (window.history.state?.back || window.history.length > 1) {
    router.back();
  } else {
    router.push(`/app/accounts/${route.params.accountId}/contacts?page=1`);
  }
};

const fetchActiveContact = async () => {
  if (route.params.contactId) {
    await store.dispatch('contacts/show', { id: route.params.contactId });
    await store.dispatch(
      'contacts/fetchContactableInbox',
      route.params.contactId
    );
  }
};

const fetchContactNotes = () => {
  const { contactId } = route.params;
  if (contactId) store.dispatch('contactNotes/get', { contactId });
};

const fetchContactConversations = () => {
  const { contactId } = route.params;
  if (contactId) store.dispatch('contactConversations/get', contactId);
};

const fetchAttributes = () => {
  store.dispatch('attributes/get');
};

const toggleContactBlock = async isBlocked => {
  const ALERT_MESSAGES = {
    success: {
      block: t('CONTACTS_LAYOUT.HEADER.ACTIONS.BLOCK_SUCCESS_MESSAGE'),
      unblock: t('CONTACTS_LAYOUT.HEADER.ACTIONS.UNBLOCK_SUCCESS_MESSAGE'),
    },
    error: {
      block: t('CONTACTS_LAYOUT.HEADER.ACTIONS.BLOCK_ERROR_MESSAGE'),
      unblock: t('CONTACTS_LAYOUT.HEADER.ACTIONS.UNBLOCK_ERROR_MESSAGE'),
    },
  };

  try {
    await store.dispatch(`contacts/update`, {
      ...selectedContact.value,
      blocked: !isBlocked,
    });
    useAlert(
      isBlocked ? ALERT_MESSAGES.success.unblock : ALERT_MESSAGES.success.block
    );
  } catch (error) {
    useAlert(
      isBlocked ? ALERT_MESSAGES.error.unblock : ALERT_MESSAGES.error.block
    );
  }
};

onMounted(() => {
  fetchActiveContact();
  fetchContactNotes();
  fetchContactConversations();
  fetchAttributes();
});
</script>

<template>
  <div
    class="flex flex-col justify-between flex-1 h-full m-0 overflow-auto bg-n-surface-1"
  >
    <ContactsDetailsLayout
      :button-label="$t('CONTACTS_LAYOUT.HEADER.SEND_MESSAGE')"
      :selected-contact="selectedContact"
      is-detail-view
      :show-pagination-footer="false"
      :is-updating="isUpdatingContact"
      @go-to-contacts-list="goToContactsList"
      @toggle-block="toggleContactBlock"
    >
      <div
        v-if="showSpinner"
        class="flex items-center justify-center py-10 text-n-slate-11"
      >
        <Spinner />
      </div>
      <ContactDetails
        v-else-if="selectedContact"
        :selected-contact="selectedContact"
        @go-to-contacts-list="goToContactsList"
      />
      <template #sidebar>
        <div
          v-if="isFetchingItem"
          class="flex items-center justify-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>
        <RaevoContactSections
          v-else
          :selected-contact="selectedContact"
          :show-forms="isAdmin"
          @go-to-contacts-list="goToContactsList"
          @open-submission="openSubmission"
        />
      </template>
    </ContactsDetailsLayout>
    <FormsSubmissionDetailsDialog ref="submissionDialogRef" />
  </div>
</template>
