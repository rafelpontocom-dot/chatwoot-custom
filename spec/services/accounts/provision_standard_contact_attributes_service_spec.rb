require 'rails_helper'

RSpec.describe Accounts::ProvisionStandardContactAttributesService do
  let(:account) { create(:account) }

  before do
    account.custom_attribute_definitions.where(
      attribute_model: :contact_attribute,
      attribute_key: 'date_of_birth'
    ).delete_all
  end

  it 'creates the canonical date of birth contact attribute' do
    expect { described_class.new(account).call }
      .to(change { account.custom_attribute_definitions.contact_attribute.count }.by(1))

    attribute = account.custom_attribute_definitions.contact_attribute.find_by!(attribute_key: 'date_of_birth')
    expect(attribute).to have_attributes(
      attribute_display_name: 'Data de nascimento',
      attribute_display_type: 'date'
    )
  end

  it 'is idempotent and preserves an existing definition' do
    existing = create(
      :custom_attribute_definition,
      account: account,
      attribute_model: :contact_attribute,
      attribute_key: 'date_of_birth',
      attribute_display_name: 'Nascimento',
      attribute_display_type: :date
    )

    expect { described_class.new(account).call }
      .not_to(change { account.custom_attribute_definitions.count })
    expect(existing.reload.attribute_display_name).to eq('Nascimento')
  end
end
