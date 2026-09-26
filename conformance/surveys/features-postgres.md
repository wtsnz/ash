<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# What each data layer supports

Generated from an unreviewed run: each result was classified automatically against the intended answer. Nothing here has been reviewed.

Feature catalog version 1: 141 features and 732 scenarios.

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

| Feature | postgres | Not working |
| --- | --- | --- |
| Integers | ✅ Works 3/3 |  |
| Floats | ✅ Works 3/3 |  |
| Decimals | ✅ Works 3/3 |  |
| Strings | 🟡 Partial 2/3 | `storage.string.edge` wrong |
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
| Durations | 🟡 Partial 1/3 | `storage.duration.edge` wrong, `storage.duration.ordinary` wrong |
| UUIDs | ✅ Works 3/3 |  |
| UUIDv7s | ✅ Works 2/2 |  |
| Maps | ✅ Works 3/3 |  |
| Arrays of strings | ✅ Works 3/3 |  |
| Arrays of integers | ✅ Works 3/3 |  |
| Embedded resources | ✅ Works 3/3 |  |
| Arrays of embedded resources | ✅ Works 3/3 |  |
| Unions | 🟡 Partial 1/2 | `storage.union.ordinary` wrong |

## 2. Operations on each type

| Feature | postgres | Not working |
| --- | --- | --- |
| Integers | ✅ Works 10/10 |  |
| Floats | ✅ Works 10/10 |  |
| Decimals | ✅ Works 10/10 |  |
| Strings | ✅ Works 9/9 |  |
| Case-insensitive strings | ✅ Works 9/9 |  |
| Binaries | ✅ Works 5/5 |  |
| Booleans | ✅ Works 5/5 |  |
| Atoms with one_of | ✅ Works 5/5 |  |
| Dates | ✅ Works 9/9 |  |
| Times | ✅ Works 9/9 |  |
| Microsecond times | ✅ Works 9/9 |  |
| UTC datetimes | ✅ Works 9/9 |  |
| Microsecond UTC datetimes | ✅ Works 9/9 |  |
| Naive datetimes | ✅ Works 9/9 |  |
| Durations | ✅ Works 5/5 |  |
| UUIDs | ✅ Works 5/5 |  |
| UUIDv7s | ✅ Works 5/5 |  |
| Maps | ✅ Works 3/3 |  |
| Arrays of strings | ✅ Works 3/3 |  |
| Arrays of integers | ✅ Works 3/3 |  |
| Embedded resources | ✅ Works 3/3 |  |
| Arrays of embedded resources | ✅ Works 3/3 |  |
| Unions | ✅ Works 3/3 |  |

## 3. Records

| Feature | postgres | Not working |
| --- | --- | --- |
| Read records | ✅ Works 1/1 |  |
| Get one record by primary key or identity | ✅ Works 2/2 |  |
| Select only some attributes | ✅ Works 2/2 |  |
| Create a record | ✅ Works 1/1 |  |
| Update a record, including to nil | ✅ Works 2/2 |  |
| Destroy a record | ✅ Works 1/1 |  |
| Update a record atomically from its current value | ✅ Works 1/1 |  |
| Not found, invalid, missing and duplicate values are errors | ✅ Works 4/4 |  |

## 4. Types

| Feature | postgres | Not working |
| --- | --- | --- |
| Strings, integers, booleans, atoms and nil round-trip | ✅ Works 3/3 |  |
| Large integers, floats and decimals round-trip | ✅ Works 2/2 |  |
| Dates, microsecond datetimes and times round-trip | ✅ Works 2/2 |  |
| UUIDs round-trip | ✅ Works 1/1 |  |
| Arrays round-trip, keeping order and duplicates | ✅ Works 1/1 |  |
| Maps round-trip, including nested values | ✅ Works 1/1 |  |
| Embedded resources round-trip | ✅ Works 1/1 |  |

## 5. Querying

