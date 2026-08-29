<script setup>
import { onBeforeUnmount, watch } from 'vue';
import Link from '@tiptap/extension-link';
import { EditorContent, useEditor } from '@tiptap/vue-3';
import StarterKit from '@tiptap/starter-kit';

const props = defineProps({
  content: { type: [Object, String], required: true },
});

const editor = useEditor({
  content: props.content,
  editable: false,
  extensions: [
    StarterKit.configure({ heading: { levels: [2, 3, 4] }, link: false }),
    Link.configure({
      openOnClick: true,
      autolink: false,
      linkOnPaste: false,
      protocols: ['http', 'https'],
      HTMLAttributes: {
        target: '_blank',
        rel: 'noopener noreferrer',
      },
    }),
  ],
  editorProps: {
    attributes: { class: 'prose prose-sm max-w-none text-n-slate-11' },
  },
});

watch(
  () => props.content,
  value => editor.value?.commands.setContent(value, { emitUpdate: false })
);

onBeforeUnmount(() => editor.value?.destroy());
</script>

<template>
  <EditorContent :editor="editor" />
</template>
