# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
class KanbanAppointmentReminders::DeliverService
  def initialize(delivery)
    @delivery = delivery
  end

  def call
    delivery.with_lock do
      next delivery if delivery.sent? || delivery.canceled? || delivery.sending?

      delivery.update!(status: 'sending', attempted_at: Time.current, error_message: nil)
      conversation = compatible_conversation
      next skip!('no_compatible_conversation') if conversation.blank?
      next skip!('opt_in_required') unless opted_in?
      next skip!('outside_whatsapp_window') if whatsapp_outside_window?(conversation)

      message = Messages::MessageBuilder.new(nil, conversation, message_params).perform
      delivery.update!(status: 'sent', sent_at: Time.current, message: message)
    end
    delivery
  rescue StandardError => e
    delivery.update(status: 'failed', error_message: e.message, updated_at: Time.current)
    raise
  end

  private

  attr_reader :delivery

  delegate :kanban_appointment_reminder_rule, :kanban_card, to: :delivery

  def compatible_conversation
    expected_type = delivery.delivery_channel == 'whatsapp' ? 'Whatsapp' : 'Email'
    card.contact.conversations.where(account_id: card.account_id).includes(:inbox).order(last_activity_at: :desc, id: :desc).find do |conversation|
      conversation.inbox&.inbox_type == expected_type
    end
  end

  def opted_in?
    key = rule.opt_in_attribute_key
    key.blank? || ActiveModel::Type::Boolean.new.cast(card.contact.custom_attributes[key])
  end

  def whatsapp_outside_window?(conversation)
    return false unless conversation.inbox&.inbox_type == 'Whatsapp'
    return false if rule.whatsapp_template_params.present?

    !conversation.can_reply?
  end

  def message_params
    params = {
      content: rendered_message,
      message_type: 'outgoing',
      private: false,
      content_attributes: { kanban_appointment_reminder_id: delivery.id }
    }
    params[:template_params] = rule.whatsapp_template_params if delivery.delivery_channel == 'whatsapp' && rule.whatsapp_template_params.present?
    params
  end

  def rendered_message
    template = rule.message_templates.to_h[delivery.offset_hours.to_s] || rule.message_templates.to_h.values.first
    template.to_s.gsub(
      /\{\{\s*(contact_name|appointment_date)\s*\}\}/,
      'contact_name' => card.contact.name.to_s,
      'appointment_date' => appointment_time.in_time_zone.strftime('%d/%m/%Y %H:%M')
    )
  end

  def appointment_time
    Time.zone.parse(delivery.appointment_value)
  end

  def skip!(reason)
    delivery.update!(status: 'skipped', error_message: reason, sent_at: nil)
    delivery
  end

  def card
    kanban_card
  end

  def rule
    kanban_appointment_reminder_rule
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity
