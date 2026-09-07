require 'rails_helper'

RSpec.describe 'Raevo AI assistant draft API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:path) { "/api/v1/accounts/#{account.id}/raevo_ai/assistant_draft" }
  let(:clusters) do
    {
      identity: { enabled: true, content: 'Secretária virtual.' },
      personality: { enabled: true, content: 'Serena.' },
      voice_style: { enabled: false, content: '' }
    }
  end

  it 'allows an account administrator to save only the account-bound assistant draft' do
    integration = RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-example', enabled: false)
    client = instance_double(RaevoAi::AssistantDraftClient, save: { response: { 'id' => 'draft-1', 'state' => 'draft' } })
    expect(RaevoAi::AssistantDraftClient).to receive(:new).with(integration: integration).and_return(client)
    expect(client).to receive(:save).with(
      editable_clusters: clusters.deep_stringify_keys,
      expected_revision: nil,
      actor_ref: "chatwoot:#{account.id}:#{administrator.id}"
    ).and_return(response: { 'id' => 'draft-1', 'state' => 'draft' })

    put path, params: { expected_revision: nil, editable_clusters: clusters }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('draft' => { 'id' => 'draft-1', 'state' => 'draft' })
  end

  it 'allows an account administrator to load the account-bound draft' do
    integration = RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-example', enabled: false)
    client = instance_double(RaevoAi::AssistantDraftClient, fetch: { response: {
                               'draft' => nil, 'active_version' => { 'version_number' => 7 }
                             } })
    expect(RaevoAi::AssistantDraftClient).to receive(:new).with(integration: integration).and_return(client)

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq(
      'draft' => nil,
      'active_version' => { 'version_number' => 7 }
    )
  end

  it 'does not allow an agent to save the account draft' do
    RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-example', enabled: true)
    agent = create(:user, account: account, role: :agent)

    put path, params: { expected_revision: nil, editable_clusters: clusters }, headers: agent.create_new_auth_token, as: :json

    expect(response).not_to have_http_status(:success)
  end

  it 'returns 409 when the draft changed after the administrator loaded it' do
    integration = RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-example', enabled: true)
    client = instance_double(RaevoAi::AssistantDraftClient)
    allow(RaevoAi::AssistantDraftClient).to receive(:new).with(integration: integration).and_return(client)
    allow(client).to receive(:save).and_raise(RaevoAi::AssistantDraftClient::Conflict)

    put path, params: { expected_revision: '2026-09-07T12:00:00.000Z', editable_clusters: clusters }, headers: administrator.create_new_auth_token,
              as: :json

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body).to eq('error' => 'assistant_draft_conflict')
  end

  it 'allows an administrator to request only an approved synthetic fixture' do
    integration = RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-example', enabled: true)
    client = instance_double(RaevoAi::AssistantDraftClient)
    allow(RaevoAi::AssistantDraftClient).to receive(:new).with(integration: integration).and_return(client)
    expect(client).to receive(:simulate).with(
      draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590', fixture_id: 'first_contact'
    ).and_return(response: { 'simulation' => { 'draft_id' => 'a0d18e55-64b1-4d93-a264-c02986186590' }, 'evaluation' => { 'verdict' => 'blocked' } })

    post "#{path}/simulate", params: {
      draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590', fixture_id: 'first_contact'
    }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq(
      'simulation' => { 'draft_id' => 'a0d18e55-64b1-4d93-a264-c02986186590' },
      'evaluation' => { 'verdict' => 'blocked' }
    )
  end

  it 'allows an administrator to record a server-evaluated review for the account draft' do
    integration = RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-example', enabled: true)
    client = instance_double(RaevoAi::AssistantDraftClient)
    allow(RaevoAi::AssistantDraftClient).to receive(:new).with(integration: integration).and_return(client)
    expect(client).to receive(:review).with(
      draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
      fixture_id: 'first_contact',
      expected_revision: '2026-09-07T12:00:00.000Z',
      decision: 'approved',
      actor_ref: "chatwoot:#{account.id}:#{administrator.id}"
    ).and_return(response: { 'id' => 'review-1', 'decision' => 'approved' })

    post "#{path}/review", params: {
      draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
      fixture_id: 'first_contact',
      expected_revision: '2026-09-07T12:00:00.000Z',
      decision: 'approved',
      evaluation: { verdict: 'ready_for_human_review' }
    }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('review' => { 'id' => 'review-1', 'decision' => 'approved' })
  end

  it 'allows an administrator to publish only an optimistically reviewed account draft' do
    integration = RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-example', enabled: true)
    client = instance_double(RaevoAi::AssistantDraftClient)
    allow(RaevoAi::AssistantDraftClient).to receive(:new).with(integration: integration).and_return(client)
    expect(client).to receive(:publish).with(
      draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
      expected_revision: '2026-09-07T12:00:00.000Z',
      expected_active_version_id: 'bbd18e55-64b1-4d93-a264-c02986186590',
      review_id: 'ccd18e55-64b1-4d93-a264-c02986186590',
      actor_ref: "chatwoot:#{account.id}:#{administrator.id}"
    ).and_return(response: { 'id' => 'a0d18e55-64b1-4d93-a264-c02986186590', 'state' => 'published' })

    post "#{path}/publish", params: {
      draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
      expected_revision: '2026-09-07T12:00:00.000Z',
      expected_active_version_id: 'bbd18e55-64b1-4d93-a264-c02986186590',
      review_id: 'ccd18e55-64b1-4d93-a264-c02986186590'
    }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('publication' => {
                                         'id' => 'a0d18e55-64b1-4d93-a264-c02986186590', 'state' => 'published'
                                       })
  end

  it 'allows an administrator to roll back with the current active version identifier' do
    integration = RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-example', enabled: true)
    client = instance_double(RaevoAi::AssistantDraftClient)
    allow(RaevoAi::AssistantDraftClient).to receive(:new).with(integration: integration).and_return(client)
    expect(client).to receive(:rollback).with(
      target_version_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
      expected_active_version_id: 'bbd18e55-64b1-4d93-a264-c02986186590',
      actor_ref: "chatwoot:#{account.id}:#{administrator.id}"
    ).and_return(response: { 'id' => 'a0d18e55-64b1-4d93-a264-c02986186590', 'state' => 'published' })

    post "#{path}/rollback", params: {
      target_version_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
      expected_active_version_id: 'bbd18e55-64b1-4d93-a264-c02986186590'
    }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq('rollback' => {
                                         'id' => 'a0d18e55-64b1-4d93-a264-c02986186590', 'state' => 'published'
                                       })
  end
end
