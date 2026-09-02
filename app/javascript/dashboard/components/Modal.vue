<script setup>
// [TODO] Use Teleport to move the modal to the end of the body
import { ref, computed, nextTick, onMounted, watch } from 'vue';
import { useEventListener } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';

const { modalType, closeOnBackdropClick, onClose } = defineProps({
  closeOnBackdropClick: { type: Boolean, default: true },
  showCloseButton: { type: Boolean, default: true },
  onClose: { type: Function, required: true },
  fullWidth: { type: Boolean, default: false },
  modalType: { type: String, default: 'centered' },
  size: { type: String, default: '' },
});

const emit = defineEmits(['close']);
const show = defineModel('show', { type: Boolean, default: false });

const modalClassName = computed(() => {
  const modalClassNameMap = {
    centered: '',
    'right-aligned': 'right-aligned',
  };

  return `modal-mask skip-context-menu ${modalClassNameMap[modalType] || ''}`;
});

// [TODO] Revisit this logic to use outside click directive
const mousedDownOnBackdrop = ref(false);
const containerRef = ref(null);

const handleMouseDown = () => {
  mousedDownOnBackdrop.value = true;
};

// Quem tinha o foco quando o modal abriu. Sem isto, fechar devolve o foco ao
// `body` e quem navega por teclado recomeça do topo da página.
const elementoQueAbriu = ref(null);

const close = () => {
  show.value = false;
  emit('close');
  onClose();
  const anterior = elementoQueAbriu.value;
  elementoQueAbriu.value = null;
  nextTick(() => anterior?.focus?.());
};

const onMouseUp = () => {
  if (mousedDownOnBackdrop.value) {
    mousedDownOnBackdrop.value = false;
    if (closeOnBackdropClick) {
      close();
    }
  }
};

// Qual dos modais abertos está por cima. Comparar pela ordem no documento é
// suficiente: quem monta depois renderiza depois e fica visualmente à frente.
const ehOTopo = () => {
  const caixa = containerRef.value;
  if (!caixa) return false;

  const abertos = [...document.querySelectorAll('.modal-mask')];
  return abertos[abertos.length - 1]?.contains(caixa) ?? false;
};

// Um diálogo que se declara `aria-modal` mas deixa o Tab sair não é modal:
// o foco vai parar a controlos tapados pelo próprio diálogo, que o leitor de
// ecrã anunciou como inertes. O ciclo fecha-se aqui, no primeiro e no último
// focável — não em cada componente que abre um modal.
const FOCUSAVEIS =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), summary, [tabindex]:not([tabindex="-1"])';

const prenderFoco = e => {
  const caixa = containerRef.value;
  if (!caixa) return;

  const alvos = [...caixa.querySelectorAll(FOCUSAVEIS)].filter(
    alvo => alvo.offsetParent !== null || alvo === document.activeElement
  );
  if (!alvos.length) {
    e.preventDefault();
    caixa.focus();
    return;
  }

  const primeiro = alvos[0];
  const ultimo = alvos[alvos.length - 1];
  const atual = document.activeElement;

  if (!caixa.contains(atual)) {
    e.preventDefault();
    (e.shiftKey ? ultimo : primeiro).focus();
    return;
  }
  if (e.shiftKey && atual === primeiro) {
    e.preventDefault();
    ultimo.focus();
  } else if (!e.shiftKey && atual === ultimo) {
    e.preventDefault();
    primeiro.focus();
  }
};

const onKeydown = e => {
  if (!show.value) return;

  if (e.code === 'Escape') {
    close();
    e.stopPropagation();
    return;
  }
  // Só o diálogo mais acima responde: com modais empilhados, o de baixo não
  // pode roubar o foco ao de cima.
  if (e.key === 'Tab' && ehOTopo()) prenderFoco(e);
};

useEventListener(document.body, 'mouseup', onMouseUp);
useEventListener(document, 'keydown', onKeydown);

watch(
  show,
  aberto => {
    if (!aberto) return;

    elementoQueAbriu.value = document.activeElement;
    // O foco entra no diálogo: no primeiro campo, se existir, senão no próprio
    // contentor. Ficar de fora deixa a leitura a meio da página por trás.
    nextTick(() => {
      const caixa = containerRef.value;
      const primeiro = caixa?.querySelector(
        'input:not([type=hidden]), textarea, select'
      );
      (primeiro || caixa)?.focus?.();
    });
  },
  { immediate: true }
);

onMounted(() => {
  if (import.meta.env.DEV && onClose && typeof onClose === 'function') {
    // eslint-disable-next-line no-console
    console.warn(
      "[DEPRECATED] The 'onClose' prop is deprecated. Please use the 'close' event instead."
    );
  }
});
</script>

<template>
  <transition name="modal-fade">
    <div
      v-if="show"
      :class="modalClassName"
      transition="modal"
      @mousedown="handleMouseDown"
    >
      <div
        ref="containerRef"
        role="dialog"
        aria-modal="true"
        tabindex="-1"
        class="relative max-h-full overflow-auto bg-n-alpha-3 shadow-md modal-container rtl:text-right skip-context-menu outline-none"
        :class="{
          'rounded-xl w-[37.5rem]': !fullWidth,
          'items-center rounded-none flex h-full justify-center w-full':
            fullWidth,
          [size]: true,
        }"
        @mouse.stop
        @mousedown="event => event.stopPropagation()"
      >
        <Button
          v-if="showCloseButton"
          ghost
          slate
          icon="i-lucide-x"
          class="absolute z-10 ltr:right-2 rtl:left-2 top-2"
          @click="close"
        />
        <slot />
      </div>
    </div>
  </transition>
</template>

<style lang="scss">
.modal-mask {
  @apply flex items-center justify-center bg-n-alpha-black2 backdrop-blur-[4px] z-[9990] h-full left-0 fixed top-0 w-full;

  .modal-container {
    &.medium {
      @apply max-w-[80%] w-[56.25rem];
    }

    // .content-box {
    //   @apply h-auto p-0;
    // }
    .content {
      @apply p-8;
    }

    form,
    .modal-content {
      @apply pt-4 pb-8 px-8 self-center;

      a {
        @apply p-4;
      }

      .ProseMirror a {
        @apply p-0;
      }
    }
  }
}

.modal-big {
  @apply w-full;
}

.modal-mask.right-aligned {
  @apply justify-end;

  .modal-container {
    @apply rounded-none h-full w-[30rem];
  }
}

.modal-enter,
.modal-leave {
  @apply opacity-0;
}

.modal-enter .modal-container,
.modal-leave .modal-container {
  transform: scale(1.1);
}
</style>
