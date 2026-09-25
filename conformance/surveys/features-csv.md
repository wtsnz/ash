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

| Feature | csv | Not working |
| --- | --- | --- |
| Integers | ✅ Works 3/3 |  |
| Floats | 🟡 Partial 1/3 | `storage.float.edge` wrong, `storage.float.ordinary` wrong |
| Decimals | ✅ Works 3/3 |  |
| Strings | 🟡 Partial 2/3 | `storage.string.edge` wrong |
| Case-insensitive strings | 🟡 Partial 2/3 | `storage.ci_string.edge` wrong |
| Binaries | 🟡 Partial 1/3 | `storage.binary.edge` wrong, `storage.binary.ordinary` wrong |
| Booleans | 🟡 Partial 1/2 | `storage.boolean.ordinary` wrong |
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
| Maps | 🟡 Partial 1/3 | `storage.map.edge` wrong, `storage.map.ordinary` wrong |
| Arrays of strings | 🟡 Partial 1/3 | `storage.strings.edge` wrong, `storage.strings.ordinary` wrong |
| Arrays of integers | 🟡 Partial 1/3 | `storage.integers.edge` wrong, `storage.integers.ordinary` wrong |
| Embedded resources | 🟡 Partial 1/3 | `storage.embedded.edge` wrong, `storage.embedded.ordinary` wrong |
| Arrays of embedded resources | 🟡 Partial 1/3 | `storage.embeddeds.edge` wrong, `storage.embeddeds.ordinary` wrong |
| Unions | 🟡 Partial 1/2 | `storage.union.ordinary` wrong |

## 2. Records

| Feature | csv | Not working |
| --- | --- | --- |
| Read records | ❔ Unknown 1 not run | `record.read_all` setup failed |
| Get one record by primary key or identity | ❔ Unknown 2 not run | `record.get_identity` setup failed, `record.get_primary_key` setup failed |
| Select only some attributes | 🔸 Incomplete 1/1 · 1 not run | `record.select` setup failed |
| Create a record | ❔ Unknown 1 not run | `record.create` setup failed |
| Update a record, including to nil | ❔ Unknown 2 not run | `record.update` setup failed, `record.update_to_nil` setup failed |
| Destroy a record | ❔ Unknown 1 not run | `record.destroy` setup failed |
| Update a record atomically from its current value | ❔ Unknown 1 not run | `record.atomic_update` setup failed |
| Not found, invalid, missing and duplicate values are errors | ❔ Unknown 4 not run | `record.identity_conflict` setup failed, `record.invalid_value` setup failed, `record.not_found` setup failed, `record.required` setup failed |

## 3. Types

| Feature | csv | Not working |
| --- | --- | --- |
| Strings, integers, booleans, atoms and nil round-trip | ❔ Unknown 3 not run | `record.types_nil` setup failed, `record.types_scalar` setup failed, `record.types_strings` setup failed |
| Large integers, floats and decimals round-trip | ❔ Unknown 2 not run | `record.types_numeric` setup failed, `values.decimal_read_control` setup failed |
| Dates, microsecond datetimes and times round-trip | ❔ Unknown 1 not run | `record.types_temporal` setup failed |
| UUIDs round-trip | ❔ Unknown 1 not run | `record.types_uuid` setup failed |
| Arrays round-trip, keeping order and duplicates | ❔ Unknown 1 not run | `record.types_array` setup failed |
| Maps round-trip, including nested values | ❔ Unknown 1 not run | `record.types_map` setup failed |
| Embedded resources round-trip | ❔ Unknown 1 not run | `record.types_embedded` setup failed |

## 4. Querying

