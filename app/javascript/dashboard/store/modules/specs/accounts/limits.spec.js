import { actions } from '../../accounts';
import EnterpriseAccountAPI from 'dashboard/api/enterprise/account';

vi.mock('dashboard/api/enterprise/account', () => ({
  default: { getLimits: vi.fn() },
}));

describe('accounts/limits', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    EnterpriseAccountAPI.getLimits.mockResolvedValue({
      data: { id: 7, limits: { agents: { allowed: 2, consumed: 1 } } },
    });
  });

  it('never requests the Cloud-only endpoint on a self-hosted account', async () => {
    const commit = vi.fn();

    await actions.limits({
      commit,
      rootGetters: { 'globalConfig/isOnChatwootCloud': false },
    });

    expect(EnterpriseAccountAPI.getLimits).not.toHaveBeenCalled();
    expect(commit).not.toHaveBeenCalled();
  });

  it('loads limits and clears the loading flag on Cloud', async () => {
    const commit = vi.fn();

    await actions.limits({
      commit,
      rootGetters: { 'globalConfig/isOnChatwootCloud': true },
    });

    expect(EnterpriseAccountAPI.getLimits).toHaveBeenCalledOnce();
    expect(commit).toHaveBeenCalledWith('SET_ACCOUNT_LIMITS', {
      id: 7,
      limits: { agents: { allowed: 2, consumed: 1 } },
    });
    expect(commit).toHaveBeenLastCalledWith('SET_ACCOUNT_UI_FLAG', {
      isFetchingLimits: false,
    });
  });
});
