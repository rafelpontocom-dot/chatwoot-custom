<script setup>
import { Handle, Position } from '@vue-flow/core';

const props = defineProps({
  data: {
    type: Object,
    required: true,
  },
});

const selectNode = event => {
  event.preventDefault();
  props.data.select?.(props.data.id);
};

// A largura vivia repetida cinco vezes como valor mágico. As ramificações TÊM
// de acompanhar o corpo, senão o nó parte-se ao meio à primeira alteração.
const LARGURA = 'w-[9.5rem]';

// A categoria era oito matizes: teal, âmbar, violeta, ciano, azul, iris, slate,
// verde. Nunca passaram pelo validador de daltonismo, e azul + iris + violeta
// são três vizinhos — o AGENTS.md proíbe azul + roxo claro por ΔE 0,4. Com oito
// matizes tudo tem cor e nada significa; pior, neste produto a cor já quer dizer
// «etapa do funil». A categoria passa a ser o ícone, e a cor fica para a única
// coisa que precisa de a gastar: o estado.
//
// Sete estados em quatro cores deixavam três pares indistinguíveis — válido e
// concluído ambos verdes, inválido e falhou ambos rubi, rascunho e ignorado
// ambos cinzentos. O ícone é o que os separa, como a regra 5 obriga.
const ESTADOS = {
  draft: {
    class: 'bg-n-alpha-2 text-n-slate-11',
    icon: 'i-lucide-pencil-line',
  },
  valid: { class: 'bg-n-teal-3 text-n-teal-11', icon: 'i-lucide-check' },
  invalid: {
    class: 'bg-n-ruby-3 text-n-ruby-11',
    icon: 'i-lucide-circle-alert',
  },
  waiting: { class: 'bg-n-amber-3 text-n-amber-11', icon: 'i-lucide-pause' },
  completed: {
    class: 'bg-n-teal-3 text-n-teal-11',
    icon: 'i-lucide-circle-check',
  },
  skipped: {
    class: 'bg-n-alpha-2 text-n-slate-11',
    icon: 'i-lucide-skip-forward',
  },
  failed: { class: 'bg-n-ruby-3 text-n-ruby-11', icon: 'i-lucide-x' },
};

const estado = state => ESTADOS[state] || ESTADOS.draft;
</script>

