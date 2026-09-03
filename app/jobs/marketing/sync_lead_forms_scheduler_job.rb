class Marketing::SyncLeadFormsSchedulerJob < ApplicationJob
  queue_as :low

  STALE_AFTER = 6.hours

  # O anunciante cria e renomeia formulario no Meta sem nos avisar. Sincroniza
  # o mais desatualizado primeiro, com teto de chamadas externas.
  def perform
    MarketingLeadForm
      .joins(:marketing_provider_connection)
      .where(marketing_provider_connections: { status: 'connected' })
      .order(Arel.sql('last_synced_at IS NULL DESC, last_synced_at ASC'))
      .where('last_synced_at <= ? OR last_synced_at IS NULL', STALE_AFTER.ago)
      .limit(Limits::BULK_EXTERNAL_HTTP_CALLS_LIMIT)
      .each { |form| Marketing::SyncLeadFormsJob.perform_later(form.marketing_provider_connection_id, form.page_id) }
  end
end