| Feature | postgres | Not working |
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

## 6. Relationships

| Feature | postgres | Not working |
| --- | --- | --- |
| Filter across to-many relationships without duplicates | ✅ Works 3/3 |  |
| Limit and offset a has-many load for each parent | ✅ Works 2/2 |  |
| Limit a many-to-many load for each parent | ✅ Works 1/1 |  |
| Relationships through other relationships | ✅ Works 1/1 |  |
| Relationship default sort applies when loading | ✅ Works 1/1 |  |
| Relationships with no attributes load everything | ✅ Works 1/1 |  |
| Relationship context reaches the read action | 🟡 Partial 1/2 | `context.relationship_context_control` wrong |
| Parent references in nested and through relationship filters | ❌ Broken 0/2 | `filter.nested_parent_control` crashed, `filter.parent_through_control` crashed |
| Load belongs-to, has-one, has-many and many-to-many relationships | ✅ Works 4/4 |  |
| Create and update related records with manage_relationship | ⚪ Untested |  |

## 7. Aggregates

| Feature | postgres | Not working |
| --- | --- | --- |
| Load each aggregate kind on records | ✅ Works 9/9 |  |
| Run each aggregate kind over a whole query | 🟡 Partial 13/15 | `root.list_unsorted` wrong, `root.unsorted_first_empty` crashed |
| Defaults, nils, uniqueness and field counts | 🟡 Partial 11/12 | `values.list_unsorted` wrong |
| Aggregate decimals, dates, times and constrained types | ✅ Works 15/15 |  |
| Order first and list aggregates, including nils and ties | ❓ Open question 8/9 | `ordering.unique_other_field` open question |
| Aggregate calculations and other aggregates | ✅ Works 3/3 |  |
| Filter the records an aggregate uses | ✅ Works 6/6 |  |
| Aggregate filters through to-many relationships count each record once | 🟡 Partial 2/11 | `filter.fanout_and` wrong, `filter.fanout_avg` wrong, `filter.fanout_count` wrong, `filter.fanout_count_records` wrong, `filter.fanout_custom` wrong, `filter.fanout_list` wrong, `filter.fanout_or` wrong, `filter.fanout_sum` wrong, `identity.composite_fanout_count` wrong |
| Aggregate filters that use other aggregates | ✅ Works 5/5 |  |
| Aggregate filters that reference the parent record | 🟡 Partial 7/8 · 1 blocked | `filter.nested_parent` crashed (blocked by `filter.nested_parent_control`) |
| Aggregate over to-one, multi-hop and many-to-many paths | 🟡 Partial 15/17 | `path.repeated_many_to_many` open question, `path.root_relationship` crashed |
| Aggregate over manual and attribute-free relationships | 🟡 Partial 2/3 | `path.no_attributes` crashed |
| Aggregate over limited, offset and from-many relationships | 🟡 Partial 6/9 | `bounds.default_sort` wrong, `bounds.from_many` wrong, `bounds.many_to_many_query_limit` open question |
| Root aggregates over sorted, limited and offset queries | 🟡 Partial 2/7 | `bounds.root_custom_limit` wrong, `bounds.root_first_distinct_sort` wrong, `bounds.root_list_limit` wrong, `bounds.root_offset_only` crashed, `bounds.root_order_then_limit` wrong |
| Distinct counts over composite and missing keys | ❓ Open question 4/5 | `identity.keyless_distinct` open question |
| Filter, sort, paginate and calculate with aggregates | ✅ Works 10/10 |  |
| Aggregates respect read actions, arguments, actor and context | 🟡 Partial 7/9 · 1 blocked | `context.prepared_query_arguments` crashed, `context.relationship_context` wrong (blocked by `context.relationship_context_control`) |
| Seeded filtered aggregates match an in-memory reference | ✅ Works 1/1 |  |

## 8. Writes

