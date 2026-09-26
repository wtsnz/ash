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

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Integers | ✅ Works 3/3 |  |
| Floats | ✅ Works 3/3 |  |
| Decimals | ❌ Broken 0/3 | `storage.decimal.edge` wrong, `storage.decimal.null` wrong, `storage.decimal.ordinary` wrong |
| Strings | ✅ Works 3/3 |  |
| Case-insensitive strings | 🟡 Partial 1/3 | `storage.ci_string.edge` wrong, `storage.ci_string.ordinary` wrong |
| Binaries | 🟡 Partial 2/3 | `storage.binary.edge` wrong |
| Booleans | ✅ Works 2/2 |  |
| Atoms with one_of | ✅ Works 2/2 |  |
| Dates | 🟡 Partial 1/3 | `storage.date.edge` wrong, `storage.date.ordinary` wrong |
| Times | ✅ Works 3/3 |  |
| Microsecond times | 🟡 Partial 1/3 | `storage.time_usec.edge` wrong, `storage.time_usec.ordinary` wrong |
| UTC datetimes | 🟡 Partial 1/3 | `storage.utc_datetime.edge` wrong, `storage.utc_datetime.ordinary` wrong |
| Microsecond UTC datetimes | 🟡 Partial 1/3 | `storage.utc_datetime_usec.edge` wrong, `storage.utc_datetime_usec.ordinary` wrong |
| Naive datetimes | 🟡 Partial 1/3 | `storage.naive_datetime.edge` wrong, `storage.naive_datetime.ordinary` wrong |
| Durations | 🟡 Partial 1/3 | `storage.duration.edge` wrong, `storage.duration.ordinary` wrong |
| UUIDs | 🟡 Partial 1/3 | `storage.uuid.edge` wrong, `storage.uuid.ordinary` wrong |
| UUIDv7s | ✅ Works 2/2 |  |
| Maps | ❌ Broken 0/3 | `storage.map.edge` wrong, `storage.map.null` wrong, `storage.map.ordinary` wrong |
| Arrays of strings | ❌ Broken 0/3 | `storage.strings.edge` wrong, `storage.strings.null` wrong, `storage.strings.ordinary` wrong |
| Arrays of integers | ❌ Broken 0/3 | `storage.integers.edge` wrong, `storage.integers.null` wrong, `storage.integers.ordinary` wrong |
| Embedded resources | ❌ Broken 0/3 | `storage.embedded.edge` wrong, `storage.embedded.null` wrong, `storage.embedded.ordinary` wrong |
| Arrays of embedded resources | ❌ Broken 0/3 | `storage.embeddeds.edge` wrong, `storage.embeddeds.null` wrong, `storage.embeddeds.ordinary` wrong |
| Unions | ❌ Broken 0/2 | `storage.union.null` wrong, `storage.union.ordinary` wrong |

## 2. Records

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Read records | ❔ Unknown 1 not run | `record.read_all` setup failed |
| Get one record by primary key or identity | ❔ Unknown 2 not run | `record.get_identity` setup failed, `record.get_primary_key` setup failed |
| Select only some attributes | ❌ Broken 0/1 · 1 not run | `read.selection_expression` crashed, `record.select` setup failed |
| Create a record | ❔ Unknown 1 not run | `record.create` setup failed |
| Update a record, including to nil | ❔ Unknown 2 not run | `record.update` setup failed, `record.update_to_nil` setup failed |
| Destroy a record | ❔ Unknown 1 not run | `record.destroy` setup failed |
| Update a record atomically from its current value | ❔ Unknown 1 not run | `record.atomic_update` setup failed |
| Not found, invalid, missing and duplicate values are errors | ❔ Unknown 4 not run | `record.identity_conflict` setup failed, `record.invalid_value` setup failed, `record.not_found` setup failed, `record.required` setup failed |

