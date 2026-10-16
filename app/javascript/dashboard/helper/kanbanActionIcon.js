// O tipo da próxima ação é texto livre de cada funil; o ícone é só um atalho
// de leitura. Usado no histórico da ficha (5j) e nas tarefas da Agenda (5m).
export const iconForActionType = type => {
  const texto = String(type || '').toLowerCase();
  if (/liga|telefon|call/.test(texto)) return 'i-lucide-phone';
  if (/whats|mensag|message|e-?mail/.test(texto)) {
    return 'i-lucide-message-circle';
  }
  if (/consulta|avalia|visita|reuni|meeting/.test(texto)) {
    return 'i-lucide-calendar';
  }
  return 'i-lucide-circle-check';
};
