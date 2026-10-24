<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# What each data layer supports

Generated from an unreviewed run: each result was classified automatically against the intended answer. Nothing here has been reviewed.

Feature catalog version 1: 172 features and 1395 scenarios.

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
| ➖ Not applicable | The data layer does not run these scenarios: a storage profile or fixture it does not opt in to, such as the combination grid, which runs on SQLite and Postgres. |
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
| Integers | ✅ Works 20/20 |  |
| Floats | ✅ Works 20/20 |  |
| Decimals | ✅ Works 20/20 |  |
| Strings | ✅ Works 18/18 |  |
| Case-insensitive strings | ✅ Works 18/18 |  |
| Binaries | ✅ Works 10/10 |  |
| Booleans | ✅ Works 5/5 |  |
| Atoms with one_of | ✅ Works 5/5 |  |
| Dates | ✅ Works 18/18 |  |
| Times | ✅ Works 18/18 |  |
| Microsecond times | ✅ Works 18/18 |  |
| UTC datetimes | ✅ Works 18/18 |  |
| Microsecond UTC datetimes | ✅ Works 18/18 |  |
| Naive datetimes | ✅ Works 18/18 |  |
| Durations | ✅ Works 10/10 |  |
| UUIDs | ✅ Works 10/10 |  |
| UUIDv7s | ✅ Works 5/5 |  |
| Maps | ✅ Works 6/6 |  |
| Arrays of strings | ✅ Works 6/6 |  |
| Arrays of integers | ✅ Works 6/6 |  |
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
| Arithmetic and rounding, with integer division as a float | ✅ Works 10/10 |  |
| String functions, including non-ASCII text | ✅ Works 11/11 |  |
| if, cond, || and && | ✅ Works 5/5 |  |
| Date and datetime arithmetic | ✅ Works 5/5 |  |
| Every signature of the date and time functions, including Duration forms | 🟡 Partial 14/16 | `sig.start_of_day.date_zone` wrong, `sig.start_of_day.datetime_zone` wrong |
| Every signature of the list, map, nil, conditional and type functions | ✅ Works 14/14 |  |
| Every signature of the string functions, with case-insensitive strings | 🟡 Partial 28/38 | `sig.string_position.string_ci` wrong, `sig.string_split.ci` wrong, `sig.string_split.ci_ci` wrong, `sig.string_split.ci_ci_trim` wrong, `sig.string_split.ci_separator` wrong, `sig.string_split.ci_separator_trim` wrong, `sig.string_split.ci_trim` wrong, `sig.string_split.default` wrong, `sig.string_split.separator` wrong, `sig.string_split.trim` wrong |
| Every signature of negation, rem and round | ✅ Works 8/8 |  |
| Every typed signature of <>, /, *, - and +, including date and time arithmetic | 🟡 Partial 37/46 | `sig.div.decimal_decimal` crashed, `sig.div.float_decimal` crashed, `sig.div.integer_decimal` crashed, `sig.minus.datetime_datetime` crashed, `sig.minus.naive_naive` crashed, `sig.minus.time_time` crashed, `sig.minus.time_usec_time_usec` crashed, `sig.minus.usec_usec` crashed, `sig.minus.utc_datetime_utc_datetime` crashed |
| Functions on unusual values: decomposed Unicode, whitespace, empty lists, overflow and halves | 🟡 Partial 13/16 | `edge.at.negative_index` open question, `edge.plus.integer_overflow` open question, `edge.string_length.graphemes` crashed |
| Negation, column comparisons and and/or with nil | 🟡 Partial 10/13 | `nil.not_contradictory_in` wrong, `nil.not_in_with_nil` open question, `nil.or` open question |
| Filters through to-many relationships return each record once | ✅ Works 9/9 |  |
| Sort by a related record's attribute | ✅ Works 1/1 |  |
| Calculations feed aggregates, filters and sorts | ✅ Works 5/5 |  |
| Filter by a calculation | ✅ Works 1/1 |  |
| Sort by one or more fields, with explicit nil order | ✅ Works 6/6 |  |
| Sort by a calculation | ✅ Works 1/1 |  |
| Limit and offset a query | ✅ Works 1/1 |  |
| Count and check existence | ✅ Works 1/1 |  |
| Stream records in batches | ✅ Works 1/1 |  |
| Distinct records by a field | ✅ Works 1/1 |  |
| Combine queries with union | ✅ Works 1/1 |  |
| Combine queries with union all, intersect and except | ✅ Works 3/3 |  |
| Load expression calculations, with arguments | ✅ Works 3/3 |  |
| Offset pagination with counts | ✅ Works 1/1 |  |
| Keyset pagination, forwards and backwards | ✅ Works 1/1 |  |
| Keyset pagination on nullable, duplicate, descending and calculated keys | ✅ Works 5/5 |  |
| Long in-lists, bulk creates past parameter limits, deep pages and aggregates over thousands of rows | 🟡 Partial 5/6 | `large.bulk_create_parameters` wrong |
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
| Create and update related records with manage_relationship | ✅ Works 2/2 |  |

