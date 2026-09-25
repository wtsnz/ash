<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# What each data layer supports

Generated from an unreviewed run: each result was classified automatically against the intended answer. Nothing here has been reviewed.

Feature catalog version 1: 103 features and 367 scenarios.

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
not run. Gap links explain everything that is not fully working, and who
owns the fix.

## 1. Storage

| Feature | sqlite | Not working |
| --- | --- | --- |
| Integers | ✅ Works 3/3 |  |
| Floats | ✅ Works 3/3 |  |
| Decimals | 🟡 Partial 2/3 | `storage.decimal.edge` wrong |
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
| Durations | 🟡 Partial 1/3 | `storage.duration.edge` wrong, `storage.duration.ordinary` wrong |
| UUIDs | ✅ Works 3/3 |  |
| UUIDv7s | ✅ Works 2/2 |  |
| Maps | ✅ Works 3/3 |  |
| Arrays of strings | ✅ Works 3/3 |  |
| Arrays of integers | ✅ Works 3/3 |  |
| Embedded resources | ✅ Works 3/3 |  |
| Arrays of embedded resources | ✅ Works 3/3 |  |
| Unions | 🟡 Partial 1/2 | `storage.union.ordinary` wrong |

## 2. Records

| Feature | sqlite | Not working |
| --- | --- | --- |
| Read records | ✅ Works 1/1 |  |
| Get one record by primary key or identity | ✅ Works 2/2 |  |
| Select only some attributes | ✅ Works 2/2 |  |
| Create a record | ✅ Works 1/1 |  |
| Update a record, including to nil | ✅ Works 2/2 |  |
| Destroy a record | ✅ Works 1/1 |  |
| Update a record atomically from its current value | ✅ Works 1/1 |  |
| Not found, invalid, missing and duplicate values are errors | ✅ Works 4/4 |  |

## 3. Types

| Feature | sqlite | Not working |
| --- | --- | --- |
| Strings, integers, booleans, atoms and nil round-trip | ✅ Works 3/3 |  |
| Large integers, floats and decimals round-trip | 🟡 Partial 1/2 | `values.decimal_read_control` wrong |
| Dates, microsecond datetimes and times round-trip | ✅ Works 1/1 |  |
| UUIDs round-trip | ✅ Works 1/1 |  |
| Arrays round-trip, keeping order and duplicates | ✅ Works 1/1 |  |
| Maps round-trip, including nested values | ✅ Works 1/1 |  |
| Embedded resources round-trip | ✅ Works 1/1 |  |

## 4. Querying

| Feature | sqlite | Not working |
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
| Distinct records by a field | ⛔ Not supported 0/1 | `query.distinct` rejected |
| Combine queries with union | ⛔ Not supported 0/1 | `query.union` rejected |
| Combine queries with union all and intersection | ⚪ Untested |  |
| Load expression calculations, with arguments | ✅ Works 3/3 |  |
| Offset pagination with counts | ✅ Works 1/1 |  |
| Keyset pagination, forwards and backwards | ✅ Works 1/1 |  |
| Pagination while records change | ⚪ Untested |  |

## 5. Relationships

| Feature | sqlite | Not working |
| --- | --- | --- |
| Filter across to-many relationships without duplicates | 🟡 Partial 1/3 | `filter.fanout_read_control` wrong, `use.fanout_read_page` wrong |
| Limit and offset a has-many load for each parent | ✅ Works 2/2 |  |
| Limit a many-to-many load for each parent | ❌ Broken 0/1 | `load.many_to_many_limit_per_parent` wrong |
| Relationships through other relationships | ❌ Broken 0/1 | `load.through` wrong |
| Relationship default sort applies when loading | ✅ Works 1/1 |  |
| Relationships with no attributes load everything | ✅ Works 1/1 |  |
| Relationship context reaches the read action | 🟡 Partial 1/2 | `context.relationship_context_control` wrong |
| Parent references in nested and through relationship filters | ❌ Broken 0/2 | `filter.nested_parent_control` crashed, `filter.parent_through_control` crashed |
| Load belongs-to, has-one, has-many and many-to-many relationships | ✅ Works 4/4 |  |
| Create and update related records with manage_relationship | ⚪ Untested |  |

