<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# What each data layer supports

Generated from an unreviewed run: each result was classified automatically against the intended answer. Nothing here has been reviewed.

Feature catalog version 1: 80 features and 302 scenarios.

| Status | Meaning |
| --- | --- |
| ✅ Works | Every scenario returns the answer Ash defines. |
| 🟡 Partial | Some scenarios work; others are rejected or wrong. |
| ⛔ Not supported | Every scenario is rejected with a documented error. |
| ❌ Broken | Nothing works, and at least one scenario gives a wrong answer or crashes. |
| ❓ Open question | The remaining scenarios need a semantic decision in Ash. |
| ⚪ Untested | Listed so the specification is complete; no scenario verifies it yet. |
| ➖ Not applicable | The data layer does not provide this storage profile. |
| ⚠️ Changed | A result no longer matches its recorded contract. |

Counts are passing scenarios out of those run. Gap links explain everything
that is not fully working, and who owns the fix.

## 1. Records

| Feature | csv | Not working |
| --- | --- | --- |
| Read records | ❌ Broken 0/1 | `record.read_all` setup failed |
| Get one record by primary key or identity | ❌ Broken 0/2 | `record.get_identity` setup failed, `record.get_primary_key` setup failed |
| Select only some attributes | 🟡 Partial 1/2 | `record.select` setup failed |
| Create a record | ❌ Broken 0/1 | `record.create` setup failed |
| Update a record, including to nil | ❌ Broken 0/2 | `record.update` setup failed, `record.update_to_nil` setup failed |
| Destroy a record | ❌ Broken 0/1 | `record.destroy` setup failed |
| Update a record atomically from its current value | ❌ Broken 0/1 | `record.atomic_update` setup failed |
| Not found, invalid, missing and duplicate values are errors | ❌ Broken 0/4 | `record.identity_conflict` setup failed, `record.invalid_value` setup failed, `record.not_found` setup failed, `record.required` setup failed |

## 2. Types

| Feature | csv | Not working |
| --- | --- | --- |
| Strings, integers, booleans, atoms and nil round-trip | ❌ Broken 0/3 | `record.types_nil` setup failed, `record.types_scalar` setup failed, `record.types_strings` setup failed |
| Large integers, floats and decimals round-trip | ❌ Broken 0/2 | `record.types_numeric` setup failed, `values.decimal_read_control` setup failed |
| Dates, microsecond datetimes and times round-trip | ❌ Broken 0/1 | `record.types_temporal` setup failed |
| UUIDs round-trip | ❌ Broken 0/1 | `record.types_uuid` setup failed |
| Arrays round-trip, keeping order and duplicates | ❌ Broken 0/1 | `record.types_array` setup failed |
| Maps round-trip, including nested values | ❌ Broken 0/1 | `record.types_map` setup failed |
| Embedded resources round-trip | ❌ Broken 0/1 | `record.types_embedded` setup failed |

## 3. Querying

| Feature | csv | Not working |
| --- | --- | --- |
| Filter with comparisons on numbers, decimals and dates | ❌ Broken 0/6 | `record.filter_date` setup failed, `record.filter_datetime_precision` setup failed, `record.filter_decimal` setup failed, `record.filter_equal` setup failed, `record.filter_not_equal` setup failed, `record.filter_range` setup failed |
| Nil behaves like SQL NULL in filters | ❌ Broken 0/5 | `record.filter_in_with_nil` setup failed, `record.filter_is_nil` setup failed, `record.filter_not` setup failed, `record.filter_not_nil` setup failed, `record.filter_true_or_nil` setup failed |
| Filter booleans and atoms, including atoms as strings | ❌ Broken 0/3 | `record.filter_atom` setup failed, `record.filter_atom_as_string` setup failed, `record.filter_boolean` setup failed |
| Filter strings: contains, case, unicode and empty | ❌ Broken 0/4 | `record.filter_case_insensitive` setup failed, `record.filter_contains` setup failed, `record.filter_empty_string` setup failed, `record.filter_unicode` setup failed |
| Filter inside arrays, maps and embedded resources | ❌ Broken 0/3 | `record.filter_array_member` setup failed, `record.filter_embedded` setup failed, `record.filter_map_key` setup failed |
| Filter by a calculation | ❌ Broken 0/1 | `record.filter_calculation` setup failed |
| Sort by one or more fields, with explicit nil order | ❌ Broken 0/6 | `record.sort_asc_nils_first` setup failed, `record.sort_date` setup failed, `record.sort_decimal` setup failed, `record.sort_desc_nils_last` setup failed, `record.sort_string` setup failed, `record.sort_tie_break` setup failed |
| Sort by a calculation | ❌ Broken 0/1 | `record.sort_calculation` setup failed |
| Limit and offset a query | ❌ Broken 0/1 | `record.limit_offset` setup failed |
| Count and check existence | ❌ Broken 0/1 | `record.count` setup failed |
| Stream records in batches | ❌ Broken 0/1 | `record.stream` setup failed |
| Distinct records by a field | ❌ Broken 0/1 | `query.distinct` setup failed |
| Combine queries with union | ❌ Broken 0/1 | `query.union` setup failed |
| Combine queries with union all and intersection | ⚪ Untested |  |
| Load expression calculations, with arguments | ❌ Broken 0/3 | `calc.in_memory` setup failed, `record.calculation_argument` setup failed, `record.calculation_load` setup failed |
| Offset pagination with counts | ❌ Broken 0/1 | `record.offset_pages` setup failed |
| Keyset pagination, forwards and backwards | ❌ Broken 0/1 | `record.keyset_pages` setup failed |
| Pagination while records change | ⚪ Untested |  |