## 7. Aggregates

| Feature | postgres | Not working |
| --- | --- | --- |
| Load each aggregate kind on records | ✅ Works 9/9 |  |
| Run each aggregate kind over a whole query | 🟡 Partial 14/15 | `root.list_unsorted` wrong |
| Defaults, nils, uniqueness and field counts | 🟡 Partial 11/12 | `values.list_unsorted` wrong |
| Aggregate decimals, dates, times and constrained types | ❓ Open question 14/15 | `values.decimal_avg` open question |
| Order first and list aggregates, including nils and ties | ❓ Open question 8/9 | `ordering.unique_other_field` open question |
| Aggregate calculations and other aggregates | ✅ Works 3/3 |  |
| Filter the records an aggregate uses | ✅ Works 6/6 |  |
| Aggregate filters through to-many relationships count each record once | 🟡 Partial 2/11 | `filter.fanout_and` wrong, `filter.fanout_avg` wrong, `filter.fanout_count` wrong, `filter.fanout_count_records` wrong, `filter.fanout_custom` wrong, `filter.fanout_list` wrong, `filter.fanout_or` wrong, `filter.fanout_sum` wrong, `identity.composite_fanout_count` wrong |
| Aggregate filters that use other aggregates | ✅ Works 5/5 |  |
| Aggregate filters that reference the parent record | 🟡 Partial 7/8 · 1 blocked | `filter.nested_parent` crashed (blocked by `filter.nested_parent_control`) |
| Aggregate over to-one, multi-hop and many-to-many paths | 🟡 Partial 15/17 | `path.repeated_many_to_many` open question, `path.root_relationship` crashed |
| Aggregate over manual and attribute-free relationships | 🟡 Partial 2/3 | `path.no_attributes` crashed |
| Aggregate over limited, offset and from-many relationships | 🟡 Partial 6/9 | `bounds.default_sort` order dependent, `bounds.from_many` wrong, `bounds.many_to_many_query_limit` open question |
| Root aggregates over sorted, limited and offset queries | 🟡 Partial 2/7 | `bounds.root_custom_limit` order dependent, `bounds.root_first_distinct_sort` order dependent, `bounds.root_list_limit` order dependent, `bounds.root_offset_only` crashed, `bounds.root_order_then_limit` order dependent |
| Distinct counts over composite and missing keys | ❓ Open question 4/5 | `identity.keyless_distinct` open question |
| Filter, sort, paginate and calculate with aggregates | ✅ Works 10/10 |  |
| Aggregates respect read actions, arguments, actor and context | 🟡 Partial 7/9 · 1 blocked | `context.prepared_query_arguments` crashed, `context.relationship_context` wrong (blocked by `context.relationship_context_control`) |
| Seeded filtered aggregates match an in-memory reference | ✅ Works 23/23 |  |

