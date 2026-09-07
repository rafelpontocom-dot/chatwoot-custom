require 'rails_helper'

RSpec.describe RaevoAi::AssistantDraftClient do
  let(:integration) do
    RaevoAiIntegration.create!(account: create(:account), clinic_id: 'clinic-example', enabled: true)
  end
  let(:editable_clusters) do
    {
      'identity' => { 'enabled' => true, 'content' => 'Secretária virtual.' },
      'personality' => { 'enabled' => true, 'content' => 'Serena.' },
      'voice_style' => { 'enabled' => false, 'content' => '' }
    }
  end

  it 'sends only the allowlisted draft payload through the server-side bridge' do
    response = instance_double(HTTParty::Response, success?: true, code: 200, body: {
      'draft' => {
        'id' => 'draft-1', 'version_number' => 2, 'revision' => '2026-09-07T12:00:00.000Z',
        'state' => 'draft', 'editable_clusters' => editable_clusters, 'internal_prompt' => 'must-not-leak'
      }
    }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      expect(HTTParty).to receive(:put).with(
        'https://elis.internal/internal/chatwoot/assistant-draft',
        headers: hash_including(
          'Authorization' => 'Bearer bridge-secret',
          'X-Raevo-Clinic-Id' => 'clinic-example',
          'X-Raevo-Actor-Ref' => 'chatwoot:3:6',
          'Content-Type' => 'application/json'
        ),
        body: {
          expected_revision: nil,
          editable_clusters: editable_clusters
        }.to_json,
        timeout: 10
      ).and_return(response)

      expect(described_class.new(integration: integration).save(
               editable_clusters: editable_clusters,
               expected_revision: nil,
               actor_ref: 'chatwoot:3:6'
             )).to eq(response: {
                        'id' => 'draft-1', 'version_number' => 2, 'revision' => '2026-09-07T12:00:00.000Z',
                        'state' => 'draft', 'editable_clusters' => editable_clusters
                      })
    end
  end

  it 'preserves a stale-revision conflict instead of treating it as an upstream outage' do
    response = instance_double(HTTParty::Response, success?: false, code: 409, body: { 'error' => 'assistant_draft_conflict' }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      allow(HTTParty).to receive(:put).and_return(response)

      expect do
        described_class.new(integration: integration).save(
          editable_clusters: editable_clusters,
          expected_revision: '2026-09-07T12:00:00.000Z',
          actor_ref: 'chatwoot:3:6'
        )
      end.to raise_error(RaevoAi::AssistantDraftClient::Conflict)
    end
  end

  it 'returns a draft or an explicit empty state through the server-side bridge' do
    response = instance_double(HTTParty::Response, success?: true, body: {
      'draft' => nil,
      'active_version' => {
        'id' => 'a0d18e55-64b1-4d93-a264-c02986186590',
        'version_number' => 7,
        'internal_prompt' => 'must-not-leak'
      }
    }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      expect(HTTParty).to receive(:get).with(
        'https://elis.internal/internal/chatwoot/assistant-draft',
        headers: hash_including('Authorization' => 'Bearer bridge-secret', 'X-Raevo-Clinic-Id' => 'clinic-example'),
        timeout: 10
      ).and_return(response)

      expect(described_class.new(integration: integration).fetch).to eq(response: {
                                                                          'draft' => nil,
                                                                          'active_version' => { 'id' => 'a0d18e55-64b1-4d93-a264-c02986186590',
                                                                                                'version_number' => 7 }
                                                                        })
    end
  end

  it 'sends only a draft identifier and an approved fixture to the simulation bridge' do
    response = instance_double(HTTParty::Response, success?: true, body: {
      'simulation' => {
        'draft_id' => 'a0d18e55-64b1-4d93-a264-c02986186590',
        'comparison' => { 'active_version_number' => 8, 'draft_version_number' => 9 },
        'response_bubbles' => ['Resposta sintética.'],
        'intent' => 'information_request',
        'simulated_actions' => [],
        'blocked_actions' => [],
        'execution' => { 'delivery_disposition' => 'discard', 'mutable_tools' => 'disabled', 'persistence' => 'none' },
        'internal_context' => 'must-not-leak'
      },
      'evaluation' => {
        'verdict' => 'ready_for_human_review',
        'criteria' => [{ 'id' => 'simulation_invariants', 'status' => 'passed', 'internal_reason' => 'must-not-leak' }]
      }
    }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      expect(HTTParty).to receive(:post).with(
        'https://elis.internal/internal/chatwoot/assistant-draft/simulate',
        headers: hash_including('Authorization' => 'Bearer bridge-secret', 'X-Raevo-Clinic-Id' => 'clinic-example'),
        body: { draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590', fixture_id: 'first_contact' }.to_json,
        timeout: 10
      ).and_return(response)

      expect(described_class.new(integration: integration).simulate(
               draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590', fixture_id: 'first_contact'
             )).to eq(response: {
                        'simulation' => {
                          'draft_id' => 'a0d18e55-64b1-4d93-a264-c02986186590',
                          'comparison' => { 'active_version_number' => 8, 'draft_version_number' => 9 },
                          'response_bubbles' => ['Resposta sintética.'],
                          'intent' => 'information_request',
                          'simulated_actions' => [],
                          'blocked_actions' => [],
                          'execution' => { 'delivery_disposition' => 'discard', 'mutable_tools' => 'disabled', 'persistence' => 'none' }
                        },
                        'evaluation' => {
                          'verdict' => 'ready_for_human_review',
                          'criteria' => [{ 'id' => 'simulation_invariants', 'status' => 'passed' }]
                        }
                      })
    end
  end

  it 'sends a review command through the server-side bridge without accepting browser evaluation data' do
    response = instance_double(HTTParty::Response, success?: true, code: 200, body: {
      'review' => {
        'id' => 'a0d18e55-64b1-4d93-a264-c02986186590',
        'draft_id' => 'bbd18e55-64b1-4d93-a264-c02986186590',
        'draft_revision' => '2026-09-07T12:00:00.000Z',
        'decision' => 'approved',
        'created_at' => '2026-09-07T12:01:00.000Z',
        'evaluation' => { 'must-not-leak' => true }
      }
    }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      expect(HTTParty).to receive(:post).with(
        'https://elis.internal/internal/chatwoot/assistant-draft/review',
        headers: hash_including(
          'Authorization' => 'Bearer bridge-secret',
          'X-Raevo-Clinic-Id' => 'clinic-example',
          'X-Raevo-Actor-Ref' => 'chatwoot:3:6',
          'Content-Type' => 'application/json'
        ),
        body: {
          draft_id: 'bbd18e55-64b1-4d93-a264-c02986186590',
          fixture_id: 'first_contact',
          expected_revision: '2026-09-07T12:00:00.000Z',
          decision: 'approved'
        }.to_json,
        timeout: 10
      ).and_return(response)

      expect(described_class.new(integration: integration).review(
               draft_id: 'bbd18e55-64b1-4d93-a264-c02986186590',
               fixture_id: 'first_contact',
               expected_revision: '2026-09-07T12:00:00.000Z',
               decision: 'approved',
               actor_ref: 'chatwoot:3:6'
             )).to eq(response: {
                        'id' => 'a0d18e55-64b1-4d93-a264-c02986186590',
                        'draft_id' => 'bbd18e55-64b1-4d93-a264-c02986186590',
                        'draft_revision' => '2026-09-07T12:00:00.000Z',
                        'decision' => 'approved',
                        'created_at' => '2026-09-07T12:01:00.000Z'
                      })
    end
  end

  it 'sends a publication command with optimistic version identifiers through the server-side bridge' do
    response = instance_double(HTTParty::Response, success?: true, code: 200, body: {
      'publication' => {
        'id' => 'a0d18e55-64b1-4d93-a264-c02986186590',
        'version_number' => 9,
        'previous_active_version_id' => 'bbd18e55-64b1-4d93-a264-c02986186590',
        'state' => 'published',
        'published_at' => '2026-09-07T12:01:00.000Z',
        'internal_audit' => 'must-not-leak'
      }
    }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      expect(HTTParty).to receive(:post).with(
        'https://elis.internal/internal/chatwoot/assistant-draft/publish',
        headers: hash_including('X-Raevo-Actor-Ref' => 'chatwoot:3:6'),
        body: {
          draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
          expected_revision: '2026-09-07T12:00:00.000Z',
          expected_active_version_id: 'bbd18e55-64b1-4d93-a264-c02986186590',
          review_id: 'ccd18e55-64b1-4d93-a264-c02986186590'
        }.to_json,
        timeout: 10
      ).and_return(response)

      expect(described_class.new(integration: integration).publish(
               draft_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
               expected_revision: '2026-09-07T12:00:00.000Z',
               expected_active_version_id: 'bbd18e55-64b1-4d93-a264-c02986186590',
               review_id: 'ccd18e55-64b1-4d93-a264-c02986186590',
               actor_ref: 'chatwoot:3:6'
             )).to eq(response: {
                        'id' => 'a0d18e55-64b1-4d93-a264-c02986186590',
                        'version_number' => 9,
                        'previous_active_version_id' => 'bbd18e55-64b1-4d93-a264-c02986186590',
                        'state' => 'published',
                        'published_at' => '2026-09-07T12:01:00.000Z'
                      })
    end
  end

  it 'sends a rollback command with the expected active version through the server-side bridge' do
    response = instance_double(HTTParty::Response, success?: true, code: 200, body: {
      'rollback' => {
        'id' => 'a0d18e55-64b1-4d93-a264-c02986186590',
        'version_number' => 8,
        'previous_active_version_id' => 'bbd18e55-64b1-4d93-a264-c02986186590',
        'state' => 'published',
        'published_at' => '2026-09-07T12:02:00.000Z',
        'internal_audit' => 'must-not-leak'
      }
    }.to_json)

    with_modified_env RAEVO_AI_SERVICE_URL: 'https://elis.internal', RAEVO_AI_SERVICE_TOKEN: 'bridge-secret' do
      expect(HTTParty).to receive(:post).with(
        'https://elis.internal/internal/chatwoot/assistant-draft/rollback',
        headers: hash_including('X-Raevo-Actor-Ref' => 'chatwoot:3:6'),
        body: {
          target_version_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
          expected_active_version_id: 'bbd18e55-64b1-4d93-a264-c02986186590'
        }.to_json,
        timeout: 10
      ).and_return(response)

      expect(described_class.new(integration: integration).rollback(
               target_version_id: 'a0d18e55-64b1-4d93-a264-c02986186590',
               expected_active_version_id: 'bbd18e55-64b1-4d93-a264-c02986186590',
               actor_ref: 'chatwoot:3:6'
             )).to eq(response: {
                        'id' => 'a0d18e55-64b1-4d93-a264-c02986186590',
                        'version_number' => 8,
                        'previous_active_version_id' => 'bbd18e55-64b1-4d93-a264-c02986186590',
                        'state' => 'published',
                        'published_at' => '2026-09-07T12:02:00.000Z'
                      })
    end
  end
end
