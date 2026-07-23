# == Schema Information
#
# Table name: kanban_boards
#
#  id                                   :bigint           not null, primary key
#  active                               :boolean          default(TRUE), not null
#  archived_at                          :datetime
#  auto_create_cards_from_conversations :boolean          default(FALSE), not null
#  compact_card_field_keys              :jsonb            not null
#  custom_field_definitions             :jsonb            not null
#  custom_field_sections                :jsonb            not null
#  description                          :text
#  inbox_scope_mode                     :string           default("all_inboxes"), not null
#  lock_version                         :integer          default(0), not null
#  lost_reason_options                  :jsonb            not null
#  name                                 :string           not null
#  next_action_types                    :jsonb            not null
#  position                             :integer          default(0), not null
#  stale_stage_thresholds               :jsonb            not null
#  use_opportunity_card_reads           :boolean          default(TRUE), not null
#  visibility_mode                      :string           default("all_agents"), not null
#  created_at                           :datetime         not null
#  updated_at                           :datetime         not null
#  account_id                           :bigint           not null
#  archived_by_id                       :bigint
#  appointment_reminder_hours           :integer
#
# Indexes
#
#  index_active_kanban_boards_on_account_id_and_name  (account_id,name) UNIQUE WHERE (active = true)
#  index_kanban_boards_on_account_id                  (account_id)
#  index_kanban_boards_on_account_id_and_active       (account_id,active)
#  index_kanban_boards_on_account_id_and_archived_at  (account_id,archived_at)
#  index_kanban_boards_on_account_id_and_position     (account_id,position)
#  index_kanban_boards_on_archived_by_id              (archived_by_id)
#
# Foreign Keys
#
#  fk_rails_...  (archived_by_id => users.id)
#
# The board owns the normalized sales configuration used by cards and settings.
# rubocop:disable Metrics/ClassLength
class KanbanBoard < ApplicationRecord
  INBOX_SCOPE_MODES = %w[all_inboxes selected_inboxes].freeze
  VISIBILITY_MODES = %w[all_agents selected_agents].freeze
  CUSTOM_FIELD_TYPES = %w[text textarea select multiselect integer decimal currency date datetime boolean url formula].freeze
  CUSTOM_FIELD_LAYOUT_WIDTHS = %w[full half third].freeze
  FORMULA_RESULT_TYPES = %w[number date datetime].freeze
  RESERVED_CUSTOM_FIELD_SECTION_KEYS = %w[timeline].freeze
  CUSTOM_FIELD_SECTION_COLORS = %w[slate blue teal green amber orange ruby rose violet iris].freeze
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
  belongs_to :archived_by, class_name: 'User', optional: true

  has_many :kanban_stages, dependent: :destroy_async
  has_many :conversation_kanban_states, dependent: :destroy_async
  has_many :kanban_cards, dependent: nil
  has_many :kanban_board_members, dependent: :destroy_async
  has_many :visible_users, through: :kanban_board_members, source: :user
  has_many :kanban_board_inboxes, dependent: :destroy_async
  has_many :kanban_saved_filters, dependent: :destroy_async
  has_many :kanban_automation_rules, dependent: :destroy_async
  has_many :kanban_automation_connections, dependent: :destroy_async
  has_many :kanban_cadences, dependent: :destroy
  has_many :kanban_appointment_reminder_rules, dependent: :destroy
  has_many :allowed_inboxes, through: :kanban_board_inboxes, source: :inbox

  attribute :visibility_mode, :string, default: 'all_agents'
  enum :visibility_mode, VISIBILITY_MODES.index_by(&:itself), validate: true

  attribute :inbox_scope_mode, :string, default: 'all_inboxes'
  enum :inbox_scope_mode, INBOX_SCOPE_MODES.index_by(&:itself), validate: true

  before_validation :normalize_sales_configuration

  validates :account_id, presence: true
  validates :name, presence: true, uniqueness: { scope: :account_id, conditions: -> { active } }, if: :active?
  validates :position, presence: true, numericality: { only_integer: true }
  validates :appointment_reminder_hours,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 168 },
            allow_nil: true

  scope :active, -> { where(active: true) }
  scope :archived, -> { where(active: false).where.not(archived_at: nil) }
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

  def configured_custom_field_sections
    custom_field_sections.presence || []
  end

  def compact_custom_field_definitions
    definitions_by_key = configured_custom_field_definitions.index_by { |definition| definition['key'] }
    Array(compact_card_field_keys).filter_map { |key| definitions_by_key[key] }
  end

  def stale_days_for_stage(stage_id)
    days = stale_stage_thresholds.to_h[stage_id.to_s].to_i
    days if days.positive?
  end

  def sales_summary
    KanbanBoards::SalesSummaryBuilder.new(self).call
  end

  def archive!(actor:)
    update!(active: false, archived_at: Time.current, archived_by: actor)
  end

  def restore!
    update!(active: true, archived_at: nil, archived_by: nil)
  end

  def custom_field_usage(field_keys = nil)
    keys = Array(field_keys.presence || configured_custom_field_definitions.pluck('key'))
    keys.index_with do |key|
      kanban_cards.where(
        "custom_field_values ? :key AND custom_field_values -> :key NOT IN ('null'::jsonb, '\"\"'::jsonb, '[]'::jsonb)",
        key: key
      ).count
    end
  end

  private

  def normalize_sales_configuration
    self.next_action_types = normalize_string_list(next_action_types)
    self.lost_reason_options = normalize_string_list(lost_reason_options)
    self.custom_field_definitions = normalize_custom_field_definitions(custom_field_definitions)
    self.custom_field_sections = normalize_custom_field_sections(custom_field_sections)
    self.compact_card_field_keys = normalize_compact_card_field_keys(compact_card_field_keys)
    self.stale_stage_thresholds = normalize_stale_stage_thresholds(stale_stage_thresholds)
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
      'options' => %w[select multiselect].include?(field_type) ? normalize_string_list(source[:options]) : [],
      'required_stage_ids' => normalize_stage_ids(source[:required_stage_ids]),
      'important' => ActiveModel::Type::Boolean.new.cast(source[:important]),
      'condition' => normalize_custom_field_condition(source[:condition]),
      'formula' => field_type == 'formula' ? source[:formula].to_s.strip.presence : nil,
      'formula_result_type' => normalize_formula_result_type(field_type, source[:formula_result_type]),
      'layout' => normalize_custom_field_layout(source[:layout])
    }
  end

  def normalize_formula_result_type(field_type, result_type)
    return nil unless field_type == 'formula'

    FORMULA_RESULT_TYPES.include?(result_type.to_s) ? result_type.to_s : 'number'
  end

  def normalize_custom_field_sections(sections)
    seen_keys = []
    Array(sections).filter_map do |section|
      source = section.to_h.with_indifferent_access
      key = source[:key].to_s.strip.parameterize(separator: '_')
      label = source[:label].to_s.strip
      label = key.capitalize if %w[details marketing].include?(key)
      next if key.blank? || label.blank? || RESERVED_CUSTOM_FIELD_SECTION_KEYS.include?(key) || seen_keys.include?(key)

      seen_keys << key
      {
        'key' => key,
        'label' => label,
        'color' => normalize_custom_field_section_color(source[:color]),
        'groups' => normalize_custom_field_groups(source[:groups])
      }
    end
  end

  def normalize_custom_field_groups(groups)
    seen_keys = []
    Array(groups).filter_map do |group|
      source = group.to_h.with_indifferent_access
      key = source[:key].to_s.strip.parameterize(separator: '_')
      label = source[:label].to_s.strip
      next if key.blank? || label.blank? || seen_keys.include?(key)

      seen_keys << key
      {
        'key' => key,
        'label' => label,
        'color' => normalize_custom_field_section_color(source[:color])
      }
    end
  end

  def normalize_custom_field_section_color(color)
    color = color.to_s
    CUSTOM_FIELD_SECTION_COLORS.include?(color) ? color : 'slate'
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

    normalized_layout = {
      'section' => source[:section].to_s.strip.presence || 'details',
      'position' => source[:position].to_i.positive? ? source[:position].to_i : 1,
      'width' => CUSTOM_FIELD_LAYOUT_WIDTHS.include?(width) ? width : 'full'
    }
    group = source[:group].to_s.strip.parameterize(separator: '_').presence
    normalized_layout['group'] = group if group
    normalized_layout
  end

  def normalize_compact_card_field_keys(field_keys)
    normalize_string_list(field_keys).map { |key| key.parameterize(separator: '_') }
  end

  def normalize_stale_stage_thresholds(thresholds)
    board_stage_ids = kanban_stages.pluck(:id).map(&:to_s)

    thresholds.to_h.each_with_object({}) do |(stage_id, days), normalized_thresholds|
      normalized_days = days.to_i
      next unless board_stage_ids.include?(stage_id.to_s) && normalized_days.positive?

      normalized_thresholds[stage_id.to_s] = normalized_days
    end
  end
end
# rubocop:enable Metrics/ClassLength