## 8. Writes

| Feature | postgres | Not working |
| --- | --- | --- |
| Upsert on an identity, in bulk, with conditions | 🟡 Partial 3/4 | `upsert.skipped_record` order dependent |
| Identities and upserts on keys that can be nil, and upsert fields | ✅ Works 5/5 |  |
| Bulk create with partial success | ✅ Works 1/1 |  |
| Bulk update atomically | ✅ Works 1/1 |  |
| Writes that filter by or read aggregates | ✅ Works 4/4 |  |
| Atomic updates with expressions, and bulk writes over sorted, limited queries | ✅ Works 4/4 |  |

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

## 13. Combinations

| Feature | postgres | Not working |
| --- | --- | --- |
| Each combined feature works on its own | ✅ Works 14/14 |  |
| Features work together, pair by pair | 🟡 Partial 16/17 | `combo.list.top_items.value_gt.global.actor.loaded` wrong |
| Aggregates and exists over paths of one to three hops, on integer and UUID keys | ✅ Works 174/174 |  |
| Sorting by the destination's aggregate inside a path | ✅ Works 4/4 |  |
| Calculations over a related field keep records whose related record is missing | ✅ Works 8/8 |  |

## 14. Consistency checks

| Feature | postgres | Not working |
| --- | --- | --- |
| Counts match loads, and root sums match an in-memory reference | ✅ Works 2/2 |  |

## 15. Adversarial invariants

| Feature | postgres | Not working |
| --- | --- | --- |
| Tenancy scopes many_to_many and through loads, aggregates and filters | 🟡 Partial 7/17 | `adv.tenant.has_one_limit` wrong, `adv.tenant.has_one_sorted` wrong, `adv.tenant.has_one_unsorted` wrong, `adv.tenant.m2m_limit_one` wrong, `adv.tenant.m2m_load` wrong, `adv.tenant.through_limit_one` wrong, `adv.tenant.through_load` wrong, `adv.tenant.through_long_load` wrong, `adv.tenant.through_many_to_many_load` wrong, `adv.tenant.through_offset` wrong |
| Schema-based tenancy scopes the same paths | 🟡 Partial 2/6 | `adv.schema.m2m_aggregates` wrong, `adv.schema.m2m_exists` wrong, `adv.schema.through_limit_one` wrong, `adv.schema.through_load` crashed |
| Bounded through loads keep their path | 🟡 Partial 5/8 | `adv.plain.has_one_limit` wrong, `adv.plain.through_limit_one` wrong, `adv.plain.through_offset` wrong |
| The join resource's read policy applies to loads, aggregates and input filters | 🟡 Partial 5/11 | `adv.join_policy.m2m_aggregate_filter` wrong, `adv.join_policy.m2m_aggregates` wrong, `adv.join_policy.m2m_exists_aggregate` wrong, `adv.join_policy.m2m_filter_input` wrong, `adv.join_policy.through_aggregates` wrong, `adv.join_policy.through_exists_aggregate` wrong |
| Updates and destroys given another tenant's records change nothing of it | 🟡 Partial 7/13 | `adv.foreign.bulk_destroy.fallback` wrong, `adv.foreign.bulk_destroy.stream` wrong, `adv.foreign.bulk_update.fallback` wrong, `adv.foreign.bulk_update.stream` wrong, `adv.foreign.bulk_update.stream_global_records` wrong, `adv.foreign.destroy_changeset` wrong |
| Upserts stay in their tenant | 🟡 Partial 3/6 | `adv.upsert.all_tenants` open question, `adv.upsert.all_tenants_skipped_bulk` open question, `adv.upsert.skipped_bulk` order dependent |
| Field policies apply to write results, embedded values included | 🟡 Partial 3/11 | `adv.field_write.bulk_create` wrong, `adv.field_write.bulk_destroy.atomic` wrong, `adv.field_write.bulk_update.atomic` wrong, `adv.field_write.bulk_update.atomic_batches` wrong, `adv.field_write.create` wrong, `adv.field_write.destroy` wrong, `adv.field_write.update` wrong, `adv.field_write.update_load` wrong |
| manage_relationship can't relate another tenant's or a hidden record | ✅ Works 4/4 |  |


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
| Keyset pagination on nullable, duplicate, descending and calculated keys | postgres | Works without advertising `record: :keyset` |
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
integers too, or the type does not store; 🔀 the answer changes with the
order rows were stored in; ❔ did not run; – does not apply to the type.

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
authorization, so the policy cannot be judged; 🔀 the answer changes with
the order rows were stored in; ❔ did not run; – does not apply, such as
getting a hidden record when the actor may read every note.

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

