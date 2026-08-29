require 'rails_helper'

RSpec.describe 'Form field groups API', type: :request do
  let(:account) { create(:account) }
  let(:other_account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:field_groups_path) { "/api/v1/accounts/#{account.id}/forms/field_groups" }
  let(:section) do
    {
      key: 'identificacao',
      title: 'Identificacao',
      fields: [
        { key: 'nome', label: 'Nome completo', type: 'text', required: true }
      ]
    }
  end

  it 'creates and lists reusable groups only for the current account' do
    FormFieldGroup.create!(account: other_account, name: 'Outro consultorio', section: section)

    post field_groups_path,
         headers: administrator.create_new_auth_token,
         params: { form_field_group: { name: 'Dados iniciais', section: section } },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include('name' => 'Dados iniciais', 'section' => section.stringify_keys)

    get field_groups_path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body.map { |group| group.fetch('name') }).to eq(['Dados iniciais'])
  end

  it 'prevents an agent from managing reusable groups' do
    get field_groups_path, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'deletes only a reusable group from the current account' do
    group = FormFieldGroup.create!(account: account, name: 'Preferencias', section: section)

    delete "#{field_groups_path}/#{group.id}", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:no_content)
    expect(FormFieldGroup.find_by(id: group.id)).to be_nil
  end

  it 'does not allow a group from another account to be deleted' do
    group = FormFieldGroup.create!(account: other_account, name: 'Outro grupo', section: section)

    delete "#{field_groups_path}/#{group.id}", headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:not_found)
    expect(FormFieldGroup.find_by(id: group.id)).to eq(group)
  end
end
