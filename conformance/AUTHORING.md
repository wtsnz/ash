<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# Authoring scenarios and adapters

Read when adding a scenario, adapter, expectation or execution profile.

## Add a scenario

Add a declaration to an existing `Scenarios` module or register another module
in `Catalog.all/0`. The runner does not change. For example:

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
observation. The count never changes the verdict. Add the ID to `Expectations` explicitly
for every applicable adapter; there is no implicit supported default.

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

Run both adapters, inspect failures, update the local gap task only after
understanding the cause, and regenerate the matrix/inventory. Every gap in
`GAPS.md` names its owner (Ash, AshSQL, AshSQLite or AshPostgres) and has an
entry in `lib/gaps.ex`. Use the failure's stack trace or a direct control to
find the owner. A gap is implementation work, a decision for Ash, or a
limitation: something unsupported by design, where the documented rejection is
the intended result. Tests reject
missing expectations, duplicate IDs, unexpected passes and changed signatures.

## Add an adapter

Implement `Ash.Conformance.Adapter`. An adapter in this repository is added to
`Adapter.all/0`; one in another repository is listed in config instead, so no
shared file changes:

```elixir
# A reviewed adapter, with its own expectation records:
config :ash_conformance, adapters: [MyDataLayer.Conformance]
# Or one that only produces unreviewed surveys:
config :ash_conformance, unreviewed_adapters: [MyDataLayer.Conformance]
```

| Callback | Responsibility |
| --- | --- |
| `id/0`, `resource/1` | Stable adapter ID and resources for shared roles. |
| `profiles/0` | Supported storage profiles. The shared profile is separate from context tenancy. |
| `setup!/0` | Create isolated storage and provision the shared schema/data model. |
| `checkout!/0`, `checkin!/0` | Isolate each case and clean up its data; these need not be SQL transactions. |
| `persist!/3` | Persist fixture maps by resource role, including tenant options. |
| `benchmark_persist!/2` | Persist larger fixtures outside timing. May delegate to ordinary persistence. |
| `custom_aggregate/0` | Adapter-specific custom aggregate implementation. |
| `instrumentation/0` | Optional module for untimed `measure/2` and `metadata/1`, or `nil`. |
| `fixture?/1` | Whether the integration provides the resources for a fixture. |
| `expectations/0` | Expectation records by scenario ID; `%{}` for a survey-only adapter. |
| `resource_config/1` (optional) | `{data_layer, config_block}` for a shared table, so the shared resource roles work unchanged. |
| `identity_options/0` (optional) | Options for every shared identity, e.g. `[pre_check?: true]` when uniqueness is not enforced by storage. |

To reuse the shared roles, implement `resource_config/1` and instantiate the
resource macros with your adapter module, as `Ash.Conformance.Ets` does with
`:ets`:

```elixir
defmodule MyDataLayer.Conformance.Resources do
  use Ash.Conformance.Resources, namespace: MyDataLayer.Conformance, adapter: MyDataLayer.Conformance
end
```

Start with `mix conformance.survey`, review what it reports, then record
expectations: supported, unsupported with the exact rejection, known defect with
the exact wrong answer, or unresolved.

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

Resource-role capability probes in `Capabilities` must be reviewed when adding
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
storage, and the roles needed by one fixture. Register it in `Adapter.all/0`
so `CONFORMANCE_ADAPTERS=mysql` selects it. Do not add a context/schema profile
merely because the adapter is SQL-based. The provisioning mechanism is separate
from shared attribute-tenant semantics.

The aggregate fixture requires these roles, all available as reference definitions
in `Resources`: `parent`, `child`, `rating`, `tag`, `link`, `child_tag`, and `event`.
Scenarios then introduce views/roles for `tenant_child`, `tenant_link`, and
`authorized_child`, plus the integration's manual relationship. The isolation
fixture persists only `tenant_parent` and `tenant_item`; authorization cases use
`secure_parent`, `secure_item`, `context_parent`, and `context_item` over that data.
`IsolationResources` documents their common attributes, identities and actions.
The separate context profile uses `schema_parent` and `schema_item`.

`Ash.Conformance.Ets` is a worked example using Ash's ETS data layer. It reuses
the shared resource roles through an `:ets` branch in `Resource`, uses private
per-process tables for isolation, and implements the manual relationship without
Ecto. It is not in `Adapter.all/0`, so it has no expectations;
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