## Combinations

✅ returns the answer Ash defines; ❌ does not, while each feature it
combines works alone; ◌ blocked: one of those features fails alone; 🔀 the
answer changes with the order rows were stored in; ❔ did not run.

| kind | relationship | filter | tenant | policy | use | Result |
| --- | --- | --- | --- | --- | --- | --- |
| `sum` | `top_items` | `none` | `tenant` | `off` | `page` | ✅ |
| `max` | `linked_items` | `none` | `global` | `off` | `filter` | ✅ |
| `exists` | `items` | `none` | `tenant` | `off` | `sort` | ✅ |
| `sum` | `linked_items` | `open` | `tenant` | `actor` | `loaded` | ✅ |
| `count` | `top_items` | `open` | `global` | `off` | `sort` | ✅ |
| `exists` | `items` | `open` | `global` | `actor` | `filter` | ✅ |
| `max` | `items` | `open` | `global` | `actor` | `page` | ✅ |
| `list` | `top_items` | `value_gt` | `global` | `actor` | `loaded` | ❌ |
| `count` | `linked_items` | `value_gt` | `tenant` | `off` | `page` | ✅ |
| `sum` | `items` | `value_gt` | `global` | `off` | `filter` | ✅ |
| `max` | `top_items` | `value_gt` | `tenant` | `actor` | `sort` | ✅ |
| `count` | `top_items` | `none` | `tenant` | `off` | `filter` | ✅ |
| `exists` | `top_items` | `value_gt` | `global` | `off` | `loaded` | ✅ |
| `exists` | `linked_items` | `none` | `global` | `off` | `page` | ✅ |
| `list` | `items` | `none` | `tenant` | `off` | `page` | ✅ |
| `list` | `linked_items` | `open` | `global` | `off` | `loaded` | ✅ |
| `sum` | `linked_items` | `none` | `global` | `off` | `sort` | ✅ |

## Decoy variant

Every scenario also runs with a hidden copy of each fixture row stored
next to the real ones: in a mirror tenant, with colliding local ids, where
the table is multitenant by attribute, and otherwise with a reserved id a
read policy hides (`Ash.Conformance.Decoy`). An issue is a decoy in the
answer (leaked), or an answer that was right and changes with decoys
(influenced); a decoy error needs triage. Each needs a recorded gap. Hints
are guesses from the direction of the change.

**13 issues** (0 leaked, 13 influenced; 0 unrecorded) · 24 need triage (0 unrecorded) · the rest clean: 1043 same, 6 base failing, 309 opted out, 0 not run.

