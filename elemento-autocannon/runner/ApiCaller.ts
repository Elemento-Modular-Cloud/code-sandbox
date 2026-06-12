// ============================================================
//  runner/ApiCaller.ts — Helper HTTP autenticato
//
//  Supporta chiamate su URL base diversi tramite
//  CallOptions.baseUrlOverride oppure tramite il metodo
//  call.forMeson("nome") che risolve l'URL da config.meson.
// ============================================================

import { request, Agent } from "undici";
import type { AuthManager } from "../auth/AuthManager";
import type { LoadTestConfig } from "../config";
import type { MetricsCollector } from "./MetricsCollector";

export interface CallOptions {
  body?: unknown;
  params?: Record<string, string | number | boolean>;
  extraHeaders?: Record<string, string>;
  /**
   * Sovrascrive il baseUrl per questa singola chiamata.
   * Usato internamente da forMeson() — preferisci quello.
   */
  baseUrlOverride?: string;
}

// ── Caller base (metodi HTTP) ──────────────────────────────

export interface HttpCaller {
  get(path: string, opts?: CallOptions): Promise<unknown>;
  post(path: string, opts?: CallOptions): Promise<unknown>;
  put(path: string, opts?: CallOptions): Promise<unknown>;
  patch(path: string, opts?: CallOptions): Promise<unknown>;
  delete(path: string, opts?: CallOptions): Promise<unknown>;
}

// ── ApiCaller esteso con forMeson() ─────────────────────

export interface ApiCaller extends HttpCaller {
  /**
   * Restituisce un caller il cui baseUrl è risolto da
   * config.services[serviceName]. Lancia errore se il
   * servizio non è dichiarato in config.
   *
   * Esempio:
   *   await call.forMeson("wasabi").get("/api/v1.0/running");
   *   await call.forMeson("azure").post("/api/v1.0/info", { body: { volume_id: "..." } });
   */
  forMeson(mesonName: string): HttpCaller;
}

// ── Factory ────────────────────────────────────────────────

export function createApiCaller(
  userId: number,
  auth: AuthManager,
  cfg: LoadTestConfig,
  metrics: MetricsCollector
): ApiCaller {

  // Funzione interna core — accetta un baseUrl esplicito
  async function callWithAuth(
    method: string,
    path: string,
    opts: CallOptions = {},
    retry = 0
  ): Promise<unknown> {
    const tokenState = await auth.getValidToken(userId);
    const tokenInjector =
      cfg.auth.tokenInjector ??
      ((h, t) => ({ ...h, Authorization: `Bearer ${t}` }));

    const base = opts.baseUrlOverride ?? cfg.baseUrl;
    let url = `${base}${path}`;

    // Query string
    if (opts.params && Object.keys(opts.params).length > 0) {
      const qs = new URLSearchParams(
        Object.entries(opts.params).map(([k, v]) => [k, String(v)])
      ).toString();
      url = `${url}?${qs}`;
    }

    const headers = tokenInjector(
      {
        "Content-Type": "application/json",
        Accept: "application/json",
        ...opts.extraHeaders,
      },
      tokenState.accessToken
    );

    const startMs = Date.now();
    let statusCode = 0;

    try {
      const { body, statusCode: sc } = await request(url, {
        method,
        headers,
        body: opts.body ? JSON.stringify(opts.body) : undefined,
        bodyTimeout: cfg.requestTimeoutMs,
        headersTimeout: cfg.requestTimeoutMs,
        dispatcher: new Agent({
          connect: {
            rejectUnauthorized: false
          }
        })
      });

      statusCode = sc;
      const latencyMs = Date.now() - startMs;

      // Token scaduto a sorpresa → invalida e riprova (una volta)
      if (statusCode === 401 && retry < 1) {
        auth.invalidate(userId);
        await body.dump();
        return callWithAuth(method, path, opts, retry + 1);
      }

      const responseBody = await parseBody(body);

      // Usa il nome del servizio nel path loggato per chiarezza
      const serviceLabel = resolveServiceLabel(cfg, base);
      const logPath = `[${serviceLabel}] ${path}`;

      metrics.record({
        userId,
        method,
        path: logPath,
        statusCode,
        latencyMs,
        success: statusCode >= 200 && statusCode < 300,
        error: statusCode >= 400 ? `HTTP ${statusCode}` : undefined,
      });

      if (cfg.verbose) {
        console.log(
          `  [User ${userId}] ${method} ${logPath} → ${statusCode} (${latencyMs}ms)`
        );
      }

      return responseBody;
    } catch (err) {
      const latencyMs = Date.now() - startMs;

      if (retry < cfg.maxRetries) {
        await sleep(500 * (retry + 1));
        return callWithAuth(method, path, opts, retry + 1);
      }

      const serviceLabel = resolveServiceLabel(cfg, base);
      metrics.record({
        userId,
        method,
        path: `[${serviceLabel}] ${path}`,
        statusCode,
        latencyMs,
        success: false,
        error: err instanceof Error ? err.message : String(err),
      });

      throw err;
    }
  }

  // Costruisce un HttpCaller con un baseUrlOverride fisso
  function buildHttpCaller(baseUrlOverride: string): HttpCaller {
    return {
      get:    (path, opts) => callWithAuth("GET",    path, { ...opts, baseUrlOverride }),
      post:   (path, opts) => callWithAuth("POST",   path, { ...opts, baseUrlOverride }),
      put:    (path, opts) => callWithAuth("PUT",    path, { ...opts, baseUrlOverride }),
      patch:  (path, opts) => callWithAuth("PATCH",  path, { ...opts, baseUrlOverride }),
      delete: (path, opts) => callWithAuth("DELETE", path, { ...opts, baseUrlOverride }),
    };
  }

  // ApiCaller pubblico
  const caller: ApiCaller = {
    get:    (path, opts) => callWithAuth("GET",    path, opts),
    post:   (path, opts) => callWithAuth("POST",   path, opts),
    put:    (path, opts) => callWithAuth("PUT",    path, opts),
    patch:  (path, opts) => callWithAuth("PATCH",  path, opts),
    delete: (path, opts) => callWithAuth("DELETE", path, opts),

    forMeson(mesonName: string): HttpCaller {
      const serviceUrl = cfg.mesons[mesonName];
      if (!serviceUrl) {
        throw new Error(
          `Servizio "${mesonName}" non trovato in config.mesons. ` +
          `Disponibili: ${Object.keys(cfg.mesons).join(", ")}`
        );
      }
      return buildHttpCaller(serviceUrl);
    },
  };

  return caller;
}

// ── Helpers ────────────────────────────────────────────────

/** Risolve il nome logico del servizio dall'URL per i log */
function resolveServiceLabel(cfg: LoadTestConfig, baseUrl: string): string {
  for (const [name, url] of Object.entries(cfg.mesons)) {
    if (url === baseUrl) return name;
  }
  return baseUrl; // fallback: mostra l'URL direttamente
}

async function parseBody(
  body: import("undici").Dispatcher.ResponseData["body"]
): Promise<unknown> {
  try {
    return await body.json();
  } catch {
    return null;
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}