FactoryBot.define do
  factory :kanban_birthday_delivery do
    account
    contact { association(:contact, account: account) }
    kanban_birthday_automation { association(:kanban_birthday_automation, account: account) }
    birthday_year { Date.current.year }
    delivery_channel { 'whatsapp' }
  end
end
