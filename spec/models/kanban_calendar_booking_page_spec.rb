require 'rails_helper'

RSpec.describe KanbanCalendarBookingPage do
  it 'generates an opaque public token and defaults to creating a new opportunity' do
    page = described_class.create!(account: create(:account))

    expect(page.public_token).to match(/\A[a-zA-Z0-9_-]{20,}\z/)
    expect(page.duplicate_policy).to eq('create_new')
  end

  it 'only accepts explicit opportunity duplicate policies' do
    page = described_class.new(account: create(:account), duplicate_policy: 'guess')

    expect(page).not_to be_valid
    expect(page.errors[:duplicate_policy]).to be_present
  end

  it 'requires a site key when turnstile is enabled' do
    page = described_class.new(account: create(:account), captcha_provider: 'turnstile')

    expect(page).not_to be_valid
    expect(page.errors[:captcha_site_key]).to be_present
  end

  it 'requires options for a public selection field' do
    page = described_class.new(
      account: create(:account),
      public_form_fields: [{ 'key' => 'preferred_unit', 'label' => 'Unidade', 'kind' => 'select', 'options' => [] }]
    )

    expect(page).not_to be_valid
    expect(page.errors[:public_form_fields]).to be_present
  end
end
