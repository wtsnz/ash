<!--
SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>

SPDX-License-Identifier: MIT
-->

# Data-layer invariants

Checks that every data layer keeps tenancy and policies when it answers. They
compare answers instead of pinning them, so most checks need no expected value:

- **isolation**: the answer with every row stored equals the answer with
  only the rows the actor may see. Reads run as organisation 1 then 2, and 2
  then 1, so a statement cached for one tenant shows up in the other's answer.
- **untouched**: after a write, every row the actor may not see is unchanged.
- **expected**: with only the rows the actor may see, the answer is the
  intended one, computed from the fixture.
- **noninterference**: changing only values the actor may not see doesn't
  change the answer. Person 1's admin-only values sort first and person 2's
  last, and the other way round; a filter, sort or cursor that reads them
  answers differently.
- **secrets**: no answer contains a value marked `SECRET`.
- **agrees**: operations that ask the same question in different ways (a
  `many_to_many`, a `has_many through:`, the plain path, an aggregate, a
  filter) give the same answer.

They run against this checkout's Ash, on ETS, AshSqlite and AshPostgres.

## Running

```sh
cd invariants
mix deps.get
mix test                          # every layer; needs PostgreSQL
mix test --only ets               # one layer: ets, sqlite or postgres
INVARIANTS_DEPS=main mix test     # AshSQL, AshSqlite and AshPostgres from their main branches
```

PostgreSQL comes from `PGHOST`, `PGPORT`, `PGUSER` and `PGPASSWORD` (default
`localhost`, `postgres`/`postgres`). The tests drop and recreate the
`ash_invariants` database (`INVARIANTS_PG_DATABASE`) and `tmp/`.

A full run takes about 6 seconds after compiling: 2,178 checks.

## How it works

- `Ash.Invariants.World`: one small fixture. Two organisations' orders join
  shared events to shared customers; one order is hidden by a read policy.
  Notes repeat local ids across organisations. People carry `SECRET` in every
  admin-only value, including an embedded resource, an array of them and a
  union.
- `Ash.Invariants.Resources`: the same resources on each layer. Orders are
  read through three shapes: multitenant by attribute (`tenant`), behind a
  read policy (`secure`) and multitenant by schema (`schema`, ETS and
  Postgres).
- `Ash.Invariants.Ops`: 97 operations, each returning a plain term:
  - loads, aggregates, `exists`, filters and `filter_input` over every path,
    and bounded loads;
  - aggregates referenced in calculations, in client filters and as inline
    aggregates in client input;
  - client filters and sorts on an admin-only field: directly, through a
    calculation argument given as an expression, through `parent/1` in
    `exists` and in an inline aggregate, and sorts on an admin-only
    aggregate;
  - keyset and offset pagination: every page together against the unpaged
    read, keyset pages sorted on an admin-only field, the cursors they
    return, and a cursor a client wrote;
  - bulk writes with every strategy given records from both organisations;
    upserts whose identity or primary key another organisation has;
    `manage_relationship` with another organisation's or a hidden note; and
    writes under field policies.
  Client input may also be refused with `Ash.Error.Invalid` instead of
  answering.
- `Ash.Invariants`: runs each operation in fresh databases (an ETS process of
  its own, or a rolled-back sandbox transaction) and checks the relations.
- `Ash.Invariants.Known`: checks that fail today, with why. A listed check
  must still fail; once it passes, its test fails until the entry is removed.

To add an operation, add it to `Ash.Invariants.Ops` with a group. If it asks
a new question, add the group's intended answer to `Ops.expected/2`.

## What it finds

With this checkout (Ash 3.37.1) and AshSQL 0.8.4, AshSqlite 0.3.0 and
AshPostgres 2.15.2, every entry in `Ash.Invariants.Known` fails as recorded;
the same holds with the data layers' `main` branches. Grouped:

| Layers | What |
| --- | --- |
| all | Aggregates and `filter_input` over a `many_to_many` skip the join resource's read policy (over `through` too, on ETS and Postgres). |
| all | An aggregate used as a root aggregate's field or in an atomic update counts rows the read policy hides. |
| all | Streaming bulk updates and destroys given records write another tenant's records (on SQLite, bulk destroys stream and do too). |
| all | Destroying a changeset built with a tenant destroys another tenant's record. |
| all | Write results show admin-only values in embedded resources, arrays and unions. |
| all | An upsert on the primary key under attribute tenancy updates another tenant's record. |
| Postgres | Under schema tenancy, a statement planned for one tenant's joined query is reused for the next; `through` loads read a shared destination from the tenant's schema. |
| Postgres | An `exists` aggregate over a `through` isn't correlated with its record. |
| ETS, SQLite | An update of a record without tenancy that references an aggregate over a multitenant resource raises (ETS) or counts every tenant's rows (SQLite). |
| SQLite | `many_to_many` loads with a limit or offset return the wrong records. |
| all | A calculation argument given as an expression in `filter_input` or `sort_input` reads a field the actor can't see. |
| all | `sort_input` on an aggregate the actor can't see raises. |
| all | An inline aggregate in client input can turn off authorization; on Postgres its filter can read the parent's hidden fields through `parent/1`. |
| SQLite | `parent/1` in client input raises, in `exists` and in an inline aggregate's filter. |

Against the previous releases (Ash 3.37.0, AshSQL 0.8.3, AshPostgres 2.15.1)
it also fails where those were fixed since: `through` loads of one record
with a limit (GHSA-g2h4-xp57-q863), `many_to_many` and `through` loads across
attribute tenants (GHSA-gr2r-f49c-9gm2), skipped bulk upserts returning
another tenant's record (GHSA-36hg-wwp2-fg8w), `through` paths ending in a
`many_to_many`, and `Ash.create/3` dropping `upsert_condition`.

With the fixes in wtsnz/ash#25, #27 and #28 merged onto this checkout, the
client-input entries pass, and nothing else changes.

## Not covered

- Other data layers, and extensions (AshGraphql, AshJsonApi, AshPhoenix).
- Read actions with arguments, a relationship's own `read_action`,
  calculations with `load/3` dependencies, and resources with UUID primary
  keys.
- Plain `Ash.Query.filter` on related data under a read policy, which Ash
  doesn't authorize by design; those filters only run under tenancy.