| Feature | csv | Not working |
| --- | --- | --- |
| Filter with comparisons on numbers, decimals and dates | ❔ Unknown 6 not run | `record.filter_date` setup failed, `record.filter_datetime_precision` setup failed, `record.filter_decimal` setup failed, `record.filter_equal` setup failed, `record.filter_not_equal` setup failed, `record.filter_range` setup failed |
| Nil behaves like SQL NULL in filters | ❔ Unknown 5 not run | `record.filter_in_with_nil` setup failed, `record.filter_is_nil` setup failed, `record.filter_not` setup failed, `record.filter_not_nil` setup failed, `record.filter_true_or_nil` setup failed |
| Filter booleans and atoms, including atoms as strings | ❔ Unknown 3 not run | `record.filter_atom` setup failed, `record.filter_atom_as_string` setup failed, `record.filter_boolean` setup failed |
| Filter strings: contains, case, unicode and empty | ❔ Unknown 4 not run | `record.filter_case_insensitive` setup failed, `record.filter_contains` setup failed, `record.filter_empty_string` setup failed, `record.filter_unicode` setup failed |
| Filter inside arrays, maps and embedded resources | ❔ Unknown 3 not run | `record.filter_array_member` setup failed, `record.filter_embedded` setup failed, `record.filter_map_key` setup failed |
| Filter by a calculation | ❔ Unknown 1 not run | `record.filter_calculation` setup failed |
| Sort by one or more fields, with explicit nil order | ❔ Unknown 6 not run | `record.sort_asc_nils_first` setup failed, `record.sort_date` setup failed, `record.sort_decimal` setup failed, `record.sort_desc_nils_last` setup failed, `record.sort_string` setup failed, `record.sort_tie_break` setup failed |
| Sort by a calculation | ❔ Unknown 1 not run | `record.sort_calculation` setup failed |
| Limit and offset a query | ❔ Unknown 1 not run | `record.limit_offset` setup failed |
| Count and check existence | ❔ Unknown 1 not run | `record.count` setup failed |
| Stream records in batches | ❔ Unknown 1 not run | `record.stream` setup failed |
| Distinct records by a field | ❔ Unknown 1 not run | `query.distinct` setup failed |
| Combine queries with union | ❔ Unknown 1 not run | `query.union` setup failed |
| Combine queries with union all and intersection | ⚪ Untested |  |
| Load expression calculations, with arguments | ❔ Unknown 3 not run | `calc.in_memory` setup failed, `record.calculation_argument` setup failed, `record.calculation_load` setup failed |
| Offset pagination with counts | ❔ Unknown 1 not run | `record.offset_pages` setup failed |
| Keyset pagination, forwards and backwards | ❔ Unknown 1 not run | `record.keyset_pages` setup failed |
| Pagination while records change | ⚪ Untested |  |

## 5. Relationships

| Feature | csv | Not working |
| --- | --- | --- |
| Filter across to-many relationships without duplicates | ❔ Unknown 3 not run | `filter.fanout_read_control` setup failed, `use.fanout_count` setup failed, `use.fanout_read_page` setup failed |
| Limit and offset a has-many load for each parent | ❔ Unknown 2 not run | `load.limit_per_parent` setup failed, `load.offset_per_parent` setup failed |
| Limit a many-to-many load for each parent | ❔ Unknown 1 not run | `load.many_to_many_limit_per_parent` setup failed |
| Relationships through other relationships | ❔ Unknown 1 not run | `load.through` setup failed |
| Relationship default sort applies when loading | ❔ Unknown 1 not run | `bounds.default_sort_control` setup failed |
| Relationships with no attributes load everything | ❔ Unknown 1 not run | `path.no_attributes_control` setup failed |
| Relationship context reaches the read action | ❔ Unknown 2 not run | `context.prepared_context_control` setup failed, `context.relationship_context_control` setup failed |
| Parent references in nested and through relationship filters | ❔ Unknown 2 not run | `filter.nested_parent_control` setup failed, `filter.parent_through_control` setup failed |
| Load belongs-to, has-one, has-many and many-to-many relationships | ❔ Unknown 4 not run | `load.belongs_to` setup failed, `load.has_many` setup failed, `load.has_one` setup failed, `load.many_to_many` setup failed |
| Create and update related records with manage_relationship | ⚪ Untested |  |

## 6. Aggregates

