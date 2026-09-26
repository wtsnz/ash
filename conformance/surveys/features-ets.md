<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# What each data layer supports

Generated from an unreviewed run: each result was classified automatically against the intended answer. Nothing here has been reviewed.

Feature catalog version 1: 118 features and 582 scenarios.

| Status | Meaning |
| --- | --- |
| ✅ Works | Every scenario ran and returns the answer Ash defines. |
| 🔸 Incomplete | Everything that ran works, but some scenarios could not run. |
| 🟡 Partial | Some scenarios work; others are rejected or wrong. |
| ⛔ Not supported | Every scenario that ran is rejected with a documented error. |
| ❌ Broken | Nothing that ran works, and at least one scenario gives a wrong answer or crashes. |
| ❓ Open question | The remaining scenarios need a semantic decision in Ash. |
| ❔ Unknown | No scenario could run, usually because the data layer could not store its fixture. Never means not supported. |
| ⚪ Untested | Listed so the specification is complete; no scenario verifies it yet. |
| ➖ Not applicable | The data layer does not provide this storage profile. |
| ⚠️ Changed | A result no longer matches its recorded contract. |

Counts are passing scenarios out of those that ran, then how many could
not run, then how many failures have a failing prerequisite (blocked).
Gap links explain everything that is not fully working, and who owns the
fix.

## 1. Storage

| Feature | ets | Not working |
| --- | --- | --- |
| Integers | ✅ Works 3/3 |  |
| Floats | ✅ Works 3/3 |  |
| Decimals | ✅ Works 3/3 |  |
| Strings | ✅ Works 3/3 |  |
| Case-insensitive strings | ✅ Works 3/3 |  |
| Binaries | ✅ Works 3/3 |  |
| Booleans | ✅ Works 2/2 |  |
| Atoms with one_of | ✅ Works 2/2 |  |
| Dates | ✅ Works 3/3 |  |
| Times | ✅ Works 3/3 |  |
| Microsecond times | ✅ Works 3/3 |  |
| UTC datetimes | ✅ Works 3/3 |  |
| Microsecond UTC datetimes | ✅ Works 3/3 |  |
| Naive datetimes | ✅ Works 3/3 |  |
| Durations | ✅ Works 3/3 |  |
| UUIDs | ✅ Works 3/3 |  |
| UUIDv7s | ✅ Works 2/2 |  |
| Maps | ✅ Works 3/3 |  |
| Arrays of strings | ✅ Works 3/3 |  |
| Arrays of integers | ✅ Works 3/3 |  |
| Embedded resources | ✅ Works 3/3 |  |
| Arrays of embedded resources | ✅ Works 3/3 |  |
| Unions | 🟡 Partial 1/2 | `storage.union.ordinary` wrong |

## 2. Records

| Feature | ets | Not working |
| --- | --- | --- |
| Read records | ✅ Works 1/1 |  |
| Get one record by primary key or identity | ✅ Works 2/2 |  |
| Select only some attributes | ✅ Works 2/2 |  |
| Create a record | ✅ Works 1/1 |  |
| Update a record, including to nil | ✅ Works 2/2 |  |
| Destroy a record | ✅ Works 1/1 |  |
| Update a record atomically from its current value | ✅ Works 1/1 |  |
| Not found, invalid, missing and duplicate values are errors | 🟡 Partial 3/4 | `record.identity_conflict` wrong |

## 3. Types

| Feature | ets | Not working |
| --- | --- | --- |
| Strings, integers, booleans, atoms and nil round-trip | ✅ Works 3/3 |  |
| Large integers, floats and decimals round-trip | ✅ Works 2/2 |  |
| Dates, microsecond datetimes and times round-trip | ✅ Works 2/2 |  |
| UUIDs round-trip | ✅ Works 1/1 |  |
| Arrays round-trip, keeping order and duplicates | ✅ Works 1/1 |  |
| Maps round-trip, including nested values | ✅ Works 1/1 |  |
| Embedded resources round-trip | ✅ Works 1/1 |  |

## 4. Querying

