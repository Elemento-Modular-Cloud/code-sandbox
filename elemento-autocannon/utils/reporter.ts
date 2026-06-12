// ============================================================
//  utils/reporter.ts — Output live e report finale
// ============================================================

import chalk from "chalk";
import type { Report } from "../runner/MetricsCollector";

// ── Live dashboard (aggiornato ogni N secondi) ─────────────

export function printLiveStats(
  metrics: import("../runner/MetricsCollector").MetricsCollector,
  activeUsers: number,
  elapsedMs: number,
  totalDurationMs: number
): void {
  const r = metrics.generateReport();
  const percent =
    totalDurationMs > 0
      ? Math.min(100, Math.round((elapsedMs / totalDurationMs) * 100))
      : null;

  const progressBar = percent !== null ? buildBar(percent) : "";
  const elapsed = formatDuration(elapsedMs);

  console.clear();
  console.log(chalk.bold.cyan("\n  ⚡ API Load Tester — Live Stats\n"));

  if (percent !== null) {
    console.log(
      `  ${progressBar}  ${chalk.yellow(elapsed)} / ${formatDuration(
        totalDurationMs
      )}  (${percent}%)\n`
    );
  } else {
    console.log(`  Elapsed: ${chalk.yellow(elapsed)}\n`);
  }

  console.log(
    `  ${chalk.green("👥 Users:")}       ${chalk.bold(activeUsers)}`
  );
  console.log(
    `  ${chalk.green("📨 Requests:")}    ${chalk.bold(r.totalRequests)}  (${r.requestsPerSecond.toFixed(1)} req/s)`
  );
  console.log(
    `  ${chalk.green("✅ Success:")}     ${chalk.bold(r.successCount)}  ${
      r.totalRequests > 0
        ? chalk.dim(
            `(${Math.round((r.successCount / r.totalRequests) * 100)}%)`
          )
        : ""
    }`
  );
  console.log(
    `  ${chalk.red("❌ Errors:")}      ${chalk.bold(r.errorCount)}`
  );
  console.log(`  ${chalk.green("⏱  Latency:")}     avg ${chalk.bold(r.overallLatency.avg + "ms")}  p95 ${chalk.bold(r.overallLatency.p95 + "ms")}  p99 ${chalk.bold(r.overallLatency.p99 + "ms")}\n`);

  if (Object.keys(r.byScenario).length > 0) {
    console.log(chalk.bold("  Scenari:"));
    for (const s of Object.values(r.byScenario)) {
      const successRate =
        s.count > 0 ? Math.round((s.success / s.count) * 100) : 0;
      const badge =
        successRate === 100
          ? chalk.green("✓")
          : successRate > 80
          ? chalk.yellow("⚠")
          : chalk.red("✗");
      console.log(
        `    ${badge} ${chalk.bold(s.name.padEnd(30))} ${s.count.toString().padStart(5)} reqs  avg ${s.avgLatencyMs}ms  p95 ${s.p95Ms}ms`
      );
    }
  }

  if (Object.keys(r.errorSummary).length > 0) {
    console.log(chalk.bold.red("\n  Errori:"));
    for (const [err, count] of Object.entries(r.errorSummary)) {
      console.log(`    ${chalk.red("•")} ${err}: ${count}x`);
    }
  }

  console.log(chalk.dim("\n  Press Ctrl+C to stop early\n"));
}

// ── Report finale ─────────────────────────────────────────────

export function printFinalReport(report: Report, virtualUsers: number): void {
  console.clear();
  console.log(chalk.bold.cyan("\n  ╔══════════════════════════════════════╗"));
  console.log(chalk.bold.cyan("  ║       REPORT FINALE — LOAD TEST      ║"));
  console.log(chalk.bold.cyan("  ╚══════════════════════════════════════╝\n"));

  console.log(`  Durata:           ${chalk.yellow(formatDuration(report.durationMs))}`);
  console.log(`  Utenti virtuali:  ${chalk.yellow(virtualUsers)}`);
  console.log(`  Totale richieste: ${chalk.yellow(report.totalRequests)}`);
  console.log(`  Throughput:       ${chalk.yellow(report.requestsPerSecond.toFixed(2) + " req/s")}`);

  const successRate =
    report.totalRequests > 0
      ? Math.round((report.successCount / report.totalRequests) * 100)
      : 0;
  const srColor = successRate >= 99 ? chalk.green : successRate >= 95 ? chalk.yellow : chalk.red;

  console.log(`  Success rate:     ${srColor(successRate + "%")}  (${report.successCount}/${report.totalRequests})`);

  console.log(chalk.bold("\n  Latenza (tutte le richieste):"));
  const l = report.overallLatency;
  console.log(`    min  ${chalk.green(l.min + "ms")}    avg  ${chalk.yellow(l.avg + "ms")}    p50  ${chalk.yellow(l.p50 + "ms")}    p95  ${chalk.red(l.p95 + "ms")}    p99  ${chalk.red(l.p99 + "ms")}    max  ${chalk.red(l.max + "ms")}`);

  if (Object.keys(report.byScenario).length > 0) {
    console.log(chalk.bold("\n  Dettaglio per scenario:"));
    console.log(
      chalk.dim(
        "  " +
          "Scenario".padEnd(32) +
          "Reqs".padStart(6) +
          "  OK%".padStart(6) +
          "  avg".padStart(7) +
          "  p95".padStart(7) +
          "  p99".padStart(7)
      )
    );
    console.log(chalk.dim("  " + "─".repeat(65)));

    for (const s of Object.values(report.byScenario).sort(
      (a, b) => b.count - a.count
    )) {
      const rate = s.count > 0 ? Math.round((s.success / s.count) * 100) : 0;
      const rateStr = rate >= 99 ? chalk.green(rate + "%") : rate >= 90 ? chalk.yellow(rate + "%") : chalk.red(rate + "%");

      console.log(
        `  ${s.name.padEnd(32)}${s.count.toString().padStart(6)}  ${rateStr.padStart(6)}  ${(s.avgLatencyMs + "ms").padStart(7)}  ${(s.p95Ms + "ms").padStart(7)}  ${(s.p99Ms + "ms").padStart(7)}`
      );
    }
  }

  if (Object.keys(report.errorSummary).length > 0) {
    console.log(chalk.bold.red("\n  Errori riscontrati:"));
    for (const [err, count] of Object.entries(report.errorSummary).sort(
      ([, a], [, b]) => b - a
    )) {
      console.log(`    ${chalk.red("•")} ${err} — ${count} volte`);
    }
  }

  console.log("\n");
}

// ── Utilities ─────────────────────────────────────────────────

function formatDuration(ms: number): string {
  const s = Math.floor(ms / 1000);
  const m = Math.floor(s / 60);
  const h = Math.floor(m / 60);
  if (h > 0) return `${h}h ${m % 60}m ${s % 60}s`;
  if (m > 0) return `${m}m ${s % 60}s`;
  return `${s}s`;
}

function buildBar(percent: number, width = 30): string {
  const filled = Math.round((percent / 100) * width);
  const bar = "█".repeat(filled) + "░".repeat(width - filled);
  return chalk.cyan(bar);
}
