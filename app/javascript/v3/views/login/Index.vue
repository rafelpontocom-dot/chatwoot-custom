<script>
// utils and composables
import { login } from '../../api/auth';
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { required, email } from '@vuelidate/validators';
import { useVuelidate } from '@vuelidate/core';
import { SESSION_STORAGE_KEYS } from 'dashboard/constants/sessionStorage';
import SessionStorage from 'shared/helpers/sessionStorage';
import AnalyticsHelper from 'dashboard/helper/AnalyticsHelper';
import { SESSION_EVENTS } from 'dashboard/helper/AnalyticsHelper/events';

// components
import SimpleDivider from '../../components/Divider/SimpleDivider.vue';
import FormInput from '../../components/Form/Input.vue';
import GoogleOAuthButton from '../../components/GoogleOauth/Button.vue';
import Spinner from 'shared/components/Spinner.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import MfaVerification from 'dashboard/components/auth/MfaVerification.vue';
import SessionLimitOverlay from 'dashboard/components/auth/SessionLimitOverlay.vue';

const ERROR_MESSAGES = {
  'no-account-found': 'LOGIN.OAUTH.NO_ACCOUNT_FOUND',
  'business-account-only': 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY',
  'saml-authentication-failed': 'LOGIN.SAML.API.ERROR_MESSAGE',
  'saml-not-enabled': 'LOGIN.SAML.API.ERROR_MESSAGE',
};

const IMPERSONATION_URL_SEARCH_KEY = 'impersonation';
const USER_NOT_CONFIRMED_ERROR_CODE = 'user_not_confirmed';
const RAEVO_LOGIN_LOGO = '/brand-assets/raevo-logo-areia.svg';

