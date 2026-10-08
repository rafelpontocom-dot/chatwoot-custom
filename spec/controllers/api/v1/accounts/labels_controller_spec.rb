require 'rails_helper'

RSpec.describe 'Label API', type: :request do
  let!(:account) { create(:account) }
  let!(:label) { create(:label, account: account) }
  let!(:conversation) { create(:conversation, account: account) }

  describe 'POST /api/v1/accounts/{account.id}/labels/reorder' do
    let(:admin) { create(:user, account: account, role: :administrator) }
    let!(:second_label) { create(:label, account: account, position: 1) }

    it 'persists the requested order for the account' do
      post "/api/v1/accounts/#{account.id}/labels/reorder",
           headers: admin.create_new_auth_token, params: { label_ids: [second_label.id, label.id] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(second_label.reload.position).to eq(0)
      expect(label.reload.position).to eq(1)
    end

    it 'rejects an unauthenticated reorder without changing positions' do
      expect do
        post "/api/v1/accounts/#{account.id}/labels/reorder", params: { label_ids: [second_label.id, label.id] }, as: :json
      end.not_to(change { second_label.reload.position })

      expect(response).to have_http_status(:unauthorized)
    end

    it 'rejects an agent without administration permission' do
      agent = create(:user, account: account, role: :agent)
      post "/api/v1/accounts/#{account.id}/labels/reorder",
           headers: agent.create_new_auth_token, params: { label_ids: [second_label.id, label.id] }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(second_label.reload.position).to eq(1)
    end

    it 'rejects labels from another account atomically' do
      foreign_label = create(:label, position: 5)
      post "/api/v1/accounts/#{account.id}/labels/reorder",
           headers: admin.create_new_auth_token, params: { label_ids: [second_label.id, foreign_label.id] }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(second_label.reload.position).to eq(1)
      expect(foreign_label.reload.position).to eq(5)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/labels' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/labels"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :administrator) }

      it 'returns all the labels in account' do
        get "/api/v1/accounts/#{account.id}/labels",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include(label.title)
      end
    end
  end

  # Decisão do Pedro, 07/10: só o administrador cria etiqueta «de todos»; o agente
  # cria só para ele. As que já existiam nascem todas de todos.
  describe 'label visibility' do
    let(:owner) { create(:user, account: account, role: :agent) }
    let(:other_agent) { create(:user, account: account, role: :agent) }
    let(:team) { create(:team, account: account) }

    def labels_for(user)
      get "/api/v1/accounts/#{account.id}/labels", headers: user.create_new_auth_token, as: :json
      response.parsed_body['payload'].pluck('title')
    end

    it 'keeps every label that already existed visible to everyone' do
      expect(label.reload.visibility).to eq('global')
      expect(labels_for(other_agent)).to include(label.title)
    end

    it 'hides a personal label from everybody but its author' do
      personal = create(:label, account: account, title: 'minha-etiqueta', visibility: :personal, created_by: owner)

      expect(labels_for(owner)).to include(personal.title)
      expect(labels_for(other_agent)).not_to include(personal.title)
    end

    # «Tipo a Macro», que foi a referência que o Pedro deu: nem o administrador vê
    # a etiqueta pessoal de outra pessoa.
    it 'hides a personal label from an administrator too' do
      personal = create(:label, account: account, title: 'minha-etiqueta', visibility: :personal, created_by: owner)
      admin = create(:user, account: account, role: :administrator)

      expect(labels_for(admin)).not_to include(personal.title)
    end

    it 'shows a team label only to members of that team' do
      team_label = create(:label, account: account, title: 'do-time', visibility: :team, team: team)
      create(:team_member, team: team, user: owner)

      expect(labels_for(owner)).to include(team_label.title)
      expect(labels_for(other_agent)).not_to include(team_label.title)
    end

    it 'forces an agent-created label to be personal even when the request asks for global' do
      post "/api/v1/accounts/#{account.id}/labels",
           headers: owner.create_new_auth_token,
           params: { label: { title: 'tentativa', visibility: 'global' } },
           as: :json

      expect(response).to have_http_status(:success)
      expect(Label.find_by(title: 'tentativa')).to have_attributes(visibility: 'personal', created_by_id: owner.id)
    end

    it 'lets an administrator create a label for everyone' do
      admin = create(:user, account: account, role: :administrator)

      post "/api/v1/accounts/#{account.id}/labels",
           headers: admin.create_new_auth_token,
           params: { label: { title: 'de-todos', visibility: 'global' } },
           as: :json

      expect(Label.find_by(title: 'de-todos')).to have_attributes(visibility: 'global', created_by_id: admin.id)
    end

    it 'lets an administrator create a label for one team' do
      admin = create(:user, account: account, role: :administrator)

      post "/api/v1/accounts/#{account.id}/labels",
           headers: admin.create_new_auth_token,
           params: { label: { title: 'do-time', visibility: 'team', team_id: team.id } },
           as: :json

      expect(Label.find_by(title: 'do-time')).to have_attributes(visibility: 'team', team_id: team.id)
    end

    # Sem isto o agente criava uma etiqueta pessoal e nunca mais lhe mudava o nome.
    it 'lets an agent rename and delete their own personal label' do
      personal = create(:label, account: account, title: 'minha-etiqueta', visibility: :personal, created_by: owner)

      patch "/api/v1/accounts/#{account.id}/labels/#{personal.id}",
            headers: owner.create_new_auth_token, params: { title: 'minha-etiqueta-2' }, as: :json

      expect(response).to have_http_status(:success)
      expect(personal.reload.title).to eq('minha-etiqueta-2')

      delete "/api/v1/accounts/#{account.id}/labels/#{personal.id}", headers: owner.create_new_auth_token, as: :json

      expect(response).to have_http_status(:ok)
    end

    # O título é único na conta. A resposta era «Title has already been taken»,
    # em inglês e sem código: o ecrã não tinha como dizer em português o que fazer.
    it 'answers a taken title with a code the screen can translate' do
      create(:label, account: account, title: 'so-da-outra', visibility: :personal, created_by: other_agent)

      post "/api/v1/accounts/#{account.id}/labels",
           headers: owner.create_new_auth_token, params: { title: 'so-da-outra' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['code']).to eq('title_taken')
    end

    it 'refuses an agent touching a label that is not their own personal one' do
      patch "/api/v1/accounts/#{account.id}/labels/#{label.id}",
            headers: other_agent.create_new_auth_token, params: { title: 'sequestrada' }, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(label.reload.title).not_to eq('sequestrada')
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/labels/:id' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/labels/#{label.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'shows the contact' do
        get "/api/v1/accounts/#{account.id}/labels/#{label.id}",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.body).to include(label.title)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/labels' do
    let(:valid_params) { { label: { title: 'test' } } }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        expect { post "/api/v1/accounts/#{account.id}/labels", params: valid_params }.not_to change(Label, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'creates the contact' do
        expect do
          post "/api/v1/accounts/#{account.id}/labels", headers: admin.create_new_auth_token,
                                                        params: valid_params
        end.to change(Label, :count).by(1)

        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/labels/:id' do
    let(:valid_params) { { title: 'Test_2' }  }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        put "/api/v1/accounts/#{account.id}/labels/#{label.id}",
            params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'updates the label' do
        patch "/api/v1/accounts/#{account.id}/labels/#{label.id}",
              headers: admin.create_new_auth_token,
              params: valid_params,
              as: :json

        expect(response).to have_http_status(:success)
        expect(label.reload.title).to eq('test_2')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/labels/:id' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/labels/#{label.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'deletes the label and enqueues label cleanup' do
        label_deleted_at = Time.zone.parse('2026-05-07 10:00:00 UTC')
        conversation.label_list.add(label.title)
        conversation.save!

        clear_enqueued_jobs

        travel_to(label_deleted_at) do
          expect do
            delete "/api/v1/accounts/#{account.id}/labels/#{label.id}", headers: admin.create_new_auth_token, as: :json
          end.to have_enqueued_job(Labels::RemoveAssociationsJob).with(
            label_title: label.title,
            account_id: account.id,
            label_deleted_at: label_deleted_at
          )
        end

        expect(response).to have_http_status(:ok)
        expect(Label.exists?(label.id)).to be(false)
      end
    end
  end
end
