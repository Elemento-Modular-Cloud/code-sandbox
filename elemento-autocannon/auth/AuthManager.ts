// ============================================================
//  auth/AuthManager.ts — Gestisce login e refresh token
//  per ogni utente virtuale in modo indipendente
// ============================================================

import { request } from "undici";
import type { AuthConfig } from "../config";

export interface TokenState {
  accessToken: string;
  refreshToken?: string;
  expiresAt: number; // timestamp ms
}

export class AuthManager {
  private tokens = new Map<number, TokenState>();
  private inFlight = new Map<number, Promise<TokenState>>();

  constructor(
    private readonly baseUrl: string,
    private readonly cfg: AuthConfig,
    private readonly timeoutMs: number
  ) {}

  /**
   * Restituisce un access_token valido per userId.
   * Esegue login se non ancora autenticato, refresh se scaduto.
   */
  async getValidToken(userId: number): Promise<TokenState> {
    const state = this.tokens.get(userId);

    if (state && !this.isExpiringSoon(state)) {
      return state;
    }

    // Evita race condition: se c'è già un refresh in corso per questo utente, aspetta
    const existing = this.inFlight.get(userId);
    if (existing) return existing;

    const promise = state?.refreshToken
      ? this.refresh(userId, state.refreshToken)
      : this.login(userId);

    this.inFlight.set(userId, promise);

    try {
      const newState = await promise;
      this.tokens.set(userId, newState);
      return newState;
    } finally {
      this.inFlight.delete(userId);
    }
  }

  /**
   * Invalida il token corrente (utile dopo un 401 inaspettato).
   */
  invalidate(userId: number): void {
    this.tokens.delete(userId);
  }

  // ── Internals ─────────────────────────────────────────────

  private async login(userId: number): Promise<TokenState> {
    const credentials = this.cfg.credentialsFactory(userId);

    const { statusCode, body } = await request(
      `${this.baseUrl}${this.cfg.loginUrl}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(credentials),
        bodyTimeout: this.timeoutMs,
        headersTimeout: this.timeoutMs,
      }
    );

    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(
        `[User ${userId}] Login failed with status ${statusCode}`
      );
    }

    const json = await body.json();
    return this.buildState(json);
  }

  private async refresh(
    userId: number,
    refreshToken: string
  ): Promise<TokenState> {
    const { statusCode, body } = await request(
      `${this.baseUrl}${this.cfg.refreshUrl}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: refreshToken }),
        bodyTimeout: this.timeoutMs,
        headersTimeout: this.timeoutMs,
      }
    );

    if (statusCode === 401) {
      // Refresh token scaduto → forza nuovo login
      this.tokens.delete(userId);
      return this.login(userId);
    }

    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(
        `[User ${userId}] Refresh failed with status ${statusCode}`
      );
    }

    const json = await body.json();
    return this.buildState(json);
  }

  private buildState(responseBody: unknown): TokenState {
    const extracted = this.cfg.tokenExtractor(responseBody);
    return {
      accessToken: extracted.accessToken,
      refreshToken: extracted.refreshToken,
      expiresAt: Date.now() + (extracted.expiresInMs ?? 900_000),
    };
  }

  /** Considera il token in scadenza se ha meno di 60 secondi di vita */
  private isExpiringSoon(state: TokenState): boolean {
    return state.expiresAt - Date.now() < 60_000;
  }
}
