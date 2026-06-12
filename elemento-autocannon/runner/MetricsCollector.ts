// ============================================================
//  runner/MetricsCollector.ts — Raccoglie e aggrega metriche
// ============================================================

export interface RequestRecord {
  userId: number;
  method: string;
  path: string;
  statusCode: number;
  latencyMs: number;
  success: boolean;
  error?: string;
}

export interface ScenarioStat {
  name: string;
  count: number;
  success: number;
  errors: number;
  avgLatencyMs: number;
  p50Ms: number;
  p95Ms: number;
  p99Ms: number;
  minMs: number;
  maxMs: number;
}

export interface Report {
  durationMs: number;
  totalRequests: number;
  successCount: number;
  errorCount: number;
  requestsPerSecond: number;
  overallLatency: {
    avg: number;
    p50: number;
    p95: number;
    p99: number;
    min: number;
    max: number;
  };
  byScenario: Record<string, ScenarioStat>;
  errorSummary: Record<string, number>;
}

export class MetricsCollector {
  private records: RequestRecord[] = [];
  private scenarioLatencies = new Map<string, number[]>();
  private startTime = Date.now();

  record(r: RequestRecord): void {
    this.records.push(r);
  }

  recordScenario(name: string, latencyMs: number): void {
    if (!this.scenarioLatencies.has(name)) {
      this.scenarioLatencies.set(name, []);
    }
    this.scenarioLatencies.get(name)!.push(latencyMs);
  }

  generateReport(): Report {
    const durationMs = Date.now() - this.startTime;
    const total = this.records.length;
    const successes = this.records.filter((r) => r.success);
    const errors = this.records.filter((r) => !r.success);

    const allLatencies = this.records.map((r) => r.latencyMs).sort((a, b) => a - b);

    // Raggruppa per scenario (method + path)
    const byScenario: Record<string, ScenarioStat> = {};
    const groups = new Map<string, RequestRecord[]>();

    for (const r of this.records) {
      const key = `${r.method} ${r.path}`;
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key)!.push(r);
    }

    for (const [name, recs] of groups.entries()) {
      const lats = recs.map((r) => r.latencyMs).sort((a, b) => a - b);
      const ok = recs.filter((r) => r.success).length;
      byScenario[name] = {
        name,
        count: recs.length,
        success: ok,
        errors: recs.length - ok,
        avgLatencyMs: avg(lats),
        p50Ms: percentile(lats, 50),
        p95Ms: percentile(lats, 95),
        p99Ms: percentile(lats, 99),
        minMs: lats[0] ?? 0,
        maxMs: lats[lats.length - 1] ?? 0,
      };
    }

    // Error summary
    const errorSummary: Record<string, number> = {};
    for (const r of errors) {
      const key = r.error ?? "unknown";
      errorSummary[key] = (errorSummary[key] ?? 0) + 1;
    }

    return {
      durationMs,
      totalRequests: total,
      successCount: successes.length,
      errorCount: errors.length,
      requestsPerSecond: total / (durationMs / 1000),
      overallLatency: {
        avg: avg(allLatencies),
        p50: percentile(allLatencies, 50),
        p95: percentile(allLatencies, 95),
        p99: percentile(allLatencies, 99),
        min: allLatencies[0] ?? 0,
        max: allLatencies[allLatencies.length - 1] ?? 0,
      },
      byScenario,
      errorSummary,
    };
  }

  reset(): void {
    this.records = [];
    this.scenarioLatencies.clear();
    this.startTime = Date.now();
  }
}

// ── Statistiche ───────────────────────────────────────────────

function percentile(sorted: number[], p: number): number {
  if (sorted.length === 0) return 0;
  const idx = Math.ceil((p / 100) * sorted.length) - 1;
  return sorted[Math.max(0, idx)];
}

function avg(arr: number[]): number {
  if (arr.length === 0) return 0;
  return Math.round(arr.reduce((s, v) => s + v, 0) / arr.length);
}
