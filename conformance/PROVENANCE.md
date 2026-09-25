<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# Provenance and dependency revisions

Read when updating dependencies or coordinating with adapter repositories.

The starting corpus is `wtsnz/ash_sql`, branch `test/aggregate-conformance`,
commit `0dfab5dbf4d1d5b978ba14d10b9afad60d698820`. Commits `4a4a7e9` to
`4e328e2` on the same branch were ported later: gap owners (`lib/gaps.ex`),
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

| Dependency | Source |
| --- | --- |
| Ash | Parent checkout, initially fork main `bc9884e08`, version 3.33.11 |
| AshSQL | `wtsnz/ash_sql` at `0985b9fdcca0a0919defdf76b0c44115fa8b8340` |
| AshSQLite | `wtsnz/ash_sqlite` at `46a4b869450a2a961ef9af44b5b69da2d5aff29c` |
| AshPostgres | `ash-project/ash_postgres` at `945073e431ec6eb3fbbb831a8ce5b561d8f8cd35` |

At inspection, AshSQL fork PR #3 and AshSQLite upstream PR #232 remained open
at those respective revisions. They contain the unreleased aggregate extraction
and grouped SQLite aggregate integration. The separately stacked from-many and
schema fixes are intentionally excluded. Updating pins requires rerunning every
inherited gap, not accepting observations from a neighboring checkout.

`override: true` on Ash forces every adapter/transitive dependency to the parent
checkout. The AshSQL override forces both adapters to the same unreleased commit
instead of their Hex version constraints. The adapters are pinned Git dependencies;
all transitive versions are in `mix.lock`. CI never reads adjacent worktrees.
For a local adapter experiment, edit the isolated project's dependency to a path
with `override: true`, run the suite, and revert only that intentional dependency
edit before proposing reproducible pins. There are no implicit environment-based
local path substitutions in this project.

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