<template>
  <Handle
    v-if="data.kind !== 'trigger'"
    type="target"
    :position="Position.Left"
    class="!size-3 !border-2 !border-n-surface-1 !bg-n-slate-9"
  />
  <!--
    Em repouso o anel de 1px separa; a sombra fica para o que flutua. `shadow-sm`
    é `none` de propósito, por isso o cartão não tinha separação nenhuma em
    repouso e depois saltava com `hover:shadow-md` — o contrário da regra 3.
  -->
  <div
    data-testid="kanban-workflow-node-card"
    :data-category="data.category"
    :aria-label="data.label"
    role="group"
    tabindex="0"
    class="grid content-start gap-1 rounded-lg bg-n-surface-1 px-3 py-2 ring-1 transition-[box-shadow] hover:ring-n-slate-6 focus:outline-none focus:ring-2 focus:ring-n-brand"
    :class="[LARGURA, data.invalid ? 'ring-2 ring-n-ruby-9' : 'ring-n-weak']"
    @keydown.enter="selectNode"
    @keydown.space="selectNode"
  >
    <div class="flex items-start gap-2">
      <span
        class="flex size-7 shrink-0 items-center justify-center rounded-md bg-n-alpha-1 text-n-slate-11"
      >
        <i
          v-if="data.icon"
          data-testid="kanban-workflow-node-icon"
          class="size-3.5"
          :class="data.icon"
          aria-hidden="true"
        />
      </span>
      <div class="min-w-0 flex-1">
        <p
          data-testid="kanban-workflow-node-category"
          class="m-0 truncate text-micro font-semibold uppercase tracking-wide text-n-slate-10"
        >
          {{ data.categoryLabel || data.category }}
        </p>
        <!--
          Duas linhas fixas, não uma cortada: «Enviar mensagem de seguimento no
          WhatsApp» não cabe numa. A altura é a mesma para todos os nós, com
          nome curto ou longo — é o que dá dimensão estável ao cartão.
        -->
        <p
          class="m-0 line-clamp-2 min-h-8 break-words text-xs font-semibold leading-snug text-n-slate-12"
        >
          {{ data.label }}
        </p>
      </div>
      <i
        v-if="data.invalid"
        class="i-lucide-circle-alert size-3.5 shrink-0 text-n-ruby-11"
        aria-hidden="true"
      />
    </div>
    <p class="m-0 h-4 truncate text-micro leading-4 text-n-slate-10">
      {{ data.summary }}
    </p>
    <!--
      O rodapé está sempre presente, mesmo vazio. Aparecer e desaparecer com o
      conteúdo era metade da instabilidade de altura.
    -->
    <div class="flex min-h-5 items-center gap-1.5">
      <span
        v-if="data.stateLabel"
        data-testid="kanban-workflow-node-state"
        class="inline-flex min-w-0 items-center gap-1 rounded-full px-1.5 py-0.5 text-micro font-medium"
        :class="estado(data.state).class"
      >
        <i
          class="size-2.5 shrink-0"
          :class="estado(data.state).icon"
          aria-hidden="true"
        />
        <span class="truncate">{{ data.stateLabel }}</span>
      </span>
      <!--
        A fila de chips crescia em altura e empurrava o cartão. Passa a contagem;
        o detalhe vive no inspector, que é onde se configura.
      -->
      <span
        v-if="data.chips?.length"
        data-testid="kanban-workflow-node-chips"
        class="ml-auto inline-flex shrink-0 items-center gap-1 text-micro tabular-nums text-n-slate-10"
        :title="data.chips.join(' · ')"
      >
        <i class="i-lucide-sliders-horizontal size-2.5" aria-hidden="true" />
        {{ data.chips.length }}
      </span>
    </div>
  </div>
  <template v-if="data.kind === 'condition'">
    <div
      v-for="branch in data.branches"
      :key="branch.id"
      :class="LARGURA"
      class="nodrag nopan relative -mt-px flex items-center gap-2 border border-n-weak bg-n-surface-1 px-3 py-1.5 text-xs text-n-slate-11 first:mt-1"
    >
      <span class="min-w-0 flex-1 break-words">{{ branch.label }}</span>
      <button
        type="button"
        class="flex p-0 size-5 items-center justify-center rounded text-n-brand hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="data.addAfterLabel"
        @click.stop="data.addAfterOption(data.id, branch.id)"
      >
        <i class="i-lucide-plus size-3" />
      </button>
      <Handle
        :id="branch.id"
        type="source"
        :position="Position.Right"
        class="!static !size-3 !border-2 !border-n-surface-1 !bg-n-brand"
      />
    </div>
    <div
      :class="LARGURA"
      class="nodrag nopan relative -mt-px flex items-center gap-2 border border-n-weak bg-n-surface-2 px-3 py-1.5 text-xs font-medium text-n-slate-11"
    >
      <span class="min-w-0 flex-1 break-words">{{ data.fallbackLabel }}</span>
      <button
        type="button"
        class="flex p-0 size-5 items-center justify-center rounded text-n-brand hover:bg-n-surface-1 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="data.addAfterLabel"
        @click.stop="data.addAfterOption(data.id, data.fallbackId)"
      >
        <i class="i-lucide-plus size-3" />
      </button>
      <Handle
        :id="data.fallbackId"
        type="source"
        :position="Position.Right"
        class="!static !size-3 !border-2 !border-n-surface-1 !bg-n-ruby-9"
      />
    </div>
  </template>
  <template v-else-if="data.kind === 'round_robin'">
    <div
      v-for="option in data.options"
      :key="option.id"
      :class="LARGURA"
      class="nodrag nopan relative -mt-px flex items-center gap-2 border border-n-weak bg-n-surface-1 px-3 py-1.5 text-xs text-n-slate-11 first:mt-1"
    >
      <span class="min-w-0 flex-1 truncate">{{ option.label }}</span>
      <button
        type="button"
        class="flex p-0 size-5 items-center justify-center rounded text-n-brand hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="data.addAfterLabel"
        @click.stop="data.addAfterOption(data.id, option.id)"
      >
        <i class="i-lucide-plus size-3" />
      </button>
      <Handle
        :id="option.id"
        type="source"
        :position="Position.Right"
        class="!static !size-3 !border-2 !border-n-surface-1 !bg-n-brand"
      />
    </div>
  </template>
  <template
    v-else-if="
      [
        'message_eligibility',
        'duplicate_check',
        'send_message',
        'wait_until_field',
        'wait_for_response',
        'wait_for_inactivity',
        'wait_for_business_hours',
        'webhook',
      ].includes(data.kind) && data.outputs
    "
  >
    <div
      v-for="output in data.outputs"
      :key="output.id"
      :class="LARGURA"
      class="nodrag nopan relative -mt-px flex items-center gap-2 border border-n-weak bg-n-surface-1 px-3 py-1.5 text-xs text-n-slate-11 first:mt-1"
    >
      <span class="min-w-0 flex-1 truncate">{{ output.label }}</span>
      <button
        type="button"
        class="flex p-0 size-5 items-center justify-center rounded text-n-brand hover:bg-n-surface-2 focus:outline-none focus:ring-2 focus:ring-n-brand"
        :aria-label="data.addAfterLabel"
        @click.stop="data.addAfterOption(data.id, output.id)"
      >
        <i class="i-lucide-plus size-3" />
      </button>
      <Handle
        :id="output.id"
        type="source"
        :position="Position.Right"
        class="!static !size-3 !border-2 !border-n-surface-1 !bg-n-brand"
      />
    </div>
  </template>
  <button
    v-else-if="data.canAddAfter"
    type="button"
    class="nodrag nopan absolute -right-3 top-full z-10 flex p-0 size-6 -translate-y-1/2 items-center justify-center rounded-full border border-solid border-n-brand bg-n-surface-1 text-n-brand shadow-sm hover:bg-n-brand hover:text-n-solid-1 focus:outline-none focus:ring-2 focus:ring-n-brand"
    :aria-label="data.addAfterLabel"
    @click.stop="data.addAfter(data.id)"
  >
    <i class="i-lucide-plus size-3" />
  </button>
  <Handle
    v-if="
      !data.terminal &&
      data.kind !== 'end' &&
      ![
        'condition',
        'duplicate_check',
        'round_robin',
        'message_eligibility',
        'send_message',
        'wait_for_response',
        'wait_for_inactivity',
        'wait_for_business_hours',
        'webhook',
      ].includes(data.kind) &&
      !(data.kind === 'wait_until_field' && data.outputs)
    "
    type="source"
    :position="Position.Right"
    class="!size-3 !border-2 !border-n-surface-1 !bg-n-brand"
  />
</template>