## 3. Types

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Strings, integers, booleans, atoms and nil round-trip | ❔ Unknown 3 not run | `record.types_nil` setup failed, `record.types_scalar` setup failed, `record.types_strings` setup failed |
| Large integers, floats and decimals round-trip | ❌ Broken 0/1 · 1 not run | `record.types_numeric` setup failed, `values.decimal_read_control` wrong |
| Dates, microsecond datetimes and times round-trip | ❌ Broken 0/1 · 1 not run · 1 blocked | `record.types_temporal` setup failed, `values.temporal_read_control` wrong (blocked by `storage.date.ordinary`, `storage.utc_datetime_usec.ordinary`) |
| UUIDs round-trip | ❔ Unknown 1 not run | `record.types_uuid` setup failed |
| Arrays round-trip, keeping order and duplicates | ❔ Unknown 1 not run | `record.types_array` setup failed |
| Maps round-trip, including nested values | ❔ Unknown 1 not run | `record.types_map` setup failed |
| Embedded resources round-trip | ❔ Unknown 1 not run | `record.types_embedded` setup failed |

## 4. Querying

| Feature | clickhouse | Not working |
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
| Distinct records by a field | ❌ Broken 0/1 | `query.distinct` crashed |
| Combine queries with union | ⛔ Not supported 0/1 | `query.union` rejected |
| Combine queries with union all and intersection | ⚪ Untested |  |
| Load expression calculations, with arguments | 🔸 Incomplete 1/1 · 2 not run | `record.calculation_argument` setup failed, `record.calculation_load` setup failed |
| Offset pagination with counts | ❔ Unknown 1 not run | `record.offset_pages` setup failed |
| Keyset pagination, forwards and backwards | ❔ Unknown 1 not run | `record.keyset_pages` setup failed |
| Pagination while records change | ⚪ Untested |  |

