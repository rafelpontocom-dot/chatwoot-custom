require 'rails_helper'

RSpec.describe Forms::DetectAbandonedInvitationsJob do
  it 'runs the abandonment service in the scheduled queue' do
    service = instance_double(Forms::DetectAbandonedInvitationsService, perform!: nil)
    allow(Forms::DetectAbandonedInvitationsService).to receive(:new).and_return(service)

    expect { described_class.perform_later }.to have_enqueued_job(described_class).on_queue('scheduled_jobs')

    described_class.perform_now

    expect(service).to have_received(:perform!)
  end
end
