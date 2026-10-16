require 'rails_helper'

# Ficheiros de configuração do repositório que vêm do Chatwoot e que o Raevo
# alterou. Um upgrade traz as versões novas inteiras e leva a alteração sem
# conflito nenhum; cada exemplo diz o que se perdia.
RSpec.describe 'Raevo repository configuration' do # rubocop:disable RSpec/DescribeClass
  def read(path) = Rails.root.join(path).read
  def yaml(path) = YAML.safe_load(read(path), aliases: true)
  def workflow_runs(path) = yaml(path)['jobs'].values.flat_map { |job| job['steps'].to_a }.filter_map { |step| step['run'] }.join("\n")

  it 'keeps ignoring the RubyLLM advisories approved for Ruby 3.4' do
    expect(yaml('.bundler-audit.yml')['ignore']).to include('CVE-2026-67987', 'CVE-2026-67989', 'CVE-2026-67991')
  end

  it 'keeps the patched rack-proxy' do
    expect(read('Gemfile')).to include("gem 'rack-proxy', '~> 1.0', '>= 1.0.3'")
    expect(Gem.loaded_specs['rack-proxy'].version).to be >= Gem::Version.new('1.0.3')
  end

  it 'lets the classes the Raevo modules extend be long' do
    expect(yaml('.rubocop.yml').dig('Metrics/ClassLength', 'Exclude')).to include(
      'app/models/account.rb',
      'app/controllers/super_admin/accounts_controller.rb',
      'app/services/whatsapp/providers/whatsapp_cloud_service.rb'
    )
  end

  it 'documents the environment the Raevo modules read' do
    keys = read('.env.example').scan(/^([A-Z_]+)=/).flatten

    expect(keys).to include(
      'RAEVO_AI_SERVICE_URL', 'RAEVO_AI_SERVICE_TOKEN',
      'GOOGLE_CALENDAR_OAUTH_CLIENT_ID', 'GOOGLE_CALENDAR_OAUTH_CLIENT_SECRET', 'GOOGLE_CALENDAR_OAUTH_CALLBACK_URL'
    )
    expect(read('tests/playwright/.env.example')).to include('KANBAN_E2E=1', 'KANBAN_E2E_BOARD_ID=')
  end

  it 'keeps sockets and the reference material out of the image and the repository' do
    expect(read('.dockerignore').lines.map(&:strip)).to include('*.sock')
    expect(read('.gitignore').lines.map(&:strip)).to include('.playwright-mcp/', 'output/')
  end

  it 'installs as RAEVO CRM, not as Chatwoot' do
    manifest = JSON.parse(read('public/manifest.json'))

    expect(manifest).to include('name' => 'RAEVO CRM', 'short_name' => 'RAEVO CRM')
    expect(manifest['icons'].pluck('src')).to eq(['/brand-assets/raevo-favicon.svg'])
  end

  # A review app do Heroku é do upstream: aqui o job esperava 40 minutos e
  # falhava em todo PR.
  it 'skips the Heroku deploy check outside the upstream repository' do
    jobs = yaml('.github/workflows/deploy_check.yml')['jobs']

    expect(jobs.values.pluck('if')).to all(eq("github.repository == 'chatwoot/chatwoot'"))
  end

  # Com o índice numa lista ordenada, um spec novo mudava de shard todos os que
  # vinham depois dele.
  it 'splits the backend specs by a stable hash of the path' do
    runs = workflow_runs('.github/workflows/run_foss_spec.yml')

    expect(runs).to include('Digest::MD5.hexdigest(f)')
    expect(runs).not_to include('SPEC_FILES')
  end

  it 'keeps the Raevo playwright setup' do
    expect(read('tests/playwright/components/ui/login.component.ts')).to include("goto('/app/login'")
    expect(read('tests/playwright/playwright.config.ts')).to include("name: 'mobile-chromium'")
    expect(JSON.parse(read('tests/playwright/tsconfig.json')).dig('compilerOptions', 'ignoreDeprecations')).to eq('6.0')
  end

  it 'keeps the Raevo instructions for whoever works on the code' do
    expect(read('AGENTS.md')).to include(
      '## Atualização do Chatwoot: porta obrigatória',
      '# Raevo Design System',
      '## Porta de Qualidade Visual Raevo'
    )
  end
end
