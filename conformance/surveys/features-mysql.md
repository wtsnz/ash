<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# What each data layer supports

Generated from an unreviewed run: each result was classified automatically against the intended answer. Nothing here has been reviewed.

Feature catalog version 1: 118 features and 581 scenarios.

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

| Feature | mysql | Not working |
| --- | --- | --- |
| Integers | ✅ Works 3/3 |  |
| Floats | ✅ Works 3/3 |  |
| Decimals | 🟡 Partial 1/3 | `storage.decimal.edge` wrong, `storage.decimal.ordinary` wrong |
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
| Durations | ❌ Broken 0/3 | `storage.duration.edge` wrong, `storage.duration.null` wrong, `storage.duration.ordinary` wrong |
| UUIDs | ✅ Works 3/3 |  |
| UUIDv7s | ✅ Works 2/2 |  |
| Maps | ✅ Works 3/3 |  |
| Arrays of strings | ❌ Broken 0/3 | `storage.strings.edge` wrong, `storage.strings.null` wrong, `storage.strings.ordinary` wrong |
| Arrays of integers | ❌ Broken 0/3 | `storage.integers.edge` wrong, `storage.integers.null` wrong, `storage.integers.ordinary` wrong |
| Embedded resources | ✅ Works 3/3 |  |
| Arrays of embedded resources | ❌ Broken 0/3 | `storage.embeddeds.edge` wrong, `storage.embeddeds.null` wrong, `storage.embeddeds.ordinary` wrong |
| Unions | 🟡 Partial 1/2 | `storage.union.ordinary` wrong |

## 2. Records

| Feature | mysql | Not working |
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

| Feature | mysql | Not working |
| --- | --- | --- |
| Strings, integers, booleans, atoms and nil round-trip | ✅ Works 3/3 |  |
| Large integers, floats and decimals round-trip | 🟡 Partial 1/2 | `record.types_numeric` wrong |
| Dates, microsecond datetimes and times round-trip | ✅ Works 1/1 |  |
| UUIDs round-trip | ✅ Works 1/1 |  |
| Arrays round-trip, keeping order and duplicates | ✅ Works 1/1 |  |
| Maps round-trip, including nested values | ✅ Works 1/1 |  |
| Embedded resources round-trip | ✅ Works 1/1 |  |

## 4. Querying

| Feature | mysql | Not working |
| --- | --- | --- |
| Filter with comparisons on numbers, decimals and dates | ✅ Works 6/6 |  |
| Nil behaves like SQL NULL in filters | ❓ Open question 4/5 | `record.filter_true_or_nil` open question |
| Filter booleans and atoms, including atoms as strings | 🟡 Partial 2/3 | `record.filter_boolean` wrong |
| Filter strings: contains, case, unicode and empty | 🟡 Partial 3/4 | `record.filter_contains` wrong |
| Filter inside arrays, maps and embedded resources | 🟡 Partial 2/3 | `record.filter_array_member` crashed |
| Filter by a calculation | ✅ Works 1/1 |  |
| Sort by one or more fields, with explicit nil order | 🟡 Partial 2/6 | `record.sort_asc_nils_first` crashed, `record.sort_date` crashed, `record.sort_decimal` crashed, `record.sort_desc_nils_last` crashed |
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

| Feature | mysql | Not working |
| --- | --- | --- |
| Filter across to-many relationships without duplicates | 🟡 Partial 1/3 | `use.fanout_count` wrong, `use.fanout_read_page` wrong |
| Limit and offset a has-many load for each parent | ❌ Broken 0/2 | `load.limit_per_parent` crashed, `load.offset_per_parent` crashed |
| Limit a many-to-many load for each parent | ❌ Broken 0/1 | `load.many_to_many_limit_per_parent` wrong |
| Relationships through other relationships | ❌ Broken 0/1 | `load.through` wrong |
| Relationship default sort applies when loading | ❌ Broken 0/1 | `bounds.default_sort_control` crashed |
| Relationships with no attributes load everything | ✅ Works 1/1 |  |
| Relationship context reaches the read action | 🟡 Partial 1/2 | `context.relationship_context_control` wrong |
| Parent references in nested and through relationship filters | ❌ Broken 0/2 | `filter.nested_parent_control` crashed, `filter.parent_through_control` crashed |
| Load belongs-to, has-one, has-many and many-to-many relationships | 🟡 Partial 3/4 | `load.has_one` crashed |
| Create and update related records with manage_relationship | ⚪ Untested |  |

