<script setup>
import { nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';

// RAEVO (123jpnbcxpg) — excluir o áudio gravado antes de o enviar.
//
// O botão do microfone cortado já descartava a gravação, mas a dica dele diz
// «gravar áudio» e ninguém o lia como apagar. Este diz o que faz e pede
// confirmação no próprio sítio: um áudio de dois minutos não se regrava num
// clique.
const emit = defineEmits(['discard']);
const { t } = useI18n();

const confirming = ref(false);
const confirmButton = ref(null);

const ask = async () => {
  confirming.value = true;
  await nextTick();
  confirmButton.value?.$el?.focus();
};

const confirm = () => {
  confirming.value = false;
  emit('discard');
};
</script>

<template>
  <NextButton
    v-if="!confirming"
    v-tooltip.top-end="t('RAEVO_CONVERSATION.RECORDING.DISCARD')"
    data-testid="raevo-discard-recording"
    icon="i-lucide-trash-2"
    :aria-label="t('RAEVO_CONVERSATION.RECORDING.DISCARD')"
    slate
    faded
    sm
    @click="ask"
  />
  <div
    v-else
    class="flex items-center gap-1"
    role="group"
    :aria-label="t('RAEVO_CONVERSATION.RECORDING.CONFIRM_QUESTION')"
  >
    <NextButton
      ref="confirmButton"
      data-testid="raevo-discard-recording-confirm"
      icon="i-lucide-trash-2"
      :label="t('RAEVO_CONVERSATION.RECORDING.CONFIRM')"
      ruby
      faded
      sm
      @click="confirm"
    />
    <NextButton
      data-testid="raevo-discard-recording-cancel"
      :label="t('RAEVO_CONVERSATION.RECORDING.CANCEL')"
      slate
      faded
      sm
      @click="confirming = false"
    />
  </div>
</template>
