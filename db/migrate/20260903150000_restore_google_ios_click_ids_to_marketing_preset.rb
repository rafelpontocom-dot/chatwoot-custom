class RestoreGoogleIosClickIdsToMarketingPreset < ActiveRecord::Migration[7.1]
  # `gbraid` e `wbraid` foram removidos junto com `dclid`, `msclkid` e `utm_id`,
  # mas nao sao a mesma coisa: sao os identificadores de clique do Google para
  # privacidade no iOS, e nesse trafego o Google manda estes *em vez de*
  # `gclid`. Uma clinica que anuncia para iPhone perde a atribuicao do Google
  # sem eles.
  #
  # rubocop:disable Rails/SkipsModelValidations
  NOVOS = [%w[gbraid gbraid], %w[wbraid wbraid]].freeze

  def up
    KanbanBoard.reset_column_information

    KanbanBoard.unscoped.find_each do |board|
      definicoes = Array(board.custom_field_definitions)
      indice_gclid = definicoes.index { |d| marketing_key?(d, 'gclid') }
      next if indice_gclid.nil?

      faltantes = NOVOS.reject { |key, _| definicoes.any? { |d| marketing_key?(d, key) } }
      next if faltantes.empty?

      board.update_columns(
        custom_field_definitions: inserir(definicoes, indice_gclid, faltantes),
        updated_at: Time.current
      )
    end
  end

  def down
    KanbanBoard.unscoped.find_each do |board|
      definicoes = Array(board.custom_field_definitions)
      restantes = definicoes.reject { |d| NOVOS.any? { |key, _| marketing_key?(d, key) } }
      next if restantes.length == definicoes.length

      board.update_columns(custom_field_definitions: renumerar(restantes), updated_at: Time.current)
    end
  end

  private

  def marketing_key?(definition, key)
    definition.is_a?(Hash) &&
      definition['key'].to_s == key &&
      (definition['layout'] || {})['section'].to_s == 'marketing'
  end

  # Logo depois do `gclid`, que e onde a pessoa espera encontra-los.
  def inserir(definicoes, indice_gclid, faltantes)
    novos = faltantes.map { |key, label| definicao(key, label) }
    renumerar(definicoes[0..indice_gclid] + novos + definicoes[(indice_gclid + 1)..])
  end

  def definicao(key, label)
    {
      'key' => key, 'label' => label, 'field_type' => 'text', 'options' => [],
      'required_stage_ids' => [], 'important' => false, 'condition' => {},
      'formula' => nil, 'formula_result_type' => nil,
      'layout' => { 'section' => 'marketing', 'position' => 0, 'width' => 'half' }
    }
  end

  def renumerar(definicoes)
    posicao = 0
    definicoes.map do |definition|
      next definition unless (definition['layout'] || {})['section'].to_s == 'marketing'

      posicao += 1
      definition.merge('layout' => definition['layout'].merge('position' => posicao))
    end
  end
  # rubocop:enable Rails/SkipsModelValidations
end