| Feature | csv | Not working |
| --- | --- | --- |
| Load each aggregate kind on records | ❔ Unknown 9 not run | `loaded.avg` setup failed, `loaded.count` setup failed, `loaded.custom` setup failed, `loaded.exists` setup failed, `loaded.first` setup failed, `loaded.list` setup failed, `loaded.max` setup failed, `loaded.min` setup failed, `loaded.sum` setup failed |
| Run each aggregate kind over a whole query | ❔ Unknown 15 not run | `root.avg` setup failed, `root.count` setup failed, `root.custom` setup failed, `root.custom_empty` setup failed, `root.exists` setup failed, `root.first` setup failed, `root.list` setup failed, `root.list_default_empty` setup failed, `root.list_empty` setup failed, `root.list_unsorted` setup failed, `root.max` setup failed, `root.min` setup failed, `root.sum` setup failed, `root.unsorted_first_empty` setup failed, `values.root_empty` setup failed |
| Defaults, nils, uniqueness and field counts | ❔ Unknown 12 not run | `query.uniq_sum_rejected` setup failed, `values.distinct_count` setup failed, `values.distinct_list` setup failed, `values.field_count` setup failed, `values.filtered_first_default` setup failed, `values.include_nil_first` setup failed, `values.include_nil_list` setup failed, `values.list_default` setup failed, `values.list_unsorted` setup failed, `values.same_name_distinct_definitions` setup failed, `values.scalar_default` setup failed, `values.string_name` setup failed |
| Aggregate decimals, dates, times and constrained types | ❔ Unknown 15 not run | `root.datetime_max` setup failed, `root.decimal_sum` setup failed, `values.constrained_scalar` setup failed, `values.date_list` setup failed, `values.date_list_desc` setup failed, `values.date_max` setup failed, `values.date_min` setup failed, `values.datetime_first` setup failed, `values.datetime_max` setup failed, `values.datetime_min` setup failed, `values.decimal_avg` setup failed, `values.decimal_max` setup failed, `values.decimal_sum` setup failed, `values.string_constraints` setup failed, `values.time_min` setup failed |
| Order first and list aggregates, including nils and ties | ❔ Unknown 9 not run | `ordering.asc_nils_first` setup failed, `ordering.asc_nils_last` setup failed, `ordering.desc_nils_first` setup failed, `ordering.desc_nils_last` setup failed, `ordering.expression_first` setup failed, `ordering.expression_list` setup failed, `ordering.list_desc` setup failed, `ordering.ties` setup failed, `ordering.unique_other_field` setup failed |
| Aggregate calculations and other aggregates | ❔ Unknown 3 not run | `field.aggregate` setup failed, `field.calculation` setup failed, `field.root_aggregate` setup failed |
| Filter the records an aggregate uses | ❔ Unknown 6 not run | `filter.exists` setup failed, `filter.join` setup failed, `filter.not_exists` setup failed, `filter.or_exists` setup failed, `filter.ordinary` setup failed, `filter.sibling_independence` setup failed |
| Aggregate filters through to-many relationships count each record once | ❔ Unknown 11 not run | `filter.fanout_and` setup failed, `filter.fanout_avg` setup failed, `filter.fanout_count` setup failed, `filter.fanout_count_records` setup failed, `filter.fanout_custom` setup failed, `filter.fanout_list` setup failed, `filter.fanout_nil_count` setup failed, `filter.fanout_not_count` setup failed, `filter.fanout_or` setup failed, `filter.fanout_sum` setup failed, `identity.composite_fanout_count` setup failed |
| Aggregate filters that use other aggregates | ❔ Unknown 5 not run | `filter.aggregate_dependency` setup failed, `filter.aggregate_dependency_calculation` setup failed, `filter.aggregate_dependency_filtered` setup failed, `filter.aggregate_dependency_many_to_many` setup failed, `filter.aggregate_dependency_to_one` setup failed |
| Aggregate filters that reference the parent record | ❔ Unknown 8 not run | `filter.nested_parent` setup failed, `filter.parent` setup failed, `filter.parent_join` setup failed, `filter.parent_relationship` setup failed, `filter.parent_through` setup failed, `filter.parent_unrelated` setup failed, `use.parent_filter` setup failed, `use.parent_sort` setup failed |
| Aggregate over to-one, multi-hop and many-to-many paths | ❔ Unknown 17 not run | `path.final_many_to_many_custom` setup failed, `path.final_many_to_many_first` setup failed, `path.final_many_to_many_list` setup failed, `path.final_many_to_many_scalar` setup failed, `path.intermediate_many_to_many` setup failed, `path.many_to_many` setup failed, `path.many_to_many_first` setup failed, `path.many_to_many_list` setup failed, `path.multi_hop` setup failed, `path.repeated_many_to_many` setup failed, `path.root_relationship` setup failed, `path.through_count` setup failed, `path.to_one` setup failed, `path.to_one_to_many_first` setup failed, `path.to_one_to_many_list` setup failed, `path.to_one_to_many_sum` setup failed, `path.unrelated` setup failed |
| Aggregate over manual and attribute-free relationships | ❔ Unknown 3 not run | `path.manual` setup failed, `path.no_attributes` setup failed, `path.no_attributes_parent` setup failed |
| Aggregate over limited, offset and from-many relationships | ❔ Unknown 9 not run | `bounds.default_sort` setup failed, `bounds.filter_after_limit` setup failed, `bounds.from_many` setup failed, `bounds.list_filter_after_limit` setup failed, `bounds.many_to_many_query_limit` setup failed, `bounds.relationship_limit` setup failed, `bounds.relationship_offset` setup failed, `bounds.relationship_offset_only` setup failed, `bounds.unsorted_limit` setup failed |
| Root aggregates over sorted, limited and offset queries | ❔ Unknown 7 not run | `bounds.root_custom_limit` setup failed, `bounds.root_first_distinct_sort` setup failed, `bounds.root_limit` setup failed, `bounds.root_list_limit` setup failed, `bounds.root_offset_only` setup failed, `bounds.root_order_then_limit` setup failed, `bounds.root_zero` setup failed |
| Distinct counts over composite and missing keys | ❔ Unknown 5 not run | `identity.composite_count` setup failed, `identity.keyless_count` setup failed, `identity.keyless_distinct` setup failed, `identity.keyless_source` setup failed, `identity.root_composite_count` setup failed |
| Filter, sort, paginate and calculate with aggregates | ❔ Unknown 10 not run | `use.calculation` setup failed, `use.filter` setup failed, `use.keyset_pagination` setup failed, `use.nested_limited_load` setup failed, `use.pagination` setup failed, `use.related_exists` setup failed, `use.related_filter` setup failed, `use.sort` setup failed, `use.to_one_filter` setup failed, `use.to_one_sort` setup failed |
| Aggregates respect read actions, arguments, actor and context | ❔ Unknown 9 not run | `context.actor` setup failed, `context.arguments` setup failed, `context.intermediate_action` setup failed, `context.intermediate_actor` setup failed, `context.prepared_query_arguments` setup failed, `context.read_action` setup failed, `context.relationship_context` setup failed, `context.shared` setup failed, `context.through_arguments` setup failed |
| Seeded filtered aggregates match an in-memory reference | ❔ Unknown 1 not run | `generated.filtered_aggregates` setup failed |

