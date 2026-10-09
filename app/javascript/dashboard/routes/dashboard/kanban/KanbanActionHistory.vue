<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import NextButton from 'dashboard/components-next/button/Button.vue';
import RaevoKpiCard from 'dashboard/components-next/raevo/RaevoKpiCard.vue';
import { iconForActionType } from 'dashboard/helper/kanbanActionIcon';

// RAEVO (09/10, 123jpnbcb5j) — o histórico das ações, como na maquete aprovada:
// a linha de números (ações, dias, prazo), cada ação com prevista/feita, quem a
// fez e o resultado, e «Fechou com N ações em D dias» numa oportunidade ganha.
// Conta só as ações concluídas — conversas e chamadas não (escolha de 08/10).
const props = defineProps({
  history: { type: Array, default: () => [] },
  /** `created_at` do cartão: segundos (como vem do servidor) ou data. */
  createdAt: { type: [Number, String], default: null },
  wonAt: { type: String, default: null },
  lostAt: { type: String, default: null },
});

const { t } = useI18n();

const VISIVEIS = 3;
const DIA_MS = 24 * 60 * 60 * 1000;

const comoData = valor =>
  typeof valor === 'number' ? new Date(valor * 1000) : new Date(valor);
// Dias de calendário no fuso de quem lê: feita no mesmo dia é feita no prazo.
const diaLocal = data =>
  new Date(data.getFullYear(), data.getMonth(), data.getDate()).getTime();
const diasEntre = (inicio, fim) =>
  Math.round((diaLocal(fim) - diaLocal(inicio)) / DIA_MS);

const formato = new Intl.DateTimeFormat(undefined, {
  day: '2-digit',
  month: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
});
const dataCurta = valor => formato.format(new Date(valor));
const dias = count =>
  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.DAYS', { count });

const acoes = computed(() =>
  props.history
    .slice()
    .reverse()
    .map((entrada, indice) => {
      const feita = new Date(entrada.completed_at);
      const prevista = entrada.scheduled_at
        ? new Date(entrada.scheduled_at)
        : null;
      const atraso = prevista ? diasEntre(prevista, feita) : 0;
      return {
        chave: `${entrada.completed_at}-${indice}`,
        tipo: entrada.type,
        icone: iconForActionType(entrada.type),
        quem: entrada.completed_by?.name || '',
        prevista: prevista ? dataCurta(prevista) : '',
        feita: dataCurta(feita),
        atraso: atraso > 0 ? atraso : 0,
        noPrazo: prevista ? atraso <= 0 : null,
        resultado: entrada.completion_note || '',
        observacao: entrada.note || '',
      };
    })
);

const mostrarTodas = ref(false);
const visiveis = computed(() =>
  mostrarTodas.value ? acoes.value : acoes.value.slice(0, VISIVEIS)
);
const escondidas = computed(() => acoes.value.length - visiveis.value.length);

const fim = computed(() => props.wonAt || props.lostAt || null);
const diasDoCartao = computed(() => {
  if (!props.createdAt) return null;
  return diasEntre(
    comoData(props.createdAt),
    fim.value ? new Date(fim.value) : new Date()
  );
});
const rotuloDosDias = computed(() => {
  if (props.wonAt) return t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.TO_WIN');
  if (props.lostAt) {
    return t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.TO_LOSE');
  }
  return t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.OPEN_FOR');
});

const comPrazo = computed(() =>
  acoes.value.filter(acao => acao.noPrazo !== null)
);
const noPrazo = computed(
  () => comPrazo.value.filter(acao => acao.noPrazo).length
);

const resumoGanha = computed(() =>
  props.wonAt && diasDoCartao.value !== null
    ? t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.WON_SUMMARY', {
        actions: t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.ACTIONS_COUNT', {
          count: acoes.value.length,
        }),
        days: dias(diasDoCartao.value),
      })
    : ''
);
</script>

<template>
  <section data-testid="kanban-action-history" class="grid gap-3">
    <p
      v-if="resumoGanha"
      data-testid="kanban-action-history-won"
      class="mb-0 text-sm font-medium text-n-slate-12"
    >
      {{ resumoGanha }}
    </p>

    <div
      data-testid="kanban-action-history-numbers"
      class="grid grid-cols-3 gap-3"
    >
      <RaevoKpiCard
        density="strip"
        :label="t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.ACTIONS')"
        :value="acoes.length"
      />
      <RaevoKpiCard
        v-if="diasDoCartao !== null"
        density="strip"
        :label="rotuloDosDias"
        :value="dias(diasDoCartao)"
      />
      <RaevoKpiCard
        v-if="comPrazo.length"
        density="strip"
        :label="t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.ON_TIME')"
        :value="
          t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.ON_TIME_VALUE', {
            done: noPrazo,
            total: comPrazo.length,
          })
        "
      />
    </div>

    <p
      v-if="!acoes.length"
      data-testid="kanban-action-history-empty"
      class="mb-0 text-sm text-n-slate-11"
    >
      {{ t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.EMPTY') }}
    </p>

    <ol v-else class="m-0 grid list-none p-0">
      <li
        v-for="acao in visiveis"
        :key="acao.chave"
        data-testid="kanban-action-history-item"
        class="grid grid-cols-[1.5rem_minmax(0,1fr)] gap-2.5 border-t border-solid border-n-weak py-2.5"
      >
        <i
          aria-hidden="true"
          class="mt-0.5 size-4 text-n-slate-11"
          :class="acao.icone"
        />
        <div class="grid min-w-0 gap-0.5">
          <div class="flex items-baseline justify-between gap-2">
            <span class="break-words text-sm font-medium text-n-slate-12">
              {{ acao.tipo }}
            </span>
            <span
              v-if="acao.quem"
              data-testid="kanban-action-history-who"
              class="shrink-0 text-xs text-n-slate-11"
            >
              {{ acao.quem }}
            </span>
          </div>
          <span
            data-testid="kanban-action-history-when"
            class="text-xs text-n-slate-11"
          >
            <template v-if="acao.prevista">
              {{
                t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.SCHEDULED', {
                  date: acao.prevista,
                })
              }}
              <i
                class="mx-1 inline-block size-1 rounded-full bg-n-slate-8 align-middle"
                aria-hidden="true"
              />
              {{ t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.DONE') }}
              <b
                v-if="acao.atraso"
                data-testid="kanban-action-history-late"
                class="font-semibold text-n-amber-11"
              >
                {{
                  t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.LATE', {
                    date: acao.feita,
                    days: dias(acao.atraso),
                  })
                }}
              </b>
              <template v-else>{{ acao.feita }}</template>
            </template>
            <template v-else>
              {{
                t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.DONE_ONLY', {
                  date: acao.feita,
                })
              }}
            </template>
          </span>
          <span
            v-if="acao.resultado"
            data-testid="kanban-action-history-result"
            class="break-words text-sm text-n-slate-12"
          >
            {{ acao.resultado }}
          </span>
          <span
            v-else-if="acao.observacao"
            class="break-words text-xs text-n-slate-11"
          >
            {{ acao.observacao }}
          </span>
        </div>
      </li>
      <li v-if="escondidas" class="border-t border-solid border-n-weak pt-1">
        <NextButton
          type="button"
          sm
          link
          slate
          data-testid="kanban-action-history-more"
          :label="
            t('KANBAN.OPPORTUNITY_DETAILS.ACTION_HISTORY.SHOW_OLDER', {
              count: escondidas,
            })
          "
          @click="mostrarTodas = true"
        />
      </li>
    </ol>
  </section>
</template>
