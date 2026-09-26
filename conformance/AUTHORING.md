<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# Authoring scenarios and adapters

Read when adding a scenario, adapter, expectation or execution profile.

## Add a scenario

Add a declaration to the `Scenarios` module for its feature level, under
`lib/scenarios/`, or register another module in `Catalog.all/0`, then list its
ID under a feature in `lib/contracts/features.ex`. The runner does not change. For example:

```elixir
new("tenant.my_read", :tenancy, [1, 2, 3], fn ctx ->
  ctx.adapter.resource(:tenant_parent)
  |> Ash.Query.set_tenant(1)
  |> Ash.Query.sort(:local_id)
  |> Ash.read!()
  |> Enum.map(& &1.local_id)
end,
  fixture: :isolation,
  capabilities: [tenant_parent: :read, tenant_parent: :sort],
  semantic_basis: "../documentation/topics/advanced/multitenancy.md"
)
```

Every ID is stable and unique. Define an explicit expected value from documented
semantics, intentional Ash tests or an explicit decision. The source operation,
fixture/profile, capabilities and expectation identify what is being specified.
Use `description:` for explanation beyond the ID, and `benchmark: true` when a
separate workload covers this operation. Use `fallback: "..."` to name an Ash
fallback the operation should exercise, such as in-memory evaluation. The runner
then records the operation's data-layer query count, through the adapter's
instrumentation, beside the result; zero queries is the only positive
observation. The count never changes the verdict. Each reviewed adapter's
`expectations.ex` (for example `lib/adapters/sqlite/expectations.ex`) holds
rules: `supported("*")` claims the rest are supported, and each
`expect(pattern, record)` records a gap, with `*` matching any part of an ID.
A scenario matched by two `expect` rules, or a rule that matches nothing,
fails. `supported` is a claim, not an acceptance: a new scenario it covers
must still pass, or the run fails and the scenario needs a reviewed record.

Declare what a scenario builds on with `requires:`. It takes scenario IDs,
for example:
- a control that runs the same path without the feature under test, such as
  `values.decimal_read_control`;
- the tier-1 storage cell of a type the scenario relies on, such as
  `Storage.stored(:decimal)`, which is `storage.decimal.ordinary`.

Helpers that take no options can pipe into `requires/2` from
`Ash.Conformance.Scenario`.

When the scenario fails and a prerequisite fails too, surveys label it
"blocked by" the prerequisite, and `ECOSYSTEM.md` ranks the blockers. A
blocked scenario keeps its classification, and the label never changes a
contract. Declare only what the operation really uses: a prerequisite that
fails for an unrelated reason gives a misleading label. The catalog rejects
unknown IDs and cycles.

A fixture row that cannot be stored gets its blockers without any
declaration: the storage cells of the row's types.

Use `fixture: :aggregate`, `:isolation` or `:context_tenancy`. New fixture builders
are selected in `Fixtures.build!/2`. Scenario-specific extra setup belongs in
`Fixtures.prepare!/2`, outside capture. A write that is itself the behavior under
test belongs in the operation. Persist fixtures through the adapter's callback.

Keep projections lossless for the behavior under test. Inherited numerical
aggregates normalize floats/decimals to six decimal places; nils, custom structs
and string whitespace remain intact. Relationship-order checks must preserve
order, not sort the observed values. Use an explicit tie-breaker and null order.

A valid-input semantic answer can also be a rejection. Prefer stable structured
fields, as in `tenant.invalid`. Exception assertions require a specific class
and narrow pattern. Never add a catch-all signature or regenerate expectations
from current output. A deliberate semantic change needs a decision and review.

Run both adapters, inspect failures, record a gap only after understanding the
cause, and regenerate the matrix, inventory and `GAPS.md` (`mix conformance.gaps`).
A gap lives where its knowledge belongs:

- `lib/contracts/shared_gaps.ex`: Ash's own defects and undecided semantics;
- `lib/sql/gaps.ex`: defects AshSQL causes on every data layer built on it;
- the adapter's `gaps/0` (for example `lib/adapters/sqlite/gaps.ex`): what only
  that data layer shows.

Each names its owners, first owner first. Use the failure's stack trace or a
direct control to find the owner. A gap is implementation work, a decision for Ash, or a
limitation: something unsupported by design, where the documented rejection is
the intended result. Tests reject
missing expectations, duplicate IDs, unexpected passes and changed signatures.

## Add a data layer

A new data layer takes one folder and one list entry. `lib/adapters/ets/adapter.ex`
is the smallest complete example.

1. **Depend on it.** Add the data layer to `mix.exs`, pinned to a release or a
   Git commit.
