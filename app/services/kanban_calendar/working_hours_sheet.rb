# A semana e as exceções de um horário, no formato em que a tela as edita:
#
#   weekly:    [{ weekday: 1, ranges: [{ from: '08:00', to: '12:00' }, { from: '14:00', to: '16:00' }] }]
#   overrides: [{ date: '2026-10-07', closed: true, note: 'Congresso' },
#               { date: '2026-10-12', ranges: [{ from: '09:00', to: '11:00' }] }]
#
# Serve o horário com nome e o horário só de uma agenda. Gravar troca a semana e
# as exceções inteiras numa transação; bloqueios com hora marcada (um intervalo
# num dia, fora do editor) ficam como estão.
class KanbanCalendar::WorkingHoursSheet
  def initialize(rules)
    @rules = rules
  end

  def payload
    active = @rules.active.to_a
    { weekly: weekly_payload(active), overrides: overrides_payload(active) }
  end

  def replace!(weekly:, overrides:)
    ActiveRecord::Base.transaction do
      editable_rules.destroy_all
      Array(weekly).each { |day| create_ranges(kind: 'weekly_window', weekday: day[:weekday], ranges: day[:ranges]) }
      Array(overrides).each { |override| create_override(override) }
    end
  end

  private

  def editable_rules
    @rules.where(kind: %w[weekly_window date_override]).or(@rules.where(kind: 'block', starts_at_local: nil))
  end

  def create_ranges(ranges:, **attributes)
    Array(ranges).each do |range|
      @rules.create!(attributes.merge(starts_at_local: range[:from], ends_at_local: range[:to]))
    end
  end

  def create_override(override)
    date = Date.iso8601(override[:date].to_s)
    return @rules.create!(kind: 'block', date: date, note: override[:note]) if ActiveModel::Type::Boolean.new.cast(override[:closed])

    create_ranges(kind: 'date_override', date: date, note: override[:note], ranges: override[:ranges])
  end

  def weekly_payload(rules)
    rules.select(&:weekly_window?).group_by(&:weekday).sort.map do |weekday, day_rules|
      { weekday: weekday, ranges: ranges_for(day_rules) }
    end
  end

  def overrides_payload(rules)
    closed = rules.select { |rule| rule.block? && rule.starts_at_local.nil? }
    open = rules.select(&:date_override?)
    (closed + open).group_by(&:date).sort.map do |date, date_rules|
      override_for(date, date_rules)
    end
  end

  def override_for(date, date_rules)
    note = date_rules.filter_map(&:note).first
    return { date: date.iso8601, closed: true, note: note } if date_rules.any?(&:block?)

    { date: date.iso8601, closed: false, note: note, ranges: ranges_for(date_rules) }
  end

  # Ordena pelo que o payload mostra — 'HH:MM' — e não pelo objeto da coluna. A
  # coluna é `time`, e o Rails devolve-a como um `Time` com data postiça: ordenar
  # por esse objeto é ordenar por (data, hora), quando a saída só tem a hora. Se as
  # datas postiças não coincidirem, a ordem lida deixa de ser a ordem mostrada.
  def ranges_for(rules)
    rules.map { |rule| { from: rule.starts_at_local.strftime('%H:%M'), to: rule.ends_at_local.strftime('%H:%M') } }
         .sort_by { |range| range[:from] }
  end
end
