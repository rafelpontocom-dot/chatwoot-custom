# Horários ocupados vindos da agenda Google, para a agenda do Raevo desenhar.
# Só o intervalo: o título do compromisso nunca sai do Google.
class Api::V1::Accounts::Calendar::BusyBlocksController < Api::V1::Accounts::BaseController
  def index
    authorize KanbanCalendarExternalBusyBlock, :index?

    render json: busy_blocks.map { |block| block_payload(block) }
  end

  private

  def busy_blocks
    scope = policy_scope(KanbanCalendarExternalBusyBlock)
            .overlapping(Time.zone.parse(params.require(:starts_at)), Time.zone.parse(params.require(:ends_at)))
            .order(:starts_at)
    resource_ids = Array(params[:resource_ids]).compact_blank
    resource_ids.present? ? scope.where(kanban_calendar_resource_id: resource_ids) : scope
  end

  def block_payload(block)
    {
      id: block.id,
      resource_id: block.kanban_calendar_resource_id,
      starts_at: block.starts_at.iso8601,
      ends_at: block.ends_at.iso8601,
      all_day: block.all_day,
      source: 'google_calendar'
    }
  end
end
