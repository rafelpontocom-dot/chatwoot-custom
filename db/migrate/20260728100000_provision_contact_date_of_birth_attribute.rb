class ProvisionContactDateOfBirthAttribute < ActiveRecord::Migration[7.1]
  STANDARD_KEY = 'date_of_birth'.freeze
  STANDARD_DESCRIPTION = 'Campo padrão de data de nascimento do contato.'.freeze

  def up
    Account.find_each do |account|
      account.custom_attribute_definitions.find_or_create_by!(
        attribute_model: :contact_attribute,
        attribute_key: STANDARD_KEY
      ) do |attribute|
        attribute.attribute_display_name = 'Data de nascimento'
        attribute.attribute_description = STANDARD_DESCRIPTION
        attribute.attribute_display_type = :date
      end
    end
  end

  def down
    CustomAttributeDefinition.where(
      attribute_model: :contact_attribute,
      attribute_key: STANDARD_KEY,
      attribute_description: STANDARD_DESCRIPTION
    ).delete_all
  end
end
