// ============================================================
//  runner/LoadRunner.ts — Orchestratore principale
//  Spawna N utenti virtuali e gestisce il ciclo di vita
// ============================================================

import chalk from "chalk";
import { AuthManager } from "../auth/AuthManager";
import { MetricsCollector } from "./MetricsCollector";
import { runVirtualUser } from "./VirtualUser";
import { printLiveStats, printFinalReport } from "../utils/reporter";
import type { LoadTestConfig } from "../config";

/** Intervallo di aggiornamento della live dashboard (ms) */
const LIVE_REFRESH_MS = 3000;

export class LoadRunner {
  private metrics = new MetricsCollector();
  private stopSignal = { stopped: false };

  constructor(private readonly cfg: LoadTestConfig) {}

  async run(): Promise<void> {
    const { cfg, metrics, stopSignal } = this;

    console.log(chalk.bold.cyan("\n  ⚡ API Load Tester — Avvio\n"));
    console.log(`  Target:         ${chalk.yellow(cfg.baseUrl)}`);
    console.log(`  Utenti virtuali: ${chalk.yellow(cfg.virtualUsers)}`);
    console.log(
      `  Durata:          ${
        cfg.durationSeconds > 0
          ? chalk.yellow(cfg.durationSeconds + "s")
          : chalk.yellow("indefinita (Ctrl+C per fermare)")
      }`
    );
    console.log(
      `  Delay tra call:  ${chalk.yellow(cfg.minDelayMs + "ms")} – ${chalk.yellow(cfg.maxDelayMs + "ms")}\n`
    );

    // ── Graceful shutdown ──────────────────────────────────────
    const cleanup = () => {
      if (!stopSignal.stopped) {
        stopSignal.stopped = true;
        console.log(chalk.yellow("\n  ⏹ Stop richiesto — attendo completamento chiamate in corso..."));
      }
    };
    process.on("SIGINT", cleanup);
    process.on("SIGTERM", cleanup);

    // ── AuthManager condiviso tra tutti gli utenti ─────────────
    const auth = new AuthManager(cfg.baseUrl, cfg.auth, cfg.requestTimeoutMs);

    // ── Spawn utenti virtuali ──────────────────────────────────
    const startTime = Date.now();

    const userPromises = Array.from(
      { length: cfg.virtualUsers },
      (_, i) =>
        runVirtualUser({
          userId: i + 1,
          auth,
          cfg,
          metrics,
          stopSignal,
        })
    );

    // ── Live dashboard ─────────────────────────────────────────
    const liveInterval = setInterval(() => {
      const elapsedMs = Date.now() - startTime;
      printLiveStats(
        metrics,
        cfg.virtualUsers,
        elapsedMs,
        cfg.durationSeconds * 1000
      );
    }, LIVE_REFRESH_MS);

    // ── Timer durata ───────────────────────────────────────────
    let durationTimer: NodeJS.Timeout | undefined;
    if (cfg.durationSeconds > 0) {
      durationTimer = setTimeout(() => {
        stopSignal.stopped = true;
      }, cfg.durationSeconds * 1000);
    }

    // ── Aspetta completamento ──────────────────────────────────
    await Promise.allSettled(userPromises);

    clearInterval(liveInterval);
    if (durationTimer) clearTimeout(durationTimer);
    process.removeListener("SIGINT", cleanup);
    process.removeListener("SIGTERM", cleanup);

    // ── Report finale ──────────────────────────────────────────
    const report = metrics.generateReport();
    printFinalReport(report, cfg.virtualUsers);

    // Salva anche su file JSON
    const fs = await import("fs/promises");
    const outPath = `./load-test-report-${Date.now()}.json`;
    await fs.writeFile(outPath, JSON.stringify(report, null, 2));
    console.log(chalk.dim(`  Report JSON salvato: ${outPath}\n`));
  }
}