## 6. Aggregates

| Feature | mysql | Not working |
| --- | --- | --- |
| Load each aggregate kind on records | ⛔ Not supported 0/9 | `loaded.avg` rejected, `loaded.count` rejected, `loaded.custom` rejected, `loaded.exists` rejected, `loaded.first` rejected, `loaded.list` rejected, `loaded.max` rejected, `loaded.min` rejected, `loaded.sum` rejected |
| Run each aggregate kind over a whole query | 🟡 Partial 6/15 | `root.custom` crashed, `root.custom_empty` crashed, `root.first` crashed, `root.list` crashed, `root.list_default_empty` crashed, `root.list_empty` crashed, `root.list_unsorted` crashed, `root.unsorted_first_empty` crashed, `values.root_empty` crashed |
| Defaults, nils, uniqueness and field counts | ⛔ Not supported 0/12 | `query.uniq_sum_rejected` rejected, `values.distinct_count` rejected, `values.distinct_list` rejected, `values.field_count` rejected, `values.filtered_first_default` rejected, `values.include_nil_first` rejected, `values.include_nil_list` rejected, `values.list_default` rejected, `values.list_unsorted` rejected, `values.same_name_distinct_definitions` rejected, `values.scalar_default` rejected, `values.string_name` rejected |
| Aggregate decimals, dates, times and constrained types | 🟡 Partial 2/15 | `values.constrained_scalar` rejected, `values.date_list` rejected, `values.date_list_desc` rejected, `values.date_max` rejected, `values.date_min` rejected, `values.datetime_first` rejected, `values.datetime_max` rejected, `values.datetime_min` rejected, `values.decimal_avg` rejected, `values.decimal_max` rejected, `values.decimal_sum` rejected, `values.string_constraints` rejected, `values.time_min` rejected |
| Order first and list aggregates, including nils and ties | ⛔ Not supported 0/9 | `ordering.asc_nils_first` rejected, `ordering.asc_nils_last` rejected, `ordering.desc_nils_first` rejected, `ordering.desc_nils_last` rejected, `ordering.expression_first` rejected, `ordering.expression_list` rejected, `ordering.list_desc` rejected, `ordering.ties` rejected, `ordering.unique_other_field` open question |
| Aggregate calculations and other aggregates | ❌ Broken 0/3 | `field.aggregate` rejected, `field.calculation` rejected, `field.root_aggregate` crashed |
| Filter the records an aggregate uses | ⛔ Not supported 0/6 | `filter.exists` rejected, `filter.join` rejected, `filter.not_exists` rejected, `filter.or_exists` rejected, `filter.ordinary` rejected, `filter.sibling_independence` rejected |
| Aggregate filters through to-many relationships count each record once | ⛔ Not supported 0/11 | `filter.fanout_and` rejected, `filter.fanout_avg` rejected, `filter.fanout_count` rejected, `filter.fanout_count_records` rejected, `filter.fanout_custom` rejected, `filter.fanout_list` rejected, `filter.fanout_nil_count` rejected, `filter.fanout_not_count` rejected, `filter.fanout_or` rejected, `filter.fanout_sum` rejected, `identity.composite_fanout_count` rejected |
| Aggregate filters that use other aggregates | ⛔ Not supported 0/5 | `filter.aggregate_dependency` rejected, `filter.aggregate_dependency_calculation` rejected, `filter.aggregate_dependency_filtered` rejected, `filter.aggregate_dependency_many_to_many` rejected, `filter.aggregate_dependency_to_one` rejected |
| Aggregate filters that reference the parent record | ⛔ Not supported 0/8 | `filter.nested_parent` rejected, `filter.parent` rejected, `filter.parent_join` rejected, `filter.parent_relationship` rejected, `filter.parent_through` rejected, `filter.parent_unrelated` rejected, `use.parent_filter` rejected, `use.parent_sort` rejected |
| Aggregate over to-one, multi-hop and many-to-many paths | ❌ Broken 0/17 | `path.final_many_to_many_custom` rejected, `path.final_many_to_many_first` rejected, `path.final_many_to_many_list` rejected, `path.final_many_to_many_scalar` rejected, `path.intermediate_many_to_many` rejected, `path.many_to_many` rejected, `path.many_to_many_first` rejected, `path.many_to_many_list` rejected, `path.multi_hop` rejected, `path.repeated_many_to_many` open question, `path.root_relationship` crashed, `path.through_count` rejected, `path.to_one` rejected, `path.to_one_to_many_first` rejected, `path.to_one_to_many_list` rejected, `path.to_one_to_many_sum` rejected, `path.unrelated` rejected |
| Aggregate over manual and attribute-free relationships | ⛔ Not supported 0/3 | `path.manual` rejected, `path.no_attributes` rejected, `path.no_attributes_parent` rejected |
| Aggregate over limited, offset and from-many relationships | ⛔ Not supported 0/9 | `bounds.default_sort` rejected, `bounds.filter_after_limit` rejected, `bounds.from_many` rejected, `bounds.list_filter_after_limit` rejected, `bounds.many_to_many_query_limit` open question, `bounds.relationship_limit` rejected, `bounds.relationship_offset` rejected, `bounds.relationship_offset_only` rejected, `bounds.unsorted_limit` rejected |
| Root aggregates over sorted, limited and offset queries | ❌ Broken 0/7 | `bounds.root_custom_limit` crashed, `bounds.root_first_distinct_sort` crashed, `bounds.root_limit` crashed, `bounds.root_list_limit` crashed, `bounds.root_offset_only` crashed, `bounds.root_order_then_limit` crashed, `bounds.root_zero` crashed |
| Distinct counts over composite and missing keys | 🟡 Partial 1/5 | `identity.composite_count` rejected, `identity.keyless_count` rejected, `identity.keyless_distinct` open question, `identity.keyless_source` rejected |
| Filter, sort, paginate and calculate with aggregates | ⛔ Not supported 0/10 | `use.calculation` rejected, `use.filter` rejected, `use.keyset_pagination` rejected, `use.nested_limited_load` rejected, `use.pagination` rejected, `use.related_exists` rejected, `use.related_filter` rejected, `use.sort` rejected, `use.to_one_filter` rejected, `use.to_one_sort` rejected |
| Aggregates respect read actions, arguments, actor and context | ⛔ Not supported 0/9 | `context.actor` rejected, `context.arguments` rejected, `context.intermediate_action` rejected, `context.intermediate_actor` rejected, `context.prepared_query_arguments` rejected, `context.read_action` rejected, `context.relationship_context` rejected, `context.shared` rejected, `context.through_arguments` rejected |
| Seeded filtered aggregates match an in-memory reference | ⛔ Not supported 0/1 | `generated.filtered_aggregates` rejected |

