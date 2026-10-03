<script setup>
import { computed, toRef } from 'vue';
import { useChannelIcon, useChannelBrandIcon } from './provider';
import Icon from 'next/icon/Icon.vue';

const props = defineProps({
  inbox: {
    type: Object,
    required: true,
  },
  // When true, render the full-color brand icon (when one exists for the
  // channel type) and fall back to the monochrome glyph otherwise.
  useBrandIcon: {
    type: Boolean,
    default: false,
  },
});

defineOptions({ inheritAttrs: false });

const inboxRef = toRef(props, 'inbox');

const channelIcon = useChannelIcon(inboxRef);
const brandIcon = useChannelBrandIcon(inboxRef);

const icon = computed(() =>
  props.useBrandIcon && brandIcon.value ? brandIcon.value : channelIcon.value
);
</script>

<template>
  <span class="inline-flex" v-bind="$attrs">
    <!-- Raevo: a imagem que a caixa recebeu em Configurações vale em todo o
         lado. Uma caixa «Canal da API» ligada ao WhatsApp não tem como se
         distinguir pelo tipo, e o glifo `{}` não diz a ninguém que canal é. -->
    <img
      v-if="inbox.avatar_url"
      :src="inbox.avatar_url"
      alt=""
      class="size-full rounded-full object-cover"
    />
    <Icon v-else :icon="icon" class="size-full" />
  </span>
</template>
