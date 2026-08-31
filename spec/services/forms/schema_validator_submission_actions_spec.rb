require 'rails_helper'

RSpec.describe Forms::SchemaValidator do
  # As ações são validadas pelo SchemaValidator, que é a porta do `publish!`.
  def schema(actions, **extra)
    {
      'sections' => [{ 'key' => 's', 'fields' => [{ 'key' => 'nome', 'type' => 'text', 'label' => 'Nome' }] }],
      'submission_actions' => actions
    }.merge(extra)
  end

  it 'accepts moving a stage automatically, and leaving a label for review' do
    validator = described_class.new(
      schema(
        [
          { 'kind' => 'move_stage', 'mode' => 'automatic', 'kanban_stage_id' => 7 },
          { 'kind' => 'apply_label', 'mode' => 'review', 'label' => 'anamnese-recebida' }
        ]
      )
    )

    expect(validator).to be_valid
  end

  it 'refuses an action it does not know' do
    validator = described_class.new(schema([{ 'kind' => 'send_sms', 'mode' => 'automatic' }]))

    expect(validator).not_to be_valid
    expect(validator.errors).to include('submission action must declare a supported kind')
  end

  it 'refuses an action that is missing what it needs to run' do
    validator = described_class.new(schema([{ 'kind' => 'move_stage', 'mode' => 'automatic' }]))

    expect(validator).not_to be_valid
    expect(validator.errors).to include('submission action `move_stage` requires kanban_stage_id')
  end

  it 'refuses to put a webhook up for human review' do
    # Ninguém confirma uma chamada HTTP: quem a recebe é outro sistema.
    validator = described_class.new(
      schema([{ 'kind' => 'webhook', 'mode' => 'review', 'url' => 'https://n8n.raevo.io/h' }])
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('submission action `webhook` does not support mode `review`')
  end

  it 'refuses a webhook that is not https' do
    validator = described_class.new(
      schema([{ 'kind' => 'webhook', 'mode' => 'automatic', 'url' => 'http://n8n.raevo.io/h' }])
    )

    # Um webhook leva dados de paciente para fora; em claro é indefensável.
    expect(validator).not_to be_valid
    expect(validator.errors).to include('submission webhook requires an https URL')
  end

  it 'refuses any action at all on a clinical form' do
    validator = described_class.new(
      schema([{ 'kind' => 'move_stage', 'mode' => 'automatic', 'kanban_stage_id' => 7 }]),
      sensitive_health: true
    )

    expect(validator).not_to be_valid
    expect(validator.errors).to include('clinical forms cannot declare submission actions')
  end

  it 'keeps accepting a form with no actions' do
    expect(described_class.new(schema([]))).to be_valid
  end
end