2. **Write `lib/adapters/<name>/adapter.ex`.**

   ```elixir
   defmodule Ash.Conformance.MyDataLayer do
     use Ash.Conformance.Adapter, id: :my_dl, label: "AshMyDataLayer", package: :ash_my_data_layer

     # The data layer and its configuration block for each shared table.
     def resource_config(table),
       do: {AshMyDataLayer.DataLayer, quote(do: my_dl(do: table(unquote(table))))}

     # Create empty storage, then define the shared resources.
     def setup! do
       # ...start a repo, create tables...
       Ash.Conformance.Resources.compile!(__MODULE__)
     end

     # Leave each case's storage empty for the next one.
     def checkin!, do: :ok
   end
   ```

   `use Ash.Conformance.Adapter` supplies every other callback. Override what
   differs: `checkout!/0` to isolate a case, `identity_options/0` when storage
   cannot enforce uniqueness, `custom_aggregate/0`, or `manual_relationship/0`
   for a manual relationship with a join form. `Adapter.roles/0` and `Adapter.table_roles/0` list the resources and
   tables to provision and clear.
3. **Register it** in config. The suite names no adapter itself: the shipped
   ones are listed in `config/config.exs` the same way.

   ```elixir
   config :ash_conformance, unreviewed_adapters: [Ash.Conformance.Ets, MyDataLayer.Conformance]
   ```
4. **Survey it.** `MIX_ENV=test mix conformance.ecosystem my_dl` adds its column
   to `ECOSYSTEM.md` and writes `surveys/features-my_dl.md` with every failing
   scenario. `Resources.compile!/1` defines the resources at setup, so what
   Ash rejects at definition time appears as definition warnings instead of
   breaking the build.
5. **Review it, when you want strict contracts.** Record an expectation for
   every scenario (supported, unsupported with the exact rejection, known
   defect with the exact wrong answer, or unresolved), return them from
   `expectations/0` (rules in `lib/adapters/<name>/expectations.ex`, resolved
   with `Ash.Conformance.Contracts.Records.resolve/2`), return the gaps only it shows from
   `gaps/0`, and move the adapter to `config :ash_conformance, adapters: [...]`.
   It then gets a column in `FEATURES.md` and runs in `mix test`.

## Adapter callbacks

| Callback | Responsibility |
| --- | --- |
| `id/0`, `label/0`, `package/0` | Stable ID, display name, and the application whose version reports show. |
| `resource/1` | The resource module for a shared role; defaults to one named under the adapter. |
| `profiles/0` | Supported storage profiles. The shared profile is separate from context tenancy. |
| `setup!/0` | Create isolated storage and provision the shared schema/data model. |
| `checkout!/0`, `checkin!/0` | Isolate each case and clean up its data; these need not be SQL transactions. |
| `persist!/3` | Persist fixture maps by resource role, including tenant options. |
| `benchmark_persist!/2` | Persist larger fixtures outside timing. May delegate to ordinary persistence. |
| `custom_aggregate/0` | Adapter-specific custom aggregate implementation. |
| `manual_relationship/0` | Manual relationship implementation; defaults to one that loads in Elixir. |
| `instrumentation/0` | Optional module for untimed `measure/2` and `metadata/1`, or `nil`. |
| `fixture?/1` | Whether the integration provides the resources for a fixture. |
| `expectations/0` | Expectation records by scenario ID; `%{}` for a survey-only adapter. |
| `gaps/0` | Gaps only this data layer shows, rendered into `GAPS.md`. |
| `resource_config/1` | `{data_layer, config_block}` for a shared table. |
| `resource_options/0` | Extra `use Ash.Resource` options for every shared resource, such as an extension that derives data layer settings from the attributes. |
| `notes/0` | What the integration does differently from a plain application, such as a workaround for a data layer defect; listed in `ECOSYSTEM.md`. |
| `identity_options/0` | Options for every shared identity, e.g. `[pre_check?: true]` when uniqueness is not enforced by storage. |

The SQL adapters implement these with repositories and migrations. The runner,
shared scenarios and benchmark harness never require a connection or an Ecto
repository. A future non-SQL adapter supplies its own resource modules and
storage lifecycle instead of using the SQL resource factory. Custom manual
relationships likewise belong to the integration. Instrumentation may return
unavailable measurements with a limitation, never fabricated zeroes.

Declare expectations for each scenario in a profile the adapter provides.
A profile unavailable on an adapter remains visible in the inventory but has
no executable semantic-pass row. This is only for storage strategy differences;
ordinary unsupported features within a supported profile must run and prove
their specific rejection. Do not omit troublesome scenarios by narrowing profiles.

Resource-role capability probes in `Contracts.Capabilities` must be reviewed when adding
roles. Parameterized claims use the actual resource, relationship, expression
or kind. The broader capability inventory is independent of scenario execution.
Optional callback exports say nothing about whether they work.

## Promotion and migration

For a known defect, preserve both the intended answer and the precise current
wrong value/error. Run it after a fix: its unexpected-pass failure is the cue to
promote the adapter expectation. Preserve the gap entry as history. Unresolved
cases require a documented decision before they can become semantic passes.

Adapter repositories can later pin an Ash suite commit and run `conformance/`
against their candidate adapter revision. The suite is not a published package
or stable plugin API yet. A future release should version the inventory, resource
roles, scenario IDs and expectation format together. Keep adapter planner and
SQL-shape tests in adapter repositories.

