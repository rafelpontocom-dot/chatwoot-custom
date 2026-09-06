namespace :raevo_ai do
  desc 'Permanently purge a verified demonstration contact from Chatwoot'
  task purge_demo_contact: :environment do
    raise 'set RAEVO_DEMO_PURGE_CONFIRMATION=DELETE_DEMO_CONTACT' unless ENV['RAEVO_DEMO_PURGE_CONFIRMATION'] == 'DELETE_DEMO_CONTACT'

    account = Account.find(ENV.fetch('RAEVO_DEMO_ACCOUNT_ID'))
    contact = account.contacts.find(ENV.fetch('RAEVO_DEMO_CONTACT_ID'))
    result = RaevoAi::DemoContactPurge.new(
      account: account,
      contact: contact,
      expected_phone_suffix: ENV.fetch('RAEVO_DEMO_PHONE_SUFFIX')
    ).perform!

    puts result.to_json
  end
end