## 7. Writes

| Feature | mysql | Not working |
| --- | --- | --- |
| Upsert on an identity, in bulk, with conditions | ❌ Broken 0/4 | `upsert.bulk` crashed, `upsert.condition` crashed, `upsert.skipped_record` wrong, `upsert.tenant_identity` rejected |
| Bulk create with partial success | ❌ Broken 0/1 | `bulk.partial_success` crashed |
| Bulk update atomically | ❌ Broken 0/1 | `bulk.atomic_increment` crashed |
| Writes that filter by or read aggregates | ❌ Broken 0/4 | `write.atomic_update` crashed, `write.bulk_destroy_filter` rejected, `write.bulk_update_filter` rejected, `write.single_atomic_update` crashed |

## 8. Transactions and locks

| Feature | mysql | Not working |
| --- | --- | --- |
| Failed actions and transactions roll back | 🟡 Partial 1/4 | `txn.after_action_rollback` wrong, `txn.explicit_rollback` crashed, `txn.raise_rollback` wrong |
| Lock rows for update | ⛔ Not supported 0/1 | `query.lock_for_update` rejected |
| Isolation between concurrent transactions | ⚪ Untested |  |

## 9. Multitenancy

| Feature | mysql | Not working |
| --- | --- | --- |
| Attribute tenancy scopes reads and requires a tenant | ✅ Works 6/6 |  |
| Tenancy scopes related records and their bounds | 🟡 Partial 2/4 | `tenant.bounds` crashed, `tenant.from_many` crashed |
| Tenancy scopes aggregates, including explicit bypass | 🟡 Partial 1/8 | `context.attribute_tenant` rejected, `context.bypass_sibling` rejected, `context.tenant_bypass` rejected, `context.through_bypass` rejected, `context.through_tenant` rejected, `tenant.aggregate_filter_sort` rejected, `tenant.loaded_aggregates` rejected |
| Tenancy scopes pages and counts | ⛔ Not supported 0/2 | `tenant.aggregate_keyset_pages` rejected, `tenant.aggregate_offset_page` rejected |
| Tenancy scopes creates, updates and destroys | 🟡 Partial 1/3 | `tenant.write_local_identity` crashed, `write.lifecycle` crashed |
| Schema-based (context) tenancy | ➖ Not applicable |  |

