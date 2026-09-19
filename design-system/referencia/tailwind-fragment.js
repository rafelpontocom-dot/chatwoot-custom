// GERADO por scripts/translate-reference.mjs — fragmento para tailwind.config.js
//
// A referência usa Tailwind v4 e declara os tokens em `@theme inline`, que o
// Tailwind v3 não tem. Em v3 o mesmo mapeamento vive aqui, no `theme.extend`.
module.exports = {
  theme: {
    extend: {
      borderRadius: {
        'sm': 'calc(var(--radius) - 4px)',
        'md': 'calc(var(--radius) - 2px)',
        'lg': 'var(--radius)',
        'xl': 'calc(var(--radius) + 4px)',
        '2xl': 'calc(var(--radius) + 8px)',
        '3xl': 'calc(var(--radius) + 12px)',
        DEFAULT: 'var(--radius)',
      },
      colors: {
      'card': 'rgb(var(--shadcn-card) / <alpha-value>)',
      'card-foreground': 'rgb(var(--shadcn-card-foreground) / <alpha-value>)',
      'popover': 'rgb(var(--shadcn-popover) / <alpha-value>)',
      'popover-foreground': 'rgb(var(--shadcn-popover-foreground) / <alpha-value>)',
      'primary': 'rgb(var(--shadcn-primary) / <alpha-value>)',
      'primary-foreground': 'rgb(var(--shadcn-primary-foreground) / <alpha-value>)',
      'secondary': 'rgb(var(--shadcn-secondary) / <alpha-value>)',
      'secondary-foreground': 'rgb(var(--shadcn-secondary-foreground) / <alpha-value>)',
      'muted': 'rgb(var(--shadcn-muted) / <alpha-value>)',
      'muted-foreground': 'rgb(var(--shadcn-muted-foreground) / <alpha-value>)',
      'accent': 'rgb(var(--shadcn-accent) / <alpha-value>)',
      'accent-foreground': 'rgb(var(--shadcn-accent-foreground) / <alpha-value>)',
      'destructive': 'rgb(var(--shadcn-destructive) / <alpha-value>)',
      'border': 'rgb(var(--shadcn-border) / <alpha-value>)',
      'input': 'rgb(var(--shadcn-input) / <alpha-value>)',
      'ring': 'rgb(var(--shadcn-ring) / <alpha-value>)',
      'chart-1': 'rgb(var(--shadcn-chart-1) / <alpha-value>)',
      'chart-2': 'rgb(var(--shadcn-chart-2) / <alpha-value>)',
      'chart-3': 'rgb(var(--shadcn-chart-3) / <alpha-value>)',
      'chart-4': 'rgb(var(--shadcn-chart-4) / <alpha-value>)',
      'chart-5': 'rgb(var(--shadcn-chart-5) / <alpha-value>)',
      'sidebar': 'rgb(var(--shadcn-sidebar) / <alpha-value>)',
      'sidebar-foreground': 'rgb(var(--shadcn-sidebar-foreground) / <alpha-value>)',
      'sidebar-primary': 'rgb(var(--shadcn-sidebar-primary) / <alpha-value>)',
      'sidebar-primary-foreground': 'rgb(var(--shadcn-sidebar-primary-foreground) / <alpha-value>)',
      'sidebar-accent': 'rgb(var(--shadcn-sidebar-accent) / <alpha-value>)',
      'sidebar-accent-foreground': 'rgb(var(--shadcn-sidebar-accent-foreground) / <alpha-value>)',
      'sidebar-border': 'rgb(var(--shadcn-sidebar-border) / <alpha-value>)',
      'sidebar-ring': 'rgb(var(--shadcn-sidebar-ring) / <alpha-value>)',
      'background': 'rgb(var(--shadcn-background) / <alpha-value>)',
      'foreground': 'rgb(var(--shadcn-foreground) / <alpha-value>)',
      },
      // Densidade medida na referência (button h-8/px-2.5, table th h-10 / td p-2).
      height: { btn: '32px', 'btn-sm': '28px', 'btn-xs': '24px', 'btn-lg': '36px', th: '40px' },
      width: { sidebar: '16rem', 'sidebar-icon': '3rem', 'sidebar-mobile': '18rem' },
    },
  },
};
