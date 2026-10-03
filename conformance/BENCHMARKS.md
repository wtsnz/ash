<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# Benchmark methodology

Read when running or comparing performance workloads.

```sh
MIX_ENV=test mise exec -- mix conformance.bench
CONFORMANCE_ADAPTERS=sqlite MIX_ENV=test mise exec -- mix conformance.bench
CONFORMANCE_ADAPTERS=postgres MIX_ENV=test mise exec -- mix conformance.bench --profile large
MIX_ENV=test mise exec -- mix conformance.bench --parents 200 --children 20 \
  --selected 10 --tenants 4 --tenant-size 1000 --skew 500 --unrelated 20000 \
  --samples 100 --warmup 10 --output results/experiment
MIX_ENV=test mise exec -- mix conformance.bench_compare \
  results/baseline/sqlite.json results/experiment/sqlite.json
```

The smoke profile has 20 parents, 4 children per parent, 5 selected parents,
2 tenants with 10 parents each, no skew, 10 samples and 3 warm-ups. The large
profile has 1000 parents, 50 children per parent, 20 selected parents, 5 tenants
with 2000 parents each, 5000 extra children on the first parent, and 100 samples.
Both are deterministic; no random generator or seed is used. Every dimension
can vary independently. Selected parents must leave at least one unselected
parent for the selectivity experiment. Children per parent must be positive.

The six workloads are loaded counts/sums, ordered first/list, aggregate filtering
and sorting, many-to-many aggregates, combined root aggregates, and tenant-scoped
loaded aggregates. Each builds expected answers by scanning literal fixture maps.
The selectivity experiment repeats the loaded count/sum workload with 100 extra
unrelated children in smoke, or 100,000 in large, attached to the final unselected
parent. Selected parents and their data remain identical. Compare its median and
query metrics to the zero-unrelated-row case; no growth threshold is imposed.

Before timing, the operation must match its oracle. Then warm-up calls run.
Each timed sample covers only the public Ash operation through returned decoded
resources/results. Projection and validation run after the timer stops. A wrong
answer aborts the workload and no successful timing report is published for it.
Database creation, migrations, fixture creation and correctness assertions are
outside timing. Larger fixture insertion uses each adapter's persistence hook.

Runs are warm, single-client, and execute inside a sandbox transaction per
dataset for deterministic rollback. This measures reads inside that transaction,
not connection establishment, transaction start/commit, or a production pool under
contention. PostgreSQL network latency and SQLite embedded execution are materially
different. Compare adapters primarily with their own baseline.

JSON includes raw end-to-end microsecond samples, sample count, min/median/max,
p95 only with at least 100 samples, and p99 only with at least 1000. These are
sample quantiles, not confidence bounds. Smoke runs make no tail-latency claim.
Results also include dataset parameters, warm-up count, runtime, OS/CPU/RAM,
scheduler count, dependency revisions, Ash commit and database version/settings.
Set `BENCHMARK_MACHINE` to a stable machine label when preserving baselines.

Telemetry is attached only for a separate untimed operation after latency
sampling. It captures query count and summed Ecto driver `query_time`. That time
includes driver/network waiting and is not exclusive database server CPU. It is
not presented as the database-time distribution of the primary samples.
Query plans and expensive profiling are not captured by this initial runner.
Capture them separately with adapter tools; do not mix instrumented timings with
these baselines. Adapters without instrumentation explicitly report it unavailable.

Comparison rejects different workloads, datasets, warm-ups/sample counts,
adapters, runtime/hardware/database configuration or adapter dependency revisions.
Ash source/version may differ because that is what the comparison can measure.
No percentage is calculated across incompatible runs. The result is descriptive,
not a regression verdict. It does not account for OS load, thermal state or noise.
Use stable hardware, close unrelated workloads, repeat runs in alternating order,
and retain the raw samples before deciding on future thresholds.

The CI workflow offers a manually triggered benchmark smoke step. It validates
execution and artifacts, not stable performance. Large profiles never run in normal
tests. Machine-specific generated reports stay in ignored `results/`; CI uploads
them as artifacts.