## 5. Relationships

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Filter across to-many relationships without duplicates | ❌ Broken 0/3 | `filter.fanout_read_control` crashed, `use.fanout_count` crashed, `use.fanout_read_page` crashed |
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

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Load each aggregate kind on records | 🟡 Partial 4/9 | `loaded.avg` wrong, `loaded.custom` rejected, `loaded.exists` rejected, `loaded.first` rejected, `loaded.list` rejected |
| Run each aggregate kind over a whole query | 🟡 Partial 5/15 | `root.custom` rejected, `root.custom_empty` rejected, `root.exists` rejected, `root.first` rejected, `root.list` rejected, `root.list_default_empty` rejected, `root.list_empty` rejected, `root.list_unsorted` rejected, `root.unsorted_first_empty` rejected, `values.root_empty` rejected |
| Defaults, nils, uniqueness and field counts | 🟡 Partial 4/12 | `values.distinct_count` wrong, `values.distinct_list` rejected, `values.filtered_first_default` rejected, `values.include_nil_first` rejected, `values.include_nil_list` rejected, `values.list_default` rejected, `values.list_unsorted` rejected, `values.same_name_distinct_definitions` wrong |
| Aggregate decimals, dates, times and constrained types | 🟡 Partial 4/15 · 9 blocked | `root.decimal_sum` wrong (blocked by `values.decimal_read_control`), `values.constrained_scalar` wrong, `values.date_list` rejected (blocked by `storage.date.ordinary`, `storage.utc_datetime_usec.ordinary`), `values.date_list_desc` rejected (blocked by `storage.date.ordinary`, `storage.utc_datetime_usec.ordinary`), `values.date_max` wrong (blocked by `storage.date.ordinary`, `storage.utc_datetime_usec.ordinary`), `values.date_min` wrong (blocked by `storage.date.ordinary`, `storage.utc_datetime_usec.ordinary`), `values.datetime_first` rejected (blocked by `storage.date.ordinary`, `storage.utc_datetime_usec.ordinary`), `values.decimal_avg` wrong (blocked by `values.decimal_read_control`), `values.decimal_max` wrong (blocked by `values.decimal_read_control`), `values.decimal_sum` wrong (blocked by `values.decimal_read_control`), `values.string_constraints` rejected |
| Order first and list aggregates, including nils and ties | ⛔ Not supported 0/9 | `ordering.asc_nils_first` rejected, `ordering.asc_nils_last` rejected, `ordering.desc_nils_first` rejected, `ordering.desc_nils_last` rejected, `ordering.expression_first` rejected, `ordering.expression_list` rejected, `ordering.list_desc` rejected, `ordering.ties` rejected, `ordering.unique_other_field` open question |
| Aggregate calculations and other aggregates | ❌ Broken 0/3 | `field.aggregate` crashed, `field.calculation` crashed, `field.root_aggregate` crashed |
| Filter the records an aggregate uses | ❌ Broken 0/6 | `filter.exists` wrong, `filter.join` wrong, `filter.not_exists` wrong, `filter.or_exists` wrong, `filter.ordinary` wrong, `filter.sibling_independence` wrong |
| Aggregate filters through to-many relationships count each record once | ❌ Broken 0/11 · 9 blocked | `filter.fanout_and` crashed (blocked by `filter.fanout_read_control`), `filter.fanout_avg` crashed (blocked by `filter.fanout_read_control`), `filter.fanout_count` crashed (blocked by `filter.fanout_read_control`), `filter.fanout_count_records` crashed (blocked by `filter.fanout_read_control`), `filter.fanout_custom` rejected (blocked by `filter.fanout_read_control`), `filter.fanout_list` rejected (blocked by `filter.fanout_read_control`), `filter.fanout_nil_count` crashed, `filter.fanout_not_count` crashed (blocked by `filter.fanout_read_control`), `filter.fanout_or` crashed (blocked by `filter.fanout_read_control`), `filter.fanout_sum` crashed (blocked by `filter.fanout_read_control`), `identity.composite_fanout_count` crashed |
| Aggregate filters that use other aggregates | ❌ Broken 0/5 | `filter.aggregate_dependency` wrong, `filter.aggregate_dependency_calculation` wrong, `filter.aggregate_dependency_filtered` wrong, `filter.aggregate_dependency_many_to_many` wrong, `filter.aggregate_dependency_to_one` crashed |
| Aggregate filters that reference the parent record | ❌ Broken 0/8 · 2 blocked | `filter.nested_parent` wrong (blocked by `filter.nested_parent_control`), `filter.parent` wrong, `filter.parent_join` wrong, `filter.parent_relationship` wrong, `filter.parent_through` wrong (blocked by `filter.parent_through_control`), `filter.parent_unrelated` rejected, `use.parent_filter` crashed, `use.parent_sort` crashed |
| Aggregate over to-one, multi-hop and many-to-many paths | ❌ Broken 0/17 | `path.final_many_to_many_custom` rejected, `path.final_many_to_many_first` rejected, `path.final_many_to_many_list` rejected, `path.final_many_to_many_scalar` wrong, `path.intermediate_many_to_many` wrong, `path.many_to_many` wrong, `path.many_to_many_first` rejected, `path.many_to_many_list` rejected, `path.multi_hop` wrong, `path.repeated_many_to_many` open question, `path.root_relationship` crashed, `path.through_count` crashed, `path.to_one` crashed, `path.to_one_to_many_first` rejected, `path.to_one_to_many_list` rejected, `path.to_one_to_many_sum` wrong, `path.unrelated` rejected |
| Aggregate over manual and attribute-free relationships | 🟡 Partial 1/3 | `path.no_attributes` wrong, `path.no_attributes_parent` wrong |
| Aggregate over limited, offset and from-many relationships | ❌ Broken 0/9 | `bounds.default_sort` rejected, `bounds.filter_after_limit` wrong, `bounds.from_many` wrong, `bounds.list_filter_after_limit` rejected, `bounds.many_to_many_query_limit` open question, `bounds.relationship_limit` wrong, `bounds.relationship_offset` wrong, `bounds.relationship_offset_only` wrong, `bounds.unsorted_limit` wrong |
| Root aggregates over sorted, limited and offset queries | ❌ Broken 0/7 | `bounds.root_custom_limit` rejected, `bounds.root_first_distinct_sort` rejected, `bounds.root_limit` wrong, `bounds.root_list_limit` rejected, `bounds.root_offset_only` wrong, `bounds.root_order_then_limit` wrong, `bounds.root_zero` rejected |
| Distinct counts over composite and missing keys | 🟡 Partial 3/5 | `identity.keyless_distinct` open question, `identity.keyless_source` crashed |
| Filter, sort, paginate and calculate with aggregates | ❌ Broken 0/10 | `use.calculation` crashed, `use.filter` crashed, `use.keyset_pagination` crashed, `use.nested_limited_load` wrong, `use.pagination` crashed, `use.related_exists` crashed, `use.related_filter` crashed, `use.sort` crashed, `use.to_one_filter` crashed, `use.to_one_sort` crashed |
| Aggregates respect read actions, arguments, actor and context | ❌ Broken 0/9 · 2 blocked | `context.actor` wrong, `context.arguments` wrong, `context.intermediate_action` wrong, `context.intermediate_actor` wrong, `context.prepared_query_arguments` wrong, `context.read_action` wrong, `context.relationship_context` wrong (blocked by `context.relationship_context_control`), `context.shared` wrong (blocked by `context.relationship_context_control`), `context.through_arguments` wrong |
| Seeded filtered aggregates match an in-memory reference | ⛔ Not supported 0/1 | `generated.filtered_aggregates` rejected |

