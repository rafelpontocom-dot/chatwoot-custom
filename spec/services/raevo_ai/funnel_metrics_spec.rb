require 'rails_helper'

RSpec.describe RaevoAi::FunnelMetrics do
  let(:account) { create(:account) }
  let(:integration) { RaevoAiIntegration.create!(account: account, clinic_id: 'clinic-anna-alice', enabled: true) }
  let(:board) { create(:kanban_board, account: account) }
  let!(:novo) { create(:kanban_stage, account: account, kanban_board: board, name: 'Novo', position: 1) }
  let!(:qualificada) { create(:kanban_stage, account: account, kanban_board: board, name: 'Qualificada', position: 2) }
  let!(:agendada) { create(:kanban_stage, account: account, kanban_board: board, name: 'Agendada', position: 3) }
  let(:contact) { create(:contact, account: account) }

  def registar_comando(state, action_id, created_at: Time.current)
    integration.raevo_ai_commands.create!(
      action_id: action_id, command_type: 'crm.ensure_opportunity',
      payload_digest: Digest::SHA256.hexdigest(action_id), state: state, created_at: created_at
    )
  end

  def cartao(stage, created_at: Time.current)
    create(:kanban_card, account: account, kanban_board: board, kanban_stage: stage,
                         contact: contact, created_at: created_at)
  end

  describe 'oportunidades criadas' do
    it 'conta só os comandos que a Elis chegou a aplicar' do
      registar_comando('applied', 'a1')
      registar_comando('applied', 'a2')
      registar_comando('failed_terminal', 'a3')
      registar_comando('claimed', 'a4')

      expect(described_class.new(integration: integration, window_days: 30).call[:opportunities_created]).to eq(2)
    end

    it 'ignora o que está fora da janela pedida' do
      registar_comando('applied', 'a1')
      registar_comando('applied', 'a2', created_at: 40.days.ago)

      expect(described_class.new(integration: integration, window_days: 30).call[:opportunities_created]).to eq(1)
    end
  end

  describe 'oportunidades qualificadas' do
    it 'diz que não sabe, em vez de zero, quando ninguém escolheu a etapa' do
      cartao(qualificada)

      expect(described_class.new(integration: integration, window_days: 30).call[:opportunities_qualified]).to be_nil
    end

    it 'conta quem chegou à etapa e quem já passou dela' do
      board.update!(qualified_stage: qualificada)
      cartao(novo)
      cartao(qualificada)
      cartao(agendada)

      expect(described_class.new(integration: integration, window_days: 30).call[:opportunities_qualified]).to eq(2)
    end

    it 'ignora cartões criados fora da janela' do
      board.update!(qualified_stage: qualificada)
      cartao(qualificada)
      cartao(qualificada, created_at: 40.days.ago)

      expect(described_class.new(integration: integration, window_days: 30).call[:opportunities_qualified]).to eq(1)
    end
  end

  it 'refuses a stage that belongs to another board' do
    outro = create(:kanban_board, account: account, name: 'Outro funil')
    alheia = create(:kanban_stage, account: account, kanban_board: outro, name: 'Alheia', position: 1)

    board.qualified_stage = alheia

    expect(board).not_to be_valid
    expect(board.errors[:qualified_stage]).to include('must be a stage of this board')
  end
end
