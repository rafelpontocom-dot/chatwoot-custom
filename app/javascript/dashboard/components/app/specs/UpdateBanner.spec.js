import UpdateBanner from '../UpdateBanner.vue';

describe('UpdateBanner', () => {
  it('does not show version updates when the installation disables them', () => {
    const shouldShowBanner = UpdateBanner.computed.shouldShowBanner.call({
      userDismissedBanner: false,
      globalConfig: {
        appVersion: '4.16.0',
        displayManifest: true,
        displayUpdateBanner: false,
      },
      latestChatwootVersion: '4.17.0',
      isAdmin: true,
      updateAvailable: true,
      isVersionNotificationDismissed: () => false,
    });

    expect(shouldShowBanner).toBe(false);
  });
});