## 7. Writes

| Feature | csv | Not working |
| --- | --- | --- |
| Upsert on an identity, in bulk, with conditions | 🟡 Partial 2/4 | `upsert.condition` wrong, `upsert.skipped_record` wrong |
| Bulk create with partial success | ❌ Broken 0/1 | `bulk.partial_success` crashed |
| Bulk update atomically | ❌ Broken 0/1 | `bulk.atomic_increment` wrong |
| Writes that filter by or read aggregates | ❔ Unknown 4 not run | `write.atomic_update` setup failed, `write.bulk_destroy_filter` setup failed, `write.bulk_update_filter` setup failed, `write.single_atomic_update` setup failed |

## 8. Transactions and locks

| Feature | csv | Not working |
| --- | --- | --- |
| Failed actions and transactions roll back | 🟡 Partial 1/4 | `txn.after_action_rollback` wrong, `txn.explicit_rollback` wrong, `txn.raise_rollback` wrong |
| Lock rows for update | ❔ Unknown 1 not run | `query.lock_for_update` setup failed |
| Isolation between concurrent transactions | ⚪ Untested |  |

## 9. Multitenancy

| Feature | csv | Not working |
| --- | --- | --- |
| Attribute tenancy scopes reads and requires a tenant | 🟡 Partial 5/6 | `tenant.invalid` wrong |
| Tenancy scopes related records and their bounds | 🟡 Partial 3/4 | `tenant.relationship_filter` crashed |
| Tenancy scopes aggregates, including explicit bypass | ⛔ Not supported 0/3 · 5 not run | `context.attribute_tenant` setup failed, `context.bypass_sibling` setup failed, `context.tenant_bypass` setup failed, `context.through_bypass` setup failed, `context.through_tenant` setup failed, `tenant.aggregate_filter_sort` rejected, `tenant.loaded_aggregates` rejected, `tenant.root_aggregates` rejected |
| Tenancy scopes pages and counts | ⛔ Not supported 0/2 | `tenant.aggregate_keyset_pages` rejected, `tenant.aggregate_offset_page` rejected |
| Tenancy scopes creates, updates and destroys | ✅ Works 3/3 |  |
| Schema-based (context) tenancy | ➖ Not applicable |  |

