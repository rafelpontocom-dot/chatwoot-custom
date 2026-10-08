<script setup>
/**
 * Quem vê a etiqueta.
 *
 * Decisão do Pedro, 07/10: três níveis — de todos, de um time, só minha. **Só o
 * administrador cria «de todos» e «de um time»**; o agente cria só para ele.
 *
 * Esta tela é uma sugestão, não a regra: a regra prende-se no servidor
 * (`LabelsController#clamped_visibility`). Um agente que mandasse
 * `visibility: global` à mão continuaria a criar uma etiqueta pessoal. O que o
 * componente faz é não MENTIR ao agente sobre o que vai acontecer.
 */
import { computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useMapGetter, useStore } from 'dashboard/composables/store';

const props = defineProps({
  visibility: {
    type: String,
    default: 'global',
  },
  teamId: {
    type: [Number, String],
    default: null,
  },
});

const emit = defineEmits(['update:visibility', 'update:teamId']);

const { t } = useI18n();
const { isAdmin } = useAdmin();
const store = useStore();
const teams = useMapGetter('teams/getTeams');

const options = computed(() => [
  { value: 'global', label: t('LABEL_MGMT.FORM.VISIBILITY.GLOBAL') },
  { value: 'team', label: t('LABEL_MGMT.FORM.VISIBILITY.TEAM') },
  { value: 'personal', label: t('LABEL_MGMT.FORM.VISIBILITY.PERSONAL') },
]);

const isTeamVisibility = computed(() => props.visibility === 'team');

onMounted(() => {
  // O agente não escolhe: a etiqueta é dele. Diz-se isso no ecrã e manda-se o
  // valor certo, em vez de deixar «de todos» selecionado e o servidor mudá-lo
  // por baixo.
  if (!isAdmin.value) {
    emit('update:visibility', 'personal');
    emit('update:teamId', null);
    return;
  }

  store.dispatch('teams/get');
});

// Trocar para «de um time» e deixar o time em branco daria uma etiqueta que o
// servidor recusa. Limpar ao sair de «time» evita mandar um time pendurado.
watch(isTeamVisibility, agora => {
  if (!agora) emit('update:teamId', null);
});
</script>

<template>
  <div class="w-full">
    <label v-if="isAdmin" class="block">
      {{ t('LABEL_MGMT.FORM.VISIBILITY.LABEL') }}
      <select
        :value="visibility"
        data-testid="label-visibility"
        @change="emit('update:visibility', $event.target.value)"
      >
        <option
          v-for="option in options"
          :key="option.value"
          :value="option.value"
        >
          {{ option.label }}
        </option>
      </select>
    </label>
    <p
      v-else
      data-testid="label-visibility-agent-note"
      class="mb-0 text-sm text-n-slate-11"
    >
      {{ t('LABEL_MGMT.FORM.VISIBILITY.AGENT_NOTE') }}
    </p>

    <label v-if="isAdmin && isTeamVisibility" class="block">
      {{ t('LABEL_MGMT.FORM.VISIBILITY.TEAM') }}
      <select
        :value="teamId ?? ''"
        data-testid="label-visibility-team"
        @change="emit('update:teamId', $event.target.value || null)"
      >
        <option value="" disabled>
          {{ t('LABEL_MGMT.FORM.VISIBILITY.TEAM_PLACEHOLDER') }}
        </option>
        <option v-for="team in teams" :key="team.id" :value="team.id">
          {{ team.name }}
        </option>
      </select>
    </label>
  </div>
</template>
