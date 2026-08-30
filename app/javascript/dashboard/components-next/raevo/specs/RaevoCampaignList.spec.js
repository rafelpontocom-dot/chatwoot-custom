import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import RaevoCampaignList from '../RaevoCampaignList.vue';

const i18n = createI18n({
  legacy: false,
  locale: 'en',
  messages: {
    en: {
      CAMPAIGN: {
        TABLE: {
          NAME: 'Campaign',
          CHANNEL: 'Channel',
          STATUS: 'Status',
          SENDER: 'Sender',
          SCHEDULED: 'Scheduled for',
          ACTIONS: 'Actions',
          EDIT: 'Edit campaign',
          DELETE: 'Delete campaign',
        },
        STATUS: {
          ACTIVE: 'Active',
          PROCESSING: 'Sending',
          COMPLETED: 'Completed',
          DISABLED: 'Disabled',
        },
      },
    },
  },
});

const mountList = campaigns =>
  mount(RaevoCampaignList, {
    props: { campaigns },
    global: { plugins: [i18n], stubs: { Icon: true } },
  });

const base = {
  id: 1,
  title: 'Reativação',
  enabled: true,
  campaign_status: 'active',
};

describe('RaevoCampaignList', () => {
  it('renders one row per campaign inside the Sereno table', () => {
    const w = mountList([base, { ...base, id: 2 }, { ...base, id: 3 }]);
    expect(w.find('[data-testid="raevo-campaigns-table"]').exists()).toBe(true);
    expect(w.findAll('tbody tr')).toHaveLength(3);
  });

  it('maps the backend enum to a stamp with colour, icon and text', () => {
    expect(mountList([base]).text()).toContain('Active');
    expect(
      mountList([{ ...base, campaign_status: 'processing' }]).text()
    ).toContain('Sending');
    expect(
      mountList([{ ...base, campaign_status: 'completed' }]).text()
    ).toContain('Completed');
  });

  // Campanha desativada tem precedência sobre o status do enum: uma campanha
  // "active" mas desligada não pode aparecer como ativa na tela.
  it('shows a disabled campaign as disabled even when the enum says active', () => {
    expect(mountList([{ ...base, enabled: false }]).text()).toContain(
      'Disabled'
    );
  });

  it('falls back to a dash when channel, sender or schedule are missing', () => {
    const linha = mountList([base])
      .find('[data-testid="raevo-campaign-row-1"]')
      .text();
    expect(linha).toContain('—');
  });

  it('emits edit and delete with the campaign', async () => {
    const w = mountList([base]);
    const botoes = w.findAll('tbody button');
    await botoes[0].trigger('click');
    await botoes[1].trigger('click');
    expect(w.emitted('edit')[0][0].id).toBe(1);
    expect(w.emitted('delete')[0][0].id).toBe(1);
  });
});