## 7. Writes

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Upsert on an identity, in bulk, with conditions | ❌ Broken 0/4 | `upsert.bulk` crashed, `upsert.condition` crashed, `upsert.skipped_record` wrong, `upsert.tenant_identity` rejected |
| Bulk create with partial success | ❌ Broken 0/1 | `bulk.partial_success` wrong |
| Bulk update atomically | ❌ Broken 0/1 | `bulk.atomic_increment` crashed |
| Writes that filter by or read aggregates | ❌ Broken 0/4 | `write.atomic_update` crashed, `write.bulk_destroy_filter` crashed, `write.bulk_update_filter` crashed, `write.single_atomic_update` rejected |

## 8. Transactions and locks

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Failed actions and transactions roll back | 🟡 Partial 1/4 | `txn.after_action_rollback` wrong, `txn.explicit_rollback` crashed, `txn.raise_rollback` wrong |
| Lock rows for update | ⛔ Not supported 0/1 | `query.lock_for_update` rejected |
| Isolation between concurrent transactions | ⚪ Untested |  |

## 9. Multitenancy

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Attribute tenancy scopes reads and requires a tenant | 🟡 Partial 5/6 | `tenant.invalid` wrong |
| Tenancy scopes related records and their bounds | 🟡 Partial 3/4 | `tenant.relationship_filter` crashed |
| Tenancy scopes aggregates, including explicit bypass | 🟡 Partial 2/8 | `context.attribute_tenant` wrong, `context.bypass_sibling` wrong, `context.through_bypass` wrong, `context.through_tenant` wrong, `tenant.aggregate_filter_sort` crashed, `tenant.loaded_aggregates` wrong |
| Tenancy scopes pages and counts | ❌ Broken 0/2 | `tenant.aggregate_keyset_pages` crashed, `tenant.aggregate_offset_page` crashed |
| Tenancy scopes creates, updates and destroys | ✅ Works 3/3 |  |
| Schema-based (context) tenancy | ➖ Not applicable |  |

## 10. Authorization

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Policies filter reads | ✅ Works 3/3 |  |
| Policies filter related records before bounds | ✅ Works 5/5 |  |
| Policies filter what aggregates count | 🟡 Partial 2/8 | `auth.aggregate_filter` crashed, `auth.aggregate_sort` crashed, `auth.context_aggregates` wrong, `auth.loaded_aggregates` wrong, `context.authorization` wrong, `context.authorization_before_bounds` wrong |
| Policies filter pages and counts | ❌ Broken 0/3 | `auth.keyset_pages` crashed, `auth.offset_page` crashed, `auth.tenant_interaction` wrong |
| Policies filter and forbid writes | 🟡 Partial 3/4 | `auth.write_bulk_update_stream` wrong |

## 11. Policies

