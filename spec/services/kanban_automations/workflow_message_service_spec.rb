require 'rails_helper'

RSpec.describe KanbanAutomations::WorkflowMessageService do
  let(:card) { create(:kanban_card) }
  let(:conversation) { instance_double(Conversation) }

  it 'defers a message until the end of quiet hours' do
    now = ActiveSupport::TimeZone['America/Sao_Paulo'].parse('2026-08-01 22:30:00')
    service = build_service(
      { quiet_hours: { start: '20:00', end: '08:00', timezone: 'America/Sao_Paulo' } },
      now: now
    )
    allow(service).to receive_messages(compatible_conversation: conversation, opted_in?: true, whatsapp_outside_window?: false)

    result = service.perform!

    expect(result).to include('status' => 'waiting', 'reason' => 'quiet_hours')
    expect(result.fetch('scheduled_at')).to eq(ActiveSupport::TimeZone['America/Sao_Paulo'].parse('2026-08-02 08:00:00').iso8601)
  end

  it 'reports why a message is not eligible without sending it' do
    service = build_service({})
    allow(service).to receive(:compatible_conversation).and_return(nil)

    expect(service.eligibility).to eq(
      'action_name' => 'send_message',
      'status' => 'skipped',
      'reason' => 'no_compatible_conversation'
    )
  end

  it 'defers a message until the configured frequency window expires' do
    now = Time.zone.parse('2026-08-01 15:00:00')
    service = build_service({ frequency_limit_hours: 24 }, now: now)
    allow(service).to receive_messages(compatible_conversation: conversation, opted_in?: true, whatsapp_outside_window?: false)
    allow(service).to receive(:last_workflow_message_at).and_return(now - 6.hours)

    result = service.perform!

    expect(result).to include('status' => 'waiting', 'reason' => 'frequency_limit')
    expect(result.fetch('scheduled_at')).to eq((now + 18.hours).iso8601)
  end

  it 'uses an approved WhatsApp template outside the reply window' do
    service = build_service(
      { whatsapp_template_params: {
        name: 'consulta_lembrete', namespace: 'grow', category: 'UTILITY', language: 'pt_BR', processed_params: {}
      } }
    )

    inbox = instance_double(Inbox, inbox_type: 'Whatsapp')
    conversation = instance_double(Conversation, inbox: inbox, can_reply?: false)

    expect(service.send(:whatsapp_outside_window?, conversation)).to be(false)
    expect(service.send(:message_params)).to include(
      template_params: include(name: 'consulta_lembrete', language: 'pt_BR')
    )
  end

  it 'renders supported contact, opportunity, and custom field variables' do
    card.update!(
      subject: 'Avaliação inicial',
      amount_cents: 15_900
    )
    card.contact.update!(name: 'Ana Paula')
    allow(card).to receive(:custom_field_values).and_return({ 'origem' => 'Google' })
    service = build_service(
      {
        content: 'Olá {{contact_name}}, {{opportunity_subject}}: {{opportunity_amount}} via {{field.origem}}.'
      }
    )

    expect(service.send(:rendered_content)).to eq(
      'Olá Ana Paula, Avaliação inicial: 159.00 via Google.'
    )
  end

  it 'passes a validated image upload to the message builder' do
    attachment_service = instance_double(KanbanAutomations::MessageAttachmentService, signed_id: 'signed-image')
    allow(KanbanAutomations::MessageAttachmentService).to receive(:new).and_return(attachment_service)

    expect(build_service({ message_attachment: { signed_id: 'signed-image' } }).send(:message_params)).to include(
      attachments: ['signed-image']
    )
  end

  def build_service(data, now: self.now)
    described_class.new(
      card: card,
      data: { channel: 'whatsapp', opt_in_attribute_key: 'marketing_messages_opt_in', content: 'Olá' }.merge(data),
      now: now
    )
  end

  def now
    @now ||= Time.zone.parse('2026-08-01 15:00:00')
  end
end
