# rubocop:disable Metrics/CyclomaticComplexity
class KanbanAppointmentReminders::ScheduleService
  def initialize(card:, rule:, appointment_version: nil, now: Time.current)
    @card = card
    @rule = rule
    @appointment_version = appointment_version || Digest::SHA256.hexdigest(appointment_value.to_s)[0, 16]
    @now = now
  end

  def call
    return 0 unless rule.active? && trigger_matches?
    return 0 if appointment_value.blank? || appointment_time.blank?
    return 0 unless appointment_time > now

    cancel_previous_versions!
    rule.offsets.sum { |offset| rule.channels.sum { |channel| schedule_delivery(offset.to_i, channel.to_s) } }
  end

  private

  attr_reader :card, :rule, :appointment_version, :now

  def appointment_value
    @appointment_value ||= if rule.field_key == 'system_starts_at'
                             card.starts_at&.iso8601
                           else
                             card.custom_field_values.to_h[rule.field_key]
                           end
  end

  def appointment_time
    @appointment_time ||= Time.zone.parse(appointment_value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def trigger_matches?
    return true unless rule.trigger_type == 'stage_entered'

    card.kanban_stage_id == rule.trigger_stage_id
  end

  def cancel_previous_versions!
    rule.deliveries.where(kanban_card: card, status: %w[scheduled sending]).where.not(
      appointment_version: appointment_version
    ).update_all(status: 'canceled', updated_at: now) # rubocop:disable Rails/SkipsModelValidations
  end

  def schedule_delivery(offset, channel)
    idempotency_key = [card.account_id, rule.id, card.id, appointment_version, offset, channel].join(':')
    scheduled_at = [appointment_time - offset.hours, now].max

    rule.deliveries.create_or_find_by!(idempotency_key: idempotency_key) do |delivery|
      delivery.assign_attributes(
        account: card.account,
        kanban_board: card.kanban_board,
        kanban_card: card,
        appointment_version: appointment_version,
        appointment_value: appointment_value.to_s,
        offset_hours: offset,
        delivery_channel: channel,
        scheduled_at: scheduled_at
      )
    end
    1
  rescue ActiveRecord::RecordNotUnique
    0
  end
end
# rubocop:enable Metrics/CyclomaticComplexity
