<script setup>
import { computed, onBeforeUnmount, ref } from 'vue';
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
const amostra = ref([]);
const mapping = ref({});
const fallbackStageId = ref('');
const aEnviar = ref(false);
const erro = ref('');
const resultado = ref(null);
let sonda = null;

const terminou = computed(() =>
  ['completed', 'failed'].includes(resultado.value?.status)
);

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

// A sonda morre com o diálogo: deixá-la a bater no servidor depois de fechado
// é gastar pedidos por uma resposta que ninguém vai ler.
const pararSonda = () => {
  if (!sonda) return;

  clearInterval(sonda);
  sonda = null;
};

const fechar = () => {
  pararSonda();
  mostrar.value = false;
};

onBeforeUnmount(pararSonda);

/**
 * Perguntar como correu até haver resposta.
 *
 * Sem isto o ecrã dizia «começou» e ficava-se por aí: ninguém sabia quantas
 * linhas entraram nem onde ir buscar as que não entraram — que é a única coisa
 * que interessa depois de uma migração.
 */
const acompanhar = importId => {
  pararSonda();
  sonda = setInterval(async () => {
    try {
      const { data } = await KanbanBoardsAPI.getImport(props.boardId, importId);
      resultado.value = data;
      if (terminou.value) {
        pararSonda();
        emit('imported', data);
      }
    } catch {
      pararSonda();
    }
  }, 2000);
};

// Lê só a primeira linha para saber os cabeçalhos. O ficheiro inteiro é
// trabalho do servidor; aqui só se precisa de saber o que há para emparelhar.
// Separador ingénuo mas suficiente para espreitar: aspas à volta do campo e
// vírgulas dentro delas, que é onde os exports de CRM tropeçam. Quem importa a
// sério é o servidor, com o CSV de verdade.
const separar = linha => {
  const { campos, atual } = [...linha].reduce(
    (estado, caractere) => {
      if (caractere === '"') return { ...estado, aspas: !estado.aspas };
      if (caractere === ',' && !estado.aspas) {
        return {
          campos: [...estado.campos, estado.atual.trim()],
          atual: '',
          aspas: false,
        };
      }

      return { ...estado, atual: estado.atual + caractere };
    },
    { campos: [], atual: '', aspas: false }
  );

  return [...campos, atual.trim()];
};

const lerCabecalhos = async event => {
  const escolhido = event.target.files?.[0];
  ficheiro.value = escolhido || null;
  colunas.value = [];
  amostra.value = [];
  if (!escolhido) return;

  const texto = await escolhido.slice(0, 8192).text();
  const linhas = texto.split(/\r?\n/).filter(Boolean);
  colunas.value = separar(linhas[0] || '');
  // Três linhas chegam para ver se o ficheiro é o que se pensa. Ler mais era
  // fazer no browser o trabalho que o servidor faz melhor.
  amostra.value = linhas.slice(1, 4).map(separar);
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
    acompanhar(data.id);
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

        <!--
          Ver o ficheiro antes de o mandar. Um export com o separador errado ou
          uma coluna a mais nota-se aqui num segundo, e não depois de criar
          trezentos cartões torcidos.
        -->
        <div v-if="amostra.length" class="grid gap-1">
          <p class="mb-0 text-xs font-medium text-n-slate-11">
            {{ t('KANBAN.IMPORT.PREVIEW') }}
          </p>
          <div
            data-testid="kanban-import-preview"
            class="overflow-x-auto rounded-lg border border-solid border-n-weak"
          >
            <table class="w-full border-collapse text-xs">
              <thead>
                <tr class="bg-n-surface-2">
                  <th
                    v-for="coluna in colunas"
                    :key="coluna"
                    class="whitespace-nowrap px-2 py-1.5 text-left font-medium text-n-slate-11"
                  >
                    {{ coluna }}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="(linha, indice) in amostra"
                  :key="indice"
                  class="border-t border-solid border-n-weak"
                >
                  <td
                    v-for="(campo, coluna) in linha"
                    :key="coluna"
                    class="whitespace-nowrap px-2 py-1.5 text-n-slate-12"
                  >
                    {{ campo }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

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
          class="grid gap-3 rounded-xl border border-solid border-n-weak bg-n-surface-1 p-4"
        >
          <template v-if="!terminou">
            <p class="m-0 flex items-center gap-2 text-sm text-n-slate-12">
              <i
                class="i-lucide-loader-circle size-4 animate-spin text-n-slate-11"
                aria-hidden="true"
              />
              {{ t('KANBAN.IMPORT.QUEUED') }}
            </p>
            <p class="m-0 text-xs text-n-slate-11">
              {{ t('KANBAN.IMPORT.QUEUED_HELP') }}
            </p>
          </template>

          <template v-else-if="resultado.status === 'failed'">
            <p
              class="m-0 flex items-center gap-2 text-sm font-medium text-n-ruby-11"
            >
              <i class="i-lucide-x-circle size-4" aria-hidden="true" />
              {{ t('KANBAN.IMPORT.FAILED') }}
            </p>
            <p
              v-if="resultado.processing_errors"
              class="m-0 text-xs text-n-slate-11"
            >
              {{ resultado.processing_errors }}
            </p>
          </template>

          <template v-else>
            <p
              data-testid="kanban-import-counts"
              class="m-0 flex items-center gap-2 text-sm font-medium text-n-slate-12"
            >
              <i
                class="i-lucide-check-circle-2 size-4 text-n-teal-11"
                aria-hidden="true"
              />
              {{
                t('KANBAN.IMPORT.DONE', {
                  imported: resultado.processed_records || 0,
                  total: resultado.total_records || 0,
                })
              }}
            </p>
            <!--
              O que não entrou é a parte que interessa depois de uma migração:
              o ficheiro vem com a razão de cada linha, pronto a corrigir e a
              reenviar.
            -->
            <a
              v-if="resultado.failed_records_url"
              data-testid="kanban-import-failed-link"
              :href="resultado.failed_records_url"
              class="flex items-center gap-2 text-sm font-medium text-n-brand hover:underline"
            >
              <i class="i-lucide-download size-4" aria-hidden="true" />
              {{ t('KANBAN.IMPORT.DOWNLOAD_FAILED') }}
            </a>
          </template>
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
