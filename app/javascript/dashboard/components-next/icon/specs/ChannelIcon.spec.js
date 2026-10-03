import { mount } from '@vue/test-utils';
import ChannelIcon from '../ChannelIcon.vue';

describe('ChannelIcon', () => {
  it('uses the configured image for camelCase inbox payloads too', () => {
    const wrapper = mount(ChannelIcon, {
      props: {
        inbox: { channelType: 'Channel::Api', avatarUrl: '/api-channel.png' },
      },
    });

    expect(wrapper.find('img').attributes('src')).toBe('/api-channel.png');
  });

  it('renders the uploaded inbox image instead of the channel glyph', () => {
    const wrapper = mount(ChannelIcon, {
      props: {
        inbox: { channel_type: 'Channel::Api', avatar_url: '/inbox.png' },
      },
    });

    expect(wrapper.get('img').attributes('src')).toBe('/inbox.png');
    expect(wrapper.get('img').attributes('alt')).toBe('');
    expect(wrapper.find('span.i-woot-api').exists()).toBe(false);
  });

  it('keeps the channel glyph for an inbox without an image', () => {
    const wrapper = mount(ChannelIcon, {
      props: { inbox: { channel_type: 'Channel::Whatsapp' } },
    });

    expect(wrapper.find('img').exists()).toBe(false);
    expect(wrapper.find('.i-woot-whatsapp').exists()).toBe(true);
  });

  it('falls back to the glyph if the uploaded image cannot load and retries a new image', async () => {
    const wrapper = mount(ChannelIcon, {
      props: {
        inbox: { channel_type: 'Channel::Api', avatar_url: '/missing.png' },
      },
    });

    await wrapper.get('img').trigger('error');
    expect(wrapper.find('img').exists()).toBe(false);
    expect(wrapper.find('.i-woot-api').exists()).toBe(true);

    await wrapper.setProps({
      inbox: { channel_type: 'Channel::Api', avatar_url: '/new-image.png' },
    });
    expect(wrapper.get('img').attributes('src')).toBe('/new-image.png');
  });
});
