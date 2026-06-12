// ============================================================
//  runner/VirtualUser.ts — Ciclo di vita di un utente virtuale
// ============================================================

import type { AuthManager } from "../auth/AuthManager";
import type { LoadTestConfig } from "../config";
import type { MetricsCollector } from "./MetricsCollector";
import { createApiCaller } from "./ApiCaller";
import { pickScenario } from "../scenarios";

export interface VirtualUserOptions {
  userId: number;
  auth: AuthManager;
  cfg: LoadTestConfig;
  metrics: MetricsCollector;
  stopSignal: { stopped: boolean };
}

/**
 * Simula un utente attivo: esegue scenari in loop con pause
 * casuali tra una chiamata e l'altra, finché stopSignal.stopped
 * non diventa true o la durata totale è scaduta.
 */
export async function runVirtualUser(opts: VirtualUserOptions): Promise<void> {
  const { userId, auth, cfg, metrics, stopSignal } = opts;
  const caller = createApiCaller(userId, auth, cfg, metrics);

  // Jitter iniziale: gli utenti non partono tutti insieme
  await sleep(randomBetween(0, cfg.minDelayMs));

  while (!stopSignal.stopped) {
    const scenario = pickScenario();
    if (scenario === null) break; // tutti gli scenari hanno esaurito il budget

    const scenarioStart = Date.now();

    try {
      await scenario.run(userId, caller);

      if (cfg.verbose) {
        console.log(
          `  ✓ [User ${userId}] ${scenario.name} (${Date.now() - scenarioStart}ms)`
        );
      }
    } catch (err) {
      if (cfg.verbose) {
        console.error(
          `  ✗ [User ${userId}] ${scenario.name} → ${
            err instanceof Error ? err.message : err
          }`
        );
      }
      // Il fallimento è già registrato in MetricsCollector via ApiCaller
    }

    // Pausa realistica tra le chiamate
    if (!stopSignal.stopped) {
      await sleep(randomBetween(cfg.minDelayMs, cfg.maxDelayMs));
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────

function randomBetween(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
