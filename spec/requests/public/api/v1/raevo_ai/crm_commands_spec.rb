require 'rails_helper'

RSpec.describe 'Raevo AI CRM commands API', type: :request do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:board) do
    create(
      :kanban_board,
      account: account,
      custom_field_definitions: [{
        'key' => 'preferred_period', 'label' => 'Preferred period', 'field_type' => 'select', 'options' => %w[morning afternoon evening]
      }]
    )
  end
  let(:source_stage) { create(:kanban_stage, account: account, kanban_board: board, name: 'New lead') }
  let(:target_stage) { create(:kanban_stage, account: account, kanban_board: board, name: 'Scheduling') }
  let(:booking_label) { create(:label, account: account, title: 'AGENDADO_IA') }
  let(:card) do
    create(:kanban_card, :conversation_origin, account: account, kanban_board: board, kanban_stage: source_stage, conversation: conversation)
  end
  let(:token) { 'a' * 64 }
  let(:integration) do
    RaevoAiIntegration.create!(
      account: account, clinic_id: 'clinic-demo', enabled: true,
      settings: {
        'command_token_digest' => Digest::SHA256.hexdigest(token),
        'crm' => {
          'boards' => {
            'acquisition' => {
              'board_id' => board.id,
              'initial_stage_id' => source_stage.id,
              'fields' => {
                'preferred_period' => {
                  'field_key' => 'preferred_period', 'type' => 'select',
                  'values' => %w[morning afternoon evening], 'overwrite' => 'if_empty'
                }
              },
              'stages' => {
                'new_lead' => { 'stage_id' => source_stage.id, 'allowed_from' => [] },
                'scheduling_requested' => { 'stage_id' => target_stage.id, 'allowed_from' => ['new_lead'] }
              },
              'labels' => {
                'booking_confirmed' => { 'label' => 'AGENDADO_IA' }
              }
            }
          },
          'contact_name' => { 'overwrite' => 'always' }
        }
      }
    )
  end
  let(:headers) { { 'X-Raevo-Clinic-Id' => integration.clinic_id, 'X-Raevo-Command-Token' => token } }

  it 'creates the opportunity through the tenant catalog without accepting a caller-supplied card or stage' do
    expect do
      post '/public/api/v1/raevo_ai/crm/opportunities', params: {
        action_id: 'turn-100:opportunity', conversation_id: conversation.display_id, board_key: 'acquisition',
        card_id: 999_999, stage_id: target_stage.id
      }, headers: headers, as: :json
    end.to change(KanbanCard.conversation, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(KanbanCard.conversation.last).to have_attributes(kanban_board: board, kanban_stage: source_stage, conversation: conversation)
    expect(response.parsed_body).to eq(
      'action_id' => 'turn-100:opportunity',
      'status' => 'applied',
      'receipts' => { 'opportunity' => { 'status' => 'created' } }
    )
  end

  it 'updates the card resolved from the trusted conversation and ignores a supplied card_id' do
    other_card = create(:kanban_card, account: account, kanban_board: board, kanban_stage: source_stage)
    post '/public/api/v1/raevo_ai/crm/fields', params: {
      action_id: 'turn-100:field:preferred_period', conversation_id: conversation.display_id,
      board_key: 'acquisition', expected_lock_version: card.lock_version,
      card_id: other_card.id,
      fields: [{ key: 'preferred_period', value: 'afternoon' }]
    }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(card.reload.custom_field_values).to include('preferred_period' => 'afternoon')
    expect(other_card.reload.custom_field_values).to eq({})
  end

  it 'moves only the conversation card using the allowed semantic event' do
    post '/public/api/v1/raevo_ai/crm/stages', params: {
      action_id: 'turn-100:stage:scheduling_requested', conversation_id: conversation.display_id,
      board_key: 'acquisition', event_key: 'scheduling_requested', expected_lock_version: card.lock_version,
      stage_id: create(:kanban_stage, account: account, kanban_board: board).id
    }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(card.reload.kanban_stage_id).to eq(target_stage.id)
  end

  it 'adds only a catalog-published label to the card resolved from the trusted conversation' do
    other_card = create(:kanban_card, account: account, kanban_board: board, kanban_stage: source_stage)

    post '/public/api/v1/raevo_ai/crm/labels', params: {
      action_id: 'turn-100:label:booking-confirmed', conversation_id: conversation.display_id,
      board_key: 'acquisition', expected_lock_version: card.lock_version,
      label: booking_label.title, card_id: other_card.id
    }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(card.reload.labels.pluck(:name)).to include(booking_label.title)
    expect(other_card.reload.labels.pluck(:name)).not_to include(booking_label.title)
  end

  it 'updates only the contact linked to the trusted conversation' do
    other_contact = create(:contact, account: account, name: 'Do not change')

    post '/public/api/v1/raevo_ai/crm/contact_name', params: {
      action_id: 'turn-100:contact-name', conversation_id: conversation.display_id,
      contact_id: other_contact.id, name: 'Marina Silva'
    }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(conversation.contact.reload.name).to eq('Marina Silva')
    expect(other_contact.reload.name).to eq('Do not change')
  end

  it 'returns only the resolved card version for a semantic command context' do
    expected_lock_version = card.lock_version
    other_card = create(:kanban_card, account: account, kanban_board: board, kanban_stage: source_stage)

    post '/public/api/v1/raevo_ai/crm/context', params: {
      conversation_id: conversation.display_id,
      board_key: 'acquisition',
      card_id: other_card.id
    }, headers: headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq({ 'lock_version' => expected_lock_version })
  end
end
