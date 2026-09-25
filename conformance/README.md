<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# Ash data-layer conformance

An executable specification of observable Ash behavior. Each scenario has one
semantic answer and explicit adapter expectations. PostgreSQL is a comparison
implementation, not the oracle. A green test suite can include matched defects;
the report separates those from semantic passes.

This independent Mix project uses the parent Ash checkout. Ash's production
dependencies, Hex package and ordinary `mix test` do not acquire either adapter.

## Setup and commands

Use the versions in this directory's `.tool-versions`: Elixir 1.20.0 / OTP 29.0.1.
This is the OTP patch release used to validate the parent's OTP 29 / Elixir 1.20
runtime. PostgreSQL 17 is the tested database profile. SQLite is bundled by the
locked Exqlite dependency.

```sh
cd conformance
mise install
mise exec -- mix deps.get --check-locked
mise exec -- mix check                         # both adapters, runner tests, format, Credo
CONFORMANCE_ADAPTERS=sqlite mise exec -- mix test
CONFORMANCE_ADAPTERS=postgres mise exec -- mix test
mise exec -- mix test --only scenario:tenant.aggregate_offset_page
mise exec -- mix test --only area:authorization
mise exec -- mix test test/runner_test.exs test/contract_test.exs test/benchmark_test.exs
MIX_ENV=test mise exec -- mix conformance.matrix
MIX_ENV=test mise exec -- mix conformance.inventory
CONFORMANCE_ADAPTERS=sqlite MIX_ENV=test mise exec -- mix conformance.probe loaded.count
MIX_ENV=test mise exec -- mix dialyzer
```

Set `CONFORMANCE_ADAPTERS=sqlite` on runner-only commands to avoid starting
Postgres. Unknown adapter names fail. Selecting an adapter controls startup
and execution, not compilation of dependencies.

Postgres defaults to TCP `localhost:5432`, user/password `postgres`, database
`ash_conformance_local`. Override `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD` and
`CONFORMANCE_PG_DATABASE`. The database name must begin with `ash_conformance_`.
Use a different name for concurrent worktrees. Setup creates this dedicated
database if absent and applies only suite migrations. It never drops databases
or truncates tables. Fixtures run inside a sandbox transaction and roll back.
SQLite uses this project's ignored `tmp/data_layer.sqlite3`.

The Postgres context-tenancy profile creates `dc_tenant_a` and `dc_tenant_b`
schemas inside that database. Both contain the same record identities with
different values. SQLite has no obligation to implement PostgreSQL schema
provisioning; its inventory says this profile is not applicable.

## Reports and coverage

`MATRIX.md` is the declared per-scenario contract. Each ID links to its source.
`CAPABILITIES.md` shows resource-specific claims and callback exports.
`COVERAGE.md` is inventory version 1 and explicitly lists planned areas.
`mix conformance.inventory` also writes `results/inventory.json`, containing
Ash.DataLayer's feature typespec, callback groups, optional callback exports,
resource-specific capabilities, supported profiles and scenario contracts.
The typespec is an inventory input, not a complete specification: real call
sites additionally check distinctness, timeout, action selection and other flags.

Tests write `results/sqlite-postgres.json` and `.md`, or names for the selected
adapter. They record intended answers, observed values, exact gap signatures,
capability claims and execution status. Claims include the resource and any
aggregate kind, relationship or expression being probed. No `can?/2` result
skips an operation. A matching declaration alone proves no behavior.

| Contract | Successful check means |
| --- | --- |
| supported | Returned the semantic answer, including an explicitly specified input rejection. |
| unsupported | Rejected this operation with the recorded error class and narrow reason. |
| known_defect | Returned exactly the recorded wrong answer or error. |
| unresolved | Matched a characterization pending the linked semantic decision; never semantic conformance. |
| planned | Has not run. Inventory only, never a passing check. |

A newly correct result in an unsupported/defect case fails until explicitly
promoted to supported. Changed wrong answers and unrelated errors fail too.
Setup and fixture errors are outside operation-error capture. Unresolved
semantics and implementation work have durable entries in [GAPS.md](GAPS.md).

Fallback is reported as `unobserved` in adapter runs. Dedicated tests in
`test/ash/data_layer/dispatch_contract_test.exs` in the parent project record
single and batch callback execution, validate results, and check optional
callback defaults. Those prove specific framework paths, not fallback execution
in every adapter scenario. A negative claim plus a correct result is insufficient.

Compare saved behavior reports by stable scenario ID:

```sh
MIX_ENV=test mise exec -- mix conformance.compare \
  --base results/base.json --current results/sqlite-postgres.json
```

Current and migrated version-1 reports are accepted. This describes observations;
it does not update expectations. Generated reports are ignored and CI uploads
artifacts. The new workflow runs each adapter independently, plus core dispatch
tests. It does not replace adapter regression suites.

## Architecture and ownership

Ash owns the shared semantic answers, inventory and framework dispatch tests.
Adapters own storage provisioning, fixture persistence, custom operations and
instrumentation. Shared scenarios call public Ash read/load/aggregate/write APIs.
They do not inspect Ecto queries, SQL or join strategies.

- `Scenario`, `Catalog`, `Runner`, `Expectations`: small registry and strict contracts.
- `scenarios/`: aggregate corpus and isolation/profile operations.
- `Resources`, `IsolationResources`, fixtures: shared resource roles and literal data.
- `Adapter`, `Database`, custom aggregate/manual implementations: SQL integrations.
- `Capabilities`, `Inventory`, `Report`, `Formatter`: claims, coverage and observations.
- `benchmark/`, `Benchmark`: independent larger fixtures, operations, oracles and timing.

See [AUTHORING.md](AUTHORING.md) for scenarios/adapters, [SEMANTICS.md](SEMANTICS.md)
for normative sources and isolation answers, [BENCHMARKS.md](BENCHMARKS.md) for
methodology, and [PROVENANCE.md](PROVENANCE.md) for migration and dependency pins.

The initial scope covers all inherited aggregate shapes; attribute tenancy;
actor and shared-context authorization; bounded/from-many relationships;
offset/keyset pagination; selection/calculations; and a write lifecycle.
Upsert, bulk/atomic actions, concurrency/locking, query combinations and generated
cases remain planned. Implemented areas are representative, not exhaustive.

## Verified baseline

On the pinned revisions and Ash 3.33.11, the 186 scenario IDs produce these
367 adapter checks. Five schema-profile scenarios run only on Postgres.

| Adapter | Semantic passes | Unsupported contracts | Known defects | Unresolved |
| --- | ---: | ---: | ---: | ---: |
| SQLite | 132 | 36 | 9 | 4 |
| PostgreSQL | 156 | 0 | 26 | 4 |

The project runs 406 tests with both adapters, including runner, contract,
reporting and benchmark-harness checks. The single-adapter commands run 219
SQLite tests and 224 Postgres tests. The core dispatch additions and relevant
Ash tests passed; the full Ash gate passed 4,233 tests and its other checks.
REUSE passed on the staged source after retrying its tool installation.
Both benchmark smoke runs validated seven workload/dataset combinations, ten
samples each. Large benchmarks were not run; smoke timings do not establish
performance regressions. Generated results remain outside the committed source.
