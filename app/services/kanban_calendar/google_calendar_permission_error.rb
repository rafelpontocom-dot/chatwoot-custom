# Quem ligou a agenda desmarcou, no ecrã do Google, a permissão de ver e editar
# os eventos. Sem ela a ligação não serve para nada, por isso nem chega a gravar.
class KanbanCalendar::GoogleCalendarPermissionError < KanbanCalendar::GoogleCalendarApiError; end
