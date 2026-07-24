class KanbanAutomations::WorkflowMessageService
  def initialize(card:, data:, now: Time.current)
    @card = card
    @data = data.to_h.deep_stringify_keys
    @now = now
  end

  def perform!
    conversation = compatible_conversation
    return skipped('no_compatible_conversation') if conversation.blank?
    return skipped('opt_in_required') unless opted_in?
    return skipped('outside_whatsapp_window') if whatsapp_outside_window?(conversation)
    return deferred('quiet_hours', quiet_hours_resume_at) if quiet_hours_resume_at.present?
    return deferred('frequency_limit', frequency_limit_resume_at) if frequency_limit_resume_at.present?

    message = Messages::MessageBuilder.new(nil, conversation, message_params).perform
    { 'action_name' => 'send_message', 'status' => 'succeeded', 'message_id' => message.id }
  end

  private

  attr_reader :card, :data, :now

  def compatible_conversation
    inbox_type = data.fetch('channel') == 'email' ? 'Email' : 'Whatsapp'
    card.contact.conversations.where(account_id: card.account_id).includes(:inbox).order(last_activity_at: :desc, id: :desc).find do |conversation|
      conversation.inbox&.inbox_type == inbox_type
    end
  end

  def opted_in?
    key = data['opt_in_attribute_key'].to_s
    key.present? && ActiveModel::Type::Boolean.new.cast(card.contact.custom_attributes[key])
  end

  def whatsapp_outside_window?(conversation)
    conversation.inbox&.inbox_type == 'Whatsapp' && !conversation.can_reply? && whatsapp_template_params.blank?
  end

  def message_params
    {
      content: rendered_content,
      message_type: 'outgoing',
      private: false,
      content_attributes: { kanban_workflow_message: true }
    }.tap do |params|
      params[:template_params] = whatsapp_template_params if whatsapp_template_params.present?
    end
  end

  def whatsapp_template_params
    @whatsapp_template_params ||= data['whatsapp_template_params'].to_h.with_indifferent_access.presence
  end

  def rendered_content
    data.fetch('content').to_s.gsub(/\{\{(?<token>[^}]+)\}\}/) do
      message_variable_value(Regexp.last_match[:token])
    end
  end

  def message_variable_value(token)
    case token
    when 'contact_name'
      card.contact.name.to_s
    when 'opportunity_subject'
      card.subject.to_s
    when 'opportunity_amount'
      format('%.2f', card.amount_cents.to_i / 100.0)
    when /\Afield\.(?<key>[a-zA-Z_][a-zA-Z0-9_]*)\z/
      card.custom_field_values.fetch(Regexp.last_match[:key], '').to_s
    else
      "{{#{token}}}"
    end
  end

  def quiet_hours_resume_at
    return unless quiet_hours_configured?

    quiet_hours_same_day? ? same_day_quiet_hours_resume_at : overnight_quiet_hours_resume_at
  end

  def frequency_limit_resume_at
    hours = data['frequency_limit_hours'].to_f
    return unless hours.positive?

    last_message_at = last_workflow_message_at
    return if last_message_at.blank?

    resume_at = last_message_at + hours.hours
    resume_at if resume_at > now
  end

  def last_workflow_message_at
    Message.joins(:conversation)
           .where(account_id: card.account_id, message_type: :outgoing, conversations: { contact_id: card.contact_id })
           .where("messages.content_attributes ->> 'kanban_workflow_message' = 'true'")
           .order(created_at: :desc)
           .pick(:created_at)
  end

  def quiet_hours
    @quiet_hours ||= data['quiet_hours'].to_h.with_indifferent_access
  end

  def quiet_hours_configured?
    quiet_hours[:start].present? && quiet_hours[:end].present? && quiet_hours_start_time != quiet_hours_end_time
  end

  def quiet_hours_timezone
    @quiet_hours_timezone ||= ActiveSupport::TimeZone[quiet_hours[:timezone]] || Time.zone
  end

  def current_quiet_time
    @current_quiet_time ||= now.in_time_zone(quiet_hours_timezone)
  end

  def quiet_hours_start_time
    @quiet_hours_start_time ||= quiet_hours_timezone.parse("#{current_quiet_time.to_date} #{quiet_hours[:start]}")
  end

  def quiet_hours_end_time
    @quiet_hours_end_time ||= quiet_hours_timezone.parse("#{current_quiet_time.to_date} #{quiet_hours[:end]}")
  end

  def quiet_hours_same_day?
    quiet_hours_start_time < quiet_hours_end_time
  end

  def quiet_hours_overnight?
    quiet_hours_start_time > quiet_hours_end_time
  end

  def within_quiet_hours?
    current_quiet_time >= quiet_hours_start_time && current_quiet_time < quiet_hours_end_time
  end

  def same_day_quiet_hours_resume_at
    quiet_hours_end_time if within_quiet_hours?
  end

  def overnight_quiet_hours_resume_at
    return quiet_hours_end_time + 1.day if current_quiet_time >= quiet_hours_start_time
    return quiet_hours_end_time if current_quiet_time < quiet_hours_end_time
  end

  def skipped(reason)
    { 'action_name' => 'send_message', 'status' => 'skipped', 'reason' => reason }
  end

  def deferred(reason, scheduled_at)
    {
      'action_name' => 'send_message',
      'status' => 'waiting',
      'reason' => reason,
      'scheduled_at' => scheduled_at.iso8601
    }
  end
end
