// ============================================================
//  scenarios/index.ts — Scenari di test per i 3 servizi
//
//  Ogni scenario punta a un servizio specifico tramite
//  call.forMeson("nome"), dove il nome corrisponde alle
//  chiavi di config.meson.
//
//  Per aggiungere uno scenario: copia uno dei blocchi qui
//  sotto, cambia name/weight/run e aggiungilo all'array.
// ============================================================

import type { ApiCaller } from "../runner/ApiCaller";

// ── Tipo scenario ──────────────────────────────────────────

export interface Scenario {
  /** Nome descrittivo (usato nei log e nei report) */
  name: string;

  /**
   * Peso relativo: determina con che probabilità viene scelto.
   * Es: weight 3 viene scelto 3x più spesso di weight 1.
   */
  weight: number;

  /** Numero massimo di volte che lo scenario può essere selezionato in totale (-1 = illimitato). */
  maxCalls: number;

  /** La logica della chiamata. Lancia eccezione se fallisce. */
  run: (userId: number, call: ApiCaller) => Promise<void>;
}

// ============================================================
//  SCENARI OBJECT STORAGE — GET /{service}/running
// ============================================================
const wasabiObjectStorageRunning: Scenario = {
  name: "wasabi | objectstorage | GET /{service}/running",
  weight: 3,
  maxCalls: -1,
  run: async (_userId, call) => {
    await call
      .forMeson("wasabi")
      .get(`/api/v1.0/objectstorage/running`);
  },
};

const azureObjectStorageRunning: Scenario = {
  name: "azure | objectstorage | GET /{service}/running",
  weight: 3,
  maxCalls: -1,
  run: async (_userId, call) => {
    await call
      .forMeson("azure")
      .get(`/api/v1.0/objectstorage/running`);
  },
};

const impossibleCloudObjectStorageRunning: Scenario = {
  name: "impossiblecloud | objectstorage | GET /{service}/running",
  weight: 3,
  maxCalls: -1,
  run: async (_userId, call) => {
    await call
      .forMeson("impossiblecloud")
      .get(`/api/v1.0/objectstorage/running`);
  },
};

const upcloudCloudObjectStorageRunning: Scenario = {
  name: "upcloud | objectstorage | GET /{service}/running",
  weight: 3,
  maxCalls: -1,
  run: async (_userId, call) => {
    await call
      .forMeson("upcloud")
      .get(`/api/v1.0/objectstorage/running`);
  },
};

const scalewayCloudObjectStorageRunning: Scenario = {
  name: "scaleway | objectstorage | GET /{service}/running",
  weight: 3,
  maxCalls: -1,
  run: async (_userId, call) => {
    await call
      .forMeson("scaleway")
      .get(`/api/v1.0/objectstorage/running`);
  },
};

// ============================================================
//  SCENARI KAAS — GET /{service}/running
// ============================================================
const scalewayKaasRunning: Scenario = {
  name: "scaleway | kaas | GET /{service}/running",
  weight: 1,
  maxCalls: -1,
  run: async (_userId, call) => {
    await call
      .forMeson("scaleway")
      .get(`/api/v1.0/kaas/running`);
  },
};

const scalewayKaasCreate: Scenario = {
  name: "scaleway | kaas | GET /{service}/create",
  weight: 1,
  maxCalls: 4,
  run: async (_userId, call) => {
    await call
      .forMeson("scaleway")
      .post(`/api/v1.0/kaas/create`, {
        body: {
          "name": "test-elemento-autocannon",
          "nodepools": [
            {
              "pool_name": "test-pool-1",
              "autoscale": false,
              "max_nodes": 1,
              "min_nodes": 1,
              "shared_storage_gb": 0,
              "specs": {
                "cpu_cores": 2,
                "ram_gb": 4,
                "storage_gb": 32,
                "gpu": 0
              }
            }
          ],
          "nodes_subnet": {
            "dhcp": true,
            "network": "192.170.0.0/22"
          },
          "update_policy": "ALWAYS_UPDATE",
          "kubernetes_version": "1.35.3",
          "controlplane_ha": false,
          "region": "it-mil",
          "billing_frequency": "month"
        }
      }
    );
  },
};

const googleKaasRunning: Scenario = {
  name: "google | kaas | GET /{service}/running",
  weight: 3,
  maxCalls: -1,
  run: async (_userId, call) => {
    await call
      .forMeson("google")
      .get(`/api/v1.0/kaas/running`);
  },
};
// ============================================================
//  EXPORT — array degli scenari attivi
// ============================================================
export const scenarios: Scenario[] = [
  // wasabiObjectStorageRunning,
  azureObjectStorageRunning,
  impossibleCloudObjectStorageRunning,
  // scalewayCloudObjectStorageRunning,
  scalewayKaasRunning,
  scalewayKaasCreate,
  upcloudCloudObjectStorageRunning,
  googleKaasRunning,
];


// Contatore globale delle selezioni per scenario (chiave = name)
const scenarioCallCounts = new Map<string, number>(
  scenarios.map((s) => [s.name, 0])
);

/**
 * Seleziona uno scenario random rispettando i pesi.
 * Gli scenari che hanno raggiunto maxCalls vengono esclusi.
 * Ritorna null se tutti gli scenari hanno esaurito il proprio budget.
 */
export function pickScenario(): Scenario | null {
  const eligible = scenarios.filter((s) => {
    if (s.maxCalls === -1) return true;
    return (scenarioCallCounts.get(s.name) ?? 0) < s.maxCalls;
  });

  if (eligible.length === 0) return null;

  const totalWeight = eligible.reduce((sum, s) => sum + s.weight, 0);
  let rand = Math.random() * totalWeight;

  for (const scenario of eligible) {
    rand -= scenario.weight;
    if (rand <= 0) {
      scenarioCallCounts.set(scenario.name, (scenarioCallCounts.get(scenario.name) ?? 0) + 1);
      return scenario;
    }
  }

  const last = eligible[eligible.length - 1];
  scenarioCallCounts.set(last.name, (scenarioCallCounts.get(last.name) ?? 0) + 1);
  return last;
}