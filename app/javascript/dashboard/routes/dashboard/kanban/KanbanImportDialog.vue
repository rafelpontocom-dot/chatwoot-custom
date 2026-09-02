<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';
import KanbanBoardsAPI from 'dashboard/api/kanbanBoards';

/**
 * Importar oportunidades de outro CRM.
 *
 * Emparelhar colunas antes de importar é o que separa uma migração de um
 * estrago: vê-se o que vai acontecer enquanto ainda dá para mudar. O ficheiro
 * de origem não precisa de usar os nossos nomes.
 */
const props = defineProps({
  boardId: { type: [String, Number], required: true },
  stages: { type: Array, default: () => [] },
  fieldDefinitions: { type: Array, default: () => [] },
});
const emit = defineEmits(['imported']);

const { t } = useI18n();

const mostrar = ref(false);
const ficheiro = ref(null);
const colunas = ref([]);
const mapping = ref({});
const fallbackStageId = ref('');
const aEnviar = ref(false);
const erro = ref('');
const resultado = ref(null);

// Colunas que o importador já entende sozinho: mostrá-las no emparelhamento
// era pedir para mapear o que não precisa de mapa.
const COLUNAS_NATIVAS = [
  'email',
  'e-mail',
  'telefone',
  'phone',
  'telemovel',
  'celular',
  'assunto',
  'subject',
  'titulo',
  'title',
  'oportunidade',
  'etapa',
  'stage',
  'fase',
  'status',
  'valor',
  'amount',
];

const colunasPorMapear = computed(() =>
  colunas.value.filter(
    coluna => !COLUNAS_NATIVAS.includes(coluna.trim().toLowerCase())
  )
);

const abrir = () => {
  ficheiro.value = null;
  colunas.value = [];
  mapping.value = {};
  fallbackStageId.value = props.stages[0]?.id || '';
  erro.value = '';
  resultado.value = null;
  mostrar.value = true;
};

const fechar = () => {
  mostrar.value = false;
};

// Lê só a primeira linha para saber os cabeçalhos. O ficheiro inteiro é
// trabalho do servidor; aqui só se precisa de saber o que há para emparelhar.
const lerCabecalhos = async event => {
  const escolhido = event.target.files?.[0];
  ficheiro.value = escolhido || null;
  colunas.value = [];
  if (!escolhido) return;

  const texto = await escolhido.slice(0, 4096).text();
  const primeira = texto.split(/\r?\n/)[0] || '';
  colunas.value = primeira
    .split(',')
    .map(coluna => coluna.replace(/^"|"$/g, '').trim())
    .filter(Boolean);
};

const importar = async () => {
  if (!ficheiro.value || aEnviar.value) return;

  aEnviar.value = true;
  erro.value = '';
  try {
    const { data } = await KanbanBoardsAPI.importOpportunities(props.boardId, {
      file: ficheiro.value,
      fallbackStageId: fallbackStageId.value,
      mapping: mapping.value,
    });
    resultado.value = data;
    emit('imported', data);
  } catch (e) {
    erro.value = e?.response?.data?.error || t('KANBAN.IMPORT.ERROR_GENERIC');
  } finally {
    aEnviar.value = false;
  }
};

defineExpose({ abrir });
</script>

<template>
  <Modal v-model:show="mostrar" :show-close-button="false" :on-close="fechar">
    <section
      v-if="mostrar"
      data-testid="kanban-import-dialog"
      class="grid w-[min(100vw-2rem,34rem)] gap-4 p-5"
      :aria-label="t('KANBAN.IMPORT.TITLE')"
    >
      <div>
        <h3 class="mb-0 text-base font-medium text-n-slate-12">
          {{ t('KANBAN.IMPORT.TITLE') }}
        </h3>
        <p class="mb-0 mt-1 text-sm text-n-slate-11">
          {{ t('KANBAN.IMPORT.DESCRIPTION') }}
        </p>
      </div>

      <template v-if="!resultado">
        <RaevoField :label="t('KANBAN.IMPORT.FILE')">
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              data-testid="kanban-import-file"
              type="file"
              accept=".csv,text/csv"
              class="py-2 leading-6"
              :class="controlClass"
              @change="lerCabecalhos"
            />
          </template>
        </RaevoField>

        <RaevoField
          :label="t('KANBAN.IMPORT.FALLBACK_STAGE')"
          :hint="t('KANBAN.IMPORT.FALLBACK_STAGE_HELP')"
          variant="select"
        >
          <template #default="{ controlClass, fieldId }">
            <select
              :id="fieldId"
              v-model="fallbackStageId"
              data-testid="kanban-import-fallback-stage"
              :class="controlClass"
            >
              <option v-for="stage in stages" :key="stage.id" :value="stage.id">
                {{ stage.name }}
              </option>
            </select>
          </template>
        </RaevoField>

        <div v-if="colunasPorMapear.length" class="grid gap-2">
          <p class="mb-0 text-xs font-medium text-n-slate-11">
            {{ t('KANBAN.IMPORT.MAPPING') }}
          </p>
          <div
            v-for="coluna in colunasPorMapear"
            :key="coluna"
            class="grid grid-cols-[minmax(0,1fr)_minmax(0,1fr)] items-center gap-3"
          >
            <span class="min-w-0 break-words text-sm text-n-slate-12">
              {{ coluna }}
            </span>
            <select
              v-model="mapping[coluna]"
              :data-testid="`kanban-import-map-${coluna}`"
              class="reset-base mb-0 h-9 w-full rounded-full border border-solid border-n-strong bg-n-surface-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-brand"
            >
              <option value="">{{ t('KANBAN.IMPORT.IGNORE') }}</option>
              <option
                v-for="definition in fieldDefinitions"
                :key="definition.key"
                :value="definition.key"
              >
                {{ definition.label || definition.key }}
              </option>
            </select>
          </div>
        </div>

        <p v-if="erro" class="m-0 text-sm text-n-ruby-11" role="alert">
          {{ erro }}
        </p>

        <div class="flex justify-end gap-2">
          <Button
            type="button"
            :label="t('KANBAN.ACTIONS.CANCEL')"
            color="slate"
            size="sm"
            @click="fechar"
          />
          <Button
            type="button"
            data-testid="kanban-import-submit"
            icon="i-lucide-upload"
            :label="t('KANBAN.IMPORT.SUBMIT')"
            color="blue"
            size="sm"
            :disabled="!ficheiro"
            :is-loading="aEnviar"
            @click="importar"
          />
        </div>
      </template>

      <template v-else>
        <div
          data-testid="kanban-import-result"
          class="grid gap-2 rounded-xl border border-solid border-n-weak bg-n-surface-1 p-4"
        >
          <p class="m-0 text-sm text-n-slate-12">
            {{ t('KANBAN.IMPORT.QUEUED') }}
          </p>
          <p class="m-0 text-xs text-n-slate-11">
            {{ t('KANBAN.IMPORT.QUEUED_HELP') }}
          </p>
        </div>
        <div class="flex justify-end">
          <Button
            type="button"
            :label="t('KANBAN.ACTIONS.CLOSE')"
            color="blue"
            size="sm"
            @click="fechar"
          />
        </div>
      </template>
    </section>
  </Modal>
</template>