## 10. Authorization

| Feature | mysql | Not working |
| --- | --- | --- |
| Policies filter reads | ✅ Works 3/3 |  |
| Policies filter related records before bounds | 🟡 Partial 2/5 | `auth.bounds` crashed, `auth.from_many` crashed, `context.authorization_bounds_control` crashed |
| Policies filter what aggregates count | 🟡 Partial 2/8 | `auth.aggregate_filter` rejected, `auth.aggregate_sort` rejected, `auth.context_aggregates` rejected, `auth.loaded_aggregates` rejected, `context.authorization` rejected, `context.authorization_before_bounds` rejected |
| Policies filter pages and counts | ⛔ Not supported 0/3 | `auth.keyset_pages` rejected, `auth.offset_page` rejected, `auth.tenant_interaction` rejected |
| Policies filter and forbid writes | 🟡 Partial 2/4 | `auth.write_bulk_update_atomic` crashed, `auth.write_bulk_update_stream` crashed |

## 11. Policies

| Feature | mysql | Not working |
| --- | --- | --- |
| A filter policy on the actor | 🟡 Partial 12/16 | `policy.owner.aggregate_filter` rejected, `policy.owner.get_error` crashed, `policy.owner.loaded_count` rejected, `policy.owner.loaded_sum` rejected |
| The same policy with no actor | 🟡 Partial 11/16 | `policy.owner_nil_actor.aggregate_filter` rejected, `policy.owner_nil_actor.bulk_destroy` wrong, `policy.owner_nil_actor.bulk_update` wrong, `policy.owner_nil_actor.loaded_count` rejected, `policy.owner_nil_actor.loaded_sum` rejected |
| forbid_if before authorize_if | 🟡 Partial 12/16 | `policy.forbid.aggregate_filter` rejected, `policy.forbid.get_error` crashed, `policy.forbid.loaded_count` rejected, `policy.forbid.loaded_sum` rejected |
| A bypass policy, for an actor it does not let through | 🟡 Partial 12/16 | `policy.bypass.aggregate_filter` rejected, `policy.bypass.get_error` crashed, `policy.bypass.loaded_count` rejected, `policy.bypass.loaded_sum` rejected |
| A bypass policy, for an actor it lets through | 🟡 Partial 10/13 | `policy.bypass_admin.aggregate_filter` rejected, `policy.bypass_admin.loaded_count` rejected, `policy.bypass_admin.loaded_sum` rejected |
| Two policies that must both pass | 🟡 Partial 12/16 | `policy.all_of.aggregate_filter` rejected, `policy.all_of.get_error` crashed, `policy.all_of.loaded_count` rejected, `policy.all_of.loaded_sum` rejected |
| One policy whose checks either pass | 🟡 Partial 12/16 | `policy.any_of.aggregate_filter` rejected, `policy.any_of.get_error` crashed, `policy.any_of.loaded_count` rejected, `policy.any_of.loaded_sum` rejected |
| A policy on a to-one relationship | 🟡 Partial 12/16 | `policy.related.aggregate_filter` rejected, `policy.related.get_error` crashed, `policy.related.loaded_count` rejected, `policy.related.loaded_sum` rejected |
| A policy on a multi-hop exists | 🟡 Partial 12/16 | `policy.member.aggregate_filter` rejected, `policy.member.get_error` crashed, `policy.member.loaded_count` rejected, `policy.member.loaded_sum` rejected |
| A policy composed with can_read | 🟡 Partial 12/16 | `policy.can_read.aggregate_filter` rejected, `policy.can_read.get_error` crashed, `policy.can_read.loaded_count` rejected, `policy.can_read.loaded_sum` rejected |
| A strict policy, for an actor it forbids | 🟡 Partial 11/16 | `policy.strict.aggregate_filter` rejected, `policy.strict.bulk_destroy` wrong, `policy.strict.bulk_update` wrong, `policy.strict.loaded_count` rejected, `policy.strict.loaded_sum` rejected |
| A strict policy, for an actor it allows | 🟡 Partial 10/13 | `policy.strict_admin.aggregate_filter` rejected, `policy.strict_admin.loaded_count` rejected, `policy.strict_admin.loaded_sum` rejected |
| Field policies hide values, in reads, filters and aggregates | 🟡 Partial 2/4 | `policy.field.field_aggregate` rejected, `policy.field.field_read` wrong |
| A filter check on create runs after the insert | ❌ Broken 0/2 | `policy.owner.create_other` wrong, `policy.owner.create_own` wrong |
| Every policy path, without authorization | 🟡 Partial 18/22 | `policy.control.aggregate_filter` rejected, `policy.control.field_aggregate` rejected, `policy.control.loaded_count` rejected, `policy.control.loaded_sum` rejected |

