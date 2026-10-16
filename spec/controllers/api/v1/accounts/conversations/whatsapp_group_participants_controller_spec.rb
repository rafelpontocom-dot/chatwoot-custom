require 'rails_helper'

RSpec.describe 'WhatsApp group participants API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:group) { create(:contact, account: account, identifier: '120363012345678162@g.us') }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, contact: group) }
  let(:path) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/whatsapp_group_participants" }

  before { create(:inbox_member, user: agent, inbox: inbox) }

  def incoming(content, at)
    create(:message, account: account, inbox: inbox, conversation: conversation, message_type: :incoming,
                     sender: group, content: content, created_at: at)
  end

  # O formato real, lido em produção a 08/10: o WAHA põe quem falou no topo da mensagem.
  it 'lists who spoke in the group, most recent first, with the text the WAHA turns into a mention' do
    incoming("👥 *Ana Souza (123456789012628@lid)*\n\nBom dia", 3.hours.ago)
    incoming("👥 *Bruno (5581999990000@c.us)*\n\nOlá @123456789012628", 2.hours.ago)
    incoming("👥 *Ana S. (123456789012628@lid)*\n\nObrigada", 1.hour.ago)

    get path, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['payload']).to eq([
                                                    { 'id' => '123456789012628@lid', 'name' => 'Ana S.',
                                                      'mention' => '@123456789012628@lid' },
                                                    { 'id' => '5581999990000@c.us', 'name' => 'Bruno', 'mention' => '@5581999990000' }
                                                  ])
  end

  it 'also reads the participant line when the template puts it at the bottom' do
    incoming("Até já\n\n👥 *Carla (987654321098765@lid)*", 1.hour.ago)

    get path, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body['payload'].pluck('name')).to eq(['Carla'])
  end

  it 'returns nobody for a conversation with a person, not a group' do
    person = create(:contact, account: account, identifier: '5581999990000@c.us')
    conversation.update!(contact: person)
    incoming("👥 *Ana (123456789012628@lid)*\n\nBom dia", 1.hour.ago)

    get path, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body['payload']).to eq([])
  end

  it 'refuses an agent who cannot see the conversation' do
    outsider = create(:user, account: account, role: :agent)

    get path, headers: outsider.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