export default {
  components: {
    FormInput,
    GoogleOAuthButton,
    Spinner,
    NextButton,
    SimpleDivider,
    MfaVerification,
    SessionLimitOverlay,
    Icon,
  },
  props: {
    ssoAuthToken: { type: String, default: '' },
    ssoAccountId: { type: String, default: '' },
    ssoConversationId: { type: String, default: '' },
    email: { type: String, default: '' },
    authError: { type: String, default: '' },
  },
  setup() {
    return {
      v$: useVuelidate(),
    };
  },
  data() {
    return {
      // We need to initialize the component with any
      // properties that will be used in it
      credentials: {
        email: '',
        password: '',
      },
      loginApi: {
        message: '',
        showLoading: false,
        hasErrored: false,
      },
      error: '',
      mfaRequired: false,
      mfaToken: null,
      sessionsLimitReached: false,
      limitedSessions: [],
      raevoLoginLogo: RAEVO_LOGIN_LOGO,
    };
  },
  validations() {
    return {
      credentials: {
        password: {
          required,
        },
        email: {
          required,
          email,
        },
      },
    };
  },
  computed: {
    ...mapGetters({ globalConfig: 'globalConfig/get' }),
    allowedLoginMethods() {
      return window.chatwootConfig.allowedLoginMethods || ['email'];
    },
    showGoogleOAuth() {
      return (
        this.allowedLoginMethods.includes('google_oauth') &&
        Boolean(window.chatwootConfig.googleOAuthClientId)
      );
    },
    showSignupLink() {
      return window.chatwootConfig.signupEnabled === 'true';
    },
    showSamlLogin() {
      return this.allowedLoginMethods.includes('saml');
    },
  },
  created() {
    if (this.ssoAuthToken) {
      this.submitLogin();
    }
    if (this.authError) {
      const messageKey = ERROR_MESSAGES[this.authError] ?? 'LOGIN.API.UNAUTH';
      // Use a method to get the translated text to avoid dynamic key warning
      const translatedMessage = this.getTranslatedMessage(messageKey);
      useAlert(translatedMessage);
      // wait for idle state
      this.requestIdleCallbackPolyfill(() => {
        // Remove the error query param from the url
        const { query } = this.$route;
        this.$router.replace({ query: { ...query, error: undefined } });
      });
    }
  },
  methods: {
    getTranslatedMessage(key) {
      // Avoid dynamic key warning by handling each case explicitly
      switch (key) {
        case 'LOGIN.OAUTH.NO_ACCOUNT_FOUND':
          return this.$t('LOGIN.OAUTH.NO_ACCOUNT_FOUND');
        case 'LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY':
          return this.$t('LOGIN.OAUTH.BUSINESS_ACCOUNTS_ONLY');
        case 'LOGIN.API.UNAUTH':
        default:
          return this.$t('LOGIN.API.UNAUTH');
      }
    },
    // TODO: Remove this when Safari gets wider support
    // Ref: https://caniuse.com/requestidlecallback
    //
    requestIdleCallbackPolyfill(callback) {
      if (window.requestIdleCallback) {
        window.requestIdleCallback(callback);
      } else {
        // Fallback for safari
        // Using a delay of 0 allows the callback to be executed asynchronously
        // in the next available event loop iteration, similar to requestIdleCallback
        setTimeout(callback, 0);
      }
    },
    showAlertMessage(message) {
      // Reset loading, current selected agent
      this.loginApi.showLoading = false;
      this.loginApi.message = message;
      useAlert(this.loginApi.message);
    },
    handleImpersonation() {
      // Detects impersonation mode via URL and sets a session flag to prevent user settings changes during impersonation.
      const urlParams = new URLSearchParams(window.location.search);
      const impersonation = urlParams.get(IMPERSONATION_URL_SEARCH_KEY);
      if (impersonation) {
        SessionStorage.set(SESSION_STORAGE_KEYS.IMPERSONATION_USER, true);
      }
    },
    submitLogin() {
      this.loginApi.hasErrored = false;
      this.loginApi.showLoading = true;

      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
      };

      login(credentials)
        .then(result => {
          // Check if MFA is required
          if (result?.mfaRequired) {
            this.loginApi.showLoading = false;
            this.mfaRequired = true;
            this.mfaToken = result.mfaToken;
            return;
          }

          // Check if sessions limit reached
          if (result?.sessionsLimitReached) {
            this.loginApi.showLoading = false;
            this.sessionsLimitReached = true;
            this.limitedSessions = result.sessions;
            AnalyticsHelper.track(SESSION_EVENTS.LIMIT_HIT);
            return;
          }

          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          if (response?.errorCode === USER_NOT_CONFIRMED_ERROR_CODE) {
            this.loginApi.showLoading = false;
            this.$router.push({
              name: 'auth_verify_email',
              state: { email: credentials.email },
            });
            return;
          }

          // Reset URL Params if the authentication is invalid
          if (this.email) {
            window.location = '/app/login';
          }
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    submitFormLogin() {
      if (this.v$.credentials.email.$invalid && !this.email) {
        this.showAlertMessage(this.$t('LOGIN.EMAIL.ERROR'));
        return;
      }

      this.submitLogin();
    },
    handleMfaVerified() {
      // MFA verification successful, continue with login
      this.handleImpersonation();
      window.location = '/app';
    },
    handleMfaCancel() {
      // User cancelled MFA, reset state
      this.mfaRequired = false;
      this.mfaToken = null;
      this.credentials.password = '';
    },
    retryLoginWithParams(extraParams) {
      const credentials = {
        email: this.email
          ? decodeURIComponent(this.email)
          : this.credentials.email,
        password: this.credentials.password,
        sso_auth_token: this.ssoAuthToken,
        ssoAccountId: this.ssoAccountId,
        ssoConversationId: this.ssoConversationId,
        ...extraParams,
      };

      this.sessionsLimitReached = false;
      this.limitedSessions = [];
      this.loginApi.showLoading = true;
      login(credentials)
        .then(result => {
          if (result?.sessionsLimitReached) {
            this.loginApi.showLoading = false;
            this.sessionsLimitReached = true;
            this.limitedSessions = result.sessions;
            AnalyticsHelper.track(SESSION_EVENTS.LIMIT_HIT);
            return;
          }
          this.handleImpersonation();
          this.showAlertMessage(this.$t('LOGIN.API.SUCCESS_MESSAGE'));
        })
        .catch(response => {
          this.loginApi.hasErrored = true;
          this.showAlertMessage(
            response?.message || this.$t('LOGIN.API.UNAUTH')
          );
        });
    },
    handleSessionRevoke(sessionId) {
      this.retryLoginWithParams({ revoke_session_id: sessionId });
    },
    handleSessionRevokeAll() {
      this.retryLoginWithParams({ revoke_all_sessions: true });
    },
    handleSessionLimitCancel() {
      this.sessionsLimitReached = false;
      this.limitedSessions = [];
      this.credentials.password = '';
    },
  },
};
</script>

<template>
  <main
    class="flex min-h-screen w-full items-center bg-[#1F1F1F] px-4 py-8 font-inter sm:px-6 lg:px-8"
  >
    <div
      class="mx-auto grid w-full max-w-6xl overflow-hidden border border-[#C7A97A]/60 bg-[#1F1F1F] shadow-[0_24px_56px_rgba(0,0,0,0.32)] lg:grid-cols-[minmax(0,1fr)_26.25rem]"
    >
      <section
        class="flex min-h-[34rem] flex-col items-center justify-center border-b border-white/20 px-8 py-12 text-center lg:border-b-0 lg:border-r lg:border-[#C7A97A]/50 lg:px-16"
      >
        <img
          :src="raevoLoginLogo"
          alt="RAEVO CRM"
          class="mb-12 h-auto w-full max-w-[320px]"
        />
        <h1
          class="max-w-md font-interDisplay text-3xl font-semibold leading-tight text-[#E9E4DA] sm:text-4xl"
        >
          {{ $t('LOGIN.RAEVO.VISION') }}
          <span class="block text-[#C7A97A]">{{
            $t('LOGIN.RAEVO.SYSTEMS')
          }}</span>
        </h1>
        <div class="my-7 h-px w-20 bg-[#C7A97A]" aria-hidden="true" />
        <p class="max-w-sm text-sm leading-6 text-[#DCCFBE]">
          {{ $t('LOGIN.RAEVO.SUBTITLE') }}
        </p>
      </section>

      <section class="flex items-center bg-white px-6 py-10 sm:px-10">
        <div
          class="w-full [&_input]:!bg-white [&_input]:!outline-[#B8AB98] [&_input:focus]:!outline-[#00B8C6] [&_input:focus]:!ring-[#00B8C6]"
        >
          <p
            class="mb-8 text-center font-interDisplay text-xl font-semibold text-[#1F1F1F]"
          >
            {{ $t('LOGIN.RAEVO.ACCESS') }}
          </p>
          <p
            v-if="showSignupLink"
            class="mb-7 text-center text-sm text-n-slate-11"
          >
            {{ $t('COMMON.OR') }}
            <router-link
              to="auth/signup"
              class="lowercase font-medium text-[#1F1F1F] underline decoration-[#C7A97A] decoration-2 underline-offset-4 hover:text-[#00B8C6]"
            >
              {{ $t('LOGIN.CREATE_NEW_ACCOUNT') }}
            </router-link>
          </p>

          <!-- Session Limit Section -->
          <SessionLimitOverlay
            v-if="sessionsLimitReached"
            :sessions="limitedSessions"
            @revoke="handleSessionRevoke"
            @revoke-all="handleSessionRevokeAll"
            @cancel="handleSessionLimitCancel"
          />

          <!-- MFA Verification Section -->
          <MfaVerification
            v-else-if="mfaRequired"
            :mfa-token="mfaToken"
            @verified="handleMfaVerified"
            @cancel="handleMfaCancel"
          />

          <!-- Regular Login Section -->
          <div v-else :class="{ 'animate-wiggle': loginApi.hasErrored }">
            <div v-if="!email">
              <div class="flex flex-col gap-4">
                <GoogleOAuthButton v-if="showGoogleOAuth" />
                <div v-if="showSamlLogin" class="text-center">
                  <router-link
                    to="/app/login/sso"
                    class="inline-flex w-full items-center justify-center rounded-md bg-[#E9E4DA] px-4 py-3 shadow-sm ring-1 ring-inset ring-[#B8AB98] hover:bg-[#DCCFBE] focus:outline-offset-0"
                  >
                    <Icon
                      icon="i-lucide-lock-keyhole"
                      class="size-5 text-n-slate-11"
                    />
                    <span class="ml-2 text-base font-medium text-[#1F1F1F]">
                      {{ $t('LOGIN.SAML.LABEL') }}
                    </span>
                  </router-link>
                </div>
                <SimpleDivider
                  v-if="showGoogleOAuth || showSamlLogin"
                  :label="$t('COMMON.OR')"
                  class="uppercase"
                />
              </div>
              <form class="space-y-5" @submit.prevent="submitFormLogin">
                <FormInput
                  v-model="credentials.email"
                  name="email_address"
                  type="text"
                  data-testid="email_input"
                  :tabindex="1"
                  required
                  :label="$t('LOGIN.EMAIL.LABEL')"
                  :placeholder="$t('LOGIN.EMAIL.PLACEHOLDER')"
                  :has-error="v$.credentials.email.$error"
                  @input="v$.credentials.email.$touch"
                />
                <FormInput
                  v-model="credentials.password"
                  type="password"
                  name="password"
                  data-testid="password_input"
                  required
                  :tabindex="2"
                  :label="$t('LOGIN.PASSWORD.LABEL')"
                  :placeholder="$t('LOGIN.PASSWORD.PLACEHOLDER')"
                  :has-error="v$.credentials.password.$error"
                  @input="v$.credentials.password.$touch"
                >
                  <p v-if="!globalConfig.disableUserProfileUpdate">
                    <router-link
                      to="auth/reset/password"
                      class="text-sm font-medium text-[#1F1F1F] underline decoration-[#C7A97A] decoration-2 underline-offset-4 hover:text-[#00B8C6]"
                      tabindex="4"
                    >
                      {{ $t('LOGIN.FORGOT_PASSWORD') }}
                    </router-link>
                  </p>
                </FormInput>
                <NextButton
                  lg
                  type="submit"
                  data-testid="submit_button"
                  class="w-full !bg-[#00B8C6] !text-[#1F1F1F] hover:!bg-[#14C5D1] focus-visible:!outline-[#1F1F1F]"
                  :tabindex="3"
                  :label="$t('LOGIN.SUBMIT')"
                  :disabled="loginApi.showLoading"
                  :is-loading="loginApi.showLoading"
                />
              </form>
            </div>
            <div v-else class="flex items-center justify-center">
              <Spinner color-scheme="primary" size="" />
            </div>
          </div>
        </div>
      </section>
    </div>
  </main>
</template>
