class Forms::SensitiveAnswerCipher
  VERSION = 'v1'.freeze

  class ConfigurationError < StandardError; end

  class << self
    def configured?
      ENV.fetch('ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY', nil).present?
    end

    def encrypt(answers)
      "#{VERSION}:#{encryptor.encrypt_and_sign(answers.stringify_keys)}"
    end

    def decrypt(ciphertext)
      version, payload = ciphertext.to_s.split(':', 2)
      raise ArgumentError, 'unsupported sensitive answer ciphertext' unless version == VERSION && payload.present?

      encryptor.decrypt_and_verify(payload).stringify_keys
    end

    private

    def encryptor
      ActiveSupport::MessageEncryptor.new(encryption_key, cipher: 'aes-256-gcm', serializer: JSON)
    end

    def encryption_key
      ActiveSupport::KeyGenerator.new(primary_key).generate_key('raevo/forms/sensitive-answers/v1', 32)
    end

    def primary_key
      return ENV.fetch('ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY') if configured?

      raise ConfigurationError, 'ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY must be configured for sensitive health forms'
    end
  end
end