## 10. Authorization

| Feature | csv | Not working |
| --- | --- | --- |
| Policies filter reads | ✅ Works 3/3 |  |
| Policies filter related records before bounds | 🔸 Incomplete 4/4 · 1 not run | `context.authorization_bounds_control` setup failed |
| Policies filter what aggregates count | ⛔ Not supported 0/6 · 2 not run | `auth.aggregate_filter` rejected, `auth.aggregate_sort` rejected, `auth.context_aggregates` rejected, `auth.context_root` rejected, `auth.loaded_aggregates` rejected, `auth.root_aggregates` rejected, `context.authorization` setup failed, `context.authorization_before_bounds` setup failed |
| Policies filter pages and counts | ⛔ Not supported 0/3 | `auth.keyset_pages` rejected, `auth.offset_page` rejected, `auth.tenant_interaction` rejected |
| Policies filter and forbid writes | 🟡 Partial 3/4 | `auth.write_bulk_update_stream` wrong |

## 11. Policies

| Feature | csv | Not working |
| --- | --- | --- |
| A filter policy on the actor | 🟡 Partial 7/16 | `policy.owner.aggregate_filter` rejected, `policy.owner.bulk_update` wrong, `policy.owner.count` rejected, `policy.owner.exists_filter_input` crashed, `policy.owner.get_error` crashed, `policy.owner.loaded_count` rejected, `policy.owner.loaded_sum` rejected, `policy.owner.offset_page` rejected, `policy.owner.sum` rejected |
| The same policy with no actor | 🟡 Partial 10/16 | `policy.owner_nil_actor.aggregate_filter` rejected, `policy.owner_nil_actor.bulk_destroy` wrong, `policy.owner_nil_actor.bulk_update` wrong, `policy.owner_nil_actor.exists_filter_input` crashed, `policy.owner_nil_actor.loaded_count` rejected, `policy.owner_nil_actor.loaded_sum` rejected |
| forbid_if before authorize_if | 🟡 Partial 7/16 | `policy.forbid.aggregate_filter` rejected, `policy.forbid.bulk_update` wrong, `policy.forbid.count` rejected, `policy.forbid.exists_filter_input` crashed, `policy.forbid.get_error` crashed, `policy.forbid.loaded_count` rejected, `policy.forbid.loaded_sum` rejected, `policy.forbid.offset_page` rejected, `policy.forbid.sum` rejected |
| A bypass policy, for an actor it does not let through | 🟡 Partial 7/16 | `policy.bypass.aggregate_filter` rejected, `policy.bypass.bulk_update` wrong, `policy.bypass.count` rejected, `policy.bypass.exists_filter_input` crashed, `policy.bypass.get_error` crashed, `policy.bypass.loaded_count` rejected, `policy.bypass.loaded_sum` rejected, `policy.bypass.offset_page` rejected, `policy.bypass.sum` rejected |
| A bypass policy, for an actor it lets through | 🟡 Partial 5/13 | `policy.bypass_admin.aggregate_filter` rejected, `policy.bypass_admin.bulk_update` wrong, `policy.bypass_admin.count` rejected, `policy.bypass_admin.exists_filter_input` crashed, `policy.bypass_admin.loaded_count` rejected, `policy.bypass_admin.loaded_sum` rejected, `policy.bypass_admin.offset_page` rejected, `policy.bypass_admin.sum` rejected |
| Two policies that must both pass | 🟡 Partial 7/16 | `policy.all_of.aggregate_filter` rejected, `policy.all_of.bulk_update` wrong, `policy.all_of.count` rejected, `policy.all_of.exists_filter_input` crashed, `policy.all_of.get_error` crashed, `policy.all_of.loaded_count` rejected, `policy.all_of.loaded_sum` rejected, `policy.all_of.offset_page` rejected, `policy.all_of.sum` rejected |
| One policy whose checks either pass | 🟡 Partial 7/16 | `policy.any_of.aggregate_filter` rejected, `policy.any_of.bulk_update` wrong, `policy.any_of.count` rejected, `policy.any_of.exists_filter_input` crashed, `policy.any_of.get_error` crashed, `policy.any_of.loaded_count` rejected, `policy.any_of.loaded_sum` rejected, `policy.any_of.offset_page` rejected, `policy.any_of.sum` rejected |
| A policy on a to-one relationship | 🟡 Partial 1/16 | `policy.related.aggregate_filter` rejected, `policy.related.bulk_destroy` crashed, `policy.related.bulk_update` crashed, `policy.related.count` crashed, `policy.related.exists_filter_input` crashed, `policy.related.get_error` crashed, `policy.related.get_hidden` crashed, `policy.related.keyset_pages` crashed, `policy.related.load` crashed, `policy.related.loaded_count` rejected, `policy.related.loaded_sum` rejected, `policy.related.offset_page` crashed, `policy.related.read` crashed, `policy.related.sum` crashed, `policy.related.update_hidden` crashed |
| A policy on a multi-hop exists | 🟡 Partial 7/16 | `policy.member.aggregate_filter` rejected, `policy.member.bulk_update` wrong, `policy.member.count` rejected, `policy.member.exists_filter_input` crashed, `policy.member.get_error` crashed, `policy.member.loaded_count` rejected, `policy.member.loaded_sum` rejected, `policy.member.offset_page` rejected, `policy.member.sum` rejected |
| A policy composed with can_read | 🟡 Partial 7/16 | `policy.can_read.aggregate_filter` rejected, `policy.can_read.bulk_update` wrong, `policy.can_read.count` rejected, `policy.can_read.exists_filter_input` crashed, `policy.can_read.get_error` crashed, `policy.can_read.loaded_count` rejected, `policy.can_read.loaded_sum` rejected, `policy.can_read.offset_page` rejected, `policy.can_read.sum` rejected |
| A strict policy, for an actor it forbids | 🟡 Partial 10/16 | `policy.strict.aggregate_filter` rejected, `policy.strict.bulk_destroy` wrong, `policy.strict.bulk_update` wrong, `policy.strict.exists_filter_input` crashed, `policy.strict.loaded_count` rejected, `policy.strict.loaded_sum` rejected |
| A strict policy, for an actor it allows | 🟡 Partial 5/13 | `policy.strict_admin.aggregate_filter` rejected, `policy.strict_admin.bulk_update` wrong, `policy.strict_admin.count` rejected, `policy.strict_admin.exists_filter_input` crashed, `policy.strict_admin.loaded_count` rejected, `policy.strict_admin.loaded_sum` rejected, `policy.strict_admin.offset_page` rejected, `policy.strict_admin.sum` rejected |
| Field policies hide values, in reads, filters and aggregates | 🟡 Partial 3/4 | `policy.field.field_aggregate` rejected |
| A filter check on create runs after the insert | 🟡 Partial 1/2 | `policy.owner.create_other` wrong |
| Every policy path, without authorization | 🟡 Partial 13/22 | `policy.control.aggregate_filter` rejected, `policy.control.bulk_update` wrong, `policy.control.count` rejected, `policy.control.exists_filter_input` crashed, `policy.control.field_aggregate` rejected, `policy.control.loaded_count` rejected, `policy.control.loaded_sum` rejected, `policy.control.offset_page` rejected, `policy.control.sum` rejected |

