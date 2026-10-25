<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# Provenance and dependency revisions

Read when updating dependencies or coordinating with adapter repositories.

The starting corpus is `wtsnz/ash_sql`, branch `test/aggregate-conformance`,
commit `0dfab5dbf4d1d5b978ba14d10b9afad60d698820`. Commits `4a4a7e9` to
`4e328e2` on the same branch were ported later: gap owners (now `lib/contracts/gaps.ex`),
23 scenarios for decimals, dates and times, aggregate-filtered bulk writes,
to-one then to-many paths, calculation dependencies and nested `parent`
references. At the time of porting those five commits existed only in the local
AshSQL worktree; this project carries its own copy. Its `conformance/` directory
contained 146 scenarios, fixtures, resource factories, explicit expectations,
report/comparison tooling and local gap tasks. This project copies that tracked
source, preserving IDs and MIT attribution, and renames the namespace to
`Ash.Conformance`. It does not move or modify the existing suite.

New here: the Ash-owned Mix project; resource/capability inventory; runner setup
boundary and integrity tests; core callback dispatch/fallback tests; attribute
and context-tenancy profiles; actor/context authorization; equivalence and write
checks; benchmark commands; and isolated CI. Two inherited fixture mutations
were moved outside operation capture without changing their datasets.

| Dependency | `release` (default) | `main` (`CONFORMANCE_DEPS=main`) |
| --- | --- | --- |
| Ash | 3.37.0 (Hex) | `ash-project/ash` `main`, `41e179ffa76dab0d24543fecab256b0123bd4c6e` |
| AshSQL | 0.8.3 (Hex) | `ash-project/ash_sql` `main`, `91360948fbab4cb2dbb955f99b9f49125b44b75e` |
| AshSQLite | 0.2.19 (Hex) | `ash-project/ash_sqlite` `main`, `1a51fcb44e3a108908906430aa8b00cba73f9f30` |
| AshPostgres | 2.15.1 (Hex) | `ash-project/ash_postgres` `main`, `7f2d90e79bbcd4c1991bd29d5764920aeaa7dffc` |

The `main` commits are those of 2026-10-24, locked in `mix.main.lock`.

Until 2026-10-24 Ash was the parent checkout (fork main `bc9884e08`, 3.33.11)
and the adapters were pinned Git commits: AshSQL `0ef973c` (ash_sql#264),
AshSQLite `f489778` (ash_sqlite#232) and AshPostgres `945073e`. Before
2026-09-25 AshSQL and AshSQLite were unmerged work on Will's forks
(`wtsnz/ash_sql` `0985b9f`, `wtsnz/ash_sqlite` `46a4b86`), squash-merged
upstream as ash_sql#264 and ash_sqlite#232.

AshSQLite 0.2.19, the latest release, predates ash_sqlite#232: it has no
aggregate support over relationships, and its verifier warns for every such
aggregate the suite defines. SQLite's expectations follow `main`, where that
work is, so the default run fails those SQLite scenarios until AshSQLite
releases it (see ADVERSARIAL.md, "Dependencies").

`override: true` on the four core packages forces every adapter and
transitive dependency to the same Ash and AshSQL. All transitive versions
are in the lock. CI never reads adjacent worktrees. For a local experiment,
set `CONFORMANCE_ASH_PATH`, `CONFORMANCE_ASH_SQL_PATH`,
`CONFORMANCE_ASH_SQLITE_PATH` or `CONFORMANCE_ASH_POSTGRES_PATH` to a
checkout, or `CONFORMANCE_DEPS=main CONFORMANCE_MAIN_DIR=<dir>` for all four.
The dependency then becomes a path with `override: true`. Nothing is
substituted unless a variable is set, CI sets none, and each report lists
any override that was active. Pins change only by editing `mix.exs` and the
lock.

The SQLite repo enables `write_transactions?`. AshSQLite defaults it to false for
existing apps but recommends it, and its installer enables it. With it off,
AshSQLite advertises no transactions and Ash runs actions without one.

No new third-party benchmark or reporting library was added. The migrated suite
already used the maintained adapter stack, ExUnit, Jason, Credo, Dialyxir and
SimpleSat. Timing uses Erlang monotonic timers; query observation uses the existing
Telemetry dependency. The selected pins compile against this Ash checkout and
passed the recorded SQLite/Postgres runs.

The inherited baseline used Ash 3.33.10 and Elixir 1.19. On Elixir 1.20, Postgres
`root.unsorted_first_empty` raises an inner `BadMapError` on nil instead of a
`KeyError` for `:sort`; the failing access remains in the pinned lateral aggregate
implementation. `bounds.root_offset_only` still fails merging nil but the runtime
formats nil on a separate line. Their exact signatures are updated for this
runtime. Neither is promoted or reclassified as supported.

Future migration should first make both suites run the same pinned dependencies
and compare by stable scenario IDs. Adapter repositories can then consume a
versioned Ash suite revision. Do not delete the older project until its owners
agree that the replacement covers their workflows.

## Where the ported files went

The source tree was reorganised by feature level after porting. Scenario IDs
did not change, so results compare across the move.

| AshSQL suite file | Here |
| --- | --- |
| `lib/scenarios/operations.ex` | `lib/scenarios/aggregates/kinds.ex`, `results.ex` and `usage.ex` |
| `lib/scenarios/relationships.ex` | `lib/scenarios/aggregates/paths.ex` |
| `lib/scenarios/filters.ex`, `bounds.ex`, `context.ex` | the same names under `lib/scenarios/aggregates/` |
| `lib/scenarios/values.ex`, `writes.ex`, `helpers.ex` | `lib/scenarios/aggregates/types.ex`, `writes.ex` and `helpers.ex` |
| `lib/expectations.ex`, `lib/gaps.ex` | `lib/contracts/` |
| `lib/resources.ex`, `lib/resource.ex`, `lib/manual.ex` | `lib/resources/aggregate.ex`, `base.ex` and `manual.ex` |
| `lib/fixtures.ex` | `lib/fixtures.ex` and `lib/fixtures/aggregate.ex` |
| `lib/database.ex`, `lib/adapter.ex` | `lib/sql/`, `lib/adapter.ex` and `lib/adapters/` |
| `lib/report.ex`, `lib/report/comparison.ex`, `lib/formatter.ex` | `lib/report.ex` and `lib/report/` |

