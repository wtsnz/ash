<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# Semantic sources and decisions

Read when changing an intended answer or investigating an unexpected result.

Expected answers come from these checked-out Ash sources:

- [Aggregates guide](../documentation/topics/resources/aggregates.md) and
  [intentional aggregate tests](../test/actions/aggregate_test.exs): aggregate
  kinds, defaults, fields, filtering, authorization and tenant scope.
- [Multitenancy guide](../documentation/topics/advanced/multitenancy.md) and
  [multitenancy tests](../test/actions/multitenancy_test.exs): required tenants,
  isolation, tenant-aware identities and explicit global actions.
- [Relationships guide](../documentation/topics/resources/relationships.md),
  the resource DSL, and [default-sort tests](../test/query/default_sort_in_relationship_test.exs):
  bounds, ordering and `from_many?`. Unsupported API shapes stay unresolved.
- [Pagination tests](../test/actions/pagination_test.exs): deterministic
  aggregate ordering, offset/keyset membership and counts.
- [Shared policy-context tests](../test/policy/context_shared_test.exs): context
  propagation through reads, relationship loads and aggregate authorization.
- [Data-layer contract](../lib/ash/data_layer/data_layer.ex) and its action/query
  call sites: capability claims, dispatch and optional callback behavior.

## Isolation fixture answers

Parent IDs are globally unique. The declared `local_id` identity is tenant-scoped;
local IDs 1, 2 and 3 exist in each tenant. Relationships intentionally join using
local IDs, so failing to constrain destination tenants changes their contents.
The database has matching tenant/local identity indexes.

| Tenant | Parent local ID | Owner | Child values with owners |
| --- | ---: | ---: | --- |
| 1 | 1 | 1 | 2 owner 1 dept 1; 3 owner 1 dept 2; 99 owner 2 dept 2 |
| 1 | 2 | 1 | 8 owner 1 dept 1 |
| 1 | 3 | 2 | 50 owner 2 dept 2 |
| 2 | 1 | 1 | 700 owner 1; 600 owner 2 |
| 2 | 2 | 2 | 900 owner 2 |
| 2 | 3 | 1 | 1000 owner 1 |

Unrestricted tenant 1 totals are 104, 8 and 50. Actor 1 sees parent 1 and 2;
child authorization reduces their totals to 5 and 8. This reverses their
aggregate ordering. Actor 2 sees parent 3; its total is 50. A root child query
for actor 2 includes values 99 and 50 because root child visibility does not
require a visible parent. This distinction is intentional.

With shared department 1 context, actor 1 sees values 2 and 8. The hidden 99
must not occupy the top relationship slot before authorization. Bounded loads
return value 3 for parent 1 under actor 1, then value 2 after offset 1.
Counts and pages are computed from the same authorized, tenant-scoped set.

A missing tenant on an enforced action is invalid. A noninteger tenant is an
invalid filter value. An integer with no stored rows returns an empty result.
The explicit `:global` read action permits reads across tenants; it is not an
implicit bypass in the normal read action.

The context-tenancy profile uses identical primary keys in two separately
provisioned Postgres schemas. Its answers come from literal data, not the
attribute-tenancy implementation. SQLite is outside this provisioning profile.

## Equivalences and limits

`equivalence.visible_count_load` compares a count with the corresponding loaded
relationship length. Preconditions: identical actor/tenant, no bounds, and unique
destination identities. `equivalence.root_reference` scans literal fixture maps
in memory for a sum. Keyset scenarios reconstruct the explicit expected sequence
and verify each page's consistent count. They do not model a SQL planner.

The aggregate corpus preserves several open semantic questions in [GAPS.md](GAPS.md):
path multiplicity, keyless distinct identity, unique-list ordering by another
field, and a missing many-to-many bounds API. Current results remain strict
characterizations. Agreement between adapters does not resolve those questions.
Generated cases and concurrent-pagination semantics are follow-up work.
