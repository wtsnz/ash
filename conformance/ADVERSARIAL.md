<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# Adversarial invariants

The suite asked "does this data layer give the right answer?". This work adds
"does anything leak?": rows from another tenant, or rows the actor's policies
hide, showing up in an answer or being written. Two parts:

1. a **decoy variant**: every scenario reruns with hidden decoy rows next to
   its fixture, and must give the same answer with no decoy in it;
2. **adversarial scenarios** (`adv.*`, 146 across SQLite and Postgres):
   the shapes and paths a leak needs that the suite didn't have, with
   answers from a reference model.

Everything here was run against the latest releases (ash 3.37.0, ash_sql
0.8.3, ash_sqlite 0.2.19, ash_postgres 2.15.1) and against ash-project
`main` (ash `41e179f`, ash_sql `9136094`, ash_sqlite `1a51fcb`, ash_postgres
`7f2d90e`, 2026-10-24). Nothing older is reported.

## Dependencies

The suite used to run Ash from the parent checkout (fork `main`, 3.33.11)
with Git-pinned adapters. It now has two dependency sets (`mix.exs`):

| Set | How | Ash | AshSQL | AshSQLite | AshPostgres |
| --- | --- | --- | --- | --- | --- |
| `release` (default) | Hex, `mix.lock` | 3.37.0 | 0.8.3 | 0.2.19 | 2.15.1 |
| `main` | `CONFORMANCE_DEPS=main`, Git, `mix.main.lock` | `41e179f` | `9136094` | `1a51fcb` | `7f2d90e` |
| `main`, local | `CONFORMANCE_DEPS=main CONFORMANCE_MAIN_DIR=<dir>` | path deps to `<dir>/ash`, `<dir>/ash_sql`, `<dir>/ash_sqlite`, `<dir>/ash_postgres`, with a lock, deps and build git ignores | | | |

`CONFORMANCE_DEPS=upstream` and `mix.upstream.lock` are gone; CI's stack
comparison job now uses `main`. `CONFORMANCE_ASH_PATH` joins the existing
per-package path overrides.

Where the two sets differ, an adapter's expectations say so with
`on_deps("release" | "main", rules)` (`Ash.Conformance.Contracts.Records`),
and a gap fixed upstream keeps its entry with `fixed_in:` (rendered in
`GAPS.md` as "Fixed upstream in …"). Effects of the bump:

- **Postgres**: everything matches on `release`. Re-pinned:
  `root.unsorted_first_empty` now passes (gap `root-first` is fixed in AshSQL
  0.8.3 and `main`), and `ordering.unique_other_field` returns
  `%{1 => ["high", "same"], 2 => ["other"], 3 => []}` instead of Postgres's
  DISTINCT/ORDER BY error (still unresolved, `unique-list-order`). On `main`
  only: `context.tenant_bypass`, `context.bypass_sibling`,
  `context.through_bypass` and `filter.parent_through_control` pass,
  `path.root_relationship` is rejected by Ash itself ("has a `path`, which is
  only supported for aggregates loaded on records"), and
  `adv.tenant.through_many_to_many_load` only shows the tenancy leak.
- **SQLite**: AshSQLite 0.2.19 predates the aggregate work the suite had
  pinned (ash_sqlite#232, `f489778`): it supports no aggregates over
  relationships and warns for each one the suite defines (96 definition
  warnings). This is unrelated to this work and isn't rewritten here.
  SQLite's expectations follow `main`, where that work is, so the default
  `release` run fails 489 SQLite scenarios and 1,568 SQLite variant runs,
  plus one contract test that expects AshSQLite to advertise `list`
  aggregates; `CONFORMANCE_DEPS=main` passes. On `main`, AshSQLite also
  supports `upsert_conflict/1` conditions (gap `upsert-conditions`, now
  `fixed_in: ["main"]`) and returns forbidden bulk destroys as errors, so
  `upsert.condition`, `upsert.skipped_record` and
  `policy.{owner_nil_actor,strict}.bulk_destroy` were promoted; it needs
  `min_sqlite_version/0` on the repo, now defined. Until AshSQLite releases
  #232, run SQLite with `CONFORMANCE_DEPS=main`, or Postgres alone with
  `CONFORMANCE_ADAPTERS=postgres` on the default set.
- **Ecosystem** (`ECOSYSTEM.md`, default set): SQLite works 709 (was 1,082);
  Postgres 1,285 (was 1,248); ETS 936 (was 896). CSV, MySQL and ClickHouse
  are unchanged; they don't run the new fixture.

## Design

### The decoy variant

`:decoy` joins the existing variants (`Ash.Conformance.Variant`), with the
same contract: run the scenario another way, and the answer must match the
scenario's own record. It is adversarial where the others are benign: their
policies hide nothing, so they can't show a path that forgets a filter.

**Decoy rows** (`Ash.Conformance.Decoy`). `Fixtures.seed!/4` stores a decoy
for every fixture row, before the row itself, so a query that loses a filter
tends to meet a decoy first. A decoy is the same row with:

- its primary key moved into a reserved range, 880,000,000 to 880,999,999;
- its tenant attribute set to that tenant's mirror (a reserved integer, or
  the tenant string with `~decoy`) wherever any role over the same table is
  multitenant by attribute. Local identities (`local_id`, the orders'
  `[:event_id, :customer_id]`) then collide across tenants, as the data
  layer allows;
- other integer attributes moved into the same range, except foreign keys
  (`*_id`, `*_key`) and `local_id`, which keep pointing at real rows: a decoy
  child belongs to a real parent, and a decoy order links a real event to a
  real customer;
- values of identities that can't repeat (every identity, except a
  tenant-scoped one under attribute tenancy) moved too: strings marked
  `~decoy`, integers into the range.

