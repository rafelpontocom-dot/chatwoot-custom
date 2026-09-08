<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import MarketingAPI from 'dashboard/api/marketing';
import { copyTextToClipboard } from 'shared/helpers/clipboard';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

/**
 * Raevo — como usar a entrada de leads, ao lado de onde se copia o token.
 *
 * O painel dizia o endereço e mandava fazer um GET no `/schema`, mas nunca
 * dizia o nome do header. Quem tinha o token certo na mão levava 401 e concluía
 * que o token era o problema — a porta responde igual para token inválido,
 * origem desligada e módulo desativado, de propósito.
 *
 * Nada aqui é texto escrito à mão sobre a API: header, caminho, campos e
 * limites saem do mesmo contrato que a porta pública usa. Documentação mantida
 * à parte do código diverge dele; esta não tem como.
 */
const { t } = useI18n();

const dialogRef = ref(null);
const referencia = ref(null);
const carregando = ref(false);
const erro = ref('');
const copiado = ref(false);

const endpoint = computed(() =>
  referencia.value ? `${window.location.origin}${referencia.value.path}` : ''
);
const grupos = computed(() => {
  const fields = referencia.value?.fields || {};
  return [
    { key: 'contact', campos: fields.contact || [] },
    { key: 'opportunity', campos: fields.opportunity || [] },
    { key: 'control', campos: fields.control || [] },
    { key: 'attribution', campos: fields.attribution || [] },
  ].filter(grupo => grupo.campos.length);
});

const exemplo = computed(() => {
  if (!referencia.value) return '';
  return [
    `curl -X POST ${endpoint.value} \\`,
    `  -H "${referencia.value.token_header}: $RAEVO_MARKETING_INTAKE_TOKEN" \\`,
    '  -H "Content-Type: application/json" \\',
    `  -d '{"name":"Ana Ribeiro","email":"ana@exemplo.pt",`,
    `       "subject":"Landing — consulta","idempotency_key":"lp-0413",`,
    `       "utm_source":"meta","utm_campaign":"setembro"}'`,
  ].join('\n');
});

const carregar = async () => {
  if (referencia.value || carregando.value) return;
  carregando.value = true;
  erro.value = '';
  try {
    const { data } = await MarketingAPI.getIntakeReference();
    referencia.value = data;
  } catch (requestError) {
    erro.value =
      requestError?.response?.data?.message ||
      t('MARKETING.INTAKE.DOCS.LOAD_ERROR');
  } finally {
    carregando.value = false;
  }
};

const copiar = async () => {
  await copyTextToClipboard(exemplo.value);
  copiado.value = true;
  window.setTimeout(() => {
    copiado.value = false;
  }, 2000);
};

const open = async () => {
  dialogRef.value?.open();
  await carregar();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('MARKETING.INTAKE.DOCS.TITLE')"
    :description="t('MARKETING.INTAKE.DOCS.DESCRIPTION')"
    :show-confirm-button="false"
    :cancel-button-label="t('MARKETING.INTAKE.DOCS.CLOSE')"
    width="2xl"
  >
    <div class="grid gap-5" data-testid="marketing-intake-docs">
      <p v-if="carregando" class="mb-0 text-sm text-n-slate-11">
        {{ t('MARKETING.INTAKE.DOCS.LOADING') }}
      </p>
      <p
        v-else-if="erro"
        class="mb-0 rounded-md bg-n-ruby-2 px-3 py-2 text-sm text-n-ruby-11"
        role="alert"
      >
        {{ erro }}
      </p>

      <template v-else-if="referencia">
        <!--
          O header primeiro: é o que faltava na tela e o que custa um 401 a
          quem assume `Authorization: Bearer`.
        -->
        <section class="grid gap-2">
          <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
            {{ t('MARKETING.INTAKE.DOCS.AUTH_TITLE') }}
          </h3>
          <p class="mb-0 text-sm leading-6 text-n-slate-11">
            {{ t('MARKETING.INTAKE.DOCS.AUTH_BODY') }}
          </p>
          <code
            class="w-fit rounded-md bg-n-alpha-2 px-2 py-1 text-sm text-n-slate-12"
            data-testid="marketing-intake-docs-header"
            >{{ referencia.token_header }}</code
          >
        </section>

        <section class="grid gap-2">
          <div class="flex items-center justify-between gap-2">
            <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
              {{ t('MARKETING.INTAKE.DOCS.REQUEST_TITLE') }}
            </h3>
            <NextButton
              :label="
                copiado
                  ? t('MARKETING.INTAKE.DOCS.COPIED')
                  : t('MARKETING.INTAKE.DOCS.COPY')
              "
              data-testid="marketing-intake-docs-copy"
              faded
              slate
              xs
              @click="copiar"
            />
          </div>
          <pre
            class="mb-0 overflow-x-auto rounded-md bg-n-alpha-2 p-3 text-xs leading-6 text-n-slate-12"
          ><code>{{ exemplo }}</code></pre>
        </section>

        <section class="grid gap-2">
          <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
            {{ t('MARKETING.INTAKE.DOCS.FIELDS_TITLE') }}
          </h3>
          <p class="mb-0 text-sm leading-6 text-n-slate-11">
            {{
              t('MARKETING.INTAKE.DOCS.FIELDS_BODY', {
                length: referencia.notes.max_value_length,
              })
            }}
          </p>
          <div v-for="grupo in grupos" :key="grupo.key" class="grid gap-1">
            <span
              class="text-micro font-semibold uppercase tracking-wide text-n-slate-10"
            >
              {{ t(`MARKETING.INTAKE.DOCS.GROUPS.${grupo.key.toUpperCase()}`) }}
            </span>
            <div class="flex flex-wrap gap-1">
              <code
                v-for="campo in grupo.campos"
                :key="campo"
                class="rounded bg-n-alpha-2 px-1.5 py-0.5 text-xs text-n-slate-11"
                >{{ campo }}</code
              >
            </div>
          </div>
        </section>

        <section class="grid gap-2">
          <h3 class="mb-0 text-sm font-semibold text-n-slate-12">
            {{ t('MARKETING.INTAKE.DOCS.LIMITS_TITLE') }}
          </h3>
          <ul class="m-0 grid list-none gap-1 p-0 text-sm text-n-slate-11">
            <li>
              {{
                t('MARKETING.INTAKE.DOCS.LIMIT_RATE', {
                  count: referencia.rate_limit_per_minute,
                })
              }}
            </li>
            <li>{{ t('MARKETING.INTAKE.DOCS.LIMIT_IDENTITY') }}</li>
            <li>{{ t('MARKETING.INTAKE.DOCS.LIMIT_IDEMPOTENCY') }}</li>
            <li>{{ t('MARKETING.INTAKE.DOCS.LIMIT_401') }}</li>
          </ul>
        </section>
      </template>
    </div>
  </Dialog>
</template>
