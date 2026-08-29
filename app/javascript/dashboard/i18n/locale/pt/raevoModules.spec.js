import englishMessages from '../en';
import brazilianPortugueseMessages from '../pt_BR';
import messages from './index';

describe('Portuguese Raevo CRM messages', () => {
  it('registers Calendar, Finance and Forms in the Portuguese catalogue', () => {
    expect(messages.SIDEBAR).toMatchObject({
      CALENDAR: 'Agenda',
      FINANCE: 'Financeiro',
      FORMS: 'Formulários',
    });
    expect(messages.CALENDAR.TITLE).toBe('Agenda');
    expect(messages.FINANCE.TITLE).toBe('Financeiro');
    expect(messages.FORMS.MULTISELECT).toMatchObject({
      SELECT: expect.any(String),
    });
    expect(messages.FORMS).toMatchObject({
      TITLE: 'Formulários',
      SUBTITLE: expect.any(String),
      ACTIONS: { NEW: expect.any(String) },
      TABS: {
        TEMPLATES: expect.any(String),
        SUBMISSIONS: expect.any(String),
      },
      EMPTY: {
        TEMPLATES_TITLE: expect.any(String),
        TEMPLATES_DESCRIPTION: expect.any(String),
      },
    });
  });

  it('keeps the base multiselect messages while adding the form workspace', () => {
    [englishMessages, brazilianPortugueseMessages, messages].forEach(
      catalogue => {
        expect(catalogue.FORMS).toMatchObject({
          MULTISELECT: { SELECT: expect.any(String) },
          TITLE: expect.any(String),
          TABS: { TEMPLATES: expect.any(String) },
        });
      }
    );
  });
});
