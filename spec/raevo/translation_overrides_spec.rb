require 'rails_helper'

# Os textos que o Raevo mudou ou acrescentou nas traduções do Chatwoot
# (config/raevo/translation-overrides.json, gerado por
# scripts/raevo-translation-overrides.rb). Um upgrade ou uma sincronização do
# Crowdin reescrevem estes ficheiros sem conflito; este teste é o que dá por isso.
RSpec.describe 'Raevo translation overrides' do # rubocop:disable RSpec/DescribeClass
  record = JSON.parse(Rails.root.join('config/raevo/translation-overrides.json').read)

  def flatten(value, prefix = nil, out = {})
    return out.merge!(prefix => value) unless value.is_a?(Hash)

    value.each { |key, child| flatten(child, [prefix, key].compact.join('.'), out) }
    out
  end

  record.fetch('files').each do |path, expected|
    it "keeps the Raevo texts in #{path}" do
      content = Rails.root.join(path).read
      current = flatten(path.end_with?('.json') ? JSON.parse(content) : YAML.safe_load(content, aliases: true))
      changed = expected.reject { |key, value| current[key] == value }

      expect(changed.keys).to be_empty, "#{changed.size} texto(s) voltaram ao original ou sumiram em #{path}: #{changed.keys.first(5).join(', ')}"
    end
  end
end
