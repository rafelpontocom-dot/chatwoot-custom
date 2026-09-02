<script setup>
import { onBeforeUnmount, ref, watch } from 'vue';
import Link from '@tiptap/extension-link';
import { EditorContent, useEditor } from '@tiptap/vue-3';
import StarterKit from '@tiptap/starter-kit';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  modelValue: { type: [Object, String], default: '' },
});
const emit = defineEmits(['update:modelValue']);
const { t } = useI18n();
const isLinkEditorOpen = ref(false);
const linkUrl = ref('');
const linkError = ref('');

const linkExtension = Link.configure({
  openOnClick: false,
  autolink: false,
  linkOnPaste: true,
  protocols: ['http', 'https'],
  HTMLAttributes: {
    target: '_blank',
    rel: 'noopener noreferrer',
  },
});

const editor = useEditor({
  content: props.modelValue,
  extensions: [
    StarterKit.configure({ heading: { levels: [2, 3, 4] }, link: false }),
    linkExtension,
  ],
  editorProps: {
    attributes: {
      class:
        'min-h-32 rounded border border-n-slate-5 bg-n-solid-1 px-3 py-2 text-sm leading-6 text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6',
    },
  },
  onUpdate: ({ editor: instance }) => {
    emit('update:modelValue', instance.getJSON());
  },
});

watch(
  () => props.modelValue,
  value => {
    if (!editor.value) return;
    if (JSON.stringify(editor.value.getJSON()) === JSON.stringify(value))
      return;

    editor.value.commands.setContent(value, { emitUpdate: false });
  }
);

onBeforeUnmount(() => editor.value?.destroy());

function isSafeHttpUrl(value) {
  try {
    const url = new URL(value);
    return ['http:', 'https:'].includes(url.protocol);
  } catch {
    return false;
  }
}

function openLinkEditor() {
  linkUrl.value = editor.value?.getAttributes('link').href || '';
  linkError.value = '';
  isLinkEditorOpen.value = true;
}

function closeLinkEditor() {
  isLinkEditorOpen.value = false;
  linkError.value = '';
}

function applyLink() {
  const href = linkUrl.value.trim();
  if (!isSafeHttpUrl(href)) {
    linkError.value = t('FORMS.RICH_TEXT.INVALID_LINK');
    return;
  }

  editor.value?.chain().focus().extendMarkRange('link').setLink({ href }).run();
  closeLinkEditor();
}

const controls = [
  {
    key: 'bold',
    icon: 'i-lucide-bold',
    label: t('FORMS.RICH_TEXT.BOLD'),
    action: () => editor.value?.chain().focus().toggleBold().run(),
  },
  {
    key: 'italic',
    icon: 'i-lucide-italic',
    label: t('FORMS.RICH_TEXT.ITALIC'),
    action: () => editor.value?.chain().focus().toggleItalic().run(),
  },
  {
    key: 'strike',
    icon: 'i-lucide-strikethrough',
    label: t('FORMS.RICH_TEXT.STRIKE'),
    action: () => editor.value?.chain().focus().toggleStrike().run(),
  },
  {
    key: 'bullet',
    icon: 'i-lucide-list',
    label: t('FORMS.RICH_TEXT.BULLET_LIST'),
    action: () => editor.value?.chain().focus().toggleBulletList().run(),
  },
  {
    key: 'ordered',
    icon: 'i-lucide-list-ordered',
    label: t('FORMS.RICH_TEXT.ORDERED_LIST'),
    action: () => editor.value?.chain().focus().toggleOrderedList().run(),
  },
  {
    key: 'link',
    icon: 'i-lucide-link',
    label: t('FORMS.RICH_TEXT.LINK'),
    action: openLinkEditor,
  },
];
</script>

<template>
  <div class="rounded border border-n-slate-4 bg-n-slate-2 p-2">
    <div class="mb-2 flex flex-wrap gap-1 border-b border-n-slate-4 pb-2">
      <button
        v-for="control in controls"
        :key="control.key"
        type="button"
        class="inline-flex p-0 size-8 items-center justify-center rounded text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
        :class="{
          'bg-n-teal-3 text-n-teal-11':
            (control.key === 'bold' && editor?.isActive('bold')) ||
            (control.key === 'italic' && editor?.isActive('italic')) ||
            (control.key === 'strike' && editor?.isActive('strike')) ||
            (control.key === 'bullet' && editor?.isActive('bulletList')) ||
            (control.key === 'ordered' && editor?.isActive('orderedList')) ||
            (control.key === 'link' && editor?.isActive('link')),
        }"
        :data-test="
          control.key === 'bold'
            ? 'forms-rich-text-bold'
            : control.key === 'link'
              ? 'forms-rich-text-link'
              : undefined
        "
        :aria-label="control.label"
        :title="control.label"
        @click="control.action"
      >
        <span :class="control.icon" class="size-4" aria-hidden="true" />
      </button>
    </div>
    <div
      v-if="isLinkEditorOpen"
      class="mb-2 grid gap-2 sm:grid-cols-[minmax(0,1fr)_auto_auto]"
    >
      <label class="sr-only" for="forms-rich-text-link-url">
        {{ t('FORMS.RICH_TEXT.LINK_URL') }}
      </label>
      <input
        id="forms-rich-text-link-url"
        v-model="linkUrl"
        data-test="forms-rich-text-link-url"
        type="url"
        inputmode="url"
        class="min-h-9 rounded border border-n-slate-5 bg-n-solid-1 px-3 text-sm text-n-slate-12 outline-none focus:border-n-teal-9 focus:ring-2 focus:ring-n-teal-6"
        :placeholder="t('FORMS.RICH_TEXT.LINK_URL_PLACEHOLDER')"
        @keyup.enter="applyLink"
      />
      <button
        data-test="forms-rich-text-link-apply"
        type="button"
        class="inline-flex min-h-9 items-center justify-center rounded bg-n-teal-9 px-3 text-sm font-medium text-n-solid-1 transition hover:bg-n-teal-10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
        @click="applyLink"
      >
        {{ t('FORMS.RICH_TEXT.APPLY_LINK') }}
      </button>
      <button
        type="button"
        class="inline-flex p-0 size-9 items-center justify-center rounded text-n-slate-11 transition hover:bg-n-slate-3 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-n-teal-6"
        :aria-label="t('FORMS.ACTIONS.CLOSE')"
        :title="t('FORMS.ACTIONS.CLOSE')"
        @click="closeLinkEditor"
      >
        <span class="i-lucide-x size-4" aria-hidden="true" />
      </button>
      <p
        v-if="linkError"
        class="text-sm text-n-ruby-11 sm:col-span-3"
        role="alert"
      >
        {{ linkError }}
      </p>
    </div>
    <EditorContent :editor="editor" />
  </div>
</template>
