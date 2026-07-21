# == Schema Information
#
# Table name: kanban_saved_filters
#
#  id              :bigint           not null, primary key
#  filters         :jsonb            not null
#  name            :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  kanban_board_id :bigint           not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_kanban_saved_filters_on_account_id       (account_id)
#  index_kanban_saved_filters_on_kanban_board_id  (kanban_board_id)
#  index_kanban_saved_filters_on_user_id          (user_id)
#  index_kanban_saved_filters_unique_name         (kanban_board_id,user_id,name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (account_id => accounts.id)
#  fk_rails_...  (kanban_board_id => kanban_boards.id)
#  fk_rails_...  (user_id => users.id)
#
class KanbanSavedFilter < ApplicationRecord
  belongs_to :account
  belongs_to :kanban_board
  belongs_to :user

  validates :name, presence: true, uniqueness: { scope: [:kanban_board_id, :user_id] }
  validate :validate_account_context

  private

  def validate_account_context
    errors.add(:account_id, :invalid) if kanban_board&.account_id != account_id
    errors.add(:account_id, :invalid) unless user&.account_users&.exists?(account_id: account_id)
  end
end