## 4. Relationships

| Feature | csv | Not working |
| --- | --- | --- |
| Filter across to-many relationships without duplicates | ❌ Broken 0/3 | `filter.fanout_read_control` setup failed, `use.fanout_count` setup failed, `use.fanout_read_page` setup failed |
| Limit and offset a has-many load for each parent | ❌ Broken 0/2 | `load.limit_per_parent` setup failed, `load.offset_per_parent` setup failed |
| Limit a many-to-many load for each parent | ❌ Broken 0/1 | `load.many_to_many_limit_per_parent` setup failed |
| Relationships through other relationships | ❌ Broken 0/1 | `load.through` setup failed |
| Relationship default sort applies when loading | ❌ Broken 0/1 | `bounds.default_sort_control` setup failed |
| Relationships with no attributes load everything | ❌ Broken 0/1 | `path.no_attributes_control` setup failed |
| Relationship context reaches the read action | ❌ Broken 0/2 | `context.prepared_context_control` setup failed, `context.relationship_context_control` setup failed |
| Parent references in nested and through relationship filters | ❌ Broken 0/2 | `filter.nested_parent_control` setup failed, `filter.parent_through_control` setup failed |
| Load belongs-to, has-one, has-many and many-to-many relationships | ❌ Broken 0/4 | `load.belongs_to` setup failed, `load.has_many` setup failed, `load.has_one` setup failed, `load.many_to_many` setup failed |
| Create and update related records with manage_relationship | ⚪ Untested |  |

## 5. Aggregates

