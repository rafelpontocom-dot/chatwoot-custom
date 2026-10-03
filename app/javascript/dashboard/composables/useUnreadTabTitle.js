import { onUnmounted, watch } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const MAX_VISIBLE_COUNT = 99;

// A guia do browser é o único sítio do produto que se vê com ele fechado. O
// número de conversas não lidas vai no título, que é o que a barra de guias
// mostra mesmo quando o ícone não muda.
export const useUnreadTabTitle = () => {
  const unreadCount = useMapGetter(
    'conversationUnreadCounts/getAllUnreadCount'
  );
  const baseTitle = document.title.trim();

  watch(
    unreadCount,
    count => {
      if (!count) {
        document.title = baseTitle;
        return;
      }

      const visibleCount =
        count > MAX_VISIBLE_COUNT ? `${MAX_VISIBLE_COUNT}+` : count;
      document.title = `(${visibleCount}) ${baseTitle}`;
    },
    { immediate: true }
  );

  onUnmounted(() => {
    document.title = baseTitle;
  });
};
