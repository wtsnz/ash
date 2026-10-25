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
- **correct**: with only the rows the actor may see stored, the answer is the
  right one, worked out from the fixture. A failure here can't be blamed on
  other tenants or hidden rows: it's a plain wrong answer or an exception.
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

A full run takes about 6 seconds after compiling: 2,253 checks.

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
- `Ash.Invariants.Ops`: 106 operations, each returning a plain term:
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
  - sorts the application writes on an admin-only calculation and on an
    attribute that isn't public, in a query and built into a read action.
    These may order by the real values, so they skip `noninterference`, but
    the records and cursors a client gets back still may not carry them;
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
the same holds with the data layers' `main` branches. Each entry has a kind,
for what goes wrong. "Caught by" names the checks that fail:

- isolation: the answer changes when other tenants' rows or hidden rows are
  stored too;
- untouched: a write changed a row the actor can't see;
- correct: the answer is wrong even with only the actor's own rows stored;
- noninterference: the answer changes when only values the actor can't see
  change;
- secrets: a value the actor can't see is in the answer;
- agrees: two ways of asking the same question give different answers.

**Reads another tenant's data**

| Issue | Layers | Caught by |
| --- | --- | --- |
| Under schema-based tenancy, a statement planned for one tenant's joined query is reused for the next tenant (the planner cache key misses the join's prefix) | Postgres | correct, isolation, agrees |
| An update of a record that isn't multitenant, referencing an aggregate over a multitenant resource, counts every tenant's rows (single and streaming updates) | SQLite | isolation, agrees |

**Writes another tenant's data**

| Issue | Layers | Caught by |
| --- | --- | --- |
| Streaming bulk updates and destroys given records write another tenant's records | ETS, SQLite, Postgres | correct, untouched, agrees |
| Streaming bulk destroys given records destroy another tenant's records | ETS, Postgres | agrees |
| Bulk destroys given records stream on AshSqlite, and destroy another tenant's records | SQLite | correct, untouched |
| Destroying a changeset built with a tenant destroys a record of another tenant | ETS, SQLite, Postgres | correct, untouched, agrees |
| An upsert on the primary key under attribute multitenancy updates another tenant's record | ETS, SQLite, Postgres | correct, untouched |

**Counts or returns rows a read policy hides**

| Issue | Layers | Caught by |
| --- | --- | --- |
| Aggregates and filter_input over a many_to_many skip the join resource's read policy | ETS, SQLite, Postgres | isolation, agrees |
| Aggregates over a has_many through skip the read policy of the resources in its path | ETS, Postgres | isolation |
| An exists aggregate over a has_many through skips the read policy of the resources in its path | ETS | isolation |
| An aggregate referenced as a root aggregate's field or in an atomic update counts rows the read policy hides | ETS, SQLite, Postgres | isolation, agrees |
| Atomic bulk results on ETS show an admin-only aggregate, counting rows the read policy hides | ETS | isolation |
| An inline aggregate in client input can turn off authorization | ETS, SQLite, Postgres | isolation, agrees |

**Shows or reveals a field the actor can't see**

| Issue | Layers | Caught by |
| --- | --- | --- |
| Write results show admin-only values in embedded resources, arrays of them and unions | ETS, SQLite, Postgres | correct, secrets, noninterference, agrees |
| Atomic bulk destroy results show admin-only values in embedded resources, arrays and unions | ETS, Postgres | correct, secrets, noninterference |
| Streaming bulk update results on ETS show admin-only values in embedded resources, arrays and unions | ETS | correct, secrets, noninterference |
| A calculation argument given as an expression in client input reads a field the actor can't see | ETS, SQLite, Postgres | correct, noninterference, agrees |
| An inline aggregate's filter in client input reads the parent's fields the actor can't see | Postgres | correct, noninterference |
| A keyset cursor carries the values the application sorted on, including a calculation the actor can't see and an attribute that isn't public | ETS, SQLite, Postgres | secrets |

**Wrong answer, whoever asks**

| Issue | Layers | Caught by |
| --- | --- | --- |
| An exists aggregate over a has_many through isn't correlated with its source record | Postgres | correct, agrees |
| many_to_many loads with a limit or offset return the wrong records | SQLite | correct, agrees |

**Raises instead of answering**

| Issue | Layers | Caught by |
| --- | --- | --- |
| Under schema-based tenancy, has_many through loads raise: they look for a shared destination in the tenant's schema | Postgres | correct, agrees |
| sort_input on an aggregate the actor can't see raises | ETS, SQLite, Postgres | correct, agrees |
| parent/1 in client input raises: in exists (a missing parent binding) and in an inline aggregate's filter | SQLite | correct |
| An atomic update of a record that isn't multitenant, referencing an aggregate over a multitenant resource, raises that the aggregate needs a tenant | ETS | correct |

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