## 12. Consistency checks

| Feature | csv | Not working |
| --- | --- | --- |
| Counts match loads, and root sums match an in-memory reference | ⛔ Not supported 0/2 | `equivalence.root_reference` rejected, `equivalence.visible_count_load` rejected |

## Claims versus results

A data layer's `can?/2` claims never decide what runs. This lists features
whose claims disagree with the result:

- advertised, but not working;
- working without being advertised, usually because Ash provides it;
- not advertised, yet not rejected, and giving wrong answers.

| Feature | Adapter | Mismatch |
| --- | --- | --- |
| Bulk create with partial success | csv | Not advertising `tenant_item: :bulk_create_with_partial_success`, but not rejected either: wrong answers |
| Bulk update atomically | csv | Not advertising `tenant_item: :update_query`, `tenant_item: {:atomic, :update}`, but not rejected either: wrong answers |
| Tenancy scopes creates, updates and destroys | csv | Works without advertising `tenant_item: :destroy_query` |
| Policies filter pages and counts | csv | Advertised, but ⛔ Not supported |


## Storage

Each cell shows the ordinary, edge and nil values, in that order. ✅ reads
back unchanged; ≈ reads back equal but in another representation, such as
`1.5` as `1.5000000000`; ❌ is lost or rejected; 🚫 the table could not be
created; 🔀 differs between seed orders; ❔ did not run; – the type has no
values of that class.

