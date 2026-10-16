# == Schema Information
#
# Table name: labels
#
#  id              :bigint           not null, primary key
#  color           :string           default("#1f93ff"), not null
#  description     :text
#  position        :integer
#  show_on_sidebar :boolean
#  title           :string
#  visibility      :integer          default("global"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint
#  created_by_id   :bigint
#  team_id         :bigint
#
# Indexes
#
#  index_labels_on_account_id            (account_id)
#  index_labels_on_created_by_id         (created_by_id)
#  index_labels_on_team_id               (team_id)
#  index_labels_on_title_and_account_id  (title,account_id) UNIQUE
#
class Label < ApplicationRecord
  include RegexHelper
  include AccountCacheRevalidator

  belongs_to :account
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :team, optional: true

  # Quem vê a etiqueta. `global` é o comportamento de sempre e continua a ser o
  # que a coluna assume por omissão: etiqueta criada por um caminho que não
  # declara visibilidade (automação, importação, API antiga) é de todos, como era
  # antes desta coluna existir.
  enum visibility: { personal: 0, team: 1, global: 2 }

  validates :title,
            presence: { message: I18n.t('errors.validations.presence') },
            format: { with: UNICODE_CHARACTER_NUMBER_HYPHEN_UNDERSCORE },
            uniqueness: { scope: :account_id }
  # Etiqueta pessoal sem autor é uma etiqueta que NINGUÉM consegue ver outra vez.
  validates :created_by, presence: true, if: :personal?
  validates :team, presence: true, if: :team?
  validate :team_belongs_to_account

  after_update_commit :update_associated_models
  # Sem ordem manual a posição é nula e, em Postgres, nulo vem por último: a conta
  # que nunca reordenou continua alfabética.
  default_scope { order(:position, :title) }

  before_validation do
    self.title = title.downcase if attribute_present?('title')
  end

  # O que este utilizador pode ver: as de todos, as suas pessoais, e as dos times
  # a que pertence. Um utilizador sem time nenhum não vê etiquetas de time.
  def self.visible_to(user, team_ids: nil)
    return all if user.blank?

    # Os times vêm do utilizador, sem olhar a `Current.account`: a relação em que
    # isto é chamado já está presa à conta, e uma etiqueta de time só aponta a um
    # time da MESMA conta (validado). Depender de `Current` aqui dava uma lista
    # vazia em qualquer contexto sem pedido HTTP — e era silencioso.
    times = team_ids.nil? ? user.teams.pluck(:id) : Array(team_ids)
    condition = where(visibility: :global)
    condition = condition.or(where(visibility: :personal, created_by_id: user.id))
    condition = condition.or(where(visibility: :team, team_id: times)) if times.present?
    condition
  end

  # O administrador administra o que é PARTILHADO — de todos e de time —, mais as
  # suas próprias pessoais. A pessoal de outra pessoa continua fora: a referência
  # que o Pedro deu foi a Macro, e lá o administrador também não vê a macro
  # pessoal de mais ninguém.
  def self.manageable_by_administrator(user)
    where.not(visibility: :personal).or(where(visibility: :personal, created_by_id: user&.id))
  end

  def conversations
    account.conversations.tagged_with(title)
  end

  def messages
    account.messages.where(conversation_id: conversations.pluck(:id))
  end

  def reporting_events
    account.reporting_events.where(conversation_id: conversations.pluck(:id))
  end

  private

  def team_belongs_to_account
    return if team.blank?
    return if team.account_id == account_id

    errors.add(:team, 'must belong to the same account')
  end

  def update_associated_models
    return unless title_previously_changed?

    Labels::UpdateJob.perform_later(title, title_previously_was, account_id)
  end
end
