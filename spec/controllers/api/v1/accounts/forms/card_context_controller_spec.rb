require 'rails_helper'

RSpec.describe 'Form card context API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account, name: 'Pedro Raevo') }
  let(:card) { create(:kanban_card, account: account, contact: contact) }
  let(:template) do
    FormTemplate.create!(
      account: account,
      name: 'Pré-consulta',
      slug: 'pre-consulta',
      category: 'pre_consultation',
      access_classification: 'commercial'
    )
  end
  let(:version) { template.publish!(schema: schema) }
  let(:path) { "/api/v1/accounts/#{account.id}/forms/kanban_cards/#{card.id}" }

  it 'lists safe invitation and submission summaries for an opportunity' do
    invitation = Forms::CreateInvitationService.new(
      account: account,
      form_template_version: version,
      contact: contact,
      kanban_card: card
    ).perform.invitation
    submission = FormSubmission.create!(
      account: account,
      form_template_version: version,
      form_invitation: invitation,
      contact: contact,
      kanban_card: card,
      answers: { 'nome' => 'Pedro Raevo' },
      metadata: {},
      submitted_at: Time.current
    )

    get path, headers: administrator.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include(
      'invitations' => include(include('id' => invitation.id, 'form_name' => 'Pré-consulta')),
      'submissions' => include(include('id' => submission.id, 'form_name' => 'Pré-consulta'))
    )
    expect(response.parsed_body.to_s).not_to include('token_digest')
    expect(response.parsed_body.to_s).not_to include('answers')
  end

  private

  def schema
    {
      'sections' => [
        { 'key' => 'identificacao', 'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' }] }
      ]
    }
  end
end