| Feature | postgres | Not working |
| --- | --- | --- |
| Upsert on an identity, in bulk, with conditions | 🟡 Partial 3/4 | `upsert.skipped_record` wrong |
| Bulk create with partial success | ✅ Works 1/1 |  |
| Bulk update atomically | ✅ Works 1/1 |  |
| Writes that filter by or read aggregates | ✅ Works 4/4 |  |

## 9. Transactions and locks

| Feature | postgres | Not working |
| --- | --- | --- |
| Failed actions and transactions roll back | ✅ Works 4/4 |  |
| Lock rows for update | ✅ Works 1/1 |  |
| Isolation between concurrent transactions | ⚪ Untested |  |

## 10. Multitenancy

| Feature | postgres | Not working |
| --- | --- | --- |
| Attribute tenancy scopes reads and requires a tenant | ✅ Works 6/6 |  |
| Tenancy scopes related records and their bounds | ✅ Works 4/4 |  |
| Tenancy scopes aggregates, including explicit bypass | 🟡 Partial 5/8 | `context.bypass_sibling` wrong, `context.tenant_bypass` wrong, `context.through_bypass` wrong |
| Tenancy scopes pages and counts | ✅ Works 2/2 |  |
| Tenancy scopes creates, updates and destroys | ✅ Works 3/3 |  |
| Schema-based (context) tenancy | ✅ Works 5/5 |  |

## 11. Authorization

| Feature | postgres | Not working |
| --- | --- | --- |
| Policies filter reads | ✅ Works 3/3 |  |
| Policies filter related records before bounds | ✅ Works 5/5 |  |
| Policies filter what aggregates count | 🟡 Partial 7/8 | `context.authorization_before_bounds` wrong |
| Policies filter pages and counts | ✅ Works 3/3 |  |
| Policies filter and forbid writes | ✅ Works 4/4 |  |

## 12. Policies

| Feature | postgres | Not working |
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
| A filter check on create runs after the insert | ✅ Works 2/2 |  |
| Every policy path, without authorization | ✅ Works 22/22 |  |

## 13. Consistency checks

| Feature | postgres | Not working |
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
| Stream records in batches | postgres | Works without advertising `record: :keyset` |
| Keyset pagination, forwards and backwards | postgres | Works without advertising `record: :keyset` |
| Parent references in nested and through relationship filters | postgres | Advertised, but ❌ Broken |
| Bulk create with partial success | postgres | Works without advertising `tenant_item: :bulk_create_with_partial_success` |
| Tenancy scopes pages and counts | postgres | Works without advertising `tenant_parent: :keyset` |


## Storage

Each cell shows the ordinary, edge and nil values, in that order. ✅ reads
back unchanged; ≈ reads back equal but in another representation, such as
`1.5` as `1.5000000000`; ❌ is lost or rejected; 🚫 the table could not be
created; 🔀 differs between seed orders; ❔ did not run; – the type has no
values of that class.

