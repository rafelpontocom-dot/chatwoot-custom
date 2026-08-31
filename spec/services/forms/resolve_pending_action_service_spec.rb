require 'rails_helper'

RSpec.describe Forms::ResolvePendingActionService do
  let(:account) { create(:account) }
  let(:board) { create(:kanban_board, account: account) }
  let(:stage) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:proxima_etapa) { create(:kanban_stage, account: account, kanban_board: board) }
  let(:contact) { create(:contact, account: account, name: 'Maria Raevo') }
  let(:card) do
    create(:kanban_card, account: account, kanban_board: board, kanban_stage: stage, contact: contact)
  end
  let(:template) do
    FormTemplate.create!(
      account: account, name: 'Captação', slug: 'captacao',
      category: 'lead_capture', access_classification: 'commercial'
    )
  end
  let(:version) do
    template.publish!(
      schema: {
        'crm_destination' => {
          'kanban_board_id' => board.id, 'kanban_stage_id' => stage.id,
          'inbox_id' => card.inbox_id, 'opportunity_policy' => 'reuse_open'
        },
        'sections' => [{ 'key' => 's', 'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' }] }],
        'submission_actions' => [
          { 'kind' => 'move_stage', 'mode' => 'review', 'kanban_stage_id' => proxima_etapa.id }
        ]
      }
    )
  end
  let(:submission) do
    submission = FormSubmission.create!(
      account: account, form_template_version: version, contact: contact,
      kanban_card: card, answers: { 'nome' => 'Maria' }, submitted_at: Time.current
    )
    Forms::ApplySubmissionActionsService.new(submission: submission).perform
    submission.reload
  end

  it 'has the action waiting before anyone decides' do
    expect(submission.metadata['pending_actions'].length).to eq(1)
    expect(card.reload.kanban_stage_id).to eq(stage.id)
  end

  it 'applies the action when it is confirmed' do
    described_class.new(submission: submission, index: 0, decision: 'confirm').perform!

    expect(card.reload.kanban_stage_id).to eq(proxima_etapa.id)
    expect(submission.reload.metadata['pending_actions']).to eq([])
  end

  it 'drops the action without applying it when it is dismissed' do
    described_class.new(submission: submission, index: 0, decision: 'dismiss').perform!

    expect(card.reload.kanban_stage_id).to eq(stage.id)
    expect(submission.reload.metadata['pending_actions']).to eq([])
  end

  it 'records who decided what, either way' do
    described_class.new(submission: submission, index: 0, decision: 'dismiss').perform!

    # Uma etapa que se move sem explicação é o que faz a equipa desconfiar.
    resolvida = submission.reload.metadata['resolved_actions'].first
    expect(resolvida['kind']).to eq('move_stage')
    expect(resolvida['decision']).to eq('dismiss')
    expect(resolvida['at']).to be_present
  end

  it 'refuses a decision it does not know' do
    expect do
      described_class.new(submission: submission, index: 0, decision: 'talvez').perform!
    end.to raise_error(described_class::UnknownAction)
  end

  it 'refuses an index that points at nothing' do
    expect do
      described_class.new(submission: submission, index: 7, decision: 'confirm').perform!
    end.to raise_error(described_class::UnknownAction)
  end
end