## 12. Consistency checks

| Feature | mysql | Not working |
| --- | --- | --- |
| Counts match loads, and root sums match an in-memory reference | 🟡 Partial 1/2 | `equivalence.visible_count_load` rejected |

## Claims versus results

A data layer's `can?/2` claims never decide what runs. This lists features
whose claims disagree with the result:

- advertised, but not working;
- working without being advertised, usually because Ash provides it;
- not advertised, yet not rejected, and giving wrong answers.

| Feature | Adapter | Mismatch |
| --- | --- | --- |
| Stream records in batches | mysql | Works without advertising `record: :keyset` |
| Load expression calculations, with arguments | mysql | Works without advertising `record: :calculate` |
| Keyset pagination, forwards and backwards | mysql | Works without advertising `record: :keyset` |
| Limit and offset a has-many load for each parent | mysql | Not advertising `parent: {:lateral_join, :children}`, but not rejected either: wrong answers |
| Limit a many-to-many load for each parent | mysql | Not advertising `parent: {:lateral_join, :tags}`, but not rejected either: wrong answers |
| Relationships through other relationships | mysql | Not advertising `parent: :through_relationship`, but not rejected either: wrong answers |
| Relationship default sort applies when loading | mysql | Advertised, but ❌ Broken |
| Parent references in nested and through relationship filters | mysql | Advertised, but ❌ Broken |
| Aggregate calculations and other aggregates | mysql | Not advertising `parent: {:aggregate, :sum}`, but not rejected either: wrong answers |
| Aggregate filters through to-many relationships count each record once | mysql | Advertised, but ⛔ Not supported |
| Aggregate over to-one, multi-hop and many-to-many paths | mysql | Not advertising `parent: {:aggregate_relationship, :tags}`, `parent: {:aggregate, :unrelated}`, but not rejected either: wrong answers |
| Root aggregates over sorted, limited and offset queries | mysql | Advertised, but ❌ Broken |
| Upsert on an identity, in bulk, with conditions | mysql | Not advertising `tenant_item: :upsert`, `tenant_item: {:atomic, :upsert}`, `tenant_item: :bulk_upsert_return_skipped`, but not rejected either: wrong answers |
| Bulk create with partial success | mysql | Not advertising `tenant_item: :bulk_create_with_partial_success`, but not rejected either: wrong answers |
| Bulk update atomically | mysql | Not advertising `tenant_item: :update_query`, but not rejected either: wrong answers |
| Writes that filter by or read aggregates | mysql | Not advertising `parent: :update_query`, `parent: :destroy_query`, but not rejected either: wrong answers |
| Policies filter pages and counts | mysql | Advertised, but ⛔ Not supported |
| A filter check on create runs after the insert | mysql | Not advertising `policy_owner_note: :transact`, but not rejected either: wrong answers |


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
| Decimals | `:decimal` | ❌ | ❌ | ✅ | ordinary, read: Decimal.new("2") |
| Strings | `:string` | ✅ | ❌ | ✅ | edge, create: ** (MyXQL.Error) (1406) Data too long for column 'value' at row 1 |
| Case-insensitive strings | `:"VARCHAR(255) COLLATE utf8mb4_0900_ai_ci"` | ✅ | ✅ | ✅ |  |
| Binaries | `:binary` | ✅ | ✅ | ✅ |  |
| Booleans | `:boolean` | ✅ | – | ✅ |  |
| Atoms with one_of | `:string` | ✅ | – | ✅ |  |
| Dates | `:date` | ✅ | ✅ | ✅ |  |
| Times | `:time` | ✅ | ✅ | ✅ |  |
| Microsecond times | `:time_usec` | ✅ | ✅ | ✅ |  |
| UTC datetimes | `:utc_datetime` | ✅ | ✅ | ✅ |  |
| Microsecond UTC datetimes | `:utc_datetime_usec` | ✅ | ✅ | ✅ |  |
| Naive datetimes | `:naive_datetime` | ✅ | ✅ | ✅ |  |
| Durations | `:duration` | 🚫 | 🚫 | 🚫 | ordinary, table: (1064) You have an error in your SQL syntax; check the manual that corresponds to your MySQL server version for the right syntax to use near 'duration, PRIMARY  |
| UUIDs | `:uuid` | ✅ | ✅ | ✅ |  |
| UUIDv7s | `:uuid` | ✅ | – | ✅ |  |
| Maps | `:map` | ✅ | ✅ | ✅ |  |
| Arrays of strings | `{:array, :string}` | 🚫 | 🚫 | 🚫 | ordinary, table: Array type is not supported by MySQL |
| Arrays of integers | `{:array, :bigint}` | 🚫 | 🚫 | 🚫 | ordinary, table: Array type is not supported by MySQL |
| Embedded resources | `:map` | ✅ | ✅ | ✅ |  |
| Arrays of embedded resources | `{:array, :map}` | 🚫 | 🚫 | 🚫 | ordinary, table: Array type is not supported by MySQL |
| Unions | `:map` | ❌ | – | ✅ | ordinary, clear: %Ash.Union{value: nil, type: :text} |

