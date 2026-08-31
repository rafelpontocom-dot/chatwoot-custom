<script setup>
import { useI18n } from 'vue-i18n';

/**
 * A aparência do formulário: marca, logótipo e tema.
 *
 * Vive no painel da direita, ao lado da pergunta e da lógica, porque é sobre
 * como o formulário se apresenta — que é o que se está a olhar ao centro. O
 * que ficou nas configurações é identidade: nome, endereço, categoria e
 * idioma. São coisas diferentes e estavam na mesma gaveta.
 */
defineProps({
  settings: { type: Object, required: true },
  formName: { type: String, default: '' },
  brandLogoUrl: { type: String, default: '' },
  isUploadingBrandLogo: { type: Boolean, default: false },
});

const emit = defineEmits(['update', 'uploadBrandLogo', 'removeBrandLogo']);
const { t } = useI18n();

const alterar = (chave, valor) => emit('update', { [chave]: valor });
const uploadBrandLogo = event => emit('uploadBrandLogo', event);
const removeBrandLogo = () => emit('removeBrandLogo');
</script>

<template>
  <div class="grid gap-4" data-test="forms-design-panel">
    <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
      {{ t('FORMS.EDITOR.BRAND_NAME') }}
      <input
        :value="settings.brand_name"
        :placeholder="t('FORMS.EDITOR.BRAND_NAME_PLACEHOLDER')"
        data-test="design-brand-name"
        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
        @input="alterar('brand_name', $event.target.value)"
      />
    </label>
    <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
      {{ t('FORMS.EDITOR.BRAND_LOGO_URL') }}
      <input
        :value="settings.brand_logo_url"
        type="url"
        :placeholder="t('FORMS.EDITOR.BRAND_LOGO_URL_PLACEHOLDER')"
        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
        @input="alterar('brand_logo_url', $event.target.value)"
      />
    </label>
    <div class="grid gap-2 text-sm text-n-slate-11">
      <p class="font-medium">
        {{ t('FORMS.EDITOR.BRAND_LOGO_UPLOAD') }}
      </p>
      <div class="flex items-center gap-3">
        <img
          v-if="brandLogoUrl"
          :src="brandLogoUrl"
          :alt="settings.brand_name || formName"
          class="size-10 rounded border border-n-slate-4 bg-n-solid-1 object-contain p-1"
        />
        <label
          class="inline-flex min-h-10 cursor-pointer items-center rounded border border-n-slate-5 px-3 text-sm font-medium text-n-slate-12 transition hover:bg-n-slate-2 focus-within:ring-2 focus-within:ring-n-teal-6"
        >
          <input
            type="file"
            accept="image/png,image/jpeg,image/webp"
            class="sr-only"
            :disabled="isUploadingBrandLogo"
            @change="uploadBrandLogo"
          />
          {{
            isUploadingBrandLogo
              ? t('FORMS.EDITOR.BRAND_LOGO_UPLOADING')
              : t('FORMS.EDITOR.BRAND_LOGO_UPLOAD_ACTION')
          }}
        </label>
        <button
          v-if="brandLogoUrl"
          type="button"
          class="inline-flex min-h-10 items-center rounded px-3 text-sm font-medium text-n-ruby-11 transition hover:bg-n-ruby-2 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-ruby-6 disabled:cursor-not-allowed disabled:opacity-50"
          :disabled="isUploadingBrandLogo"
          @click="removeBrandLogo"
        >
          {{ t('FORMS.EDITOR.BRAND_LOGO_REMOVE_ACTION') }}
        </button>
      </div>
      <p class="text-xs leading-5 text-n-slate-10">
        {{ t('FORMS.EDITOR.BRAND_LOGO_UPLOAD_HINT') }}
      </p>
    </div>
    <label class="grid gap-1.5 text-sm font-medium text-n-slate-11">
      {{ t('FORMS.EDITOR.THEME') }}
      <select
        :value="settings.theme"
        data-test="design-theme"
        class="min-h-10 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
        @change="alterar('theme', $event.target.value)"
      >
        <option value="calm">
          {{ t('FORMS.EDITOR.THEMES.CALM') }}
        </option>
        <option value="warm">
          {{ t('FORMS.EDITOR.THEMES.WARM') }}
        </option>
        <option value="contrast">
          {{ t('FORMS.EDITOR.THEMES.CONTRAST') }}
        </option>
      </select>
    </label>
  </div>
</template>