Under schema-based tenancy a decoy goes in the same schema. A resource
without an integer primary key gets no decoys (no policy could hide them).

**What hides them.** The decoy resource set (`Decoy` namespace, like
`PermitPolicy`) gets a read/update/destroy policy, `NotDecoy`:

- on a resource multitenant by attribute (and not `global?`), it passes every
  row, so tenancy alone hides the mirror tenant. A tenancy leak can't be
  masked by the policy;
- elsewhere, including `global?` resources and schema tenancy, it hides the
  reserved id range;
- a resource with its own policies keeps them and gets `NotDecoy` as an
  additional policy (both must pass).

**The invariant.** `Runner.execute_variant!/3` fails a decoy run whose
outcome, error messages included, contains a reserved id, a reserved value
or a `~decoy` string (`Decoy.leaks/1`), unless a variant record pins the leak,
and then requires the scenario's own record as for every variant. So every
scenario is a leak test without a new expected value.

**Opt-outs**, each with a stated reason, for answers that rightly change:

- `Variant.across_tenants/0` (4 scenarios): reads across tenants on purpose
  (`tenant.explicit_global`, `context.tenant_bypass`, `context.bypass_sibling`,
  `context.through_bypass`);
- `Variant.plain_relationship_filter/0` (33 scenarios): plain filters
  through a relationship. The policies guide
  authorizes relationship paths only in `filter_input`, so policy-hidden
  decoys rightly match (the fan-out filters, `read.join_*`, `filter.exists`,
  `shape.exists.*.exists_expr`, ...). Plain relationship filters that don't
  change still run.

The policy grid, combination grid and authorization scenarios have their own
authorization axis and don't run any variant, as before.

**Data layers.** The decoy set is defined for SQLite and Postgres (with the
other variant sets) and ETS (`variants: [:decoy]`). CSV, MySQL and ClickHouse
have none and report "not run".

### The adversarial scenarios

`Ash.Conformance.Adversarial` holds the fixture and reference model;
`Ash.Conformance.Scenarios.Adversarial` the 76 scenarios (70 outside the
Postgres schema profile). Resources (`Resources.Adversarial`) are defined only
for adapters whose `fixture?(:adversarial)` is true (SQLite, Postgres, ETS),
so the other data layers' reports don't change. `through` relationships are
compiled at run time, as `load.through`'s are: AshSQLite only warns that it
can't support them, and a build-time warning would fail the build.

Events and customers are shared; orders join them, in three shapes over one
table (attribute tenancy on `org_id`; a read policy `visible == true`; plain)
and a schema-tenant shape on Postgres. Customers 5 (Zed) and 6 (Yan) sort
first by name and are unrelated to organisation 1, so a path that reads the
destination unfiltered returns one of them.