| Feature | clickhouse | Not working |
| --- | --- | --- |
| A filter policy on the actor | 🟡 Partial 10/16 · 5 blocked | `policy.owner.aggregate_filter` crashed (blocked by `policy.control.aggregate_filter`), `policy.owner.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.owner.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.owner.get_error` crashed, `policy.owner.loaded_count` wrong (blocked by `policy.control.loaded_count`), `policy.owner.loaded_sum` wrong (blocked by `policy.control.loaded_sum`) |
| The same policy with no actor | 🟡 Partial 11/16 · 4 blocked | `policy.owner_nil_actor.aggregate_filter` crashed (blocked by `policy.control.aggregate_filter`), `policy.owner_nil_actor.bulk_destroy` wrong, `policy.owner_nil_actor.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.owner_nil_actor.loaded_count` wrong (blocked by `policy.control.loaded_count`), `policy.owner_nil_actor.loaded_sum` wrong (blocked by `policy.control.loaded_sum`) |
| forbid_if before authorize_if | 🟡 Partial 10/16 · 5 blocked | `policy.forbid.aggregate_filter` crashed (blocked by `policy.control.aggregate_filter`), `policy.forbid.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.forbid.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.forbid.get_error` crashed, `policy.forbid.loaded_count` wrong (blocked by `policy.control.loaded_count`), `policy.forbid.loaded_sum` wrong (blocked by `policy.control.loaded_sum`) |
| A bypass policy, for an actor it does not let through | 🟡 Partial 10/16 · 5 blocked | `policy.bypass.aggregate_filter` crashed (blocked by `policy.control.aggregate_filter`), `policy.bypass.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.bypass.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.bypass.get_error` crashed, `policy.bypass.loaded_count` wrong (blocked by `policy.control.loaded_count`), `policy.bypass.loaded_sum` wrong (blocked by `policy.control.loaded_sum`) |
| A bypass policy, for an actor it lets through | 🟡 Partial 8/13 · 5 blocked | `policy.bypass_admin.aggregate_filter` crashed (blocked by `policy.control.aggregate_filter`), `policy.bypass_admin.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.bypass_admin.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.bypass_admin.loaded_count` wrong (blocked by `policy.control.loaded_count`), `policy.bypass_admin.loaded_sum` wrong (blocked by `policy.control.loaded_sum`) |
| Two policies that must both pass | 🟡 Partial 10/16 · 5 blocked | `policy.all_of.aggregate_filter` crashed (blocked by `policy.control.aggregate_filter`), `policy.all_of.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.all_of.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.all_of.get_error` crashed, `policy.all_of.loaded_count` wrong (blocked by `policy.control.loaded_count`), `policy.all_of.loaded_sum` wrong (blocked by `policy.control.loaded_sum`) |
| One policy whose checks either pass | 🟡 Partial 10/16 · 5 blocked | `policy.any_of.aggregate_filter` crashed (blocked by `policy.control.aggregate_filter`), `policy.any_of.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.any_of.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.any_of.get_error` crashed, `policy.any_of.loaded_count` wrong (blocked by `policy.control.loaded_count`), `policy.any_of.loaded_sum` wrong (blocked by `policy.control.loaded_sum`) |
| A policy on a to-one relationship | 🟡 Partial 1/16 · 5 blocked | `policy.related.aggregate_filter` crashed (blocked by `policy.control.aggregate_filter`), `policy.related.bulk_destroy` crashed, `policy.related.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.related.count` crashed, `policy.related.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.related.get_error` crashed, `policy.related.get_hidden` crashed, `policy.related.keyset_pages` crashed, `policy.related.load` crashed, `policy.related.loaded_count` crashed (blocked by `policy.control.loaded_count`), `policy.related.loaded_sum` crashed (blocked by `policy.control.loaded_sum`), `policy.related.offset_page` crashed, `policy.related.read` crashed, `policy.related.sum` crashed, `policy.related.update_hidden` crashed |
| A policy on a multi-hop exists | 🟡 Partial 6/16 · 5 blocked | `policy.member.aggregate_filter` crashed (blocked by `policy.control.aggregate_filter`), `policy.member.bulk_destroy` crashed, `policy.member.bulk_update` crashed (blocked by `policy.control.bulk_update`), `policy.member.count` crashed, `policy.member.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.member.get_error` crashed, `policy.member.loaded_count` wrong (blocked by `policy.control.loaded_count`), `policy.member.loaded_sum` wrong (blocked by `policy.control.loaded_sum`), `policy.member.sum` crashed, `policy.member.update_hidden` crashed |
| A policy composed with can_read | 🟡 Partial 6/16 · 5 blocked | `policy.can_read.aggregate_filter` crashed (blocked by `policy.control.aggregate_filter`), `policy.can_read.bulk_destroy` crashed, `policy.can_read.bulk_update` crashed (blocked by `policy.control.bulk_update`), `policy.can_read.count` crashed, `policy.can_read.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.can_read.get_error` crashed, `policy.can_read.loaded_count` wrong (blocked by `policy.control.loaded_count`), `policy.can_read.loaded_sum` wrong (blocked by `policy.control.loaded_sum`), `policy.can_read.sum` crashed, `policy.can_read.update_hidden` crashed |
| A strict policy, for an actor it forbids | 🟡 Partial 11/16 · 4 blocked | `policy.strict.aggregate_filter` crashed (blocked by `policy.control.aggregate_filter`), `policy.strict.bulk_destroy` wrong, `policy.strict.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.strict.loaded_count` wrong (blocked by `policy.control.loaded_count`), `policy.strict.loaded_sum` wrong (blocked by `policy.control.loaded_sum`) |
| A strict policy, for an actor it allows | 🟡 Partial 8/13 · 5 blocked | `policy.strict_admin.aggregate_filter` crashed (blocked by `policy.control.aggregate_filter`), `policy.strict_admin.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.strict_admin.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.strict_admin.loaded_count` wrong (blocked by `policy.control.loaded_count`), `policy.strict_admin.loaded_sum` wrong (blocked by `policy.control.loaded_sum`) |
| Field policies hide values, in reads, filters and aggregates | ❌ Broken 0/4 · 1 blocked | `policy.field.field_aggregate` wrong (blocked by `policy.control.field_aggregate`), `policy.field.field_filter` crashed, `policy.field.field_filter_input` crashed, `policy.field.field_read` crashed |
| A filter check on create runs after the insert | ❌ Broken 0/2 | `policy.owner.create_other` wrong, `policy.owner.create_own` wrong |
| Every policy path, without authorization | 🟡 Partial 16/22 | `policy.control.aggregate_filter` crashed, `policy.control.bulk_update` wrong, `policy.control.exists_filter_input` crashed, `policy.control.field_aggregate` wrong, `policy.control.loaded_count` wrong, `policy.control.loaded_sum` wrong |