| Scenario | Status | Hint | Diff | Gap |
| --- | --- | --- | --- | --- |
| `bounds.filter_after_limit` | influenced | hidden rows took limit/offset slots? | `1: 2 → nil` | [Authorization bounds](GAPS.md#authorization-bounds) |
| `bounds.list_filter_after_limit` | influenced | hidden rows took limit/offset slots? | `1: [2] → []` | [Authorization bounds](GAPS.md#authorization-bounds) |
| `bounds.relationship_limit` | influenced | hidden rows took limit/offset slots? | `1: 9 → nil` | [Authorization bounds](GAPS.md#authorization-bounds) |
| `bounds.relationship_offset` | influenced |  | `1: 2 → nil, 2: nil → 4` | [Authorization bounds](GAPS.md#authorization-bounds) |
| `bounds.relationship_offset_only` | influenced | counts hidden rows? | `1: 4 → 11, 2: nil → 4` | [Authorization bounds](GAPS.md#authorization-bounds) |
| `bounds.unsorted_limit` | influenced | hidden rows took limit/offset slots? | `1: 1 → 0, 2: 1 → 0` | [Authorization bounds](GAPS.md#authorization-bounds) |
| `field.root_aggregate` | influenced | counts hidden rows? | `5 → 10` | [Aggregate reference authorization](GAPS.md#aggregate-reference-authorization) |
| `filter.aggregate_dependency` | influenced | counts hidden rows? | `1: 1 → 3` | [Aggregate reference authorization](GAPS.md#aggregate-reference-authorization) |
| `filter.aggregate_dependency_calculation` | influenced | counts hidden rows? | `1: 1 → 3` | [Aggregate reference authorization](GAPS.md#aggregate-reference-authorization) |
| `filter.aggregate_dependency_filtered` | influenced | counts hidden rows? | `1: 2 → 4` | [Aggregate reference authorization](GAPS.md#aggregate-reference-authorization) |
| `write.atomic_update` | influenced | counts hidden rows? | `[0] #1: 4 → 8, [1] #1: 1 → 2` | [Aggregate reference authorization](GAPS.md#aggregate-reference-authorization) |
| `write.bulk_update_filter` | influenced |  | `[1] #1: "beta" → "big"` | [Aggregate reference authorization](GAPS.md#aggregate-reference-authorization) |
| `write.single_atomic_update` | influenced | counts hidden rows? | `1 → 2` | [Aggregate reference authorization](GAPS.md#aggregate-reference-authorization) |

Need triage: the scenario's own run is right, and with decoys it raises. Scenarios with the same error and gap share a row.

| Scenario | Error | Gap |
| --- | --- | --- |
| `shape.exists.integer.depth_2.constant.filter` and 5 more | `Ash.Error.Unknown: ** (RuntimeError) no such relationship Ash.Conformance.Postgres.ShapeIntegerLeaf.integer_mids` | [Exists path authorization](GAPS.md#exists-path-authorization) |
| `shape.exists.integer.depth_3.constant.filter` and 5 more | `Ash.Error.Unknown: ** (RuntimeError) no such relationship Ash.Conformance.Postgres.ShapeIntegerTip.integer_mids` | [Exists path authorization](GAPS.md#exists-path-authorization) |
| `shape.exists.uuid.depth_2.constant.filter` and 5 more | `Ash.Error.Unknown: ** (RuntimeError) no such relationship Ash.Conformance.Postgres.ShapeUuidLeaf.uuid_mids` | [Exists path authorization](GAPS.md#exists-path-authorization) |
| `shape.exists.uuid.depth_3.constant.filter` and 5 more | `Ash.Error.Unknown: ** (RuntimeError) no such relationship Ash.Conformance.Postgres.ShapeUuidTip.uuid_mids` | [Exists path authorization](GAPS.md#exists-path-authorization) |

6 scenarios already fail without decoys, so a difference isn't a decoy signal; their own gaps: [Authorization bounds](GAPS.md#authorization-bounds), [Join resource policies](GAPS.md#join-resource-policies), [Nested parent](GAPS.md#nested-parent), [No attributes](GAPS.md#no-attributes), [Prepared query](GAPS.md#prepared-query).


## Blockers

| Blocker | Its result | Not run | Failing | Only blocker of |
| --- | --- | ---: | ---: | ---: |
| `context.relationship_context_control` | wrong | 0 | 1 | 1 |
| `filter.nested_parent_control` | crashed | 0 | 1 | 1 |
