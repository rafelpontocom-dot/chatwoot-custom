# == Schema Information
#
# Table name: kanban_boards
#
#  id                                   :bigint           not null, primary key
#  active                               :boolean          default(TRUE), not null
#  auto_create_cards_from_conversations :boolean          default(FALSE), not null
#  description                          :text
#  inbox_scope_mode                     :string           default("all_inboxes"), not null
#  lost_reason_options                  :jsonb            not null
#  name                                 :string           not null
#  next_action_types                    :jsonb            not null
#  position                             :integer          default(0), not null
#  use_opportunity_card_reads           :boolean          default(TRUE), not null
#  visibility_mode                      :string           default("all_agents"), not null
#  created_at                           :datetime         not null
#  updated_at                           :datetime         not null
#  account_id                           :bigint           not null
#
# Indexes
#
#  index_active_kanban_boards_on_account_id_and_name  (account_id,name) UNIQUE WHERE (active = true)
#  index_kanban_boards_on_account_id                  (account_id)
#  index_kanban_boards_on_account_id_and_active       (account_id,active)
#  index_kanban_boards_on_account_id_and_position     (account_id,position)
#
class KanbanBoard < ApplicationRecord
  INBOX_SCOPE_MODES = %w[all_inboxes selected_inboxes].freeze
  VISIBILITY_MODES = %w[all_agents selected_agents].freeze
  CUSTOM_FIELD_TYPES = %w[text select integer decimal date datetime boolean formula].freeze
  CUSTOM_FIELD_LAYOUT_WIDTHS = %w[full half third].freeze
  DEFAULT_NEXT_ACTION_TYPES = [
    'Chamar novamente',
    'Enviar proposta',
    'Enviar link de pagamento',
    'Cobrar retorno',
    'Confirmar pagamento',
    'Enviar contrato',
    'Outro'
  ].freeze
  DEFAULT_LOST_REASON_OPTIONS = [
    'Sem resposta',
    'Preço',
    'Sem interesse',
    'Fora do perfil',
    'Fechou com outro',
    'Outro'
  ].freeze

  belongs_to :account

  has_many :kanban_stages, dependent: :destroy_async
  has_many :conversation_kanban_states, dependent: :destroy_async
  has_many :kanban_cards, dependent: nil
  has_many :kanban_board_members, dependent: :destroy_async
  has_many :visible_users, through: :kanban_board_members, source: :user
  has_many :kanban_board_inboxes, dependent: :destroy_async
  has_many :allowed_inboxes, through: :kanban_board_inboxes, source: :inbox

  attribute :visibility_mode, :string, default: 'all_agents'
  enum :visibility_mode, VISIBILITY_MODES.index_by(&:itself), validate: true

  attribute :inbox_scope_mode, :string, default: 'all_inboxes'
  enum :inbox_scope_mode, INBOX_SCOPE_MODES.index_by(&:itself), validate: true

  before_validation :normalize_sales_configuration

  validates :account_id, presence: true
  validates :name, presence: true, uniqueness: { scope: :account_id, conditions: -> { active } }, if: :active?
  validates :position, presence: true, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(position: :asc, id: :asc) }
  scope :accepting_inbox, lambda { |inbox_id|
    joins_sql = KanbanBoardInbox.where('kanban_board_inboxes.kanban_board_id = kanban_boards.id')
                                .where(inbox_id: inbox_id)
                                .select('1').to_sql
    where("inbox_scope_mode = 'all_inboxes' OR (inbox_scope_mode = 'selected_inboxes' AND EXISTS (#{joins_sql}))")
  }

  def inbox_allowed?(inbox_or_id)
    inbox_id = inbox_or_id.is_a?(Inbox) ? inbox_or_id.id : inbox_or_id.to_i

    return false if inbox_id.blank?

    if all_inboxes?
      Inbox.exists?(account_id: account_id, id: inbox_id)
    else
      kanban_board_inboxes.exists?(inbox_id: inbox_id)
    end
  end

  def configured_next_action_types
    next_action_types.presence || DEFAULT_NEXT_ACTION_TYPES
  end

  def configured_lost_reason_options
    lost_reason_options.presence || DEFAULT_LOST_REASON_OPTIONS
  end

  def configured_custom_field_definitions
    custom_field_definitions.presence || []
  end

  def sales_summary
    KanbanBoards::SalesSummaryBuilder.new(self).call
  end

  private

  def normalize_sales_configuration
    self.next_action_types = normalize_string_list(next_action_types)
    self.lost_reason_options = normalize_string_list(lost_reason_options)
    self.custom_field_definitions = normalize_custom_field_definitions(custom_field_definitions)
  end

  def normalize_string_list(values)
    Array(values).filter_map do |value|
      normalized_value = value.to_s.strip
      normalized_value.presence
    end.uniq
  end

  def normalize_custom_field_definitions(definitions)
    seen_keys = []
    Array(definitions).filter_map do |definition|
      normalized_definition = normalize_custom_field_definition(definition)
      next if normalized_definition.blank? || seen_keys.include?(normalized_definition['key'])

      seen_keys << normalized_definition['key']
      normalized_definition
    end
  end

  def normalize_custom_field_definition(definition)
    source = definition.to_h.with_indifferent_access
    key, label, field_type = custom_field_identity(source)

    return if key.blank? || label.blank? || CUSTOM_FIELD_TYPES.exclude?(field_type)

    {
      'key' => key,
      'label' => label,
      'field_type' => field_type,
      'options' => field_type == 'select' ? normalize_string_list(source[:options]) : [],
      'required_stage_ids' => normalize_stage_ids(source[:required_stage_ids]),
      'condition' => normalize_custom_field_condition(source[:condition]),
      'formula' => field_type == 'formula' ? source[:formula].to_s.strip.presence : nil,
      'layout' => normalize_custom_field_layout(source[:layout])
    }
  end

  def custom_field_identity(source)
    [
      source[:key].to_s.strip.parameterize(separator: '_'),
      source[:label].to_s.strip,
      source[:field_type].to_s.strip
    ]
  end

  def normalize_stage_ids(stage_ids)
    board_stage_ids = kanban_stages.pluck(:id)

    Array(stage_ids).filter_map(&:presence).map(&:to_i).uniq & board_stage_ids
  end

  def normalize_custom_field_condition(condition)
    source = condition.to_h.with_indifferent_access
    field_key = source[:field_key].to_s.strip.parameterize(separator: '_')

    return {} if field_key.blank?

    { 'field_key' => field_key, 'equals' => source[:equals].to_s }
  end

  def normalize_custom_field_layout(layout)
    source = layout.to_h.with_indifferent_access
    width = source[:width].to_s

    {
      'section' => source[:section].to_s.strip.presence || 'details',
      'position' => source[:position].to_i.positive? ? source[:position].to_i : 1,
      'width' => CUSTOM_FIELD_LAYOUT_WIDTHS.include?(width) ? width : 'full'
    }
  end
end