## 6. Aggregates

| Feature | sqlite | Not working |
| --- | --- | --- |
| Load each aggregate kind on records | ✅ Works 9/9 |  |
| Run each aggregate kind over a whole query | 🟡 Partial 9/15 | `root.custom` rejected, `root.custom_empty` rejected, `root.list` rejected, `root.list_default_empty` rejected, `root.list_empty` rejected, `root.list_unsorted` rejected |
| Defaults, nils, uniqueness and field counts | ✅ Works 12/12 |  |
| Aggregate decimals, dates, times and constrained types | 🟡 Partial 12/15 | `root.decimal_sum` wrong, `values.decimal_max` wrong, `values.decimal_sum` wrong |
| Order first and list aggregates, including nils and ties | ❓ Open question 8/9 | `ordering.unique_other_field` open question |
| Aggregate calculations and other aggregates | ✅ Works 3/3 |  |
| Filter the records an aggregate uses | ✅ Works 6/6 |  |
| Aggregate filters through to-many relationships count each record once | 🟡 Partial 3/11 | `filter.fanout_and` rejected, `filter.fanout_avg` rejected, `filter.fanout_count` rejected, `filter.fanout_custom` rejected, `filter.fanout_list` rejected, `filter.fanout_or` rejected, `filter.fanout_sum` rejected, `identity.composite_fanout_count` crashed |
| Aggregate filters that use other aggregates | 🟡 Partial 1/5 | `filter.aggregate_dependency` rejected, `filter.aggregate_dependency_calculation` rejected, `filter.aggregate_dependency_filtered` rejected, `filter.aggregate_dependency_many_to_many` rejected |
| Aggregate filters that reference the parent record | ⛔ Not supported 0/8 | `filter.nested_parent` rejected, `filter.parent` rejected, `filter.parent_join` rejected, `filter.parent_relationship` rejected, `filter.parent_through` rejected, `filter.parent_unrelated` rejected, `use.parent_filter` rejected, `use.parent_sort` rejected |
| Aggregate over to-one, multi-hop and many-to-many paths | 🟡 Partial 10/17 | `path.final_many_to_many_custom` rejected, `path.final_many_to_many_first` rejected, `path.final_many_to_many_list` rejected, `path.intermediate_many_to_many` rejected, `path.repeated_many_to_many` open question, `path.root_relationship` crashed, `path.through_count` wrong |
| Aggregate over manual and attribute-free relationships | ⛔ Not supported 0/3 | `path.manual` rejected, `path.no_attributes` rejected, `path.no_attributes_parent` rejected |
| Aggregate over limited, offset and from-many relationships | 🟡 Partial 5/9 | `bounds.default_sort` wrong, `bounds.from_many` wrong, `bounds.many_to_many_query_limit` open question, `bounds.unsorted_limit` crashed |
| Root aggregates over sorted, limited and offset queries | 🟡 Partial 5/7 | `bounds.root_custom_limit` rejected, `bounds.root_list_limit` rejected |
| Distinct counts over composite and missing keys | 🟡 Partial 1/5 | `identity.composite_count` crashed, `identity.keyless_distinct` open question, `identity.keyless_source` crashed, `identity.root_composite_count` crashed |
| Filter, sort, paginate and calculate with aggregates | ✅ Works 10/10 |  |
| Aggregates respect read actions, arguments, actor and context | 🟡 Partial 8/9 | `context.relationship_context` wrong |
| Seeded filtered aggregates match an in-memory reference | ✅ Works 1/1 |  |

## 7. Writes

