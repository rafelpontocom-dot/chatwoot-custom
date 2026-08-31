require 'rails_helper'

RSpec.describe 'Calendar resource and procedure removal', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:contact) { create(:contact, account: account) }

  let(:procedure) do
    KanbanCalendarProcedure.create!(
      account: account,
      name: 'Consulta inicial',
      duration_minutes: 50,
      recurrence_allowed: false
    )
  end

  let(:resource) do
    KanbanCalendarResource.create!(
      account: account,
      name: 'Consultório 1',
      resource_type: 'room',
      timezone: 'America/Sao_Paulo'
    )
  end

  def book!
    KanbanCalendar::BookAppointmentService.new(
      account: account,
      contact: contact,
      procedure: procedure,
      resource_ids: [resource.id],
      starts_at: Time.zone.parse('2026-08-10 13:00:00'),
      timezone: 'America/Sao_Paulo'
    ).perform!
  end

  describe 'DELETE /calendar/resources/:id' do
    it 'deletes the agenda outright when nothing is booked on it' do
      target = resource

      delete "/api/v1/accounts/#{account.id}/calendar/resources/#{target.id}",
             headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['outcome']).to eq('deleted')
      expect(KanbanCalendarResource.exists?(target.id)).to be(false)
    end

    it 'archives instead, and says so, when appointments already exist' do
      book!

      delete "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}",
             headers: administrator.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['outcome']).to eq('archived')
      # Quem atendeu quem é histórico clínico: não pode desaparecer.
      expect(resource.reload.active).to be(false)
    end

    it 'refuses an agent without the configure permission' do
      agent = create(:user, account: account, role: :agent)

      delete "/api/v1/accounts/#{account.id}/calendar/resources/#{resource.id}",
             headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(KanbanCalendarResource.exists?(resource.id)).to be(true)
    end
  end

  describe 'DELETE /calendar/procedures/:id' do
    it 'deletes the procedure outright when nothing is booked' do
      target = procedure

      delete "/api/v1/accounts/#{account.id}/calendar/procedures/#{target.id}",
             headers: administrator.create_new_auth_token, as: :json

      expect(response.parsed_body['outcome']).to eq('deleted')
      expect(KanbanCalendarProcedure.exists?(target.id)).to be(false)
    end

    it 'archives instead when appointments already exist' do
      book!

      delete "/api/v1/accounts/#{account.id}/calendar/procedures/#{procedure.id}",
             headers: administrator.create_new_auth_token, as: :json

      expect(response.parsed_body['outcome']).to eq('archived')
      expect(procedure.reload.active).to be(false)
    end
  end
end
