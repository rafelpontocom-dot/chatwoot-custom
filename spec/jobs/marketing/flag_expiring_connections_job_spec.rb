require 'rails_helper'

RSpec.describe Marketing::FlagExpiringConnectionsJob do
  let(:account) { create(:account) }

  def connection(expires_at:, status: 'connected')
    account.marketing_provider_connections.create!(
      provider: 'meta', external_account_id: SecureRandom.hex(4),
      status: status, access_token: 'tok', expires_at: expires_at
    )
  end

  # Sem isto a clínica descobre pela ausência de leads, dias depois.
  it 'flags a connection while there is still a week to act' do
    expiring = connection(expires_at: 3.days.from_now)

    described_class.perform_now

    expect(expiring.reload).to have_attributes(status: 'attention', last_error: 'token_expiring')
  end

  # Faixa numa tela de configuração ninguém vê; a expiração precisa procurar
  # a pessoa, não esperar por ela.
  it 'writes to the administrators, since nobody opens the settings page' do
    connection(expires_at: 3.days.from_now)

    expect { described_class.perform_now }
      .to have_enqueued_mail(AdministratorNotifications::IntegrationsNotificationMailer, :marketing_meta_token_expiring)
  end

  # Marcar tira a conexão do escopo `connected`: um email por vencimento, e não
  # um por hora durante a semana inteira de folga.
  it 'writes once, not every hour until the token dies' do
    connection(expires_at: 3.days.from_now)
    described_class.perform_now

    expect { described_class.perform_now }
      .not_to have_enqueued_mail(AdministratorNotifications::IntegrationsNotificationMailer, :marketing_meta_token_expiring)
  end

  it 'leaves a healthy connection alone' do
    healthy = connection(expires_at: 40.days.from_now)

    described_class.perform_now

    expect(healthy.reload.status).to eq('connected')
  end

  it 'ignores a connection that was never connected' do
    idle = connection(expires_at: 1.day.from_now, status: 'disconnected')

    described_class.perform_now

    expect(idle.reload.status).to eq('disconnected')
  end

  it 'ignores a connection with no expiry at all' do
    forever = connection(expires_at: nil)

    described_class.perform_now

    expect(forever.reload.status).to eq('connected')
  end
end
