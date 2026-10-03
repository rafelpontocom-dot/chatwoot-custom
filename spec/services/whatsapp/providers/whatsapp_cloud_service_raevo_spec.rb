require 'rails_helper'

RSpec.describe Whatsapp::Providers::WhatsappCloudService do
  let(:channel) do
    create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false)
  end
  let(:conversation) { create(:conversation, inbox: channel.inbox) }
  let(:agent) { create(:user) }
  let(:message) do
    create(:message, conversation: conversation, inbox: channel.inbox, sender: agent, message_type: :outgoing, content: 'Ola')
  end

  it 'adds the agent name only to the WhatsApp payload' do
    allow(channel).to receive(:agent_name_signature_enabled?).and_return(true)
    request = stub_request(:post, 'https://graph.facebook.com/v13.0/123456789/messages')
              .with do |outgoing|
                body = JSON.parse(outgoing.body)
                body['text']['body'] == "*#{agent.available_name}*:\nOla" &&
                  body['to'] == '+123456789'
              end
              .to_return(status: 200, body: { messages: [{ id: 'sent-id' }] }.to_json,
                         headers: { 'Content-Type' => 'application/json' })

    expect(described_class.new(whatsapp_channel: channel).send_message('+123456789', message)).to eq('sent-id')
    expect(request).to have_been_requested.once
    expect(message.reload.content).to eq('Ola')
  end
end
