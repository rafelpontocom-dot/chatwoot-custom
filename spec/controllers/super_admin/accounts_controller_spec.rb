require 'rails_helper'

RSpec.describe 'Super Admin accounts API', type: :request do
  include ActiveJob::TestHelper

  let!(:super_admin) { create(:super_admin) }
  let!(:account) { create(:account) }

  describe 'GET /super_admin/accounts' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get '/super_admin/accounts'
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated user' do
      it 'shows the list of accounts' do
        sign_in(super_admin, scope: :super_admin)
        get '/super_admin/accounts'
        expect(response).to have_http_status(:success)
        expect(response.body).to include('New account')
        expect(response.body).to include(account.name)
      end
    end
  end

  describe 'GET /super_admin/accounts/{account_id}' do
    context 'when it is an authenticated user' do
      it 'shows effective Captain model routing', if: ChatwootApp.enterprise? do
        account.update!(captain_models: { 'editor' => 'gpt-4.1' })
        sign_in(super_admin, scope: :super_admin)

        get "/super_admin/accounts/#{account.id}"
        document = Nokogiri::HTML(response.body)
        summaries = document.css('details summary').map { |summary| summary.text.squish }

        expect(response).to have_http_status(:success)
        expect(document.at_css('#captain_models').text.squish).to eq('Captain models')
        expect(summaries).to include('View model routing')
        expect(summaries).not_to include('All features')
        expect(summaries).not_to include('Captain models')
        expect(response.body).to include('Editor', 'OpenAI', 'openai', 'gpt-4.1', 'Account override', 'Label suggestion', 'Default')
      end
    end
  end

  describe 'GET /super_admin/accounts/{account_id}/edit' do
    context 'when it is an authenticated user' do
      it 'renders a Captain model selector for every AI feature', if: ChatwootApp.enterprise? do
        account.update!(captain_models: { 'editor' => 'gpt-4.1' })
        sign_in(super_admin, scope: :super_admin)

        get "/super_admin/accounts/#{account.id}/edit"

        expect(response).to have_http_status(:success)
        Llm::Models.feature_keys.each do |feature_key|
          expect(response.body).to include("account[captain_models][#{feature_key}]")
        end

        document = Nokogiri::HTML(response.body)
        editor_select = document.at_css('select[name="account[captain_models][editor]"]')
        default_model_id = Llm::Models.default_model_for('editor')
        default_model = Llm::Models.model_config(default_model_id)['display_name']

        expect(editor_select.at_css('option[value=""]').text.squish).to eq("Use default: #{default_model} (#{default_model_id})")
      end
    end
  end

  describe 'PATCH /super_admin/accounts/{account_id}' do
    context 'when it is an authenticated user' do
      it 'updates Captain model overrides without changing unrelated settings' do
        account.update!(
          captain_models: { 'editor' => 'gpt-4.1' },
          keep_pending_on_bot_failure: true
        )
        sign_in(super_admin, scope: :super_admin)

        patch "/super_admin/accounts/#{account.id}",
              params: {
                account: {
                  name: account.name,
                  locale: account.locale,
                  status: account.status,
                  captain_models: {
                    editor: '',
                    assistant: 'gpt-5.2'
                  }
                }
              }

        expect(response).to have_http_status(:redirect)
        expect(account.reload.captain_models).to eq('assistant' => 'gpt-5.2')
        expect(account.keep_pending_on_bot_failure).to be true
      end

      it 'rejects invalid Captain model overrides' do
        sign_in(super_admin, scope: :super_admin)

        patch "/super_admin/accounts/#{account.id}",
              params: {
                account: {
                  name: account.name,
                  locale: account.locale,
                  status: account.status,
                  captain_models: {
                    label_suggestion: 'gpt-5.1'
                  }
                }
              }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('not a valid model for label_suggestion')
        expect(account.reload.captain_models).to be_nil
      end
    end
  end

  describe 'POST /super_admin/accounts/{account_id}/reset_cache' do
    before do
      create(:label, account: account)
      create(:inbox, account: account)
      create(:team, account: account)
    end

    after do
      Conversations::UnreadCounts::Store.clear_account!(account.id)
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/super_admin/accounts/#{account.id}/reset_cache"
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated user' do
      it 'shows the list of accounts' do
        expect(account.cache_keys.keys).to contain_exactly(:inbox, :label, :team)
        sign_in(super_admin, scope: :super_admin)

        now_timestamp = Time.now.utc.to_i
        post "/super_admin/accounts/#{account.id}/reset_cache"
        expect(response).to have_http_status(:redirect)
        expect(flash[:notice]).to eq('Cache keys cleared')

        range = now_timestamp..(now_timestamp + 10)
        expect(account.reload.cache_keys.values.all? { |v| range.cover?(v.to_i) }).to be(true)
      end

      it 'clears conversation unread count cache' do
        inbox = account.inboxes.first
        store = Conversations::UnreadCounts::Store
        inbox_key = store.inbox_key(account.id, inbox.id)
        store.mark_base_ready!(account.id)
        store.add_base_membership(account_id: account.id, inbox_id: inbox.id, label_ids: [], conversation_id: 1)

        sign_in(super_admin, scope: :super_admin)
        post "/super_admin/accounts/#{account.id}/reset_cache"

        expect(response).to have_http_status(:redirect)
        expect(store.base_ready?(account.id)).to be(false)
        expect(store.counts_for_keys([inbox_key])).to eq(inbox_key => 0)
      end
    end
  end

  describe 'POST /super_admin/accounts/{account_id}/provision_raevo_ai' do
    let(:board) { create(:kanban_board, account: account) }
    let(:qualification) { create(:kanban_stage, account: account, kanban_board: board) }
    let(:command_token) { 'a' * 48 }
    let(:provisioning_params) do
      {
        raevo_ai: {
          clinic_id: 'clinic-demo',
          command_token: command_token,
          board_key: 'consulta',
          board_id: board.id,
          initial_stage_id: qualification.id,
          stages_json: {
            qualified: { stage_id: qualification.id, allowed_from: [] }
          }.to_json
        }
      }
    end

    it 'shows the provisioning controls on the account detail page' do
      sign_in(super_admin, scope: :super_admin)

      get "/super_admin/accounts/#{account.id}"

      expect(response).to have_http_status(:success)
      expect(response.body).to include('RAEVO AI')
      expect(response.body).to include('Provision AI')
    end

    it 'requires a Super Admin session' do
      post "/super_admin/accounts/#{account.id}/provision_raevo_ai", params: provisioning_params

      expect(response).to have_http_status(:redirect)
      expect(account.raevo_ai_integration).to be_nil
    end

    it 'provisions the catalog and fields without enabling the account' do
      sign_in(super_admin, scope: :super_admin)

      post "/super_admin/accounts/#{account.id}/provision_raevo_ai", params: provisioning_params

      integration = account.reload.raevo_ai_integration
      expect(response).to redirect_to("http://www.example.com/super_admin/accounts/#{account.id}")
      expect(integration).to be_present
      expect(integration).not_to be_enabled
      expect(integration.settings.dig('crm', 'boards', 'consulta', 'board_id')).to eq(board.id)
      expect(integration.settings['command_token_digest']).to eq(Digest::SHA256.hexdigest(command_token))
      expect(board.reload.configured_custom_field_definitions.map { |field| field['key'] }).to include('raevo_ai_status')
      expect(response.body).not_to include(command_token)
    end

    it 'rejects a non-object semantic stage catalog without creating an integration' do
      sign_in(super_admin, scope: :super_admin)

      post "/super_admin/accounts/#{account.id}/provision_raevo_ai",
           params: provisioning_params.deep_merge(raevo_ai: { stages_json: [{ stage_id: qualification.id }].to_json })

      expect(response).to redirect_to("http://www.example.com/super_admin/accounts/#{account.id}")
      expect(account.reload.raevo_ai_integration).to be_nil
    end
  end

  describe 'POST /super_admin/accounts/{account_id}/activate_raevo_ai' do
    let!(:integration) do
      RaevoAiIntegration.create!(
        account: account,
        clinic_id: 'clinic-demo',
        enabled: false,
        settings: {
          'command_token_digest' => Digest::SHA256.hexdigest('a' * 48),
          'crm' => { 'boards' => { 'consulta' => { 'board_id' => 1, 'initial_stage_id' => 1, 'stages' => { 'qualified' => {} } } } },
          'opportunity_ai_tab' => { 'enabled' => true, 'board_ids' => [1] }
        }
      )
    end

    it 'requires explicit confirmation before enabling the account' do
      sign_in(super_admin, scope: :super_admin)

      post "/super_admin/accounts/#{account.id}/activate_raevo_ai"

      expect(response).to redirect_to("http://www.example.com/super_admin/accounts/#{account.id}")
      expect(integration.reload).not_to be_enabled
    end

    it 'enables a provisioned integration after the operator confirms the token is deployed' do
      sign_in(super_admin, scope: :super_admin)

      post "/super_admin/accounts/#{account.id}/activate_raevo_ai", params: { token_deployed: '1' }

      expect(response).to redirect_to("http://www.example.com/super_admin/accounts/#{account.id}")
      expect(integration.reload).to be_enabled
    end
  end

  describe 'DELETE /super_admin/accounts/{account_id}' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/super_admin/accounts/#{account.id}"
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when it is an authenticated user' do
      it 'Deletes the account' do
        total_accounts = Account.count
        sign_in(super_admin, scope: :super_admin)

        perform_enqueued_jobs(only: DeleteObjectJob) do
          delete "/super_admin/accounts/#{account.id}"
        end

        expect(Account.count).to eq(total_accounts - 1)
      end
    end
  end
end