| Feature | sqlite | Not working |
| --- | --- | --- |
| Upsert on an identity, in bulk, with conditions | 🟡 Partial 2/4 | `upsert.condition` crashed, `upsert.skipped_record` crashed |
| Bulk create with partial success | ✅ Works 1/1 |  |
| Bulk update atomically | ✅ Works 1/1 |  |
| Writes that filter by or read aggregates | ✅ Works 4/4 |  |

## 8. Transactions and locks

| Feature | sqlite | Not working |
| --- | --- | --- |
| Failed actions and transactions roll back | ✅ Works 4/4 |  |
| Lock rows for update | ⛔ Not supported 0/1 | `query.lock_for_update` rejected |
| Isolation between concurrent transactions | ⚪ Untested |  |

## 9. Multitenancy

| Feature | sqlite | Not working |
| --- | --- | --- |
| Attribute tenancy scopes reads and requires a tenant | ✅ Works 6/6 |  |
| Tenancy scopes related records and their bounds | ✅ Works 4/4 |  |
| Tenancy scopes aggregates, including explicit bypass | ✅ Works 8/8 |  |
| Tenancy scopes pages and counts | ✅ Works 2/2 |  |
| Tenancy scopes creates, updates and destroys | ✅ Works 3/3 |  |
| Schema-based (context) tenancy | ➖ Not applicable |  |

## 10. Authorization

| Feature | sqlite | Not working |
| --- | --- | --- |
| Policies filter reads | ✅ Works 3/3 |  |
| Policies filter related records before bounds | ✅ Works 5/5 |  |
| Policies filter what aggregates count | 🟡 Partial 7/8 | `context.authorization_before_bounds` wrong |
| Policies filter pages and counts | ✅ Works 3/3 |  |
| Policies filter and forbid writes | ✅ Works 4/4 |  |

## 11. Consistency checks

| Feature | sqlite | Not working |
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
| Stream records in batches | sqlite | Works without advertising `record: :keyset` |
| Load expression calculations, with arguments | sqlite | Works without advertising `record: :calculate` |
| Keyset pagination, forwards and backwards | sqlite | Works without advertising `record: :keyset` |
| Limit and offset a has-many load for each parent | sqlite | Works without advertising `parent: {:lateral_join, :children}` |
| Limit a many-to-many load for each parent | sqlite | Not advertising `parent: {:lateral_join, :tags}`, but not rejected either: wrong answers |
| Relationships through other relationships | sqlite | Not advertising `parent: :through_relationship`, but not rejected either: wrong answers |
| Parent references in nested and through relationship filters | sqlite | Advertised, but ❌ Broken |
| Bulk create with partial success | sqlite | Works without advertising `tenant_item: :bulk_create_with_partial_success` |
| Tenancy scopes pages and counts | sqlite | Works without advertising `tenant_parent: :keyset` |


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
| Decimals | `:decimal` | ✅ | ❌ | ✅ | edge, read: Decimal.new("12345678901234568") |
| Strings | `:text` | ✅ | ✅ | ✅ |  |
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
| Durations | `:duration` | ❌ | ❌ | ✅ | ordinary, create: ** (Exqlite.Error) unsupported type: %Duration{hour: 1, minute: 30} |
| UUIDs | `:uuid` | ✅ | ✅ | ✅ |  |
| UUIDv7s | `:uuid` | ✅ | – | ✅ |  |
| Maps | `:map` | ✅ | ✅ | ✅ |  |
| Arrays of strings | `{:array, :text}` | ✅ | ✅ | ✅ |  |
| Arrays of integers | `{:array, :bigint}` | ✅ | ✅ | ✅ |  |
| Embedded resources | `:map` | ✅ | ✅ | ✅ |  |
| Arrays of embedded resources | `{:array, :map}` | ✅ | ✅ | ✅ |  |
| Unions | `:map` | ❌ | – | ✅ | ordinary, clear: %Ash.Union{value: nil, type: :text} |
