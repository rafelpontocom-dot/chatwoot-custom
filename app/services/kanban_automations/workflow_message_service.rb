class KanbanAutomations::WorkflowMessageService
  def initialize(card:, data:)
    @card = card
    @data = data.to_h.deep_stringify_keys
  end

  def perform!
    conversation = compatible_conversation
    return skipped('no_compatible_conversation') if conversation.blank?
    return skipped('opt_in_required') unless opted_in?
    return skipped('outside_whatsapp_window') if whatsapp_outside_window?(conversation)

    message = Messages::MessageBuilder.new(nil, conversation, message_params).perform
    { 'action_name' => 'send_message', 'status' => 'succeeded', 'message_id' => message.id }
  end

  private

  attr_reader :card, :data

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
    conversation.inbox&.inbox_type == 'Whatsapp' && !conversation.can_reply?
  end

  def message_params
    {
      content: rendered_content,
      message_type: 'outgoing',
      private: false,
      content_attributes: { kanban_workflow_message: true }
    }
  end

  def rendered_content
    data.fetch('content').to_s.gsub('{{contact_name}}', card.contact.name.to_s)
  end

  def skipped(reason)
    { 'action_name' => 'send_message', 'status' => 'skipped', 'reason' => reason }
  end
end
