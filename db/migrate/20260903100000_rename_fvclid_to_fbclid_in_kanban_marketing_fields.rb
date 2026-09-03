class RenameFvclidToFbclidInKanbanMarketingFields < ActiveRecord::Migration[7.1]
  # O identificador de clique do Meta chama-se `fbclid`. Entrou no preset como
  # `fvclid` por engano de digitacao e uma migracao anterior tornou o engano
  # canonico. Corrigido agora, antes de a captacao automatica de atribuicao
  # comecar a escrever nele: a partir daí o erro apareceria em relatorio,
  # exportacao e payload de conversao, e cada dia custaria mais.
  #
  # Migracao de reparo de dados: contorna validacoes de modelo de proposito.
  # rubocop:disable Rails/SkipsModelValidations
  LEGACY_KEY = 'fvclid'.freeze
  CANONICAL_KEY = 'fbclid'.freeze

  def up
    rename_marketing_field(LEGACY_KEY, CANONICAL_KEY)
  end

  def down
    rename_marketing_field(CANONICAL_KEY, LEGACY_KEY)
  end

  private

  def rename_marketing_field(from, to)
    KanbanBoard.reset_column_information

    KanbanBoard.unscoped.find_each do |board|
      definitions = Array(board.custom_field_definitions)
      renamed = rename_definitions(definitions, from, to)
      next if renamed == definitions

      board.update_columns(
        custom_field_definitions: renamed,
        compact_card_field_keys: rename_compact_keys(board.compact_card_field_keys, from, to),
        updated_at: Time.current
      )
      rename_card_values(board, from, to)
    end
  end

  def rename_definitions(definitions, from, to)
    definitions.map do |definition|
      next definition unless marketing_field?(definition, from)

      # o rotulo guardado era o proprio nome da chave
      definition.merge('key' => to, 'label' => definition['label'].to_s == from ? to : definition['label'])
    end
  end

  def marketing_field?(definition, key)
    definition.is_a?(Hash) &&
      definition['key'].to_s == key &&
      (definition['layout'] || {})['section'].to_s == 'marketing'
  end

  def rename_compact_keys(keys, from, to)
    Array(keys).map { |key| key.to_s == from ? to : key.to_s }.uniq
  end

  def rename_card_values(board, from, to)
    board.kanban_cards.find_each do |card|
      values = (card.custom_field_values || {}).stringify_keys
      next unless values.key?(from)

      # nunca sobrepor um valor ja existente no destino
      values[to] = values[from] if values[to].blank?
      values.delete(from)
      card.update_columns(custom_field_values: values, updated_at: Time.current)
    end
  end
  # rubocop:enable Rails/SkipsModelValidations
end