## 12. Consistency checks

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Counts match loads, and root sums match an in-memory reference | 🟡 Partial 1/2 | `equivalence.visible_count_load` wrong |

## Claims versus results

A data layer's `can?/2` claims never decide what runs. This lists features
whose claims disagree with the result:

- advertised, but not working;
- working without being advertised, usually because Ash provides it;
- not advertised, yet not rejected, and giving wrong answers.

| Feature | Adapter | Mismatch |
| --- | --- | --- |
| Select only some attributes | clickhouse | Advertised, but ❌ Broken |
| Large integers, floats and decimals round-trip | clickhouse | Advertised, but ❌ Broken |
| Dates, microsecond datetimes and times round-trip | clickhouse | Advertised, but ❌ Broken |
| Distinct records by a field | clickhouse | Not advertising `child: :distinct_sort`, but not rejected either: wrong answers |
| Filter across to-many relationships without duplicates | clickhouse | Not advertising `child: {:filter_relationship, :ratings}`, but not rejected either: wrong answers |
| Limit and offset a has-many load for each parent | clickhouse | Works without advertising `parent: {:lateral_join, :children}` |
| Limit a many-to-many load for each parent | clickhouse | Not advertising `parent: {:lateral_join, :tags}`, but not rejected either: wrong answers |
| Relationships through other relationships | clickhouse | Not advertising `parent: :through_relationship`, but not rejected either: wrong answers |
| Relationships with no attributes load everything | clickhouse | Works without advertising `parent: {:filter_relationship, :all_children}` |
| Parent references in nested and through relationship filters | clickhouse | Not advertising `parent: {:filter_relationship, :same_tenant_tags}`, but not rejected either: wrong answers |
| Load belongs-to, has-one, has-many and many-to-many relationships | clickhouse | Works without advertising `child: {:filter_relationship, :parent}`, `parent: {:filter_relationship, :tags}` |
| Aggregate calculations and other aggregates | clickhouse | Advertised, but ❌ Broken |
| Filter the records an aggregate uses | clickhouse | Not advertising `parent: :aggregate_filter`, but not rejected either: wrong answers |
| Aggregate filters through to-many relationships count each record once | clickhouse | Not advertising `child: {:filter_relationship, :ratings}`, but not rejected either: wrong answers |
| Aggregate filters that use other aggregates | clickhouse | Not advertising `child: :aggregate_filter`, but not rejected either: wrong answers |
| Aggregate filters that reference the parent record | clickhouse | Not advertising `parent: {:aggregate_relationship, :above_threshold}`, but not rejected either: wrong answers |
| Aggregate over to-one, multi-hop and many-to-many paths | clickhouse | Not advertising `parent: {:aggregate_relationship, :tags}`, `parent: {:aggregate, :unrelated}`, but not rejected either: wrong answers |
| Aggregate over limited, offset and from-many relationships | clickhouse | Not advertising `parent: {:aggregate_relationship, :top_children}`, but not rejected either: wrong answers |
| Root aggregates over sorted, limited and offset queries | clickhouse | Advertised, but ❌ Broken |
| Filter, sort, paginate and calculate with aggregates | clickhouse | Not advertising `parent: :aggregate_filter`, `parent: :aggregate_sort`, but not rejected either: wrong answers |
| Aggregates respect read actions, arguments, actor and context | clickhouse | Not advertising `parent: {:aggregate_relationship, :children}`, but not rejected either: wrong answers |
| Seeded filtered aggregates match an in-memory reference | clickhouse | Advertised, but ⛔ Not supported |
| Upsert on an identity, in bulk, with conditions | clickhouse | Not advertising `tenant_item: :upsert`, `tenant_item: {:atomic, :upsert}`, `tenant_item: :bulk_upsert_return_skipped`, but not rejected either: wrong answers |
| Bulk create with partial success | clickhouse | Not advertising `tenant_item: :bulk_create_with_partial_success`, but not rejected either: wrong answers |
| Bulk update atomically | clickhouse | Not advertising `tenant_item: {:atomic, :update}`, but not rejected either: wrong answers |
| Writes that filter by or read aggregates | clickhouse | Advertised, but ❌ Broken |
| Tenancy scopes pages and counts | clickhouse | Not advertising `tenant_parent: :keyset`, but not rejected either: wrong answers |
| Policies filter pages and counts | clickhouse | Advertised, but ❌ Broken |
| A filter check on create runs after the insert | clickhouse | Not advertising `policy_owner_note: :transact`, but not rejected either: wrong answers |


