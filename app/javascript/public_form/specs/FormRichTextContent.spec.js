import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import FormRichTextContent from '../FormRichTextContent.vue';

describe('FormRichTextContent', () => {
  it('renders safe rich-text links for the public form', async () => {
    const wrapper = mount(FormRichTextContent, {
      props: {
        content: {
          type: 'doc',
          content: [
            {
              type: 'paragraph',
              content: [
                {
                  type: 'text',
                  text: 'Política de privacidade',
                  marks: [
                    {
                      type: 'link',
                      attrs: { href: 'https://raevo.io/privacidade' },
                    },
                  ],
                },
              ],
            },
          ],
        },
      },
    });

    await nextTick();
    await nextTick();
    const link = wrapper.get('a');
    expect(link.attributes('href')).toBe('https://raevo.io/privacidade');
    expect(link.attributes('target')).toBe('_blank');
    expect(link.attributes('rel')).toBe('noopener noreferrer');
  });
});
