require 'rails_helper'

RSpec.describe 'Raevo AI knowledge API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:path) { "/api/v1/accounts/#{account.id}/raevo_ai/knowledge" }
  let!(:integration) { RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-anna-alice', enabled: true) }
  let(:item) do
    { id: nil, topic_key: 'precos', title: 'Botox', content: 'A partir de X', commercial_profile: 'private' }
  end

  def com_cliente(duplo)
    allow(RaevoAi::KnowledgeClient).to receive(:new).with(integration: integration).and_return(duplo)
  end

  it 'answers not configured when the account has no bridge' do
    RaevoAiIntegration.find(integration.id).destroy!

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:not_found)
  end

  it 'lets an agent read what the assistant knows' do
    com_cliente(instance_double(RaevoAi::KnowledgeClient, fetch: { topics: [], published: [], draft: nil, versions: [] }))

    get path, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
  end

  it 'does not let an agent change what the assistant tells patients' do
    patch path, params: { item: item, expected_revision: nil }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'saves a draft without publishing it' do
    duplo = instance_double(RaevoAi::KnowledgeClient)
    com_cliente(duplo)
    expect(duplo).to receive(:save_draft).with(hash_including(expected_revision: 3))
                                         .and_return(draft: { 'revision' => 4, 'items' => [] })

    patch path, params: { item: item, expected_revision: 3 }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body['draft']['revision']).to eq(4)
  end

  it 'refuses an item with a topic key that is not a key' do
    patch path, params: { item: item.merge(topic_key: 'Preços!'), expected_revision: 1 },
                headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'refuses an item carrying a field we did not ask for' do
    # Um `embedding` vindo do browser não tem como ser confiável; o conjunto de
    # campos é fechado de propósito.
    patch path, params: { item: item.merge(embedding: [0.1]), expected_revision: 1 },
                headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'reports a conflict when someone else edited in between' do
    duplo = instance_double(RaevoAi::KnowledgeClient)
    com_cliente(duplo)
    allow(duplo).to receive(:save_draft).and_raise(RaevoAi::KnowledgeClient::Conflict)

    patch path, params: { item: item, expected_revision: 1 }, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:conflict)
  end

  it 'asks the clinic to confirm before a sensitive publication goes out' do
    duplo = instance_double(RaevoAi::KnowledgeClient)
    com_cliente(duplo)
    allow(duplo).to receive(:publish).and_raise(RaevoAi::KnowledgeClient::SensitiveConfirmationRequired, %w[precos])

    post "#{path}/publish", params: { expected_revision: 4, confirmed_sensitive_keys: [] },
                            headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:precondition_required)
    expect(response.parsed_body['topics']).to eq(['precos'])
  end

  it 'publishes when the confirmation came with the request' do
    duplo = instance_double(RaevoAi::KnowledgeClient)
    com_cliente(duplo)
    expect(duplo).to receive(:publish).with(hash_including(confirmed_sensitive_keys: ['precos']))
                                      .and_return(active_version: { 'id' => 'v2', 'version_number' => 2 })

    post "#{path}/publish", params: { expected_revision: 4, confirmed_sensitive_keys: ['precos'] },
                            headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
  end

  it 'refuses to publish without saying which revision it saw' do
    post "#{path}/publish", params: { confirmed_sensitive_keys: [] },
                            headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'refuses a rollback to something that is not a version id' do
    post "#{path}/rollback", params: { version_id: 'nao-e-uuid' },
                             headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'says the bridge is down instead of pretending the base is empty' do
    com_cliente(instance_double(RaevoAi::KnowledgeClient).tap { |d| allow(d).to receive(:fetch).and_raise(RaevoAi::UpstreamError) })

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:service_unavailable)
  end
end
