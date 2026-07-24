class KanbanBirthdayAutomations::ProcessService
  BATCH_SIZE = 500

  def initialize(automation:)
    @automation = automation
    @counts = Hash.new(0)
  end

  def perform!
    return counts unless automation.active?

    with_account_timezone do
      return counts unless send_time_reached?

      birthday_target = Time.zone.today + automation.days_before.days
      contacts_scope.find_each(batch_size: BATCH_SIZE) do |contact|
        process_contact(contact, birthday_target)
      end
    end

    counts
  end

  private

  attr_reader :automation, :counts

  def contacts_scope
    automation.account.contacts.where("custom_attributes ->> 'date_of_birth' IS NOT NULL")
  end

  def send_time_reached?
    Time.zone.now.strftime('%H:%M') >= automation.send_time
  end

  def process_contact(contact, birthday_target)
    birth_date = parse_birth_date(contact.custom_attributes['date_of_birth'])
    return if birth_date.blank? || !birthday_matches?(birth_date, birthday_target)
    return if external_opt_in_required? && !opted_in?(contact)

    automation.delivery_channels.each do |channel|
      process_channel(contact, channel, birthday_target)
    end
  end

  def process_channel(contact, channel, birthday_target)
    conversation = compatible_conversation(contact, channel)
    return count(:without_conversation) if conversation.blank?
    return count(:outside_whatsapp_window) if outside_whatsapp_window?(conversation, channel)

    deliver_channel(contact, conversation, channel, birthday_target)
  end

  def deliver_channel(contact, conversation, channel, birthday_target)
    delivery = automation.kanban_birthday_deliveries.find_or_create_by!(
      account: automation.account,
      contact: contact,
      birthday_year: birthday_target.year,
      delivery_channel: channel
    )
    return unless claim_delivery(delivery)

    message = send_message(contact, conversation, channel, birthday_target)
    delivery.update!(status: :sent, message_id: message.id, sent_at: Time.current, error_message: nil)
    counts[:sent] += 1
  rescue ActiveRecord::RecordNotUnique
    counts[:duplicate] += 1
  rescue StandardError => e
    delivery&.update(status: :failed, error_message: e.message, attempted_at: Time.current)
    counts[:failed] += 1
    Rails.logger.error("Kanban birthday delivery failed for contact #{contact.id}: #{e.message}")
  end

  def outside_whatsapp_window?(conversation, channel)
    channel == 'whatsapp' && !conversation.can_reply? && automation.whatsapp_template_params.blank?
  end

  def count(key)
    counts[key] += 1
    nil
  end

  def claim_delivery(delivery)
    delivery.with_lock do
      next false if delivery.sent? || delivery.sending?

      delivery.update!(status: :sending, attempted_at: Time.current, error_message: nil)
      true
    end
  end

  def send_message(contact, conversation, channel, birthday_target)
    params = {
      content: render_message(contact, birthday_target),
      message_type: 'outgoing',
      private: false,
      content_attributes: { birthday_automation_id: automation.id }
    }
    params[:template_params] = automation.whatsapp_template_params if channel == 'whatsapp'
    attachment_signed_id = message_attachment_signed_id
    params[:attachments] = [attachment_signed_id] if attachment_signed_id.present?

    Messages::MessageBuilder.new(nil, conversation, params).perform
  end

  def message_attachment_signed_id
    @message_attachment_signed_id ||= KanbanAutomations::MessageAttachmentService.new(
      data: { message_attachment: automation.message_attachment }
    ).signed_id
  end

  def compatible_conversation(contact, channel)
    inbox_type = channel == 'whatsapp' ? 'Whatsapp' : 'Email'
    contact.conversations
           .where(account_id: automation.account.id)
           .includes(:inbox)
           .order(last_activity_at: :desc, id: :desc)
           .find { |conversation| conversation.inbox&.inbox_type == inbox_type }
  end

  def render_message(contact, birthday_target)
    automation.message_template.gsub(
      /\{\{\s*(contact_name|birthday_date)\s*\}\}/,
      'contact_name' => contact.name.to_s,
      'birthday_date' => I18n.l(birthday_target, format: :long)
    )
  end

  def external_opt_in_required?
    automation.delivery_channels.present?
  end

  def opted_in?(contact)
    ActiveModel::Type::Boolean.new.cast(contact.custom_attributes[automation.opt_in_attribute_key])
  end

  def parse_birth_date(value)
    Date.iso8601(value.to_s)
  rescue Date::Error
    nil
  end

  def birthday_matches?(birth_date, target)
    Date.new(target.year, birth_date.month, birth_date.day) == target
  rescue Date::Error
    birth_date.month == 2 && birth_date.day == 29 && target == Date.new(target.year, 2, 28)
  end

  def with_account_timezone(&)
    Time.use_zone(automation.timezone_name, &)
  rescue ArgumentError
    Time.use_zone('UTC', &)
  end
end
