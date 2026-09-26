<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# Ash data-layer conformance

A test suite and report generator that checks how well each Ash data layer
does what Ash says it should: which features work, which are unsupported,
which give wrong answers, and who owns each fix.

It runs the same scenarios against every registered data layer (AshPostgres,
AshSqlite, Ash's ETS layer, AshCsv, AshMysql and AshClickhouse today) and
writes the results side by side.

## Why it exists

Ash defines behaviour: what a filter on a nil means, what an aggregate counts
when a policy hides some rows, what a keyset page returns. Each data layer
implements that behaviour on its own. Until now nothing checked the data
layers against Ash's definition, or against each other:

- **Each data layer tests its own queries.** AshPostgres's tests check the SQL
  AshPostgres builds, not whether the answer matches what Ash documents or
  what AshSqlite returns for the same query.
- **Capability claims are not behaviour.** A data layer's `can?/2` says what
  it intends to support. A claim can be wrong in both directions: advertised
  and broken, or unadvertised and silently giving wrong answers.
- **Users cannot see what works.** Choosing a data layer, or finding out why a
  query behaves differently after switching, means reading source code.
- **Work on shared code flies blind.** A change to AshSQL can fix SQLite and
  break Postgres, and nothing says so until a user notices.

This suite gives every behaviour one intended answer, taken from Ash's
documentation or source, and records exactly what each data layer does
instead.

## What it tells you

- **[ECOSYSTEM.md](ECOSYSTEM.md)**: every data layer, a column each. It
  opens with a summary by tier, then the storage grid (which Ash types each
  can store and read back unchanged), the operations grid (which filters,
  sorts and aggregates work on each type), the policy grid (every policy
  shape on every read and write path) and the combination grid (features
  alone and in pairs), then every feature from basic reads up to
  multitenancy and authorization, then the blockers to fix first.
- **[FEATURES.md](FEATURES.md)**: the same features for the reviewed data
  layers, from their recorded contracts, with a gap link for everything that
  is not fully working.
- **[GAPS.md](GAPS.md)**: every known gap, with what goes wrong, the
  evidence, and who owns the fix (Ash, AshSQL or a data layer), in the order
  the work is needed.
- **`surveys/features-<data layer>.md`**: one data layer in detail, with
  each failing scenario, the column type behind each storage cell, and the
  full policy table.

Statuses are strict about what they claim. "Works" means every scenario ran
and returned Ash's answer. A scenario that could not run, because the data
layer could not store its test data, is "unknown", never "broken" or "not
supported".

A failure is labelled "blocked" when a prerequisite also fails. The
prerequisite is either a control that runs the same path without the
feature under test, or the storage of a type the scenario needs.
`ECOSYSTEM.md` ranks these blockers, so you can see which one fix unblocks
the most scenarios. For example, AshCsv cannot read a boolean back. That
stops 247 scenarios from running, and for 189 of them it is the only
cause.

## How it decides

- **One intended answer per scenario.** Scenarios call Ash's public API and
  compare the result with an answer from Ash's documentation or source. No
  data layer is the oracle: when every data layer agrees on a wrong answer,
  the scenario still fails.
- **Strict comparison.** `2` and `2.0` differ. Every scenario runs three
  times, with its rows stored forwards, backwards and rotated, and the runs
  must agree, so an answer that depends on storage order cannot pass.
- **Tiers keep failures local.** Each Ash type is stored in its own table,
  so a type a data layer cannot store fails only that type. Each filter,
  sort and aggregate then runs on every type it applies to, with integers as
  the control, so a type is only blamed when the operation works on
  integers. Each policy path also runs without authorization, so a policy is
  only blamed when the path itself works. The combination grid runs each
  feature alone before combining features in pairs, so a combination is
  only blamed when each part works. It runs on SQLite and Postgres for now,
  to keep the six-data-layer run short.
- **Reviewed and surveyed data layers.** Reviewed data layers (SQLite and
  Postgres) have an expectation record for every scenario, and `mix test`
  fails when a result changes, including when a known defect is fixed.
  Surveyed data layers are classified automatically (works, rejected, wrong,
  crashed, unknown) and marked as unreviewed.
- **Gaps are pinned.** A known defect records the exact wrong answer or
  error, not just "fails". A different wrong answer is a new failure.

## Quick start

Use the versions in `.tool-versions` (Elixir 1.20.0, OTP 29.0.1) through
mise. A plain `mix` on another OTP version fails in confusing ways, for
example a NIF that will not load.

```sh
cd conformance
mise install
mise exec -- mix deps.get --check-locked
mise exec -- mix check        # SQLite and Postgres: compile, format, Credo, every test
```

Postgres 17 must be running on `localhost:5432` (user and password
`postgres`). Override with `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD` and
`CONFORMANCE_PG_DATABASE`, whose name must start with `ash_conformance_`.
SQLite needs nothing: it uses `tmp/data_layer.sqlite3`.

Everyday commands:

```sh
CONFORMANCE_ADAPTERS=sqlite mise exec -- mix test               # one reviewed data layer
mise exec -- mix test --only scenario:policy.owner.read          # one scenario
mise exec -- mix test --only area:policies                       # one area
CONFORMANCE_ADAPTERS=ets MIX_ENV=test mise exec -- mix conformance.probe loaded.count
MIX_ENV=test mise exec -- mix conformance.survey csv             # survey any data layer
```

### Compare every data layer

`mix conformance.ecosystem` surveys every registered data layer and rewrites
`ECOSYSTEM.md` and `surveys/`. MySQL and ClickHouse need servers; CI runs
them as services. Locally, for example:

```sh
docker run -d --name ash-conformance-mysql -e MYSQL_ROOT_PASSWORD=mysql -p 13306:3306 mysql:8.4
docker run -d --name ash-conformance-clickhouse -e CLICKHOUSE_SKIP_USER_SETUP=1 -p 18123:8123 \
  clickhouse/clickhouse-server:25.8
MYSQL_PORT=13306 CLICKHOUSE_URL=http://localhost:18123 MIX_ENV=test mise exec -- mix conformance.ecosystem
```

A data layer whose storage cannot be set up is reported as "not run", with
the reason; the others still run.

### Compare two versions of the stack

`CONFORMANCE_DEPS=upstream` switches AshSQL, AshSqlite and AshPostgres to
ash-project `main` (locked in `mix.upstream.lock`), with their own deps and
build directories. Comparing surveys shows what a branch changes:

```sh
CONFORMANCE_DEPS=upstream MIX_ENV=test mise exec -- mix conformance.survey sqlite
MIX_ENV=test mise exec -- mix conformance.survey sqlite
MIX_ENV=test mise exec -- mix conformance.compare_surveys \
  results/upstream/survey-sqlite.json results/survey-sqlite.json
```

To test a local checkout of a data layer, point at it, for example
`CONFORMANCE_ASH_SQLITE_PATH=../../ash_sqlite`. `CONFORMANCE_ASH_SQL_PATH`,
`CONFORMANCE_ASH_POSTGRES_PATH` and `CONFORMANCE_ASH_MYSQL_PATH` work the
same way. Reports list any such overrides.

### Search for disagreements with generated filters

Written scenarios check the answers someone decided. Generated filters look
for the ones nobody thought to write. StreamData generates random filters
over the expression fixture, and each one, and its negation, is checked
against SQL's three-valued logic, which Ash's expression guide specifies.
Failures are shrunk to a minimal filter:

```sh
MIX_ENV=test mise exec -- mix conformance.fuzz sqlite --runs 500 --rounds 5 --seed 7
MIX_ENV=test mise exec -- mix conformance.fuzz postgres --oracle runtime  # against Ash's evaluator
MIX_ENV=test mise exec -- mix conformance.fuzz ash                        # Ash's evaluator alone
```

A report lists leads, not results. A person decides each answer and turns it
into a written scenario with a gap. `mix test` runs a small, seeded search
on each reviewed data layer, and fails on any disagreement not yet triaged.

### Regenerate the committed reports

```sh
MIX_ENV=test mise exec -- mix conformance.features    # FEATURES.md
MIX_ENV=test mise exec -- mix conformance.gaps        # GAPS.md
MIX_ENV=test mise exec -- mix conformance.matrix      # MATRIX.md
MIX_ENV=test mise exec -- mix conformance.inventory   # COVERAGE.md and CAPABILITIES.md
```

Tests fail when one of these is out of date, and CI fails when
`ECOSYSTEM.md` or `surveys/` differ from a fresh run.

## Add a data layer

A data layer is one folder, `lib/adapters/<name>/`, and one entry in
`config/config.exs`. The adapter supplies its resource configuration block
and storage setup; everything else has defaults. Start it as a surveyed data
layer, read its survey, then add expectation rules and gaps to make it
reviewed. [AUTHORING.md](AUTHORING.md) walks through it, with ETS as the
smallest example.

Expectations are rules:

```elixir
def rules do
  [
    supported("*"),
    expect("policy.*.get_error", unsupported(~r/error expressions/, "error-expressions")),
    expect("storage.decimal.edge", defect_value(..., "decimal-precision"))
  ]
end
```

Each scenario resolves to exactly one record. A rule that matches nothing, or
two rules for one scenario, fails. `supported` is a claim, not an acceptance:
a scenario it covers must still pass.

## What touches your databases

- **Postgres, SQLite and MySQL:** setup creates the database if absent and
  applies the suite's migrations. The tier-1 storage tables (`st_*`) are
  dropped and recreated on every setup, so their column types stay current.
  Each scenario runs in a sandbox transaction that rolls back.
- **ClickHouse:** setup drops and recreates the `ash_conformance_local`
  database, and tables are truncated between scenarios.
- **CSV:** files live in `tmp/csv/` and are deleted between scenarios.

## Layout

Module names follow paths under `lib/`:

| Path | What lives there |
| --- | --- |
| `scenario.ex`, `runner.ex`, `catalog.ex`, `compare.ex` | Declaring scenarios, running them in three seed orders, strict comparison. |
| `scenarios/` | The scenarios, one file per area and `aggregates/` by topic; `storage.ex` and `policies.ex` generate the two grids. |
| `storage.ex`, `operations.ex`, `policy.ex`, `combinations.ex`, `tiers.ex` | Tier 1's types and round trip, tier 2's operations and their answers, the policy and combination grids' reference models, and which tier each scenario belongs to. |
| `resources/`, `fixtures.ex`, `fixtures/` | Shared resource roles each adapter instantiates, and each fixture's rows. |
| `adapter.ex`, `adapters/` | The adapter behaviour, and one folder per data layer: its adapter and, when reviewed, its expectation rules and its own gaps. |
| `contracts/` | The feature catalog, record builders, shared gaps and capability claims. |
| `sql/` | Database setup, migrations, column types, instrumentation and AshSQL's gaps, for the SQL data layers. |
| `probe.ex`, `survey.ex`, `report.ex`, `report/` | Running without expectations, and every report. |
| `benchmark.ex`, `benchmark/` | Separate larger workloads and timing. |

More: [AUTHORING.md](AUTHORING.md) for scenarios and data layers,
[SEMANTICS.md](SEMANTICS.md) for where intended answers come from,
[BENCHMARKS.md](BENCHMARKS.md) for benchmarks, and
[PROVENANCE.md](PROVENANCE.md) for dependency pins.

## Prior art

Django runs one test suite against each database backend, declares
capabilities per backend and lists known failures. Laravel runs one database
integration suite against several connections. This suite borrows both ideas,
and is stricter about failures: every known gap pins the exact wrong result or
error and names who owns the fix, and it keeps advertised support, observed
behaviour, unsupported features, defects and open decisions separate.
