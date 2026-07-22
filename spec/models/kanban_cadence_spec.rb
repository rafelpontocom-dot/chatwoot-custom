require 'rails_helper'

RSpec.describe KanbanCadence do
  it 'accepts internal follow-up steps' do
    cadence = build(
      :kanban_cadence,
      steps: [
        { delay_hours: 0, action_type: 'Enviar proposta', note: 'Enviar a proposta' },
        { delay_hours: 48, action_type: 'Cobrar retorno', note: 'Confirmar recebimento' }
      ]
    )

    expect(cadence).to be_valid
  end

  it 'rejects steps that try to send customer messages' do
    cadence = build(:kanban_cadence, steps: [{ delay_hours: 1, action_type: 'send_message' }])

    expect(cadence).not_to be_valid
    expect(cadence.errors[:steps]).to be_present
  end
end