| Feature | ets | Not working |
| --- | --- | --- |
| Filter with comparisons on numbers, decimals and dates | ✅ Works 6/6 |  |
| Nil behaves like SQL NULL in filters | ❓ Open question 4/5 | `record.filter_true_or_nil` open question |
| Filter booleans and atoms, including atoms as strings | ✅ Works 3/3 |  |
| Filter strings: contains, case, unicode and empty | ✅ Works 4/4 |  |
| Filter inside arrays, maps and embedded resources | ✅ Works 3/3 |  |
| Filter by a calculation | ✅ Works 1/1 |  |
| Sort by one or more fields, with explicit nil order | ✅ Works 6/6 |  |
| Sort by a calculation | ✅ Works 1/1 |  |
| Limit and offset a query | ✅ Works 1/1 |  |
| Count and check existence | ✅ Works 1/1 |  |
| Stream records in batches | ✅ Works 1/1 |  |
| Distinct records by a field | ✅ Works 1/1 |  |
| Combine queries with union | ✅ Works 1/1 |  |
| Combine queries with union all and intersection | ⚪ Untested |  |
| Load expression calculations, with arguments | ✅ Works 3/3 |  |
| Offset pagination with counts | ✅ Works 1/1 |  |
| Keyset pagination, forwards and backwards | ✅ Works 1/1 |  |
| Pagination while records change | ⚪ Untested |  |

## 5. Relationships

| Feature | ets | Not working |
| --- | --- | --- |
| Filter across to-many relationships without duplicates | ✅ Works 3/3 |  |
| Limit and offset a has-many load for each parent | ✅ Works 2/2 |  |
| Limit a many-to-many load for each parent | ✅ Works 1/1 |  |
| Relationships through other relationships | ✅ Works 1/1 |  |
| Relationship default sort applies when loading | ✅ Works 1/1 |  |
| Relationships with no attributes load everything | ✅ Works 1/1 |  |
| Relationship context reaches the read action | 🟡 Partial 1/2 | `context.relationship_context_control` wrong |
| Parent references in nested and through relationship filters | ❌ Broken 0/2 | `filter.nested_parent_control` wrong, `filter.parent_through_control` wrong |
| Load belongs-to, has-one, has-many and many-to-many relationships | ✅ Works 4/4 |  |
| Create and update related records with manage_relationship | ⚪ Untested |  |

## 6. Aggregates

| Feature | ets | Not working |
| --- | --- | --- |
| Load each aggregate kind on records | 🟡 Partial 8/9 | `loaded.custom` rejected |
| Run each aggregate kind over a whole query | 🟡 Partial 10/15 | `root.custom` rejected, `root.custom_empty` rejected, `root.first` wrong, `root.list` wrong, `root.list_default_empty` wrong |
| Defaults, nils, uniqueness and field counts | 🟡 Partial 11/12 | `values.list_default` wrong |
| Aggregate decimals, dates, times and constrained types | 🟡 Partial 14/15 | `values.constrained_scalar` wrong |
| Order first and list aggregates, including nils and ties | ❓ Open question 8/9 | `ordering.unique_other_field` open question |
| Aggregate calculations and other aggregates | 🟡 Partial 2/3 | `field.root_aggregate` wrong |
| Filter the records an aggregate uses | 🟡 Partial 5/6 | `filter.join` wrong |
| Aggregate filters through to-many relationships count each record once | 🟡 Partial 10/11 | `filter.fanout_custom` rejected |
| Aggregate filters that use other aggregates | ✅ Works 5/5 |  |
| Aggregate filters that reference the parent record | 🟡 Partial 4/8 · 2 blocked | `filter.nested_parent` wrong (blocked by `filter.nested_parent_control`), `filter.parent` wrong, `filter.parent_join` wrong, `filter.parent_through` wrong (blocked by `filter.parent_through_control`) |
| Aggregate over to-one, multi-hop and many-to-many paths | 🟡 Partial 14/17 | `path.final_many_to_many_custom` rejected, `path.repeated_many_to_many` open question, `path.root_relationship` wrong |
| Aggregate over manual and attribute-free relationships | ✅ Works 3/3 |  |
| Aggregate over limited, offset and from-many relationships | 🟡 Partial 6/9 | `bounds.filter_after_limit` wrong, `bounds.list_filter_after_limit` wrong, `bounds.many_to_many_query_limit` open question |
| Root aggregates over sorted, limited and offset queries | 🟡 Partial 6/7 | `bounds.root_custom_limit` rejected |
| Distinct counts over composite and missing keys | 🟡 Partial 1/5 | `identity.composite_count` wrong, `identity.keyless_count` wrong, `identity.keyless_distinct` open question, `identity.root_composite_count` wrong |
| Filter, sort, paginate and calculate with aggregates | ✅ Works 10/10 |  |
| Aggregates respect read actions, arguments, actor and context | 🟡 Partial 8/9 · 1 blocked | `context.relationship_context` wrong (blocked by `context.relationship_context_control`) |
| Seeded filtered aggregates match an in-memory reference | ✅ Works 1/1 |  |