## Policies

✅ returns the answer Ash's policy semantics define; ❌ does not, while the
same path works without authorization; ◌ the path fails even without
authorization, so the policy cannot be judged; ❔ did not run; – does not
apply, such as getting a hidden record when the actor may read every note.

| Case | `read` | `get_hidden` | `get_error` | `count` | `sum` | `offset_page` | `keyset_pages` | `load` | `loaded_count` | `loaded_sum` | `aggregate_filter` | `exists_filter` | `exists_filter_input` | `bulk_update` | `bulk_destroy` | `update_hidden` | `field_read` | `field_filter` | `field_filter_input` | `field_aggregate` | `create_own` | `create_other` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| owner | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | ❌ | ❌ |
| owner_nil_actor | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ✅ | ❌ | ❌ | ✅ | – | – | – | – | – | – |
| forbid | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| bypass | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| bypass_admin | ✅ | – | – | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – | – |
| all_of | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| any_of | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| related | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| member | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| can_read | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – |
| strict | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ✅ | ❌ | ❌ | ✅ | – | – | – | – | – | – |
| strict_admin | ✅ | – | – | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ✅ | ✅ | ✅ | – | – | – | – | – | – | – |
| field | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | ❌ | ✅ | ✅ | ◌ | – | – |
| control (no authorization) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
