import { createApp } from 'vue';
import { createI18n } from 'vue-i18n';

import '../dashboard/assets/scss/app.scss';
import PublicBookingApp from '../public_booking/PublicBookingApp.vue';

const element = document.querySelector('#public-booking-app');

const base = {
  STEPS_LABEL: 'Etapas do agendamento',
  STEPS: { TIME: 'Horário', DETAILS: 'Seus dados', DONE: 'Pronto' },
  NO_PROCEDURES: 'Ainda não há procedimentos disponíveis para agendamento.',
  LOADING: 'Carregando horários disponíveis…',
  PROCEDURE: 'Procedimento',
  PROCEDURE_META: '{minutes} min · {location}',
  FREE: 'sem custo',
  DURATION: '{count} minutos',
  LOCATIONS: {
    IN_PERSON: 'Presencial',
    VIDEO: 'Vídeo',
    PHONE: 'Telefone',
    OTHER: 'Outro local',
  },
  WITH_WHOM: 'Com quem?',
  ANYONE: 'Qualquer profissional',
  PREVIOUS_MONTH: 'Mês anterior',
  NEXT_MONTH: 'Próximo mês',
  NO_ROOM_HINT: 'Dias sem destaque não têm vaga para esta combinação.',
  PICK_DAY: 'Escolha um dia',
  LOADING_SLOTS: 'Buscando horários…',
  FREE_TIMES:
    'Nenhum horário livre | 1 horário livre | {count} horários livres',
  TIMEZONE: 'Fuso horário',
  HOLD_NOTE:
    'Enquanto você preenche, o horário fica reservado por {minutes} minutos.',
  HOLD_ENDING: 'O horário fica reservado só mais {seconds} segundos.',
  RESCHEDULE_NOTE:
    'Escolha o novo horário. O anterior só é liberado quando o novo for confirmado.',
  OPTIONAL: 'opcional',
  PAYMENT_METHOD: 'Forma de pagamento',
  METHODS: { PIX: 'Pix', CARD: 'Cartão', ON_SITE: 'Pagar na clínica' },
  AT_CLINIC: 'Na clínica',
  TOTAL: 'Total',
  CONSENT:
    'Autorizo o uso dos meus dados para realizar este agendamento e receber o retorno da equipe.',
  BACK: 'Voltar',
  CONFIRM: 'Confirmar agendamento',
  PAY_AND_CONFIRM: 'Pagar e confirmar',
  CONFIRMING: 'Confirmando…',
  REQUEST_ERROR: 'Não foi possível concluir o agendamento.',
  ERRORS: {
    REQUIRED: 'Preencha este campo.',
    CPF: 'Confira o CPF.',
    PHONE: 'Informe o WhatsApp com DDD.',
    EMAIL: 'Confira o e-mail.',
    CONSENT: 'Para marcar, é preciso autorizar o uso dos dados.',
    REASON: 'Diga o motivo do cancelamento.',
    SLOT_TAKEN: 'Este horário acabou de ser reservado. Escolha outro.',
    HOLD_EXPIRED: 'O tempo de reserva acabou. Escolha o horário de novo.',
    TOO_MANY: 'Muitas tentativas seguidas. Aguarde um pouco e tente de novo.',
    PAYMENT_FAILED:
      'Não foi possível abrir o pagamento agora. Tente outra forma de pagamento ou pague na clínica.',
  },
  DONE: {
    TITLES: {
      CONFIRMED: 'Consulta marcada',
      AWAITING_PAYMENT: 'Aguardando confirmação do pagamento',
      CANCELED: 'Consulta cancelada',
    },
    WHEN: '{day}, às {time}',
    WITH: 'com {name}',
    IN: 'na {room}',
    WHATSAPP_SENT: ' Enviamos a confirmação no seu WhatsApp.',
    AWAITING: ' O horário fica reservado até o pagamento ser confirmado.',
    PAID: 'Pago por {method} · {amount}',
    PAYMENT_PENDING: 'Pagamento pendente · {amount}',
    PAY_AT_CLINIC: 'Pagamento na clínica',
    OPEN_PAYMENT: 'Abrir pagamento',
    ADD_TO_CALENDAR: 'Adicionar ao meu calendário',
    RESCHEDULE: 'Remarcar',
    CANCEL: 'Cancelar consulta',
    REASON_REQUIRED: 'Motivo do cancelamento',
    REASON_OPTIONAL: 'Motivo do cancelamento (opcional)',
    CONFIRM_CANCEL: 'Cancelar consulta',
  },
};

const messages = {
  pt_BR: { PUBLIC_BOOKING: base },
  pt: {
    PUBLIC_BOOKING: {
      ...base,
      NO_PROCEDURES:
        'Ainda não existem procedimentos disponíveis para marcação.',
      LOADING: 'A carregar horários disponíveis…',
      LOADING_SLOTS: 'A procurar horários…',
      HOLD_NOTE:
        'Enquanto preenche, o horário fica reservado durante {minutes} minutos.',
      CONSENT:
        'Autorizo a utilização dos meus dados para realizar esta marcação e receber o contacto da equipa.',
      CONFIRM: 'Confirmar marcação',
      CONFIRMING: 'A confirmar…',
      REQUEST_ERROR: 'Não foi possível concluir a marcação.',
      DONE: {
        ...base.DONE,
        WHATSAPP_SENT: ' Enviámos a confirmação para o seu WhatsApp.',
      },
    },
  },
};

const i18n = createI18n({ legacy: false, locale: 'pt_BR', messages });

if (element) {
  createApp(PublicBookingApp, {
    bookingPageUrl: element.dataset.bookingPageUrl || '',
    initialProcedureSlug: element.dataset.procedureSlug || '',
    isPrivateBooking: element.dataset.privateBooking === 'true',
    bookingToken: element.dataset.bookingToken || '',
  })
    .use(i18n)
    .mount(element);
}
