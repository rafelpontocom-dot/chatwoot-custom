require 'rails_helper'

RSpec.describe Forms::ApplySubmissionActionsService do
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

  def schema(actions)
    {
      'crm_destination' => {
        'kanban_board_id' => board.id, 'kanban_stage_id' => stage.id,
        'inbox_id' => card.inbox_id, 'opportunity_policy' => 'reuse_open'
      },
      'sections' => [{ 'key' => 's', 'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' }] }],
      'submission_actions' => actions
    }
  end

  def submission_for(actions)
    version = template.publish!(schema: schema(actions))
    FormSubmission.create!(
      account: account, form_template_version: version, contact: contact,
      kanban_card: card, answers: { 'nome' => 'Maria' }, submitted_at: Time.current
    )
  end

  describe 'automatic' do
    it 'moves the opportunity to the configured stage' do
      submission = submission_for(
        [{ 'kind' => 'move_stage', 'mode' => 'automatic', 'kanban_stage_id' => proxima_etapa.id }]
      )

      described_class.new(submission: submission).perform

      expect(card.reload.kanban_stage_id).to eq(proxima_etapa.id)
    end

    it 'records a failure instead of moving to a stage from another board' do
      outro = create(:kanban_stage, account: account, kanban_board: create(:kanban_board, account: account))
      submission = submission_for(
        [{ 'kind' => 'move_stage', 'mode' => 'automatic', 'kanban_stage_id' => outro.id }]
      )

      described_class.new(submission: submission).perform

      expect(card.reload.kanban_stage_id).to eq(stage.id)
      expect(submission.reload.metadata['failed_actions']).to eq(['move_stage'])
    end
  end

  describe 'review' do
    it 'leaves the action proposed instead of applying it' do
      submission = submission_for(
        [{ 'kind' => 'move_stage', 'mode' => 'review', 'kanban_stage_id' => proxima_etapa.id }]
      )

      described_class.new(submission: submission).perform

      # A secretaria confirma; até lá a oportunidade não se mexe sozinha.
      expect(card.reload.kanban_stage_id).to eq(stage.id)
      expect(submission.reload.metadata['pending_actions'].first['kind']).to eq('move_stage')
    end

    it 'applies the automatic ones and proposes only the rest' do
      submission = submission_for(
        [
          { 'kind' => 'move_stage', 'mode' => 'automatic', 'kanban_stage_id' => proxima_etapa.id },
          { 'kind' => 'apply_label', 'mode' => 'review', 'label' => 'anamnese-recebida' }
        ]
      )

      described_class.new(submission: submission).perform

      expect(card.reload.kanban_stage_id).to eq(proxima_etapa.id)
      expect(submission.reload.metadata['pending_actions'].map { |a| a['kind'] }).to eq(['apply_label'])
    end
  end

  describe 'webhook' do
    it 'sends only what identifies, never an answer' do
      submission = submission_for(
        [{ 'kind' => 'webhook', 'mode' => 'automatic', 'url' => 'https://n8n.raevo.io/hook' }]
      )

      expect(Forms::SubmissionWebhookJob).to receive(:perform_later) do |url, payload|
        expect(url).to eq('https://n8n.raevo.io/hook')
        expect(payload.keys).to contain_exactly(
          :account_id, :submission_id, :form_template_id, :kanban_card_id, :contact_id
        )
      end

      described_class.new(submission: submission).perform
    end
  end

  describe 'attach_to_history' do
    it 'leaves a private note on the conversation, without any answer in it' do
      conversation = create(:conversation, account: account, contact: contact, inbox: card.inbox)
      card.update!(conversation: conversation)
      submission = submission_for([{ 'kind' => 'attach_to_history', 'mode' => 'automatic' }])

      expect { described_class.new(submission: submission).perform }
        .to change { conversation.messages.count }.by(1)

      nota = conversation.messages.last
      expect(nota.private).to be(true)
      expect(nota.content).to include('Captação')
      # O conteúdo pertence à ficha, que tem autorização própria, e não ao
      # histórico que a equipa toda lê.
      expect(nota.content).not_to include('Maria')
    end

    it 'records a failure when the opportunity has no conversation' do
      card.update!(conversation: nil)
      submission = submission_for([{ 'kind' => 'attach_to_history', 'mode' => 'automatic' }])

      described_class.new(submission: submission).perform

      expect(submission.reload.metadata['failed_actions']).to eq(['attach_to_history'])
    end
  end

  describe 'guards' do
    it 'does nothing at all for a clinical form' do
      clinico = FormTemplate.create!(
        account: account, name: 'Anamnese', slug: 'anamnese',
        category: 'clinical', access_classification: 'sensitive_health'
      )
      # O validador já recusa publicar isto — ver o spec do SchemaValidator. Aqui
      # a versão entra sem validação de propósito, para provar que o serviço
      # também recusa dados que tenham entrado antes da regra existir.
      version = clinico.form_template_versions.new(
        account: account, version_number: 1, published_at: Time.current,
        schema: {
          'sections' => [{ 'key' => 's', 'fields' => [
            { 'key' => 'consent', 'type' => 'consent', 'label' => 'Consinto', 'required' => true }
          ] }],
          'submission_actions' => [
            { 'kind' => 'move_stage', 'mode' => 'automatic', 'kanban_stage_id' => proxima_etapa.id }
          ]
        }
      )
      version.save!(validate: false)

      with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
        submission = FormSubmission.create_from_answers!(
          account: account, form_template_version: version, contact: contact,
          answers: { 'consent' => true }
        )
        submission.update!(kanban_card: card)

        described_class.new(submission: submission).perform
      end

      # Uma resposta clínica não move nada sozinha. É a mesma regra do
      # mapeamento para CRM, que já recusa.
      expect(card.reload.kanban_stage_id).to eq(stage.id)
    end

    it 'does nothing when the submission has no opportunity' do
      version = template.publish!(
        schema: schema([{ 'kind' => 'move_stage', 'mode' => 'automatic', 'kanban_stage_id' => proxima_etapa.id }])
      )
      sem_card = FormSubmission.create!(
        account: account, form_template_version: version, contact: contact,
        answers: { 'nome' => 'Maria' }, submitted_at: Time.current
      )

      expect { described_class.new(submission: sem_card).perform }.not_to raise_error
      expect(sem_card.reload.metadata['pending_actions']).to be_nil
    end
  end
end
