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
separate workload covers this operation. Add the ID to `Expectations` explicitly
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
understanding the cause, and regenerate the matrix/inventory. Tests reject
missing expectations, duplicate IDs, unexpected passes and changed signatures.

## Add an adapter

Implement `Ash.Conformance.Adapter` and register it in `Adapter.all/0`:

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