## Storage

Each cell shows the ordinary, edge and nil values, in that order. ✅ reads
back unchanged; ≈ reads back equal but in another representation, such as
`1.5` as `1.5000000000`; ❌ is lost or rejected; 🚫 the table could not be
created; 🔀 differs between seed orders; ❔ did not run; – the type has no
values of that class.

| Type | Column | Ordinary | Edge | Nil | First problem |
| --- | --- | --- | --- | --- | --- |
| Integers | `Nullable(Int64)` | ✅ | ✅ | ✅ |  |
| Floats | `Nullable(Float64)` | ✅ | ✅ | ✅ |  |
| Decimals | `—` | 🚫 | 🚫 | 🚫 | ordinary, table: ["Code: 43. DB::Exception: Decimal argument precision is invalid. (ILLEGAL_TYPE_OF_ARGUMENT) (version 25.8.33.6 (official build))"] |
| Strings | `Nullable(String)` | ✅ | ✅ | ✅ |  |
| Case-insensitive strings | `Nullable(String)` | ≈ | ≈ | ✅ | ordinary, read: "Hello" |
| Binaries | `Nullable(String)` | ✅ | ❌ | ✅ | edge, create: ** (Jason.EncodeError) invalid byte 0xFF in <<0, 255, 0, 128>> |
| Booleans | `Nullable(UInt8)` | ✅ | – | ✅ |  |
| Atoms with one_of | `Nullable(String)` | ✅ | – | ✅ |  |
| Dates | `Nullable(Date)` | ❌ | ❌ | ✅ | ordinary, read: "2024-02-29" |
| Times | `Nullable(String)` | ✅ | ✅ | ✅ |  |
| Microsecond times | `Nullable(String)` | ❌ | ❌ | ✅ | ordinary, read: "12:34:56.123456" |
| UTC datetimes | `Nullable(DateTime64(6))` | ≈ | ≈ | ✅ | ordinary, read: ~U[2024-02-29 12:34:56.000000Z] |
| Microsecond UTC datetimes | `Nullable(DateTime64(6))` | ❌ | ❌ | ✅ | ordinary, update: ~U[2024-02-29 12:34:56.000000Z] |
| Naive datetimes | `Nullable(DateTime64(6))` | ❌ | ❌ | ✅ | ordinary, read: ~U[2024-02-29 12:34:56.000000Z] |
| Durations | `Nullable(String)` | ❌ | ❌ | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol Jason.Encoder not implemented for Duration (a struct), Jason.Encoder protocol must always be explicitly implemented. |
| UUIDs | `Nullable(UUID)` | ❌ | ❌ | ✅ | ordinary, update: nil |
| UUIDv7s | `Nullable(UUID)` | ✅ | – | ✅ |  |
| Maps | `—` | 🚫 | 🚫 | 🚫 | ordinary, table: ClickHouse does not support Nullable(Map(String, String)) because the inner type is a |
| Arrays of strings | `—` | 🚫 | 🚫 | 🚫 | ordinary, table: ClickHouse does not support Nullable(Array(String)) because the inner type is a |
| Arrays of integers | `—` | 🚫 | 🚫 | 🚫 | ordinary, table: ClickHouse does not support Nullable(Array(Int64)) because the inner type is a |
| Embedded resources | `—` | 🚫 | 🚫 | 🚫 | ordinary, table: ClickHouse does not support Nullable(Map(String, String)) because the inner type is a |
| Arrays of embedded resources | `—` | 🚫 | 🚫 | 🚫 | ordinary, table: ClickHouse does not support Nullable(Array(String)) because the inner type is a |
| Unions | `—` | 🚫 | – | 🚫 | ordinary, table: ClickHouse does not support Nullable(Map(String, String)) because the inner type is a |