| Group | Shapes and paths |
| --- | --- |
| `adv.tenant.*` (17) | `many_to_many`; `has_many through` of 2 steps (`[:orders, :customer]`), 4 steps, and 3 steps ending in a `many_to_many` (`[:orders, :event, :buyers]`); sorted and unsorted `has_one through`; one record's bounded loads (`limit: 1`, `offset`); `count`/`list`/`first` aggregates; `exists`; relationship and aggregate filters. Each reads organisation 1, then 2. |
| `adv.schema.*` (6, Postgres) | The same under schema-based tenancy, with shared events and customers. |
| `adv.plain.*` (8) | Bounded `through` loads and `has_one through` with no tenancy or policy, and a two-record control. |
| `adv.join_policy.*` (11) | The join resource's read policy on loads, aggregates, `exists` aggregates, an aggregate filter and `filter_input`, with plain-path controls. |
| `adv.foreign.*` (13) | Single update and destroy given another tenant's record (option and changeset forms); bulk update and destroy given one record of each tenant, for `:atomic`, `:atomic_batches`, `:stream` and `[:atomic, :stream]` with a non-atomic action; records read across tenants. The answer is what each call returns and what is stored for both tenants. |
| `adv.upsert.*` (6) | Upserts in organisation 1 whose identity values organisation 2 has, single and bulk, with and without `return_skipped_upsert?`, including an `all_tenants?` identity. |
| `adv.field_write.*` (11) | Field policies on create, update, destroy, bulk create and bulk update/destroy results (`:atomic`, `:atomic_batches`, `:stream`), at the top level, in an embedded resource, an array of embedded resources and a union, with an aggregate loaded on the bulk query or through `load:`. |
| `adv.manage.*` (4) | `manage_relationship` with the same tenant's record (control), another tenant's, one the actor can't read, and replacing a `many_to_many` in one tenant. |

Whether an upsert in one tenant may update or return another tenant's row
through an `all_tenants?` identity is undocumented, so those two scenarios
are `:unresolved` (decision gap `all-tenants-upsert`). On ETS the `code`
identity is tenant-scoped, as an all-tenants identity can't be pre-checked.

### Reporting

- `FEATURES.md`: section 15, "Adversarial invariants" (8 features), and a
  "Decoy variant" section with each reviewed data layer's decoy records,
  separated from records every authorization variant shares.
- `ECOSYSTEM.md`: the "Adversarial invariants" tier, and a "Decoy variant"
  section: per data layer, how many scenarios gave the same answer, leaked,
  changed, opted out or didn't run, and each changed one with its gap.
- `surveys/features-<adapter>.md`: each decoy that changed an answer, with
  both outcomes.
- `GAPS.md`: 12 new gaps (below), `fixed_in` on 4.

## Acceptance

Every known case is caught, on both the latest releases and `main`. "Own
answer" means the scenario's base run fails against the reference model;
"decoy" means the decoy variant also catches it on its own.

| Known case | Caught by | Data layers | Release | `main` | Gap |
| --- | --- | --- | --- | --- | --- |
| `ash_postgres-through-tenant` | own answer: `adv.tenant.m2m_load`, `.through_load`, `.through_long_load`, `.has_one_sorted`, `.has_one_unsorted`, `.m2m_limit_one`; on `main` also `.through_many_to_many_load` | Postgres (SQLite and ETS `many_to_many` correct; SQLite `through` is `through-fallback`) | caught | caught | `through-tenant` |
| `ash-through-limit-one` | own answer: `adv.plain.through_limit_one`, `.through_offset`, `.has_one_limit`, and their `adv.tenant`/`adv.schema` forms | Postgres, SQLite, ETS | caught | caught | `through-limit-one` |
| `ash-join-resource-policies` | own answer: `adv.join_policy.m2m_aggregates`, `.through_aggregates`, `.m2m_exists_aggregate`, `.m2m_aggregate_filter`, `.m2m_filter_input` (and `.through_exists_aggregate` on SQLite/ETS); decoy: the aggregates double (hidden decoy orders count) | Postgres, SQLite, ETS | caught | caught | `join-resource-policies` |
| `ash-bulk-stream-tenant` | own answer: `adv.foreign.bulk_update.{stream,fallback,stream_global_records}`, `adv.foreign.bulk_destroy.{stream,fallback}`; on SQLite also `bulk_destroy.{atomic,atomic_batches}` (Ash forces `:stream`) | Postgres, SQLite, ETS | caught | caught | `bulk-stream-tenant` |
| `ash-destroy-record-tenant` | own answer: `adv.foreign.destroy_changeset` (controls `destroy_option`, `update_changeset` pass) | Postgres, SQLite, ETS | caught | caught | `destroy-record-tenant` |
| `ash_postgres-skipped-upsert-tenant` | own answer: `adv.upsert.skipped_bulk` (order-dependent: the forward seed order returns organisation 2's note 201), and the existing `upsert.skipped_record` | Postgres (SQLite `main` and ETS correct) | caught | caught | `skipped-upsert-tenant` |
| `ash-field-policies-write-results` | own answer: `adv.field_write.{create,update,update_load,destroy,bulk_create,bulk_update.atomic,bulk_update.atomic_batches,bulk_destroy.atomic}`: embedded SSN, card numbers in an array and the card in a union are returned; ETS also `bulk_update.stream`, and its atomic results include the admin-only `order_count` (decoy: it counts hidden orders too) | Postgres, SQLite, ETS | caught | caught | `write-result-field-policies` |

Why the decoy variant alone doesn't catch more of these: the leaks need
shapes the old fixtures don't have (`many_to_many` or `through` with a
tenant-scoped join, bulk writes given records, embedded field policies), and
in the new scenarios the base answer already fails. Decoys keep foreign keys
pointing at real rows, so a leaked decoy join row surfaces as a real
customer id, caught by the answer changing rather than by the leak scan. No
data layer put a reserved id in any outcome ("0 leaked" everywhere).

