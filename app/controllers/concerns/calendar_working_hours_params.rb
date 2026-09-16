# O corpo do editor da semana, igual para o horário com nome e para o horário
# só de uma agenda.
module CalendarWorkingHoursParams
  private

  def working_hours_params
    permitted = params.permit(weekly: [:weekday, { ranges: [:from, :to] }], overrides: [:date, :closed, :note, { ranges: [:from, :to] }])
    {
      weekly: permitted.fetch(:weekly, []).map { |day| day.to_h.deep_symbolize_keys.merge(weekday: day[:weekday].to_i) },
      overrides: permitted.fetch(:overrides, []).map { |override| override.to_h.deep_symbolize_keys }
    }
  end
end
