class AdministratorNotifications::IntegrationsNotificationMailer < AdministratorNotifications::BaseMailer
  def slack_disconnect
    subject = 'Your Slack integration has expired'
    action_url = settings_url('integrations/slack')
    send_notification(subject, action_url: action_url)
  end

  def dialogflow_disconnect
    subject = 'Your Dialogflow integration was disconnected'
    send_notification(subject)
  end

  # O Meta nao emite refresh token. Quando o de 60 dias morre, os leads param
  # de chegar em silencio e a clinica so descobre pela ausencia — por isso o
  # aviso sai por email, e nao so como faixa numa tela que ninguem abre.
  def marketing_meta_token_expiring(connection)
    subject = 'Your Meta connection for Lead Ads is about to expire'
    action_url = "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{Current.account.id}/marketing"
    send_notification(subject, action_url: action_url,
                               meta: { display_name: connection.display_name, expires_on: connection.expires_at&.to_date })
  end

  def openai_disconnect
    subject = 'Your OpenAI integration was disconnected'
    action_url = settings_url('integrations/openai')
    send_notification(subject, action_url: action_url)
  end
end