## Policies

✅ returns the answer Ash's policy semantics define; ❌ does not, while the
same path works without authorization; ◌ the path fails even without
authorization, so the policy cannot be judged; ❔ did not run; – does not
apply, such as getting a hidden record when the actor may read every note.

| Case | `read` | `get_hidden` | `get_error` | `count` | `sum` | `offset_page` | `keyset_pages` | `load` | `loaded_count` | `loaded_sum` | `aggregate_filter` | `exists_filter` | `exists_filter_input` | `bulk_update` | `bulk_destroy` | `update_hidden` | `field_read` | `field_filter` | `field_filter_input` | `field_aggregate` | `create_own` | `create_other` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| owner | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | ❌ | ❌ |
| owner_nil_actor | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ✅ | ❌ | ✅ | – | – | – | – | – | – |
| forbid | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| bypass | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| bypass_admin | ✅ | – | – | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | – | – | – | – | – | – | – |
| all_of | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| any_of | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| related | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ❌ | ❌ | – | – | – | – | – | – |
| member | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ❌ | ❌ | – | – | – | – | – | – |
| can_read | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ❌ | ❌ | – | – | – | – | – | – |
| strict | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ✅ | ❌ | ✅ | – | – | – | – | – | – |
| strict_admin | ✅ | – | – | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | – | – | – | – | – | – | – |
| field | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | ❌ | ❌ | ❌ | ◌ | – | – |
| control (no authorization) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |

## Blockers

| Blocker | Its result | Not run | Failing | Only blocker of |
| --- | --- | ---: | ---: | ---: |
| `policy.control.aggregate_filter` | crashed | 0 | 12 | 12 |
| `policy.control.exists_filter_input` | crashed | 0 | 12 | 12 |
| `policy.control.loaded_count` | wrong | 0 | 12 | 12 |
| `policy.control.loaded_sum` | wrong | 0 | 12 | 12 |
| `policy.control.bulk_update` | wrong | 0 | 10 | 10 |
| `filter.fanout_read_control` | crashed | 0 | 9 | 9 |
| `storage.date.ordinary` | lost at read: "2024-02-29" | 0 | 6 | 0 |
| `storage.utc_datetime_usec.ordinary` | lost at update: ~U[2024-02-29 12:34:56.000000Z] | 0 | 6 | 0 |
| `values.decimal_read_control` | wrong | 0 | 4 | 4 |
| `context.relationship_context_control` | wrong | 0 | 2 | 2 |
| `filter.nested_parent_control` | crashed | 0 | 1 | 1 |
| `filter.parent_through_control` | crashed | 0 | 1 | 1 |
| `policy.control.field_aggregate` | wrong | 0 | 1 | 1 |

Setup failures that no storage cell explains: no type in the row
raised when stored on its own, or tier 1 could not test it.

| Scenarios | Role | Reason |
| ---: | --- | --- |
| 58 | `record` | protocol Jason.Encoder not implemented for Ash.Conformance.Resources.Address (a struct), Jason.Encoder protocol must always be explicitly implemented. |
