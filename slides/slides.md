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
---

# Testing with HANA Cloud

### Automated, production-like testing for SAP CAP

<div class="pt-8 opacity-80">
World Cup 2026 app · native HANA SQL view · HANA <code>dayname()</code> · vitest · <code>cds bind</code>
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
- ✅ Calculation views
- ✅ `.hdbtable` / functions / procedures
- ✅ HANA-specific SQL
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

# When you NEED a HANA-backed test

Add one whenever the change touches:

- 📊 **Native HANA SQL views** (`.hdbview`) — e.g. window functions like `RANK()`
- 🧱 `.hdbtable`, `.hdbcalculationview`, `.hdbfunction`, `.hdbprocedure`, synonyms
- 🔤 HANA-specific **SQL** and **functions** (`dayname`, regex, spatial, JSON, aggregations)
- 🔗 Entities annotated **`@cds.persistence.exists`**
- 🚀 Anything relying on **HDI deployment** / production persistence

<div class="pt-6 opacity-80">
Rule of thumb: keep fast SQLite unit tests, and gate DB-specific behavior with HANA.
</div>

---
hideInToc: true
---

# Why vitest?

- Modern, fast, ESM & TypeScript out of the box
- Works with `@cap-js/cds-test` (`cds.test()` → `GET/POST/expect/axios`)
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
"test:local": "NODE_ENV=development ... :memory: vitest run",
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