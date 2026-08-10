import { createApp } from 'vue';
import { createI18n } from 'vue-i18n';

import '../dashboard/assets/scss/app.scss';
import PublicBookingApp from '../public_booking/PublicBookingApp.vue';

const element = document.querySelector('#public-booking-app');

const messages = {
  pt_BR: {
    PUBLIC_BOOKING: {
      EYEBROW: 'Agendamento online',
      DEFAULT_TITLE: 'Agende seu horário',
      NO_PROCEDURES: 'Ainda não há procedimentos disponíveis para agendamento.',
      LOADING: 'Carregando horários disponíveis...',
      CONFIRMED: 'Agendamento confirmado',
      CONFIRMED_DESCRIPTION:
        'Recebemos sua solicitação. A equipe continuará o atendimento pelo canal informado.',
      PROCEDURE: 'Procedimento',
      MINUTES: '{value} min',
      TIME: 'Horário',
      RESOURCE: 'Profissional ou recurso',
      DATE: 'Data',
      LOADING_SLOTS: 'Buscando horários...',
      NO_SLOTS: 'Não há horários livres nesta data.',
      CONTACT: 'Seus dados',
      NAME: 'Nome',
      PHONE: 'Telefone',
      EMAIL: 'E-mail',
      CONSENT:
        'Autorizo o uso dos meus dados para realizar este agendamento e receber o retorno da equipe.',
      CONFIRMING: 'Confirmando...',
      CONFIRM: 'Confirmar agendamento',
      CAPTCHA_REQUIRED: 'Conclua a verificação de segurança para confirmar.',
      REQUEST_ERROR: 'Não foi possível concluir o agendamento.',
    },
  },
  pt: {
    PUBLIC_BOOKING: {
      EYEBROW: 'Marcação online',
      DEFAULT_TITLE: 'Marque o seu horário',
      NO_PROCEDURES:
        'Ainda não existem procedimentos disponíveis para marcação.',
      LOADING: 'A carregar horários disponíveis...',
      CONFIRMED: 'Marcação confirmada',
      CONFIRMED_DESCRIPTION:
        'Recebemos o seu pedido. A equipa continuará o atendimento pelo canal indicado.',
      PROCEDURE: 'Procedimento',
      MINUTES: '{value} min',
      TIME: 'Horário',
      RESOURCE: 'Profissional ou recurso',
      DATE: 'Data',
      LOADING_SLOTS: 'A procurar horários...',
      NO_SLOTS: 'Não existem horários livres nesta data.',
      CONTACT: 'Os seus dados',
      NAME: 'Nome',
      PHONE: 'Telefone',
      EMAIL: 'E-mail',
      CONSENT:
        'Autorizo a utilização dos meus dados para realizar esta marcação e receber o contacto da equipa.',
      CONFIRMING: 'A confirmar...',
      CONFIRM: 'Confirmar marcação',
      CAPTCHA_REQUIRED: 'Conclua a verificação de segurança para confirmar.',
      REQUEST_ERROR: 'Não foi possível concluir a marcação.',
    },
  },
};

const i18n = createI18n({
  legacy: false,
  locale: 'pt_BR',
  messages,
});

if (element) {
  createApp(PublicBookingApp, {
    bookingPageUrl: element.dataset.bookingPageUrl,
    initialProcedureSlug: element.dataset.procedureSlug || '',
    isPrivateBooking: element.dataset.privateBooking === 'true',
  })
    .use(i18n)
    .mount(element);
}
