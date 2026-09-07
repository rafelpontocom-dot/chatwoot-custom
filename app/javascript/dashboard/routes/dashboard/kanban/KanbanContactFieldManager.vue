<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import NextButton from 'dashboard/components-next/button/Button.vue';
import RaevoField from 'dashboard/components-next/raevo/RaevoField.vue';

/**
 * Raevo — quais campos do contato aparecem na ficha.
 *
 * A definição do campo é do Chatwoot (`custom_attribute_definitions`), não
 * nossa: criar um aqui cria um atributo de contato de verdade, que passa a
 * existir também na barra lateral do contato. O board guarda só a colocação —
 * quais aparecem e em que ordem.
 *
 * Sem esta camada a aba mostrava todo atributo que existisse na conta, e o
 * comercial acabava a ler `waha_whatsapp_jid` como se fosse dado de negócio.
 */
const props = defineProps({
  /** chaves colocadas na ficha, na ordem em que aparecem */
  modelValue: { type: Array, default: () => [] },
  disabled: { type: Boolean, default: false },
});
const emit = defineEmits(['update:modelValue']);

const { t } = useI18n();
const store = useStore();
const getAttributesByModel = useMapGetter('attributes/getAttributesByModel');

const definicoes = computed(
  () => getAttributesByModel.value('contact_attribute') || []
);
const rotuloDe = definicao =>
  definicao.attribute_display_name || definicao.attribute_key;

const colocados = computed(() =>
  props.modelValue
    .map(key => definicoes.value.find(d => d.attribute_key === key))
    .filter(Boolean)
);
const disponiveis = computed(() =>
  definicoes.value.filter(d => !props.modelValue.includes(d.attribute_key))
);

const mover = (index, passo) => {
  const destino = index + passo;
  if (destino < 0 || destino >= props.modelValue.length) return;
  const proximo = [...props.modelValue];
  [proximo[index], proximo[destino]] = [proximo[destino], proximo[index]];
  emit('update:modelValue', proximo);
};
const colocar = key => {
  if (!key || props.modelValue.includes(key)) return;
  emit('update:modelValue', [...props.modelValue, key]);
};
const retirar = key =>
  emit(
    'update:modelValue',
    props.modelValue.filter(chave => chave !== key)
  );

const chaveParaColocar = ref('');
const adicionarColocado = () => {
  colocar(chaveParaColocar.value);
  chaveParaColocar.value = '';
};

// Criar aqui cria no Chatwoot. Não há campo de contato "só do CRM": duplicar o
// armazenamento é como o funil legado acabou com o mesmo dado em dois sítios.
const novoRotulo = ref('');
const criando = ref(false);
const erro = ref('');
const chaveDe = rotulo =>
  rotulo
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '');

const criarCampo = async () => {
  const rotulo = novoRotulo.value.trim();
  if (!rotulo || criando.value) return;
  criando.value = true;
  erro.value = '';
  try {
    const criado = await store.dispatch('attributes/create', {
      attribute_display_name: rotulo,
      attribute_display_type: 'text',
      attribute_description: rotulo,
      attribute_key: chaveDe(rotulo),
      attribute_model: 'contact_attribute',
    });
    colocar(criado?.attribute_key || chaveDe(rotulo));
    novoRotulo.value = '';
  } catch (requestError) {
    erro.value =
      requestError?.response?.data?.message ||
      t('KANBAN.SETTINGS.CONTACT_FIELDS.CREATE_ERROR');
  } finally {
    criando.value = false;
  }
};
</script>