| Feature | csv | Not working |
| --- | --- | --- |
| Load each aggregate kind on records | ❌ Broken 0/9 | `loaded.avg` setup failed, `loaded.count` setup failed, `loaded.custom` setup failed, `loaded.exists` setup failed, `loaded.first` setup failed, `loaded.list` setup failed, `loaded.max` setup failed, `loaded.min` setup failed, `loaded.sum` setup failed |
| Run each aggregate kind over a whole query | ❌ Broken 0/15 | `root.avg` setup failed, `root.count` setup failed, `root.custom` setup failed, `root.custom_empty` setup failed, `root.exists` setup failed, `root.first` setup failed, `root.list` setup failed, `root.list_default_empty` setup failed, `root.list_empty` setup failed, `root.list_unsorted` setup failed, `root.max` setup failed, `root.min` setup failed, `root.sum` setup failed, `root.unsorted_first_empty` setup failed, `values.root_empty` setup failed |
| Defaults, nils, uniqueness and field counts | ❌ Broken 0/12 | `query.uniq_sum_rejected` setup failed, `values.distinct_count` setup failed, `values.distinct_list` setup failed, `values.field_count` setup failed, `values.filtered_first_default` setup failed, `values.include_nil_first` setup failed, `values.include_nil_list` setup failed, `values.list_default` setup failed, `values.list_unsorted` setup failed, `values.same_name_distinct_definitions` setup failed, `values.scalar_default` setup failed, `values.string_name` setup failed |
| Aggregate decimals, dates, times and constrained types | ❌ Broken 0/15 | `root.datetime_max` setup failed, `root.decimal_sum` setup failed, `values.constrained_scalar` setup failed, `values.date_list` setup failed, `values.date_list_desc` setup failed, `values.date_max` setup failed, `values.date_min` setup failed, `values.datetime_first` setup failed, `values.datetime_max` setup failed, `values.datetime_min` setup failed, `values.decimal_avg` setup failed, `values.decimal_max` setup failed, `values.decimal_sum` setup failed, `values.string_constraints` setup failed, `values.time_min` setup failed |
| Order first and list aggregates, including nils and ties | ❌ Broken 0/9 | `ordering.asc_nils_first` setup failed, `ordering.asc_nils_last` setup failed, `ordering.desc_nils_first` setup failed, `ordering.desc_nils_last` setup failed, `ordering.expression_first` setup failed, `ordering.expression_list` setup failed, `ordering.list_desc` setup failed, `ordering.ties` setup failed, `ordering.unique_other_field` setup failed |
| Aggregate calculations and other aggregates | ❌ Broken 0/3 | `field.aggregate` setup failed, `field.calculation` setup failed, `field.root_aggregate` setup failed |
| Filter the records an aggregate uses | ❌ Broken 0/6 | `filter.exists` setup failed, `filter.join` setup failed, `filter.not_exists` setup failed, `filter.or_exists` setup failed, `filter.ordinary` setup failed, `filter.sibling_independence` setup failed |
| Aggregate filters through to-many relationships count each record once | ❌ Broken 0/11 | `filter.fanout_and` setup failed, `filter.fanout_avg` setup failed, `filter.fanout_count` setup failed, `filter.fanout_count_records` setup failed, `filter.fanout_custom` setup failed, `filter.fanout_list` setup failed, `filter.fanout_nil_count` setup failed, `filter.fanout_not_count` setup failed, `filter.fanout_or` setup failed, `filter.fanout_sum` setup failed, `identity.composite_fanout_count` setup failed |
| Aggregate filters that use other aggregates | ❌ Broken 0/5 | `filter.aggregate_dependency` setup failed, `filter.aggregate_dependency_calculation` setup failed, `filter.aggregate_dependency_filtered` setup failed, `filter.aggregate_dependency_many_to_many` setup failed, `filter.aggregate_dependency_to_one` setup failed |
| Aggregate filters that reference the parent record | ❌ Broken 0/8 | `filter.nested_parent` setup failed, `filter.parent` setup failed, `filter.parent_join` setup failed, `filter.parent_relationship` setup failed, `filter.parent_through` setup failed, `filter.parent_unrelated` setup failed, `use.parent_filter` setup failed, `use.parent_sort` setup failed |
| Aggregate over to-one, multi-hop and many-to-many paths | ❌ Broken 0/17 | `path.final_many_to_many_custom` setup failed, `path.final_many_to_many_first` setup failed, `path.final_many_to_many_list` setup failed, `path.final_many_to_many_scalar` setup failed, `path.intermediate_many_to_many` setup failed, `path.many_to_many` setup failed, `path.many_to_many_first` setup failed, `path.many_to_many_list` setup failed, `path.multi_hop` setup failed, `path.repeated_many_to_many` setup failed, `path.root_relationship` setup failed, `path.through_count` setup failed, `path.to_one` setup failed, `path.to_one_to_many_first` setup failed, `path.to_one_to_many_list` setup failed, `path.to_one_to_many_sum` setup failed, `path.unrelated` setup failed |
| Aggregate over manual and attribute-free relationships | ❌ Broken 0/3 | `path.manual` setup failed, `path.no_attributes` setup failed, `path.no_attributes_parent` setup failed |
| Aggregate over limited, offset and from-many relationships | ❌ Broken 0/9 | `bounds.default_sort` setup failed, `bounds.filter_after_limit` setup failed, `bounds.from_many` setup failed, `bounds.list_filter_after_limit` setup failed, `bounds.many_to_many_query_limit` setup failed, `bounds.relationship_limit` setup failed, `bounds.relationship_offset` setup failed, `bounds.relationship_offset_only` setup failed, `bounds.unsorted_limit` setup failed |
| Root aggregates over sorted, limited and offset queries | ❌ Broken 0/7 | `bounds.root_custom_limit` setup failed, `bounds.root_first_distinct_sort` setup failed, `bounds.root_limit` setup failed, `bounds.root_list_limit` setup failed, `bounds.root_offset_only` setup failed, `bounds.root_order_then_limit` setup failed, `bounds.root_zero` setup failed |
| Distinct counts over composite and missing keys | ❌ Broken 0/5 | `identity.composite_count` setup failed, `identity.keyless_count` setup failed, `identity.keyless_distinct` setup failed, `identity.keyless_source` setup failed, `identity.root_composite_count` setup failed |
| Filter, sort, paginate and calculate with aggregates | ❌ Broken 0/10 | `use.calculation` setup failed, `use.filter` setup failed, `use.keyset_pagination` setup failed, `use.nested_limited_load` setup failed, `use.pagination` setup failed, `use.related_exists` setup failed, `use.related_filter` setup failed, `use.sort` setup failed, `use.to_one_filter` setup failed, `use.to_one_sort` setup failed |
| Aggregates respect read actions, arguments, actor and context | ❌ Broken 0/9 | `context.actor` setup failed, `context.arguments` setup failed, `context.intermediate_action` setup failed, `context.intermediate_actor` setup failed, `context.prepared_query_arguments` setup failed, `context.read_action` setup failed, `context.relationship_context` setup failed, `context.shared` setup failed, `context.through_arguments` setup failed |
| Seeded filtered aggregates match an in-memory reference | ❌ Broken 0/1 | `generated.filtered_aggregates` setup failed |

