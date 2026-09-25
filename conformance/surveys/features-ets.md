<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# What each data layer supports

Generated from an unreviewed run: each result was classified automatically against the intended answer. Nothing here has been reviewed.

Feature catalog version 1: 80 features and 302 scenarios.

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

## 1. Records

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

## 2. Types

| Feature | ets | Not working |
| --- | --- | --- |
| Strings, integers, booleans, atoms and nil round-trip | ✅ Works 3/3 |  |
| Large integers, floats and decimals round-trip | ✅ Works 2/2 |  |
| Dates, microsecond datetimes and times round-trip | ✅ Works 1/1 |  |
| UUIDs round-trip | ✅ Works 1/1 |  |
| Arrays round-trip, keeping order and duplicates | ✅ Works 1/1 |  |
| Maps round-trip, including nested values | ✅ Works 1/1 |  |
| Embedded resources round-trip | ✅ Works 1/1 |  |

## 3. Querying

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

## 4. Relationships

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

## 5. Aggregates

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
| Aggregate filters that reference the parent record | 🟡 Partial 4/8 | `filter.nested_parent` wrong, `filter.parent` wrong, `filter.parent_join` wrong, `filter.parent_through` wrong |
| Aggregate over to-one, multi-hop and many-to-many paths | 🟡 Partial 14/17 | `path.final_many_to_many_custom` rejected, `path.repeated_many_to_many` open question, `path.root_relationship` wrong |
| Aggregate over manual and attribute-free relationships | ✅ Works 3/3 |  |
| Aggregate over limited, offset and from-many relationships | 🟡 Partial 6/9 | `bounds.filter_after_limit` wrong, `bounds.list_filter_after_limit` wrong, `bounds.many_to_many_query_limit` open question |
| Root aggregates over sorted, limited and offset queries | 🟡 Partial 6/7 | `bounds.root_custom_limit` rejected |
| Distinct counts over composite and missing keys | 🟡 Partial 1/5 | `identity.composite_count` wrong, `identity.keyless_count` wrong, `identity.keyless_distinct` open question, `identity.root_composite_count` wrong |
| Filter, sort, paginate and calculate with aggregates | ✅ Works 10/10 |  |
| Aggregates respect read actions, arguments, actor and context | 🟡 Partial 8/9 | `context.relationship_context` wrong |
| Seeded filtered aggregates match an in-memory reference | ✅ Works 1/1 |  |

## 6. Writes

| Feature | ets | Not working |
| --- | --- | --- |
| Upsert on an identity, in bulk, with conditions | ✅ Works 4/4 |  |
| Bulk create with partial success | ✅ Works 1/1 |  |
| Bulk update atomically | ✅ Works 1/1 |  |
| Writes that filter by or read aggregates | ✅ Works 4/4 |  |

## 7. Transactions and locks

| Feature | ets | Not working |
| --- | --- | --- |
| Failed actions and transactions roll back | 🟡 Partial 1/4 | `txn.after_action_rollback` wrong, `txn.explicit_rollback` crashed, `txn.raise_rollback` wrong |
| Lock rows for update | ⛔ Not supported 0/1 | `query.lock_for_update` rejected |
| Isolation between concurrent transactions | ⚪ Untested |  |

## 8. Multitenancy

| Feature | ets | Not working |
| --- | --- | --- |
| Attribute tenancy scopes reads and requires a tenant | 🟡 Partial 5/6 | `tenant.invalid` wrong |
| Tenancy scopes related records and their bounds | ✅ Works 4/4 |  |
| Tenancy scopes aggregates, including explicit bypass | 🟡 Partial 6/8 | `context.through_bypass` wrong, `tenant.aggregate_filter_sort` crashed |
| Tenancy scopes pages and counts | ❌ Broken 0/2 | `tenant.aggregate_keyset_pages` crashed, `tenant.aggregate_offset_page` crashed |
| Tenancy scopes creates, updates and destroys | ✅ Works 3/3 |  |
| Schema-based (context) tenancy | ➖ Not applicable |  |

## 9. Authorization

| Feature | ets | Not working |
| --- | --- | --- |
| Policies filter reads | ✅ Works 3/3 |  |
| Policies filter related records before bounds | ✅ Works 5/5 |  |
| Policies filter what aggregates count | 🟡 Partial 7/8 | `auth.aggregate_sort` crashed |
| Policies filter pages and counts | 🟡 Partial 1/3 | `auth.keyset_pages` crashed, `auth.offset_page` crashed |
| Policies filter and forbid writes | ✅ Works 4/4 |  |

## 10. Consistency checks

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

