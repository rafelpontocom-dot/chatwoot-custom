require 'rails_helper'

RSpec.describe RaevoAi::KnowledgeClient do
  let(:integration) do
    RaevoAiIntegration.create!(account: create(:account), clinic_id: 'clinic-example', enabled: true)
  end
  let(:item) do
    { 'id' => 'a1', 'topic_key' => 'precos', 'title' => 'Botox', 'content' => 'A partir de X',
      'commercial_profile' => 'private' }
  end

  def com_ponte(&)
    with_modified_env(RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret', &)
  end

  it 'never lets the vector or the internal claim key reach the browser' do
    # `embedding` é maquinaria de busca e `claim_key`/`source` são rastreio
    # interno: nada disso tem porque chegar ao ecrã da clínica.
    response = instance_double(HTTParty::Response, success?: true, code: 200, body: {
      'topics' => [{ 'key' => 'precos', 'label' => 'Preços', 'sensitive' => true, 'weight' => 9 }],
      'published' => [item.merge('embedding' => [0.1, 0.2], 'claim_key' => 'botox', 'source' => 'chatwoot')],
      'draft' => nil,
      'versions' => []
    }.to_json)

    com_ponte do
      allow(HTTParty).to receive(:get).and_return(response)
      resultado = described_class.new(integration: integration).fetch

      expect(resultado[:published].first.keys)
        .to match_array(%w[id topic_key title content commercial_profile])
      expect(resultado[:topics].first.keys).to match_array(%w[key label sensitive])
    end
  end

  it 'reads the draft with its revision, which is what guards the next write' do
    response = instance_double(HTTParty::Response, success?: true, code: 200, body: {
      'topics' => [], 'published' => [], 'versions' => [],
      'draft' => { 'revision' => 4, 'items' => [item] }
    }.to_json)

    com_ponte do
      allow(HTTParty).to receive(:get).and_return(response)

      expect(described_class.new(integration: integration).fetch[:draft])
        .to eq('revision' => 4, 'items' => [item])
    end
  end

  it 'treats an absent draft as a legitimate answer, not a failure' do
    response = instance_double(HTTParty::Response, success?: true, code: 200, body: {
      'topics' => [], 'published' => [], 'versions' => [], 'draft' => nil
    }.to_json)

    com_ponte do
      allow(HTTParty).to receive(:get).and_return(response)

      expect(described_class.new(integration: integration).fetch[:draft]).to be_nil
    end
  end

  it 'saves the draft without publishing anything' do
    response = instance_double(HTTParty::Response, success?: true, code: 200, body: {
      'draft' => { 'revision' => 5, 'items' => [item] }
    }.to_json)

    com_ponte do
      expect(HTTParty).to receive(:put).with(
        'https://elis.internal/internal/chatwoot/knowledge/draft',
        headers: hash_including('X-Raevo-Actor-Ref' => 'chatwoot:1:2'),
        body: { expected_revision: 4, item: item }.to_json,
        timeout: 10
      ).and_return(response)

      resultado = described_class.new(integration: integration)
                                 .save_draft(item: item, expected_revision: 4, actor_ref: 'chatwoot:1:2')
      expect(resultado[:draft]['revision']).to eq(5)
    end
  end

  it 'raises a conflict when someone else edited in between' do
    response = instance_double(HTTParty::Response, success?: false, code: 409,
                                                   body: { 'error' => 'knowledge_conflict' }.to_json)

    com_ponte do
      allow(HTTParty).to receive(:put).and_return(response)

      expect { described_class.new(integration: integration).save_draft(item: item, expected_revision: 1, actor_ref: 'x') }
        .to raise_error(described_class::Conflict)
    end
  end

  it 'hands back what still needs confirming instead of publishing a sensitive change' do
    response = instance_double(HTTParty::Response, success?: false, code: 428, body: {
      'error' => 'sensitive_confirmation_required', 'topics' => %w[precos convenios]
    }.to_json)

    com_ponte do
      allow(HTTParty).to receive(:post).and_return(response)

      expect { described_class.new(integration: integration).publish(expected_revision: 4, confirmed_sensitive_keys: [], actor_ref: 'x') }
        .to raise_error(described_class::SensitiveConfirmationRequired) { |erro| expect(erro.topics).to eq(%w[precos convenios]) }
    end
  end

  it 'reports the bridge being down instead of pretending the base is empty' do
    com_ponte do
      allow(HTTParty).to receive(:get).and_raise(Errno::ECONNREFUSED)

      expect { described_class.new(integration: integration).fetch }.to raise_error(RaevoAi::UpstreamError)
    end
  end

  it 'refuses to work without the bridge configured' do
    expect { described_class.new(integration: integration).fetch }.to raise_error(RaevoAi::ConfigurationError)
  end
end
