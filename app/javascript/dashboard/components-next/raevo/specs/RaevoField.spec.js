import { mount } from '@vue/test-utils';
import RaevoField from '../RaevoField.vue';
import {
  RAEVO_CONTROL_CLASS,
  RAEVO_SELECT_CLASS,
  RAEVO_TEXTAREA_CLASS,
} from '../raevoControl';

const mountField = (props = {}, slotTemplate = null) =>
  mount(RaevoField, {
    props,
    slots: {
      default:
        slotTemplate ||
        `<template #default="{ controlClass, fieldId, describedBy }">
           <input :id="fieldId" :class="controlClass" :aria-describedby="describedBy" />
         </template>`,
    },
  });

describe('RaevoField', () => {
  it('renders the label above the control and ties them by id', () => {
    const wrapper = mountField({ label: 'Procedimento' });

    const label = wrapper.find('label');
    const input = wrapper.find('input');

    expect(label.text()).toContain('Procedimento');
    expect(label.attributes('for')).toBe(input.attributes('id'));
  });

  it('hands the slot the class matching the variant', () => {
    expect(mountField().find('input').classes().join(' ')).toBe(
      RAEVO_CONTROL_CLASS
    );

    const select = mountField(
      { variant: 'select' },
      `<template #default="{ controlClass }"><select :class="controlClass" /></template>`
    );
    expect(select.find('select').classes().join(' ')).toBe(RAEVO_SELECT_CLASS);

    const textarea = mountField(
      { variant: 'textarea' },
      `<template #default="{ controlClass }"><textarea :class="controlClass" /></template>`
    );
    expect(textarea.find('textarea').classes().join(' ')).toBe(
      RAEVO_TEXTAREA_CLASS
    );
  });

  it('draws its own caret for selects so the control keeps one shell', () => {
    expect(
      mountField({ variant: 'select' }).find('.i-lucide-chevron-down').exists()
    ).toBe(true);
    expect(mountField().find('.i-lucide-chevron-down').exists()).toBe(false);
  });

  it('announces the error and hides the hint while it is showing', () => {
    const wrapper = mountField({
      hint: 'Opcional',
      error: 'Escolha um procedimento',
    });

    const error = wrapper.find('[role="alert"]');
    expect(error.text()).toBe('Escolha um procedimento');
    expect(wrapper.text()).not.toContain('Opcional');
    expect(wrapper.find('input').attributes('aria-describedby')).toBe(
      error.attributes('id')
    );
  });

  it('describes the control by the hint when there is no error', () => {
    const wrapper = mountField({ hint: 'Usado no link público' });

    expect(wrapper.find('input').attributes('aria-describedby')).toBe(
      wrapper.find('p').attributes('id')
    );
  });

  it('follows the Sereno geometry: one-line controls are pills, textarea is not', () => {
    // docs/raevo-design-system.md §4
    expect(RAEVO_CONTROL_CLASS).toContain('h-10');
    expect(RAEVO_CONTROL_CLASS).toContain('rounded-full');
    expect(RAEVO_SELECT_CLASS).toContain('h-10');
    expect(RAEVO_SELECT_CLASS).toContain('rounded-full');
    expect(RAEVO_TEXTAREA_CLASS).toContain('rounded-lg');
    expect(RAEVO_TEXTAREA_CLASS).not.toContain('rounded-full');
    [RAEVO_CONTROL_CLASS, RAEVO_SELECT_CLASS, RAEVO_TEXTAREA_CLASS].forEach(
      cls => {
        expect(cls).toContain('border-n-strong');
      }
    );
  });
});
