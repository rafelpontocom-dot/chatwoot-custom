require 'rails_helper'

RSpec.describe Forms::SensitiveAnswerCipher do
  around do |example|
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => 'forms-test-encryption-key' do
      example.run
    end
  end

  it 'encrypts and restores an anamnese answer document' do
    answers = { 'alergias' => 'Penicilina', 'medicamentos' => 'Nenhum' }

    ciphertext = described_class.encrypt(answers)

    expect(ciphertext).not_to include('Penicilina')
    expect(described_class.decrypt(ciphertext)).to eq(answers)
  end

  it 'refuses to process clinical answers without an application encryption key' do
    with_modified_env 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY' => nil do
      expect { described_class.encrypt('alergias' => 'Penicilina') }
        .to raise_error(Forms::SensitiveAnswerCipher::ConfigurationError)
    end
  end
end