| Type | Column | Ordinary | Edge | Nil | First problem |
| --- | --- | --- | --- | --- | --- |
| Integers | `:bigint` | ✅ | ✅ | ✅ |  |
| Floats | `:float` | ✅ | ✅ | ✅ |  |
| Decimals | `:decimal` | ✅ | ✅ | ✅ |  |
| Strings | `:text` | ✅ | ❌ | ✅ | edge, create: invalid byte sequence for encoding "UTF8": 0x00 |
| Case-insensitive strings | `:citext` | ✅ | ✅ | ✅ |  |
| Binaries | `:binary` | ✅ | ✅ | ✅ |  |
| Booleans | `:boolean` | ✅ | – | ✅ |  |
| Atoms with one_of | `:text` | ✅ | – | ✅ |  |
| Dates | `:date` | ✅ | ✅ | ✅ |  |
| Times | `:time` | ✅ | ✅ | ✅ |  |
| Microsecond times | `:time_usec` | ✅ | ✅ | ✅ |  |
| UTC datetimes | `:utc_datetime` | ✅ | ✅ | ✅ |  |
| Microsecond UTC datetimes | `:utc_datetime_usec` | ✅ | ✅ | ✅ |  |
| Naive datetimes | `:naive_datetime` | ✅ | ✅ | ✅ |  |
| Durations | `:duration` | ≈ | ≈ | ✅ | ordinary, read: %Duration{hour: 1, minute: 30, microsecond: {0, 6}} |
| UUIDs | `:uuid` | ✅ | ✅ | ✅ |  |
| UUIDv7s | `:uuid` | ✅ | – | ✅ |  |
| Maps | `:map` | ✅ | ✅ | ✅ |  |
| Arrays of strings | `{:array, :text}` | ✅ | ✅ | ✅ |  |
| Arrays of integers | `{:array, :bigint}` | ✅ | ✅ | ✅ |  |
| Embedded resources | `:map` | ✅ | ✅ | ✅ |  |
| Arrays of embedded resources | `{:array, :map}` | ✅ | ✅ | ✅ |  |
| Unions | `:map` | ❌ | – | ✅ | ordinary, clear: %Ash.Union{value: nil, type: :text} |

## Operations

✅ returns the answer Ash defines; ❌ does not, while the same operation
works on integers and the type stores; ◌ blocked: the operation fails on
integers too, or the type does not store; ❔ did not run; – does not apply
to the type.

| Type | `eq` | `in` | `is_nil` | `gt` | `sort` | `count` | `min` | `max` | `sum` | `first` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Integers | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Floats | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Decimals | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Strings | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | ✅ |
| Case-insensitive strings | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | ✅ |
| Binaries | ✅ | ✅ | ✅ | – | – | ✅ | – | – | – | ✅ |
| Booleans | ✅ | ✅ | ✅ | – | – | ✅ | – | – | – | ✅ |
| Atoms with one_of | ✅ | ✅ | ✅ | – | – | ✅ | – | – | – | ✅ |
| Dates | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | ✅ |
| Times | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | ✅ |
| Microsecond times | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | ✅ |
| UTC datetimes | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | ✅ |
| Microsecond UTC datetimes | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | ✅ |
| Naive datetimes | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | ✅ |
| Durations | ✅ | ✅ | ✅ | – | – | ✅ | – | – | – | ✅ |
| UUIDs | ✅ | ✅ | ✅ | – | – | ✅ | – | – | – | ✅ |
| UUIDv7s | ✅ | ✅ | ✅ | – | – | ✅ | – | – | – | ✅ |
| Maps | – | – | ✅ | – | – | ✅ | – | – | – | ✅ |
| Arrays of strings | – | – | ✅ | – | – | ✅ | – | – | – | ✅ |
| Arrays of integers | – | – | ✅ | – | – | ✅ | – | – | – | ✅ |
| Embedded resources | – | – | ✅ | – | – | ✅ | – | – | – | ✅ |
| Arrays of embedded resources | – | – | ✅ | – | – | ✅ | – | – | – | ✅ |
| Unions | – | – | ✅ | – | – | ✅ | – | – | – | ✅ |

## Policies

✅ returns the answer Ash's policy semantics define; ❌ does not, while the
same path works without authorization; ◌ the path fails even without
authorization, so the policy cannot be judged; ❔ did not run; – does not
apply, such as getting a hidden record when the actor may read every note.

| Case | `read` | `get_hidden` | `get_error` | `count` | `sum` | `offset_page` | `keyset_pages` | `load` | `loaded_count` | `loaded_sum` | `aggregate_filter` | `exists_filter` | `exists_filter_input` | `bulk_update` | `bulk_destroy` | `update_hidden` | `field_read` | `field_filter` | `field_filter_input` | `field_aggregate` | `create_own` | `create_other` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| owner | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | ✅ | ✅ |
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
| `filter.nested_parent_control` | crashed | 0 | 1 | 1 |