## 6. Writes

| Feature | csv | Not working |
| --- | --- | --- |
| Upsert on an identity, in bulk, with conditions | 🟡 Partial 2/4 | `upsert.condition` wrong, `upsert.skipped_record` wrong |
| Bulk create with partial success | ❌ Broken 0/1 | `bulk.partial_success` crashed |
| Bulk update atomically | ❌ Broken 0/1 | `bulk.atomic_increment` wrong |
| Writes that filter by or read aggregates | ❌ Broken 0/4 | `write.atomic_update` setup failed, `write.bulk_destroy_filter` setup failed, `write.bulk_update_filter` setup failed, `write.single_atomic_update` setup failed |

## 7. Transactions and locks

| Feature | csv | Not working |
| --- | --- | --- |
| Failed actions and transactions roll back | 🟡 Partial 1/4 | `txn.after_action_rollback` wrong, `txn.explicit_rollback` wrong, `txn.raise_rollback` wrong |
| Lock rows for update | ❌ Broken 0/1 | `query.lock_for_update` setup failed |
| Isolation between concurrent transactions | ⚪ Untested |  |

## 8. Multitenancy

| Feature | csv | Not working |
| --- | --- | --- |
| Attribute tenancy scopes reads and requires a tenant | 🟡 Partial 5/6 | `tenant.invalid` wrong |
| Tenancy scopes related records and their bounds | 🟡 Partial 3/4 | `tenant.relationship_filter` crashed |
| Tenancy scopes aggregates, including explicit bypass | ❌ Broken 0/8 | `context.attribute_tenant` setup failed, `context.bypass_sibling` setup failed, `context.tenant_bypass` setup failed, `context.through_bypass` setup failed, `context.through_tenant` setup failed, `tenant.aggregate_filter_sort` rejected, `tenant.loaded_aggregates` rejected, `tenant.root_aggregates` rejected |
| Tenancy scopes pages and counts | ⛔ Not supported 0/2 | `tenant.aggregate_keyset_pages` rejected, `tenant.aggregate_offset_page` rejected |
| Tenancy scopes creates, updates and destroys | ✅ Works 3/3 |  |
| Schema-based (context) tenancy | ➖ Not applicable |  |

## 9. Authorization

| Feature | csv | Not working |
| --- | --- | --- |
| Policies filter reads | ✅ Works 3/3 |  |
| Policies filter related records before bounds | 🟡 Partial 4/5 | `context.authorization_bounds_control` setup failed |
| Policies filter what aggregates count | ❌ Broken 0/8 | `auth.aggregate_filter` rejected, `auth.aggregate_sort` rejected, `auth.context_aggregates` rejected, `auth.context_root` rejected, `auth.loaded_aggregates` rejected, `auth.root_aggregates` rejected, `context.authorization` setup failed, `context.authorization_before_bounds` setup failed |
| Policies filter pages and counts | ⛔ Not supported 0/3 | `auth.keyset_pages` rejected, `auth.offset_page` rejected, `auth.tenant_interaction` rejected |
| Policies filter and forbid writes | 🟡 Partial 3/4 | `auth.write_bulk_update_stream` wrong |

