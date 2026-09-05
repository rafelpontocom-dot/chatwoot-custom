require 'rails_helper'

RSpec.describe Marketing::Meta::SyncLeadFormsService do
  let(:account) { create(:account) }
  let(:connection) do
    account.marketing_provider_connections.create!(
      provider: 'meta', external_account_id: 'meta-1', status: 'connected', access_token: 'user-token',
      settings: { 'pages' => [{ 'id' => '10', 'name' => 'Clinica' }] }
    )
  end
  let(:forms) do
    [{ 'id' => 'f1', 'name' => 'Diagnostico', 'status' => 'ACTIVE',
       'questions' => [{ 'key' => 'full_name', 'label' => 'Seu nome', 'type' => 'FULL_NAME' }] },
     { 'id' => 'f2', 'name' => 'Script 2024', 'status' => 'ARCHIVED', 'questions' => [] }]
  end

  before do
    connection.store_page_tokens!('10' => 'page-token')
    stub_request(:get, %r{graph\.facebook\.com/.*/10/leadgen_forms})
      .to_return(status: 200, body: { data: forms }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  # Uma clinica antiga acumula dezenas de arquivados; importa-los esconde o vivo.
  it 'leaves archived forms out, since they collect nothing' do
    described_class.new(connection: connection, page_id: '10').perform

    expect(account.marketing_lead_forms.pluck(:external_form_id)).to eq(['f1'])
  end

  it 'keeps the questions as the advertiser wrote them' do
    record = described_class.new(connection: connection, page_id: '10').perform.first

    expect(record.questions).to eq([{ 'key' => 'full_name', 'label' => 'Seu nome', 'type' => 'FULL_NAME' }])
    expect(record.page_name).to eq('Clinica')
  end

  # Sincronizar de novo nao pode desfazer o trabalho de quem configurou.
  it 'never overwrites a mapping that someone chose' do
    record = described_class.new(connection: connection, page_id: '10').perform.first
    record.update!(field_mapping: { 'full_name' => 'name' })

    described_class.new(connection: connection, page_id: '10').perform

    expect(record.reload.field_mapping).to eq('full_name' => 'name')
  end
end