<template>
  <section class="grid content-start gap-3" data-testid="kanban-contact-fields">
    <!-- A aba já nomeia a secção; repetir o título desenhava-o duas vezes. -->
    <p class="mb-0 text-xs leading-5 text-n-slate-11">
      {{ t('KANBAN.SETTINGS.CONTACT_FIELDS.DESCRIPTION') }}
    </p>

    <p
      v-if="!colocados.length"
      class="mb-0 rounded-md bg-n-alpha-2 px-3 py-2 text-xs text-n-slate-11"
    >
      {{ t('KANBAN.SETTINGS.CONTACT_FIELDS.EMPTY') }}
    </p>

    <ul v-else class="m-0 grid list-none gap-1 p-0">
      <li
        v-for="(definicao, index) in colocados"
        :key="definicao.attribute_key"
        :data-testid="`kanban-contact-field-${definicao.attribute_key}`"
        class="flex items-center gap-2 rounded-md border border-n-weak bg-n-surface-1 px-3 py-2"
      >
        <span class="min-w-0 flex-1 truncate text-sm text-n-slate-12">
          {{ rotuloDe(definicao) }}
        </span>
        <code class="truncate text-micro text-n-slate-10">{{
          definicao.attribute_key
        }}</code>
        <NextButton
          :disabled="disabled || index === 0"
          :aria-label="t('KANBAN.SETTINGS.CONTACT_FIELDS.MOVE_UP')"
          :title="t('KANBAN.SETTINGS.CONTACT_FIELDS.MOVE_UP')"
          icon="i-lucide-arrow-up"
          faded
          slate
          xs
          @click="mover(index, -1)"
        />
        <NextButton
          :disabled="disabled || index === colocados.length - 1"
          :aria-label="t('KANBAN.SETTINGS.CONTACT_FIELDS.MOVE_DOWN')"
          :title="t('KANBAN.SETTINGS.CONTACT_FIELDS.MOVE_DOWN')"
          icon="i-lucide-arrow-down"
          faded
          slate
          xs
          @click="mover(index, 1)"
        />
        <NextButton
          :disabled="disabled"
          :aria-label="t('KANBAN.SETTINGS.CONTACT_FIELDS.REMOVE')"
          :title="t('KANBAN.SETTINGS.CONTACT_FIELDS.REMOVE')"
          :data-testid="`kanban-contact-field-remove-${definicao.attribute_key}`"
          icon="i-lucide-x"
          faded
          slate
          xs
          @click="retirar(definicao.attribute_key)"
        />
      </li>
    </ul>

    <div v-if="disponiveis.length" class="flex items-end gap-2">
      <RaevoField
        :label="t('KANBAN.SETTINGS.CONTACT_FIELDS.PLACE_EXISTING')"
        variant="select"
        class="flex-1"
      >
        <template #default="{ controlClass, fieldId }">
          <select
            :id="fieldId"
            v-model="chaveParaColocar"
            :class="controlClass"
            :disabled="disabled"
            data-testid="kanban-contact-field-picker"
          >
            <option value="">
              {{ t('KANBAN.SETTINGS.CONTACT_FIELDS.PLACE_PLACEHOLDER') }}
            </option>
            <option
              v-for="definicao in disponiveis"
              :key="definicao.attribute_key"
              :value="definicao.attribute_key"
            >
              {{ rotuloDe(definicao) }}
            </option>
          </select>
        </template>
      </RaevoField>
      <NextButton
        :label="t('KANBAN.SETTINGS.CONTACT_FIELDS.PLACE_ACTION')"
        :disabled="disabled || !chaveParaColocar"
        data-testid="kanban-contact-field-place"
        faded
        slate
        sm
        @click="adicionarColocado"
      />
    </div>

    <div class="grid gap-2 rounded-md border border-n-weak p-3">
      <p class="mb-0 text-xs leading-5 text-n-slate-11">
        {{ t('KANBAN.SETTINGS.CONTACT_FIELDS.CREATE_HINT') }}
      </p>
      <div class="flex items-end gap-2">
        <RaevoField
          :label="t('KANBAN.SETTINGS.CONTACT_FIELDS.CREATE_LABEL')"
          class="flex-1"
          :error="erro"
        >
          <template #default="{ controlClass, fieldId }">
            <input
              :id="fieldId"
              v-model="novoRotulo"
              :class="controlClass"
              :disabled="disabled || criando"
              data-testid="kanban-contact-field-new-label"
              :placeholder="
                t('KANBAN.SETTINGS.CONTACT_FIELDS.CREATE_PLACEHOLDER')
              "
            />
          </template>
        </RaevoField>
        <NextButton
          :label="t('KANBAN.SETTINGS.CONTACT_FIELDS.CREATE_ACTION')"
          :is-loading="criando"
          :disabled="disabled || !novoRotulo.trim()"
          data-testid="kanban-contact-field-create"
          sm
          @click="criarCampo"
        />
      </div>
    </div>
  </section>
</template>
