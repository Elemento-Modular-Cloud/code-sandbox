# ⚡ API Load Tester

Simulatore di utenti attivi per testare la tua infrastruttura API.
Ogni utente virtuale ha la propria sessione auth (access + refresh token), esegue scenari randomici con pause realistiche tra le chiamate.

---

## Struttura del progetto

```
load-tester/
├── src/
│   ├── config.ts                    ← ✏️  Configura URL, VU, auth, delay
│   ├── index.ts                     ← Entrypoint CLI
│   ├── auth/
│   │   └── AuthManager.ts           ← Login, refresh, invalidation per utente
│   ├── runner/
│   │   ├── LoadRunner.ts            ← Orchestratore principale
│   │   ├── VirtualUser.ts           ← Ciclo di vita di un utente virtuale
│   │   ├── ApiCaller.ts             ← HTTP helper autenticato
│   │   └── MetricsCollector.ts      ← Raccolta e aggregazione metriche
│   ├── scenarios/
│   │   └── index.ts                 ← ✏️  Definisci qui i tuoi scenari
│   └── utils/
│       ├── reporter.ts              ← Dashboard live + report finale
│       └── autocannonBenchmark.ts   ← Benchmark puro (throughput massimo)
```

---

## Setup

```bash
npm install
```

---

## Configurazione

### 1. `src/config.ts` — parametri base

```ts
export const defaultConfig: LoadTestConfig = {
  baseUrl: "https://api.tuodominio.com",   // ← URL della tua API
  virtualUsers: 10,                         // ← N utenti simultanei
  durationSeconds: 60,                      // ← durata test (0 = infinito)
  minDelayMs: 2000,                         // ← pausa minima tra chiamate
  maxDelayMs: 8000,                         // ← pausa massima tra chiamate

  auth: {
    loginUrl: "/auth/login",
    refreshUrl: "/auth/refresh",

    // Credenziali per ogni utente di test
    credentialsFactory: (userId) => ({
      username: `testuser_${userId}@example.com`,
      password: "password_test",
    }),

    // Adatta in base alla struttura dei token della tua API
    tokenExtractor: (body) => ({
      accessToken: body.access_token,
      refreshToken: body.refresh_token,
      expiresInMs: body.expires_in * 1000,
    }),
  },
};
```

### 2. `src/scenarios/index.ts` — scenari di test

Ogni scenario ha:
- `name` — usato nei report
- `weight` — probabilità relativa di essere scelto
- `run(userId, call)` — la logica della chiamata

```ts
{
  name: "scaleway | kaas | GET /{service}/running",
  weight: 1,
  maxCalls: -1,
  run: async (_userId, call) => {
    await call
      .forMeson("scaleway")
      .get(`/api/v1.0/kaas/running`);
  },
},
{
  name: "azure | kaas | GET /{service}/running",
  weight: 3,
  maxCalls: -1,
  run: async (_userId, call) => {
    await call
      .forMeson("azure")
      .get(`/api/v1.0/kaas/running`);
  },
},
```

L'helper `call` espone: `.get()` `.post()` `.put()` `.patch()` `.delete()`  
Il token viene iniettato automaticamente. Retry e refresh sono gestiti in automatico.

---

## Utilizzo

### Test comportamentale (modalità principale)

```bash
# Usa la config di default
npm run load

# Override da CLI
npx ts-node src/index.ts --users 50 --duration 120

# Con log verbosi per ogni chiamata
npx ts-node src/index.ts --users 10 --duration 60 --verbose

# Tutti gli override disponibili
npx ts-node src/index.ts \
  --users 100          \   # utenti virtuali
  --duration 300       \   # secondi
  --min-delay 1000     \   # ms tra le chiamate
  --max-delay 5000     \   # ms tra le chiamate
  --url https://api.example.com \
  --verbose
```

### Benchmark puro con autocannon

Misura il throughput massimo su un endpoint specifico (senza logica sessione).  
Utile per trovare il breaking point o validare ottimizzazioni.

```bash
npm run benchmark

# Con override
npx ts-node src/index.ts --benchmark --users 100 --duration 30
```

Configura l'endpoint nel file `src/utils/autocannonBenchmark.ts` → funzione `main()`.

---

## Output

### Live dashboard (aggiornata ogni 3 secondi)
```
⚡ API Load Tester — Live Stats

  ██████████████░░░░░░░░░░░░░░░░  23s / 60s  (38%)

  👥 Users:       10
  📨 Requests:    847  (14.1 req/s)
  ✅ Success:     841  (99%)
  ❌ Errors:      6
  ⏱  Latency:    avg 312ms  p95 890ms  p99 1240ms

  Scenari:
    ✓ GET /items                      412 reqs  avg 210ms  p95 540ms
    ✓ GET /items/:id                  198 reqs  avg 198ms  p95 420ms
    ✓ POST /items                      95 reqs  avg 580ms  p95 1200ms
    ⚠ Flusso: crea e recupera         142 reqs  avg 890ms  p95 1800ms
```

### Report finale
Stampato a terminale + salvato come `load-test-report-<timestamp>.json`

---

## Architettura auth

```
VirtualUser (userId) 
    │
    ▼
ApiCaller.callWithAuth()
    │
    ▼
AuthManager.getValidToken(userId)
    ├── Token valido → usa direttamente
    ├── Token in scadenza (<60s) → refresh automatico
    ├── Refresh in corso → aspetta (no race condition)
    └── 401 inaspettato → invalida + ri-login
```

Ogni utente virtuale ha token **indipendenti**. Il refresh è deduplicato per utente (se due chiamate concurrent dello stesso utente trovano il token scaduto, viene fatto un solo refresh).

---

## Quando usare behavioral test vs autocannon

| | Behavioral test | Autocannon |
|---|---|---|
| **Scopo** | Simula utenti reali | Misura throughput massimo |
| **Auth** | Sessione per utente, refresh automatico | Token statico |
| **Delay** | Sì (2-8s tra chiamate) | No (massima velocità) |
| **Scenari** | Randomici con pesi | Endpoint singolo |
| **Output** | Report per scenario | Latency percentili, req/s |
| **Usa quando** | Vuoi simulare traffico realistico | Vuoi trovare il limite dell'API |
