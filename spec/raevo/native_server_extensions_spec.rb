require 'rails_helper'

# Mudanças do Raevo dentro de ficheiros de servidor do Chatwoot. Cada exemplo
# falha se um upgrade repuser o ficheiro original — o contrato
# native-server-extensions em config/raevo/upstream-contracts.json aponta para aqui.
RSpec.describe 'Raevo changes inside native server files', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  describe 'conversations_controller.rb' do
    it 'sends the WhatsApp read receipt when an agent opens the conversation' do
      conversation = create(:conversation, account: account)
      create(:inbox_member, user: admin, inbox: conversation.inbox)
      receipt = instance_double(Whatsapp::ConversationReadReceiptService, perform: true)
      allow(Whatsapp::ConversationReadReceiptService).to receive(:new).and_return(receipt)

      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/update_last_seen",
           headers: admin.create_new_auth_token, as: :json

      expect(Whatsapp::ConversationReadReceiptService).to have_received(:new).with(conversation: conversation)
      expect(receipt).to have_received(:perform)
    end
  end

  describe 'accounts_controller.rb and account_settings_schema.rb' do
    it 'stores the account currency and reporting timezone' do
      patch "/api/v1/accounts/#{account.id}",
            params: { currency: 'EUR', reporting_timezone: 'Europe/Lisbon' },
            headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(account.reload.settings).to include('currency' => 'EUR', 'reporting_timezone' => 'Europe/Lisbon')
    end

    it 'refuses a currency outside the supported list' do
      account.settings['currency'] = 'XYZ'

      expect(account).not_to be_valid
    end
  end

  describe 'dashboard_controller.rb' do
    it 'exposes DISPLAY_UPDATE_BANNER to the dashboard' do
      expect(DashboardController::GLOBAL_CONFIG_KEYS).to include('DISPLAY_UPDATE_BANNER')
    end
  end

  describe 'async_dispatcher.rb' do
    it 'delivers events to the Raevo listeners' do
      listeners = AsyncDispatcher.new.listeners

      expect(listeners).to include(KanbanCardListener.instance, KanbanCalendarPaymentListener.instance,
                                   MarketingListener.instance, Whatsapp::AssignmentGreetingListener.instance)
    end
  end

  describe 'application_helper.rb' do
    it 'offers only Portuguese, Brazil first' do
      helper = Class.new { include ApplicationHelper }.new

      expect(helper.available_locales_with_name.pluck(:iso_639_1_code)).to eq(%w[pt_BR pt])
    end
  end

  describe 'config/initializers/languages.rb' do
    it 'names both Portuguese variants by country' do
      helper = Class.new { include ApplicationHelper }.new

      expect(helper.available_locales_with_name.pluck(:name)).to eq(['Português (Brasil)', 'Português (Portugal)'])
    end
  end

  describe 'config/installation_config.yml' do
    let(:config) { YAML.safe_load(Rails.root.join('config/installation_config.yml').read).index_by { |item| item['name'] } }

    it 'brands the installation as RAEVO CRM' do
      expect(config.transform_values { |item| item['value'] }).to include(
        'INSTALLATION_NAME' => 'RAEVO CRM', 'BRAND_NAME' => 'RAEVO CRM', 'BRAND_URL' => 'https://crm.raevo.io',
        'LOGO' => '/brand-assets/raevo-logo.svg', 'LOGO_THUMBNAIL' => '/brand-assets/raevo-favicon.svg'
      )
    end

    it 'keeps the Raevo settings that the Super Admin edits' do
      expect(config.keys).to include(
        'DISPLAY_UPDATE_BANNER', 'GOOGLE_CALENDAR_OAUTH_CALLBACK_URL', 'GOOGLE_CALENDAR_OAUTH_CLIENT_ID',
        'GOOGLE_CALENDAR_OAUTH_CLIENT_SECRET', 'MARKETING_META_APP_ID', 'MARKETING_META_APP_SECRET',
        'MARKETING_META_OAUTH_CALLBACK_URL', 'MARKETING_META_VERIFY_TOKEN'
      )
      expect(config['DISPLAY_UPDATE_BANNER']['value']).to be(false)
    end
  end

  describe 'super_admin/features.yml' do
    it 'lists Marketing among the Super Admin apps' do
      features = YAML.safe_load(Rails.root.join('app/helpers/super_admin/features.yml').read)

      expect(features['marketing']).to include('name' => 'Marketing', 'config_key' => 'marketing')
    end
  end

  describe 'integrations_notification_mailer.rb' do
    it 'warns the administrators when the Meta connection is about to expire' do
      expect(AdministratorNotifications::IntegrationsNotificationMailer.instance_method(:marketing_meta_token_expiring)).to be_present
    end
  end

  describe 'conversation.rb' do
    it 'knows the opportunities opened from it' do
      expect(Conversation.reflect_on_association(:kanban_cards)&.macro).to eq(:has_many)
    end
  end

  describe 'vueapp.html.erb' do
    it 'serves the Raevo favicon and theme colour' do
      get '/app/login'

      expect(response.body).to include('/brand-assets/raevo-favicon.svg')
      expect(response.body).not_to include('#2781F6')
    end
  end

  describe 'lib/events/types.rb' do
    %w[
      KANBAN_BOARD_UPDATED KANBAN_STAGE_CREATED KANBAN_STAGE_UPDATED KANBAN_STAGE_DELETED KANBAN_STAGE_REORDERED
      KANBAN_CARD_CREATED KANBAN_CARD_UPDATED KANBAN_CARD_DELETED KANBAN_CARD_REORDERED KANBAN_CARD_STAGE_CHANGED
      KANBAN_CARD_OWNER_CHANGED KANBAN_CARD_AMOUNT_CHANGED KANBAN_CARD_CUSTOM_FIELDS_CHANGED KANBAN_CARD_FIELDS_CHANGED
      KANBAN_CARD_NEXT_ACTION_SCHEDULED KANBAN_CARD_NEXT_ACTION_COMPLETED KANBAN_CARD_NEXT_ACTION_OVERDUE
      KANBAN_CARD_WON KANBAN_CARD_LOST KANBAN_CARD_REOPENED KANBAN_CARD_ARCHIVED KANBAN_CARD_RESTORED
      KANBAN_CARD_MANUAL_STARTED KANBAN_CARD_CUSTOMER_MESSAGE_RECEIVED KANBAN_CARD_WEBHOOK_RECEIVED
      KANBAN_APPOINTMENT_CREATED KANBAN_APPOINTMENT_RESCHEDULED KANBAN_APPOINTMENT_CANCELED
      KANBAN_APPOINTMENT_CONFIRMED KANBAN_APPOINTMENT_COMPLETED KANBAN_APPOINTMENT_NO_SHOW FINANCE_PAYMENT_CREATED
      FINANCE_PAYMENT_OVERDUE FINANCE_PAYMENT_CONFIRMED FINANCE_PAYMENT_RECEIVED FINANCE_PAYMENT_CANCELED
      FINANCE_PAYMENT_REFUNDED FINANCE_PAYMENT_CHARGEBACK FORMS_INVITATION_SENT FORMS_INVITATION_OPENED
      FORMS_INVITATION_EXPIRED FORMS_INVITATION_ABANDONED FORMS_SUBMISSION_CRITICAL FORMS_SUBMISSION_COMPLETED
    ].each do |name|
      it "defines #{name}" do
        expect(Events::Types.const_get(name)).to match(/\A(kanban|finance|forms)\./)
      end
    end
  end
end
