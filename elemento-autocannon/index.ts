// ============================================================
//  index.ts — Entrypoint CLI
//
//  Utilizzo:
//    npx ts-node src/index.ts                  # usa defaultConfig
//    npx ts-node src/index.ts --users 50       # 50 utenti virtuali
//    npx ts-node src/index.ts --duration 120   # 2 minuti
//    npx ts-node src/index.ts --users 20 --duration 60 --verbose
// ============================================================

import { LoadRunner } from "./runner/LoadRunner";
import { defaultConfig } from "./config";
import type { LoadTestConfig } from "./config";

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  // ── Parse argomenti CLI ──────────────────────────────────
  const get = (flag: string): string | undefined => {
    const idx = args.indexOf(flag);
    return idx !== -1 ? args[idx + 1] : undefined;
  };

  const has = (flag: string): boolean => args.includes(flag);

  // ── Configurazione finale (default + override CLI) ────────
  const cfg: LoadTestConfig = {
    ...defaultConfig,

    virtualUsers: parseInt(get("--users") ?? String(defaultConfig.virtualUsers), 10),
    durationSeconds: parseInt(get("--duration") ?? String(defaultConfig.durationSeconds), 10),
    verbose: has("--verbose") || defaultConfig.verbose,

    // Override opzionali
    ...(get("--min-delay") && { minDelayMs: parseInt(get("--min-delay")!, 10) }),
    ...(get("--max-delay") && { maxDelayMs: parseInt(get("--max-delay")!, 10) }),
    ...(get("--url") && { baseUrl: get("--url")! }),
  };

  validateConfig(cfg);

  const runner = new LoadRunner(cfg);
  await runner.run();
}

function validateConfig(cfg: LoadTestConfig): void {
  if (cfg.virtualUsers < 1 || cfg.virtualUsers > 10_000) {
    throw new Error("--users deve essere tra 1 e 10.000");
  }
  if (cfg.minDelayMs >= cfg.maxDelayMs) {
    throw new Error("min-delay deve essere < max-delay");
  }
  if (!cfg.baseUrl.startsWith("http")) {
    throw new Error("baseUrl deve iniziare con http:// o https://");
  }
}

main().catch((err) => {
  console.error("Errore fatale:", err);
  process.exit(1);
});
