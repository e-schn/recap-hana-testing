---
theme: seriph
title: Testing with HANA Cloud
info: |
  ## Testing CAP Applications with SAP HANA Cloud
  Automated, production-like testing for CAP — with vitest, a native HANA SQL view and a HANA-only function.
class: text-center
transition: slide-left
mdc: true
hideInToc: true
background: '#00192b'
fonts:
  sans: 'Inter'
  mono: 'JetBrains Mono'
  weights: '400,500,600,700'
---

<div class="flex flex-col items-center justify-center gap-4">

<img src="./assets/logo.png" class="w-60" />

# Testing with HANA Cloud

<div class="text-xl opacity-90">Armin Hatting · Corporate Business Solutions</div>

<img src="./assets/cbs_logo_white_orange.png" class="w-44" />

</div>

<!--
20 minutes: ~5 min intro, ~13 min live demo, ~2 min AI section.
Goal: make "test against real HANA" the default for CAP teams.
-->

---
hideInToc: true
---

# The gap: SQLite vs HANA

<div grid="~ cols-2 gap-4" class="pt-4">

<div class="p-4 rounded border border-gray-400">

### In-memory SQLite

- ⚡ Fast, zero setup
- Great for unit tests
- ✅ Plain entities, CRUD, most logic

</div>

<div class="p-4 rounded border border-teal-500">

### SAP HANA Cloud

- 🎯 Production-like
- ✅ `.hdbtable` / functions / procedures / calculation views
- ✅ HANA-specific SQL and Functions
- ✅ HDI deployment artifacts

</div>

</div>

<div class="pt-6 text-center text-teal-400">
Some behavior <b>only exists on HANA</b>. If you never test there, you never test it.
</div>

<!--
The point: SQLite is a great approximation, but "native HANA logic" is invisible to it.
-->

---
hideInToc: true
---

# Why vitest?

- Modern, fast, ESM & TypeScript out of the box
- Works with `@cap-js/cds-test`
- One small config for HANA:

```ts
// vitest.config.ts
export default defineConfig({
  test: {
    globals: true,
    testTimeout: 120_000,          // HANA round-trips are slower
    pool: 'forks',
    poolOptions: { forks: { singleFork: true } },
  },
});
```

```json
// package.json
"test:sqlite": "CDS_ENV=development cds_requires_db_credentials_url=:memory: vitest run",
"test":       "cds bind --exec --profile test vitest run"
```

<!--
vitest sets NODE_ENV=test → CAP picks the [test] profile → HANA. Nice alignment.
-->

---
layout: center
class: text-center
hideInToc: true
---

# 🎬 Demo

---
hideInToc: true
---

# CI/CD: HANA tests in the pipeline
<br> 

```bash
# 1. Log in
cf api <api-endpoint>
cf auth "$CF_USER" "$CF_PASSWORD"
cf target -o "$CF_ORG" -s "$CF_SPACE"

# 2. Create a dedicated, disposable HANA test container
cf create-service hana hdi-shared <cap-test-instance>

# 3. Bind + deploy the model into that container
cds bind --to <cap-test-instance> --for test
cds deploy --to hana:<cap-test-instance> --profile test --auto-undeploy

# 4. Run the tests against real HANA
cds bind --exec --profile test vitest run

# 5. Clean up (optional)
cf delete-service <cap-test-instance>
```

<!--
Key points: dedicated throwaway container per pipeline run, never production data;
--auto-undeploy keeps it clean; cleanup step runs even on failure (trap/always()).
-->

---
layout: center
class: text-center
hideInToc: true
---

<div class="flex flex-col items-center justify-center gap-10">

<div grid="~ cols-2 gap-10" class="pt-4">

<div class="flex flex-col items-center gap-4">
<img src="./assets/github_qrcode.png" class="w-80 rounded bg-white p-3" />
<div class="text-2xl opacity-90">Code on GitHub</div>
<div class="text-lg opacity-70">github.com/cbs-Group/recap-hana-testing</div>
</div>

<div class="flex flex-col items-center gap-4">
<img src="./assets/feedback_qrcode.png" class="w-80 rounded bg-white p-3" />
<div class="text-2xl opacity-90">Your feedback</div>
</div>

</div>

</div>

---