## 7. Writes

| Feature | ets | Not working |
| --- | --- | --- |
| Upsert on an identity, in bulk, with conditions | ✅ Works 4/4 |  |
| Bulk create with partial success | ✅ Works 1/1 |  |
| Bulk update atomically | ✅ Works 1/1 |  |
| Writes that filter by or read aggregates | ✅ Works 4/4 |  |

## 8. Transactions and locks

| Feature | ets | Not working |
| --- | --- | --- |
| Failed actions and transactions roll back | 🟡 Partial 1/4 | `txn.after_action_rollback` wrong, `txn.explicit_rollback` crashed, `txn.raise_rollback` wrong |
| Lock rows for update | ⛔ Not supported 0/1 | `query.lock_for_update` rejected |
| Isolation between concurrent transactions | ⚪ Untested |  |

## 9. Multitenancy

| Feature | ets | Not working |
| --- | --- | --- |
| Attribute tenancy scopes reads and requires a tenant | 🟡 Partial 5/6 | `tenant.invalid` wrong |
| Tenancy scopes related records and their bounds | ✅ Works 4/4 |  |
| Tenancy scopes aggregates, including explicit bypass | 🟡 Partial 6/8 | `context.through_bypass` wrong, `tenant.aggregate_filter_sort` crashed |
| Tenancy scopes pages and counts | ❌ Broken 0/2 | `tenant.aggregate_keyset_pages` crashed, `tenant.aggregate_offset_page` crashed |
| Tenancy scopes creates, updates and destroys | ✅ Works 3/3 |  |
| Schema-based (context) tenancy | ➖ Not applicable |  |

## 10. Authorization

| Feature | ets | Not working |
| --- | --- | --- |
| Policies filter reads | ✅ Works 3/3 |  |
| Policies filter related records before bounds | ✅ Works 5/5 |  |
| Policies filter what aggregates count | 🟡 Partial 7/8 | `auth.aggregate_sort` crashed |
| Policies filter pages and counts | 🟡 Partial 1/3 | `auth.keyset_pages` crashed, `auth.offset_page` crashed |
| Policies filter and forbid writes | ✅ Works 4/4 |  |

## 11. Policies

| Feature | ets | Not working |
| --- | --- | --- |
| A filter policy on the actor | ✅ Works 16/16 |  |
| The same policy with no actor | ✅ Works 16/16 |  |
| forbid_if before authorize_if | ✅ Works 16/16 |  |
| A bypass policy, for an actor it does not let through | ✅ Works 16/16 |  |
| A bypass policy, for an actor it lets through | ✅ Works 13/13 |  |
| Two policies that must both pass | ✅ Works 16/16 |  |
| One policy whose checks either pass | ✅ Works 16/16 |  |
| A policy on a to-one relationship | ✅ Works 16/16 |  |
| A policy on a multi-hop exists | ✅ Works 16/16 |  |
| A policy composed with can_read | ✅ Works 16/16 |  |
| A strict policy, for an actor it forbids | ✅ Works 16/16 |  |
| A strict policy, for an actor it allows | ✅ Works 13/13 |  |
| Field policies hide values, in reads, filters and aggregates | ✅ Works 4/4 |  |
| A filter check on create runs after the insert | ❌ Broken 0/2 | `policy.owner.create_other` wrong, `policy.owner.create_own` wrong |
| Every policy path, without authorization | ✅ Works 22/22 |  |

## 12. Consistency checks

| Feature | ets | Not working |
| --- | --- | --- |
| Counts match loads, and root sums match an in-memory reference | ✅ Works 2/2 |  |

## Claims versus results

A data layer's `can?/2` claims never decide what runs. This lists features
whose claims disagree with the result:

- advertised, but not working;
- working without being advertised, usually because Ash provides it;
- not advertised, yet not rejected, and giving wrong answers.

