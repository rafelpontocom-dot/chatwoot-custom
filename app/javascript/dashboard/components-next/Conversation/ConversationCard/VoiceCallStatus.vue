<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  VOICE_CALL_STATUS,
  VOICE_CALL_DIRECTION,
} from 'dashboard/components-next/message/constants';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  status: { type: String, default: '' },
  direction: { type: String, default: '' },
});

const { t } = useI18n();

const ICON_MAP = {
  [VOICE_CALL_STATUS.IN_PROGRESS]: 'i-ph-phone-call',
  [VOICE_CALL_STATUS.NO_ANSWER]: 'i-ph-phone-x',
  [VOICE_CALL_STATUS.FAILED]: 'i-ph-phone-x',
  [VOICE_CALL_STATUS.REJECTED]: 'i-ph-phone-x',
};

const COLOR_MAP = {
  [VOICE_CALL_STATUS.IN_PROGRESS]: 'text-n-teal-9',
  [VOICE_CALL_STATUS.RINGING]: 'text-n-teal-9',
  [VOICE_CALL_STATUS.COMPLETED]: 'text-n-slate-11',
  [VOICE_CALL_STATUS.NO_ANSWER]: 'text-n-ruby-9',
  [VOICE_CALL_STATUS.FAILED]: 'text-n-ruby-9',
  [VOICE_CALL_STATUS.REJECTED]: 'text-n-ruby-9',
};

const isOutbound = computed(
  () => props.direction === VOICE_CALL_DIRECTION.OUTBOUND
);
const isFailed = computed(() =>
  [
    VOICE_CALL_STATUS.NO_ANSWER,
    VOICE_CALL_STATUS.FAILED,
    VOICE_CALL_STATUS.REJECTED,
  ].includes(props.status)
);

const label = computed(() => {
  if (props.status === VOICE_CALL_STATUS.IN_PROGRESS) {
    return t('CONVERSATION.VOICE_CALL.CALL_IN_PROGRESS');
  }
  if (props.status === VOICE_CALL_STATUS.COMPLETED) {
    return t('CONVERSATION.VOICE_CALL.CALL_ENDED');
  }
  if (props.status === VOICE_CALL_STATUS.RINGING) {
    return isOutbound.value
      ? t('CONVERSATION.VOICE_CALL.OUTGOING_CALL')
      : t('CONVERSATION.VOICE_CALL.INCOMING_CALL');
  }
  return isFailed.value
    ? t('CONVERSATION.VOICE_CALL.MISSED_CALL')
    : t('CONVERSATION.VOICE_CALL.INCOMING_CALL');
});

const iconName = computed(() => {
  if (ICON_MAP[props.status]) return ICON_MAP[props.status];
  return isOutbound.value ? 'i-ph-phone-outgoing' : 'i-ph-phone-incoming';
});

const statusColor = computed(
  () => COLOR_MAP[props.status] || 'text-n-slate-11'
);
</script>

<template>
  <div class="grid grid-cols-[auto_1fr] items-center gap-1 min-w-0 text-sm">
    <Icon class="size-3.5" :icon="iconName" :class="statusColor" />
    <span class="truncate text-body-main" :class="statusColor">
      {{ label }}
    </span>
  </div>
</template>