**Fix-revert.** A patched copy of each dependency, swapped in and out of
`deps/` on the release set, turns the scenarios green:

- Ash `lateral_join?/4` checking `through` before its `limit == 1` branches:
  `adv.plain.through_limit_one`, `.through_offset`, `.has_one_limit` pass; the
  tenant and schema forms then show the Postgres tenancy leak instead.
- Ash `Ash.Actions.Destroy` keeping a tenant the changeset already has:
  `adv.foreign.destroy_changeset` passes; `destroy_option`,
  `update_changeset`, `write.lifecycle` and `tenant.write_bulk_destroy` still
  pass.
- Ecto's planner copying an inlined join query's prefix onto its join (new
  finding 1): `adv.schema.m2m_aggregates` and `.m2m_exists` pass;
  `adv.schema.m2m_load`, `.through_aggregates`, `schema.loaded_aggregates`
  and `schema.relationships` still pass.

## New findings

Beyond the seven known cases. Each has a minimal standalone script in
`ISSUES/UNFILED/review/conformance-adversarial/` (`STACK=release` or
`STACK=main`), and a gap in `GAPS.md`. None is written up anywhere public.

| # | Finding | Owner | Release | `main` | Suite | Script |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | **Schema-based tenancy: aggregates and `exists` over a `many_to_many` from a shared resource read the first tenant's join table for every tenant.** AshSQL joins the tenant's join table as an interpolated `%Ecto.Query{prefix: tenant}`. Ecto puts that prefix in the SQL, but the join it builds (`query_to_joins/4`) has no `prefix` of its own, and the statement cache key only reads the join's, so the statement planned for the first tenant is reused. Tenant b gets tenant a's `buyer_count`/`buyer_ids`, and `exists(buyers, id == 2)` is false for tenant b. Loads are right. Cross-tenant data, Postgres schema tenancy. | Ecto, AshSQL | reproduces | reproduces | `adv.schema.m2m_aggregates`, `adv.schema.m2m_exists` (`joined-prefix-cache`) | `schema_m2m_prefix_cache.exs` |
| 2 | **An `exists` aggregate with a `query:` over a `through` relationship isn't correlated with its source**: it compiles to `exists((SELECT 1 FROM customers WHERE id = $1))`, true for every record when any destination row matches. `count` with the same query, and `exists()` in a filter, are right. Lets a caller test for any matching destination row regardless of relationship. | AshSQL | reproduces | reproduces | `adv.join_policy.through_exists_aggregate` on Postgres (`through-exists-aggregate`) | `through_exists_aggregate.exs` |
| 3 | **Aggregates referenced in an atomic update, in an atomic bulk update's query, as the field of a root aggregate, or in another aggregate's query count rows the related read policy hides.** The policies guide says aggregates "referenced *anywhere* will *always* authorize". Found by the decoy variant. The first three on SQLite, Postgres and ETS; the fourth on Postgres and ETS (SQLite on `main` is right). | Ash | reproduces | reproduces | decoy: `write.atomic_update`, `write.single_atomic_update`, `write.bulk_update_filter`, `field.root_aggregate`, `filter.aggregate_dependency*` (`aggregate-reference-authorization`) | `aggregate_reference_authorization.exs` |
| 4 | **A `through` path ending in a `many_to_many` joins the destination on the wrong key**: each event gets the customer whose id equals its own, an unrelated record. | AshPostgres | reproduces | **fixed** | `adv.tenant.through_many_to_many_load` (`through-many-to-many-step`, `fixed_in: ["main"]`) | `through_many_to_many_step.exs` |
| 5 | `Ash.create/3` documents `upsert_condition` but drops it (it only passes options `for_create/4` declares), so the upsert always writes. Functional, not a leak; the scenarios use a changeset instead. | Ash | reproduces | reproduces | none | `create_upsert_condition.exs` |

