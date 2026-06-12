// ============================================================
//  config.ts — Centralizza tutti i parametri del load tester
// ============================================================

export interface LoadTestConfig {
  /**
   * URL base di default (usato da auth e come fallback se uno
   * scenario non specifica un servizio).
   */
  baseUrl: string;

  /**
   * Mappa dei servizi disponibili: ogni chiave è un nome logico
   * e il valore è il suo URL base completo (host + porta).
   * Gli scenari vi accedono tramite call.forMeson("nome").
   */
  mesons: Record<string, string>;

  /** Numero di utenti virtuali da simulare in parallelo */
  virtualUsers: number;

  /** Durata totale del test in secondi (0 = indefinito) */
  durationSeconds: number;

  /** Pausa minima tra una chiamata e l'altra per utente (ms) */
  minDelayMs: number;

  /** Pausa massima tra una chiamata e l'altra per utente (ms) */
  maxDelayMs: number;

  /** Timeout per ogni singola richiesta HTTP (ms) */
  requestTimeoutMs: number;

  /** Quante volte ritentare se una chiamata fallisce */
  maxRetries: number;

  /** Abilita log verbosi per ogni chiamata */
  verbose: boolean;

  auth: AuthConfig;
}

export interface AuthConfig {
  /** Endpoint per ottenere un nuovo access_token */
  loginUrl: string;

  /** Endpoint per rinnovare l'access_token via refresh_token */
  refreshUrl: string;

  /**
   * Factory che restituisce le credenziali per l'utente N.
   * Personalizza qui la logica di generazione utenti di test.
   */
  credentialsFactory: (userId: number) => Record<string, unknown>;

  /**
   * Estrae i token dalla risposta di login/refresh.
   * Adatta in base alla struttura della tua API.
   */
  tokenExtractor: (responseBody: unknown) => {
    accessToken: string;
    refreshToken?: string;
    expiresInMs?: number;
  };

  /**
   * Inietta il token nelle headers della request.
   * Default: Authorization: Bearer <token>
   */
  tokenInjector?: (
    headers: Record<string, string>,
    accessToken: string
  ) => Record<string, string>;
}

// ============================================================
//  DEFAULT CONFIG 
// ============================================================
export const defaultConfig: LoadTestConfig = {
  // URL base di default (usato per auth e come fallback)
  baseUrl: "https://beta.portal.elemento.cloud:9999/api/v2",

  // URL meson usati negli scenari tramite call.forMeson("nome")
  mesons: {
    impossiblecloud: "https://impossiblecloud.dev.meson.elemento.cloud:7770",   // cloud provider
    wasabi: "https://wasabi.dev.meson.elemento.cloud:7770",                     // cloud provider
    azure: "https://azure.dev.meson.elemento.cloud:7770",                       // cloud provider
    upcloud: "https://upcloud.dev.meson.elemento.cloud:7770",                   // cloud provider
    scaleway: "https://scaleway.dev.meson.elemento.cloud:7770",                 // cloud provider
    google: "https://google.dev.meson.elemento.cloud:7770",                     // cloud provider
    oracle: "https://oracle.dev.meson.elemento.cloud:7770",                     // cloud provider
    ovh: "https://ovh.dev.meson.elemento.cloud:7770",                           // cloud provider
  },

  virtualUsers: 10,
  durationSeconds: 60,

  minDelayMs: 5000,   // 5 secondi
  maxDelayMs: 10000,   // 10 secondi

  requestTimeoutMs: 10_000,
  maxRetries: 2,
  verbose: false,

  auth: {
    loginUrl: "/auth/userpass",
    refreshUrl: "/auth/refresh",

    // Genera credenziali per ogni utente virtuale
    credentialsFactory: (userId: number) => ({
      username: `your elemento username`,
      password: "your elemento password",
    }),

    // Estrae i token dalla risposta — adatta alla tua API
    tokenExtractor: (body: unknown) => {
      const b = body as Record<string, unknown>;
      return {
        accessToken: b["access_token"] as string,
        refreshToken: b["refresh_token"] as string,
        expiresInMs: b["expires_in"] != null ? (b["expires_in"] as number) * 1000 : 900_000,
      };
    },

    // Bearer token standard
    tokenInjector: (headers, accessToken) => ({
      ...headers,
      Authorization: `Bearer ${accessToken}`,
    }),
  },
};