| Type | Column | Ordinary | Edge | Nil | First problem |
| --- | --- | --- | --- | --- | --- |
| Integers | `—` | ✅ | ✅ | ✅ |  |
| Floats | `—` | ❌ | ❌ | ✅ | ordinary, create: stored value for value could not be casted from the stored value to type Ash.Type.Float: "1.5" |
| Decimals | `—` | ✅ | ✅ | ✅ |  |
| Strings | `—` | ✅ | ❌ | ✅ | edge, read: nil |
| Case-insensitive strings | `—` | ✅ | ❌ | ✅ | edge, read: nil |
| Binaries | `—` | ❌ | ❌ | ✅ | ordinary, update: "dGV4dA==" |
| Booleans | `—` | ❌ | – | ✅ | ordinary, create: stored value for value could not be casted from the stored value to type Ash.Type.Boolean: "true" |
| Atoms with one_of | `—` | ✅ | – | ✅ |  |
| Dates | `—` | ✅ | ✅ | ✅ |  |
| Times | `—` | ✅ | ✅ | ✅ |  |
| Microsecond times | `—` | ✅ | ✅ | ✅ |  |
| UTC datetimes | `—` | ✅ | ✅ | ✅ |  |
| Microsecond UTC datetimes | `—` | ✅ | ✅ | ✅ |  |
| Naive datetimes | `—` | ✅ | ✅ | ✅ |  |
| Durations | `—` | ❌ | ❌ | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol String.Chars not implemented for Duration (a struct) |
| UUIDs | `—` | ✅ | ✅ | ✅ |  |
| UUIDv7s | `—` | ✅ | – | ✅ |  |
| Maps | `—` | ❌ | ❌ | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol String.Chars not implemented for Map |
| Arrays of strings | `—` | ❌ | ❌ | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol Enumerable not implemented for BitString |
| Arrays of integers | `—` | ❌ | ❌ | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol Enumerable not implemented for BitString |
| Embedded resources | `—` | ❌ | ❌ | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol String.Chars not implemented for Ash.Conformance.Resources.Address (a struct) |
| Arrays of embedded resources | `—` | ❌ | ❌ | ✅ | ordinary, create: ** (ArgumentError) cannot convert the given list to a string. |
| Unions | `—` | ❌ | – | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol String.Chars not implemented for Ash.Union (a struct) |

## Policies

✅ returns the answer Ash's policy semantics define; ❌ does not, while the
same path works without authorization; ◌ the path fails even without
authorization, so the policy cannot be judged; ❔ did not run; – does not
apply, such as getting a hidden record when the actor may read every note.

| Case | `read` | `get_hidden` | `get_error` | `count` | `sum` | `offset_page` | `keyset_pages` | `load` | `loaded_count` | `loaded_sum` | `aggregate_filter` | `exists_filter` | `exists_filter_input` | `bulk_update` | `bulk_destroy` | `update_hidden` | `field_read` | `field_filter` | `field_filter_input` | `field_aggregate` | `create_own` | `create_other` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| owner | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | ✅ | ❌ |
| owner_nil_actor | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ❌ | ✅ | – | – | – | – | – | – |
| forbid | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| bypass | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| bypass_admin | ✅ | – | – | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | – | – | – | – | – | – | – |
| all_of | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| any_of | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| related | ❌ | ❌ | ❌ | ◌ | ◌ | ◌ | ❌ | ❌ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ❌ | ❌ | – | – | – | – | – | – |
| member | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| can_read | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| strict | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ❌ | ✅ | – | – | – | – | – | – |
| strict_admin | ✅ | – | – | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | – | – | – | – | – | – | – |
| field | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | ✅ | ✅ | ✅ | ◌ | – | – |
| control (no authorization) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
