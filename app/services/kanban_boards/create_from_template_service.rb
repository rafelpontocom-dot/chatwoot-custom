class KanbanBoards::CreateFromTemplateService
  TEMPLATES = {
    'whatsapp_sales' => ['Novo lead', 'Em conversa', 'Interesse identificado', 'Proposta enviada', 'Follow-up', 'Fechado', 'Perdido'],
    'clinic' => ['Novo lead', 'Qualificado', 'Consulta agendada', 'Confirmado', 'Compareceu', 'Fechado', 'Perdido'],
    'b2b' => ['Novo lead', 'Diagnóstico', 'Proposta', 'Negociação', 'Contrato enviado', 'Fechado', 'Perdido'],
    'blank' => []
  }.freeze

  # Um funil nascia sempre sem campos. Uma clínica precisa sempre das mesmas
  # coisas — procedimento, valor, profissional, data — e ficava a criá-las à
  # mão, uma a uma, em cada funil. O único preset que existia era o de
  # marketing, que é aquilo de que uma clínica menos precisa.
  #
  # Poucos e certos de propósito: apagar o que sobra é mais fácil do que
  # descobrir o que falta.
  FIELDS = {
    'clinic' => [
      { key: 'procedimento', label: 'Procedimento', field_type: 'select',
        options: %w[Consulta Avaliação Procedimento Retorno], width: 'half' },
      { key: 'valor_orcado', label: 'Valor orçado', field_type: 'currency', width: 'half' },
      { key: 'profissional', label: 'Profissional', field_type: 'text', width: 'half' },
      { key: 'data_procedimento', label: 'Data do procedimento', field_type: 'date', width: 'half' },
      { key: 'origem', label: 'Como nos conheceu', field_type: 'select',
        options: ['Indicação', 'Instagram', 'Google', 'Passou em frente', 'Outro'], width: 'half' },
      { key: 'observacoes', label: 'Observações', field_type: 'textarea', width: 'full' }
    ],
    'b2b' => [
      { key: 'empresa', label: 'Empresa', field_type: 'text', width: 'half' },
      { key: 'valor_orcado', label: 'Valor da proposta', field_type: 'currency', width: 'half' },
      { key: 'decisor', label: 'Quem decide', field_type: 'text', width: 'half' },
      { key: 'observacoes', label: 'Observações', field_type: 'textarea', width: 'full' }
    ]
  }.freeze

  CARD_FIELDS = {
    'clinic' => %w[procedimento valor_orcado data_procedimento],
    'b2b' => %w[empresa valor_orcado]
  }.freeze

  def initialize(account:, attributes:, template_key:)
    @account = account
    @attributes = attributes
    @template_key = template_key.presence || 'blank'
  end

  def perform!
    stage_names = TEMPLATES.fetch(template_key)

    KanbanBoard.transaction do
      board = KanbanBoard.create!(attributes.merge(account: account).merge(template_field_attributes))
      stage_names.each.with_index(1) do |name, position|
        board.kanban_stages.create!(account: account, name: name, position: position)
      end
      board
    end
  end

  private

  def template_field_attributes
    fields = FIELDS[template_key]
    return {} if fields.blank?

    {
      custom_field_definitions: fields.each_with_index.map { |field, index| field_definition(field, index) },
      compact_card_field_keys: CARD_FIELDS.fetch(template_key, [])
    }
  end

  def field_definition(field, index)
    {
      'key' => field[:key],
      'label' => field[:label],
      'field_type' => field[:field_type],
      'options' => field[:options] || [],
      'required_stage_ids' => [],
      'condition' => {},
      'formula' => nil,
      'layout' => { 'section' => 'details', 'position' => index + 1, 'width' => field[:width] }
    }
  end

  attr_reader :account, :attributes, :template_key
end