| Feature | Adapter | Mismatch |
| --- | --- | --- |
| Select only some attributes | ets | Works without advertising `record: :select` |
| Stream records in batches | ets | Works without advertising `record: :keyset` |
| Keyset pagination, forwards and backwards | ets | Works without advertising `record: :keyset` |
| Parent references in nested and through relationship filters | ets | Advertised, but ❌ Broken |
| Upsert on an identity, in bulk, with conditions | ets | Works without advertising `tenant_item: :bulk_upsert_return_skipped` |
| Bulk create with partial success | ets | Works without advertising `tenant_item: :bulk_create_with_partial_success` |
| Tenancy scopes pages and counts | ets | Not advertising `tenant_parent: :keyset`, but not rejected either: wrong answers |
| A filter check on create runs after the insert | ets | Not advertising `policy_owner_note: :transact`, but not rejected either: wrong answers |


## Storage

Each cell shows the ordinary, edge and nil values, in that order. ✅ reads
back unchanged; ≈ reads back equal but in another representation, such as
`1.5` as `1.5000000000`; ❌ is lost or rejected; 🚫 the table could not be
created; 🔀 differs between seed orders; ❔ did not run; – the type has no
values of that class.

| Type | Column | Ordinary | Edge | Nil | First problem |
| --- | --- | --- | --- | --- | --- |
| Integers | `—` | ✅ | ✅ | ✅ |  |
| Floats | `—` | ✅ | ✅ | ✅ |  |
| Decimals | `—` | ✅ | ✅ | ✅ |  |
| Strings | `—` | ✅ | ✅ | ✅ |  |
| Case-insensitive strings | `—` | ✅ | ✅ | ✅ |  |
| Binaries | `—` | ✅ | ✅ | ✅ |  |
| Booleans | `—` | ✅ | – | ✅ |  |
| Atoms with one_of | `—` | ✅ | – | ✅ |  |
| Dates | `—` | ✅ | ✅ | ✅ |  |
| Times | `—` | ✅ | ✅ | ✅ |  |
| Microsecond times | `—` | ✅ | ✅ | ✅ |  |
| UTC datetimes | `—` | ✅ | ✅ | ✅ |  |
| Microsecond UTC datetimes | `—` | ✅ | ✅ | ✅ |  |
| Naive datetimes | `—` | ✅ | ✅ | ✅ |  |
| Durations | `—` | ✅ | ✅ | ✅ |  |
| UUIDs | `—` | ✅ | ✅ | ✅ |  |
| UUIDv7s | `—` | ✅ | – | ✅ |  |
| Maps | `—` | ✅ | ✅ | ✅ |  |
| Arrays of strings | `—` | ✅ | ✅ | ✅ |  |
| Arrays of integers | `—` | ✅ | ✅ | ✅ |  |
| Embedded resources | `—` | ✅ | ✅ | ✅ |  |
| Arrays of embedded resources | `—` | ✅ | ✅ | ✅ |  |
| Unions | `—` | ❌ | – | ✅ | ordinary, clear: %Ash.Union{value: nil, type: :text} |

## Policies

✅ returns the answer Ash's policy semantics define; ❌ does not, while the
same path works without authorization; ◌ the path fails even without
authorization, so the policy cannot be judged; ❔ did not run; – does not
apply, such as getting a hidden record when the actor may read every note.

| Case | `read` | `get_hidden` | `get_error` | `count` | `sum` | `offset_page` | `keyset_pages` | `load` | `loaded_count` | `loaded_sum` | `aggregate_filter` | `exists_filter` | `exists_filter_input` | `bulk_update` | `bulk_destroy` | `update_hidden` | `field_read` | `field_filter` | `field_filter_input` | `field_aggregate` | `create_own` | `create_other` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| owner | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | ❌ | ❌ |
| owner_nil_actor | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| forbid | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| bypass | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| bypass_admin | ✅ | – | – | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – | – |
| all_of | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| any_of | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| related | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| member | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| can_read | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| strict | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| strict_admin | ✅ | – | – | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – | – |
| field | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | ✅ | ✅ | ✅ | ✅ | – | – |
| control (no authorization) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

## Blockers

| Blocker | Its result | Not run | Failing | Only blocker of |
| --- | --- | ---: | ---: | ---: |
| `context.relationship_context_control` | wrong | 0 | 1 | 1 |
| `filter.nested_parent_control` | wrong | 0 | 1 | 1 |
| `filter.parent_through_control` | wrong | 0 | 1 | 1 |
