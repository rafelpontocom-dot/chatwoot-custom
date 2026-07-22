FactoryBot.define do
  factory :kanban_birthday_automation do
    account
    active { false }
    days_before { 0 }
    delivery_channels { ['whatsapp'] }
    opt_in_attribute_key { 'birthday_messages_opt_in' }
    message_template { 'Feliz aniversário, {{contact_name}}!' }
  end
end
