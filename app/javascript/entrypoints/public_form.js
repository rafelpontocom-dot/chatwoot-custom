import { createApp } from 'vue';
import PublicFormApp from '../public_form/PublicFormApp.vue';

const element = document.querySelector('#public-form-app');

if (element) {
  createApp(PublicFormApp).mount(element);
}