## Bring up a new data layer, such as MySQL

Start with an adapter module that lists `[:shared]` in `profiles/0`, isolated
storage, and the roles needed by one fixture. Register it under
`unreviewed_adapters` in config so `CONFORMANCE_ADAPTERS=mysql` selects it for
probes. Do not add a context/schema profile
merely because the adapter is SQL-based. The provisioning mechanism is separate
from shared attribute-tenant semantics.

The aggregate fixture requires these roles, all available as reference definitions
in `Resources.Aggregate`: `parent`, `child`, `rating`, `tag`, `link`, `child_tag`, and `event`.
Scenarios then introduce views/roles for `tenant_child`, `tenant_link`, and
`authorized_child`, plus the integration's manual relationship. The isolation
fixture persists only `tenant_parent` and `tenant_item`; authorization cases use
`secure_parent`, `secure_item`, `context_parent`, and `context_item` over that data.
`Resources.Isolation` documents their common attributes, identities and actions.
The separate context profile uses `schema_parent` and `schema_item`.

`Ash.Conformance.Ets` is a worked example using Ash's ETS data layer. It reuses
the shared resource roles through `resource_config/1`, uses private per-process
tables for isolation, and uses the default manual relationship, which loads
without Ecto. It is registered as unreviewed, so it has no expectations;
`test/ets_bringup_test.exs` probes it. Most aggregate scenarios observe the
intended answer, and the transaction rollbacks show where ETS, which has no
transactions, differs.

You can work incrementally before every scenario has an expectation:

```sh
CONFORMANCE_ADAPTERS=mysql MIX_ENV=test mise exec -- mix conformance.probe loaded.count
CONFORMANCE_ADAPTERS=mysql MIX_ENV=test mise exec -- mix conformance.probe tenant.read
```

`conformance.probe` needs only the selected scenario's fixtures/resources. It
runs the public operation and shows the intended answer, actual result or error,
and resource-specific capability claims. Setup failures still fail the command.
Its output is explicitly unreviewed and reports zero semantic passes, including
when the answer looks correct. Exit success only means the observation was
captured. It never writes or accepts an expectation and is not a CI conformance
result. Reports are isolated under `results/probes/`.

Investigate each result against `semantic_basis` and the literal fixture. Then
add an explicit supported, unsupported, known-defect or unresolved expectation.
The regular test command requires a complete expectation map for every adapter
in its advertised profiles; probes intentionally do not relax that requirement.
This lets a new adapter progress case by case while the full suite remains strict.

For edge-case discovery, add a scenario with the intended answer and fixture,
then probe it on an existing adapter before classifying the outcome. Useful next
cases are listed in `COVERAGE.md`. Exercise a direct read/load control when an
aggregate is surprising, minimize the data, and verify the public API can express
the requested semantics. Do not convert matching adapter outputs into a new rule.

## Reference: results, contracts and evidence

Ash owns the shared semantic answers, inventory and framework dispatch tests.
Adapters own storage provisioning, fixture persistence, custom operations and
instrumentation. Shared scenarios call public Ash read/load/aggregate/write APIs.
They do not inspect Ecto queries, SQL or join strategies.

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

Fallback evidence has two sources. Dedicated tests in
`test/ash/data_layer/dispatch_contract_test.exs` in the parent project record
single and batch callback execution, validate results, and check optional
callback defaults. In adapter runs, a scenario can name the Ash fallback it
probes; the runner then counts the data-layer queries issued by the operation
alone and records that beside a successful result. For example, `calc.in_memory`
records zero queries: Ash evaluated the calculation itself. That shows who did
the work, not whether the data layer could have. The count never changes
whether a scenario passes. Other scenarios report `unobserved`. A negative
claim plus a correct result is insufficient.

Every scenario runs three times, with fixtures seeded forward, in reverse and
rotated to start from the middle. The runs must agree. A result that depends on
the order rows were stored in can never pass; a defect of that kind pins what
each order returned. Results are compared strictly, so `2` and `2.0` differ.

Each report also records the runtime, dependency revisions, database version and
settings for every selected adapter, because claims and results can depend on
them.

Compare saved behavior reports by stable scenario ID:

```sh
MIX_ENV=test mise exec -- mix conformance.compare \
  --base results/base.json --current results/sqlite-postgres.json
```

Current and migrated version-1 reports are accepted. This describes observations;
it does not update expectations. Generated reports are ignored and CI uploads
artifacts. The new workflow runs each adapter independently, plus core dispatch
tests. It does not replace adapter regression suites.

SQLite uses this project's ignored `tmp/data_layer.sqlite3`. Its repo enables
`write_transactions?`, as AshSQLite recommends and its installer does. AshSQLite's
`:transact` claim follows that repo setting, so capability claims are recorded
per resource, not per adapter.

The Postgres context-tenancy profile creates `dc_tenant_a` and `dc_tenant_b`
schemas inside that database. Both contain the same record identities with
different values. SQLite has no obligation to implement PostgreSQL schema
provisioning; its inventory says this profile is not applicable.