Also found, but not new:

- **Authorization bounds on more paths** (decoy): `bounds.filter_after_limit`,
  `.list_filter_after_limit`, `.relationship_limit`, `.relationship_offset`,
  `.relationship_offset_only` and (Postgres) `.unsorted_limit` let hidden
  rows take a limited relationship's slots before the policy applies, on
  SQLite and Postgres, release and `main`; ETS is right. Existing gap
  `authorization-bounds`, which named one path.
- **ETS atomic bulk results** count hidden orders in an aggregate loaded on
  the bulk query (`order_count` 8 under decoys), so the ETS-only case of the
  field-policy draft also skips the related read policy.
- **Schema-tenant `through` load with a shared destination** queries
  `"dc_tenant_a"."adv_customers"` and fails (`schema-through-destination`);
  noted in the through-tenant draft as an error, not an exposure.
- **ETS four-hop `through` paths** raise `FunctionClauseError` on 3.37.0
  (`adv.tenant.through_long_load`, `.through_many_to_many_load`); #3060,
  fixed on `main`.
- **`all_tenants?` upserts** update and return another tenant's row on every
  data layer; recorded as a decision (`all-tenants-upsert`), not a defect.

Seen only on the old pins and gone on the latest releases: ETS returned nil
for `field.root_aggregate` on 3.33.11 (it now returns 5, and 10 with
decoys, finding 3).

## Runtime cost

Measured on this machine (Apple silicon, local Postgres 17), SQLite and
Postgres together, `mix test`, wall clock including setup:

| Run | Tests | Time |
| --- | ---: | ---: |
| Before this work (old pins, 3.33.11) | | 237 s |
| Now, `main` set, everything | 11,963 | 515 s |
| The decoy variant alone (`--only variant:decoy`) | 2,161 | 132 s |
| The adversarial scenarios alone, with their variants (`--only area:adversarial`) | 730 | 63 s |
| Now, `release` set (SQLite failing) | 11,963 | 472 s of tests |

The decoy variant reruns about 1,080 scenarios per data layer in three seed
orders, with a fixture twice the size: about a quarter of the suite's time.
The remaining increase over the old run is the 146 new scenarios' benign
variants and the dependency change, which this run doesn't separate.
`mix conformance.ecosystem` for all six data layers takes 312 s; the decoy
pass runs only on SQLite, Postgres and ETS.

## Out of reach

- **Extensions.** AshGraphql, AshJsonApi, AshTypescript and AshPhoenix reach
  several of these (the drafts show how); exercising them needs a request
  harness, which is later work.
- **Data layers.** CSV, MySQL and ClickHouse have no decoy set and don't run
  the adversarial fixture. ETS has no schema-tenancy profile here, so
  `adv.schema.*` runs on Postgres only.
- **What decoys can't hide.** Resources without an integer primary key
  (UUID shapes, keyless events) get no decoys. Composite join rows hide by
  their first key, so a hidden join row between two real records needs a
  scenario of its own (`adv.join_policy.*`). Decoy foreign keys point at real
  rows, so most leaks show as a changed answer rather than a reserved id; a
  second kind of decoy pointing at decoy destinations would make the leak
  scan fire, but only where the destination's own filter is also skipped.
- **Plain relationship filters.** They are unauthorized by design, so the
  decoy variant can't test their policy paths; tenancy on them still runs.
- **Writes to decoys.** Stored-state checks leave decoys out, so a write
  that changes a decoy without returning it is only caught where the
  scenario's answer depends on it.
- **SQLite on the default set** fails until AshSQLite releases its aggregate
  work (see Dependencies).
