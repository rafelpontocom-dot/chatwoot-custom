require 'rails_helper'

RSpec.describe 'Calendar procedures API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }

  it 'publishes a procedure with its own slug and public presentation' do
    post "/api/v1/accounts/#{account.id}/calendar/procedures",
         headers: administrator.create_new_auth_token,
         params: {
           procedure: {
             name: 'Consulta inicial',
             duration_minutes: 50,
             public_booking_enabled: true,
             public_slug: 'consulta-inicial',
             public_title: 'Sua primeira consulta',
             public_description: 'Escolha o melhor horario para voce.'
           }
         },
         as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include(
      'public_booking_enabled' => true,
      'public_slug' => 'consulta-inicial',
      'public_title' => 'Sua primeira consulta',
      'public_description' => 'Escolha o melhor horario para voce.'
    )
  end
end
