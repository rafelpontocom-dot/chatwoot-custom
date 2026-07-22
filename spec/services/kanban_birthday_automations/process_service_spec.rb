require 'rails_helper'

RSpec.describe KanbanBirthdayAutomations::ProcessService do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:automation) do
    create(
      :kanban_birthday_automation,
      account: account,
      active: true,
      delivery_channels: ['whatsapp'],
      timezone: 'UTC'
    )
  end
  let(:contact) do
    create(
      :contact,
      account: account,
      name: 'Ana',
      phone_number: '+5511999999999',
      custom_attributes: {
        'date_of_birth' => Date.current.iso8601,
        'birthday_messages_opt_in' => true
      }
    )
  end
  let(:whatsapp_channel) do
    create(
      :channel_whatsapp,
      account: account,
      provider: 'whatsapp_cloud',
      provider_config: { 'api_key' => 'test_key', 'phone_number_id' => '123456789', 'source' => 'embedded_signup' },
      sync_templates: false,
      validate_provider_config: false
    )
  end
  let(:whatsapp_inbox) { create(:inbox, account: account, channel: whatsapp_channel) }
  let(:conversation) { create(:conversation, account: account, contact: contact, inbox: whatsapp_inbox) }

  before do
    conversation
    create(:message, account: account, conversation: conversation, inbox: conversation.inbox, sender: contact)
  end

  it 'sends one opt-in message and remains idempotent on retries' do
    message = instance_double(Message, id: 42)
    builder = instance_double(Messages::MessageBuilder, perform: message)
    allow(Messages::MessageBuilder).to receive(:new).and_return(builder)

    result = described_class.new(automation: automation).perform!

    expect(result).to include(sent: 1)
    expect(KanbanBirthdayDelivery.count).to eq(1)

    expect(builder).to have_received(:perform)
    expect(KanbanBirthdayDelivery.last).to have_attributes(status: 'sent', message_id: 42)
    expect(described_class.new(automation: automation).perform!).not_to include(:sent)
    expect(builder).to have_received(:perform).once
  end

  it 'does not send without the contact opt-in' do
    contact.update!(custom_attributes: { 'date_of_birth' => Date.current.iso8601 })

    expect(Messages::MessageBuilder).not_to receive(:new)
    expect(described_class.new(automation: automation).perform!).not_to include(:sent)
    expect(KanbanBirthdayDelivery.count).to eq(0)
  end

  it 'does not send WhatsApp free-form messages outside the messaging window' do
    conversation.messages.incoming.last.update!(created_at: 2.days.ago)

    expect(Messages::MessageBuilder).not_to receive(:new)
    expect(described_class.new(automation: automation).perform!).to include(outside_whatsapp_window: 1)
  end

  it 'supports a WhatsApp template outside the messaging window' do
    automation.update!(whatsapp_template_params: { name: 'birthday', language: 'pt_BR' })
    conversation.messages.incoming.last.update!(created_at: 2.days.ago)
    message = instance_double(Message, id: 43)
    builder = instance_double(Messages::MessageBuilder, perform: message)
    allow(Messages::MessageBuilder).to receive(:new).and_return(builder)

    described_class.new(automation: automation).perform!

    expect(Messages::MessageBuilder).to have_received(:new).with(
      nil,
      conversation,
      hash_including(template_params: { 'name' => 'birthday', 'language' => 'pt_BR' })
    )
  end

  it 'selects an email conversation for email delivery' do
    automation.update!(delivery_channels: ['email'])
    email_inbox = create(:inbox, account: account, channel: create(:channel_email, account: account))
    email_conversation = create(:conversation, account: account, contact: contact, inbox: email_inbox)
    allow(email_conversation).to receive(:can_reply?).and_return(true)
    message = instance_double(Message, id: 44)
    allow(Messages::MessageBuilder).to receive(:new).and_return(instance_double(Messages::MessageBuilder, perform: message))

    described_class.new(automation: automation).perform!

    expect(Messages::MessageBuilder).to have_received(:new).with(nil, email_conversation, anything)
  end

  it 'handles February 29 birthdays on February 28 in a non-leap year' do
    travel_to Time.utc(2027, 2, 28, 9) do
      automation.update!(whatsapp_template_params: { name: 'birthday', language: 'pt_BR' })
      contact.update!(
        custom_attributes: {
          'date_of_birth' => '2000-02-29',
          'birthday_messages_opt_in' => true
        }
      )
      message = instance_double(Message, id: 45)
      allow(Messages::MessageBuilder).to receive(:new).and_return(instance_double(Messages::MessageBuilder, perform: message))

      described_class.new(automation: automation).perform!

      expect(KanbanBirthdayDelivery.count).to eq(1)
    end
  end

  it 'processes contacts in batches without duplicate deliveries' do
    stub_const('KanbanBirthdayAutomations::ProcessService::BATCH_SIZE', 2)
    contact.update!(custom_attributes: {})
    contacts = create_list(
      :contact,
      5,
      account: account,
      phone_number: nil,
      custom_attributes: {
        'date_of_birth' => Date.current.iso8601,
        'birthday_messages_opt_in' => true
      }
    )
    contacts.each do |birthday_contact|
      birthday_conversation = create(
        :conversation,
        account: account,
        contact: birthday_contact,
        inbox: whatsapp_inbox
      )
      create(
        :message,
        account: account,
        conversation: birthday_conversation,
        inbox: whatsapp_inbox,
        sender: birthday_contact
      )
    end
    message = instance_double(Message, id: 46)
    allow(Messages::MessageBuilder).to receive(:new).and_return(
      instance_double(Messages::MessageBuilder, perform: message)
    )

    result = described_class.new(automation: automation).perform!

    expect(result).to include(sent: 5)
    expect(KanbanBirthdayDelivery.where(status: :sent).count).to eq(5)
    expect(Messages::MessageBuilder).to have_received(:new).exactly(5).times
  end

  it 'scans a high-volume contact set in bounded batches' do
    stub_const('KanbanBirthdayAutomations::ProcessService::BATCH_SIZE', 10)
    contact.update!(custom_attributes: {})
    create_list(
      :contact,
      100,
      account: account,
      custom_attributes: {
        'date_of_birth' => Date.current.iso8601,
        'birthday_messages_opt_in' => true
      }
    )

    result = described_class.new(automation: automation).perform!

    expect(result).to include(without_conversation: 100)
    expect(KanbanBirthdayDelivery.count).to eq(0)
  end
end