## 10. Consistency checks

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
| Read records | csv | Advertised, but ❌ Broken |
| Get one record by primary key or identity | csv | Advertised, but ❌ Broken |
| Create a record | csv | Advertised, but ❌ Broken |
| Update a record, including to nil | csv | Advertised, but ❌ Broken |
| Destroy a record | csv | Advertised, but ❌ Broken |
| Update a record atomically from its current value | csv | Not advertising `record: {:atomic, :update}`, but not rejected either: wrong answers |
| Not found, invalid, missing and duplicate values are errors | csv | Advertised, but ❌ Broken |
| Strings, integers, booleans, atoms and nil round-trip | csv | Advertised, but ❌ Broken |
| Large integers, floats and decimals round-trip | csv | Advertised, but ❌ Broken |
| Dates, microsecond datetimes and times round-trip | csv | Advertised, but ❌ Broken |
| UUIDs round-trip | csv | Advertised, but ❌ Broken |
| Arrays round-trip, keeping order and duplicates | csv | Advertised, but ❌ Broken |
| Maps round-trip, including nested values | csv | Advertised, but ❌ Broken |
| Embedded resources round-trip | csv | Advertised, but ❌ Broken |
| Filter with comparisons on numbers, decimals and dates | csv | Advertised, but ❌ Broken |
| Nil behaves like SQL NULL in filters | csv | Advertised, but ❌ Broken |
| Filter booleans and atoms, including atoms as strings | csv | Advertised, but ❌ Broken |
| Filter strings: contains, case, unicode and empty | csv | Advertised, but ❌ Broken |
| Filter inside arrays, maps and embedded resources | csv | Advertised, but ❌ Broken |
| Filter by a calculation | csv | Not advertising `record: :expression_calculation`, but not rejected either: wrong answers |
| Sort by one or more fields, with explicit nil order | csv | Advertised, but ❌ Broken |
| Sort by a calculation | csv | Advertised, but ❌ Broken |
| Limit and offset a query | csv | Advertised, but ❌ Broken |
| Count and check existence | csv | Not advertising `record: {:query_aggregate, :count}`, `record: {:query_aggregate, :exists}`, but not rejected either: wrong answers |
| Stream records in batches | csv | Not advertising `record: :keyset`, but not rejected either: wrong answers |
| Distinct records by a field | csv | Not advertising `child: :distinct`, `child: :distinct_sort`, but not rejected either: wrong answers |
| Combine queries with union | csv | Not advertising `child: :combine`, `parent: {:combine, :union}`, but not rejected either: wrong answers |
| Load expression calculations, with arguments | csv | Not advertising `record: :expression_calculation`, `record: :calculate`, but not rejected either: wrong answers |
| Offset pagination with counts | csv | Advertised, but ❌ Broken |
| Keyset pagination, forwards and backwards | csv | Not advertising `record: :keyset`, but not rejected either: wrong answers |
| Filter across to-many relationships without duplicates | csv | Not advertising `child: {:filter_relationship, :ratings}`, but not rejected either: wrong answers |
| Limit and offset a has-many load for each parent | csv | Not advertising `parent: {:lateral_join, :children}`, but not rejected either: wrong answers |
| Limit a many-to-many load for each parent | csv | Not advertising `parent: {:lateral_join, :tags}`, but not rejected either: wrong answers |
| Relationships through other relationships | csv | Not advertising `parent: :through_relationship`, but not rejected either: wrong answers |
| Relationship default sort applies when loading | csv | Advertised, but ❌ Broken |
| Relationships with no attributes load everything | csv | Not advertising `parent: {:filter_relationship, :all_children}`, but not rejected either: wrong answers |
| Relationship context reaches the read action | csv | Advertised, but ❌ Broken |
| Parent references in nested and through relationship filters | csv | Not advertising `parent: {:filter_relationship, :same_tenant_tags}`, but not rejected either: wrong answers |
| Load belongs-to, has-one, has-many and many-to-many relationships | csv | Not advertising `child: {:filter_relationship, :parent}`, `parent: {:filter_relationship, :tags}`, but not rejected either: wrong answers |
| Load each aggregate kind on records | csv | Not advertising `parent: {:aggregate, :count}`, `parent: {:aggregate, :sum}`, `parent: {:aggregate, :avg}`, `parent: {:aggregate, :min}`, `parent: {:aggregate, :max}`, `parent: {:aggregate, :exists}`, `parent: {:aggregate, :first}`, `parent: {:aggregate, :list}`, `parent: {:aggregate, :custom}`, but not rejected either: wrong answers |
| Run each aggregate kind over a whole query | csv | Not advertising `child: {:query_aggregate, :count}`, `child: {:query_aggregate, :sum}`, `child: {:query_aggregate, :avg}`, `child: {:query_aggregate, :min}`, `child: {:query_aggregate, :max}`, `child: {:query_aggregate, :exists}`, `child: {:query_aggregate, :first}`, `child: {:query_aggregate, :list}`, `child: {:query_aggregate, :custom}`, but not rejected either: wrong answers |
| Defaults, nils, uniqueness and field counts | csv | Not advertising `parent: {:aggregate, :list}`, `parent: {:aggregate, :count}`, but not rejected either: wrong answers |
| Aggregate decimals, dates, times and constrained types | csv | Not advertising `parent: {:aggregate, :sum}`, `parent: {:aggregate, :max}`, but not rejected either: wrong answers |
| Order first and list aggregates, including nils and ties | csv | Not advertising `parent: {:aggregate, :first}`, `parent: {:aggregate, :list}`, but not rejected either: wrong answers |
| Aggregate calculations and other aggregates | csv | Not advertising `parent: {:aggregate, :sum}`, but not rejected either: wrong answers |
| Filter the records an aggregate uses | csv | Not advertising `parent: :aggregate_filter`, but not rejected either: wrong answers |
| Aggregate filters through to-many relationships count each record once | csv | Not advertising `child: {:filter_relationship, :ratings}`, but not rejected either: wrong answers |
| Aggregate filters that use other aggregates | csv | Not advertising `child: :aggregate_filter`, but not rejected either: wrong answers |
| Aggregate filters that reference the parent record | csv | Not advertising `parent: {:aggregate_relationship, :above_threshold}`, but not rejected either: wrong answers |
| Aggregate over to-one, multi-hop and many-to-many paths | csv | Not advertising `parent: {:aggregate_relationship, :tags}`, `parent: {:aggregate, :unrelated}`, but not rejected either: wrong answers |
| Aggregate over manual and attribute-free relationships | csv | Not advertising `parent: {:aggregate_relationship, :manual_children}`, `parent: {:aggregate_relationship, :all_children}`, but not rejected either: wrong answers |
| Aggregate over limited, offset and from-many relationships | csv | Not advertising `parent: {:aggregate_relationship, :top_children}`, but not rejected either: wrong answers |
| Root aggregates over sorted, limited and offset queries | csv | Not advertising `child: {:query_aggregate, :sum}`, but not rejected either: wrong answers |
| Distinct counts over composite and missing keys | csv | Not advertising `parent: :composite_primary_key`, but not rejected either: wrong answers |
| Filter, sort, paginate and calculate with aggregates | csv | Not advertising `parent: :aggregate_filter`, `parent: :aggregate_sort`, but not rejected either: wrong answers |
| Aggregates respect read actions, arguments, actor and context | csv | Not advertising `parent: {:aggregate_relationship, :children}`, but not rejected either: wrong answers |
| Seeded filtered aggregates match an in-memory reference | csv | Not advertising `parent: {:aggregate, :count}`, `child: {:query_aggregate, :count}`, but not rejected either: wrong answers |
| Bulk create with partial success | csv | Not advertising `tenant_item: :bulk_create_with_partial_success`, but not rejected either: wrong answers |
| Bulk update atomically | csv | Not advertising `tenant_item: :update_query`, `tenant_item: {:atomic, :update}`, but not rejected either: wrong answers |
| Writes that filter by or read aggregates | csv | Not advertising `parent: :update_query`, `parent: :destroy_query`, but not rejected either: wrong answers |
| Lock rows for update | csv | Not advertising `parent: {:lock, :for_update}`, but not rejected either: wrong answers |
| Tenancy scopes aggregates, including explicit bypass | csv | Not advertising `tenant_parent: {:aggregate, :count}`, but not rejected either: wrong answers |
| Tenancy scopes creates, updates and destroys | csv | Works without advertising `tenant_item: :destroy_query` |
| Policies filter what aggregates count | csv | Not advertising `secure_parent: {:aggregate, :count}`, but not rejected either: wrong answers |
| Policies filter pages and counts | csv | Advertised, but ⛔ Not supported |

