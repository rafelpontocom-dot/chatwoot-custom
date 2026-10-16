import tailwindConfig from '../../../../tailwind.config';
import { colors } from '../../../../theme/colors';
import packageJson from '../../../../package.json';

// tailwind.config.js, theme/colors.js e package.json são do Chatwoot. Um
// upgrade traz as versões novas inteiras; isto falha se a identidade do Raevo
// ou as portas dele ficarem pelo caminho.

describe('Raevo build configuration', () => {
  it('takes the brand colour from the Raevo token, not from Chatwoot blue', () => {
    expect(colors.n.brand).toBe('rgb(var(--brand-color) / <alpha-value>)');
  });

  it('uses the Raevo font and the 10px control radius', () => {
    const { fontFamily, borderRadius } = tailwindConfig.theme.extend;

    expect(fontFamily.sans).toBe('var(--raevo-font-sans)');
    expect(borderRadius).toMatchObject({ md: '8px', lg: '10px', xl: '14px' });
  });

  it('knows the Raevo control sizes and the public form/booking apps', () => {
    const { height, width } = tailwindConfig.theme.extend;

    expect(height.control).toBe('var(--raevo-control-h)');
    expect(width.sidebar).toBe('var(--raevo-sidebar-w)');
    expect(tailwindConfig.content).toEqual(
      expect.arrayContaining([
        './app/javascript/public_form/**/*.vue',
        './app/javascript/public_booking/**/*.vue',
      ])
    );
  });

  it('keeps the Raevo design gates and the libraries the modules need', () => {
    expect(Object.keys(packageJson.scripts)).toEqual(
      expect.arrayContaining([
        'raevo:design',
        'raevo:tokens',
        'raevo:palette',
        'skills:install',
      ])
    );
    expect(Object.keys(packageJson.dependencies)).toEqual(
      expect.arrayContaining([
        '@vue-flow/core',
        '@tiptap/vue-3',
        'chart.js',
        'vue-chartjs',
        '@fontsource-variable/plus-jakarta-sans',
      ])
    );
  });
});
