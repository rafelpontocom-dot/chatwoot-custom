class Accounts::ProvisionStandardContactAttributesService
  DATE_OF_BIRTH_KEY = 'date_of_birth'.freeze
  DATE_OF_BIRTH_NAME = 'Data de nascimento'.freeze
  DATE_OF_BIRTH_DESCRIPTION = 'Campo padrão de data de nascimento do contato.'.freeze

  def initialize(account)
    @account = account
  end

  def call
    attribute = @account.custom_attribute_definitions.find_or_initialize_by(
      attribute_model: :contact_attribute,
      attribute_key: DATE_OF_BIRTH_KEY
    )
    return attribute if attribute.persisted?

    attribute.assign_attributes(
      attribute_display_name: DATE_OF_BIRTH_NAME,
      attribute_description: DATE_OF_BIRTH_DESCRIPTION,
      attribute_display_type: :date
    )
    attribute.save!
    attribute
  end
end
