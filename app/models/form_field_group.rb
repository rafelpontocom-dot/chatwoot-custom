# == Schema Information
#
# Table name: form_field_groups
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  section    :jsonb            not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :bigint           not null
#
# Indexes
#
#  index_form_field_groups_on_account_id           (account_id)
#  index_form_field_groups_on_account_id_and_name  (account_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#
class FormFieldGroup < ApplicationRecord
  belongs_to :account

  validates :name, presence: true, length: { maximum: 120 }, uniqueness: { scope: :account_id }
  validate :section_is_valid

  def admin_payload
    {
      id: id,
      name: name,
      section: section,
      updated_at: updated_at
    }
  end

  private

  def section_is_valid
    validator = Forms::SchemaValidator.new('sections' => [section])
    return if validator.valid?

    validator.errors.each { |error| errors.add(:section, error) }
  end
end
