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

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Read records | ❌ Broken 0/1 | `record.read_all` setup failed |
| Get one record by primary key or identity | ❌ Broken 0/2 | `record.get_identity` setup failed, `record.get_primary_key` setup failed |
| Select only some attributes | ❌ Broken 0/2 | `read.selection_expression` crashed, `record.select` setup failed |
| Create a record | ❌ Broken 0/1 | `record.create` setup failed |
| Update a record, including to nil | ❌ Broken 0/2 | `record.update` setup failed, `record.update_to_nil` setup failed |
| Destroy a record | ❌ Broken 0/1 | `record.destroy` setup failed |
| Update a record atomically from its current value | ❌ Broken 0/1 | `record.atomic_update` setup failed |
| Not found, invalid, missing and duplicate values are errors | ❌ Broken 0/4 | `record.identity_conflict` setup failed, `record.invalid_value` setup failed, `record.not_found` setup failed, `record.required` setup failed |

## 2. Types

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Strings, integers, booleans, atoms and nil round-trip | ❌ Broken 0/3 | `record.types_nil` setup failed, `record.types_scalar` setup failed, `record.types_strings` setup failed |
| Large integers, floats and decimals round-trip | ❌ Broken 0/2 | `record.types_numeric` setup failed, `values.decimal_read_control` wrong |
| Dates, microsecond datetimes and times round-trip | ❌ Broken 0/1 | `record.types_temporal` setup failed |
| UUIDs round-trip | ❌ Broken 0/1 | `record.types_uuid` setup failed |
| Arrays round-trip, keeping order and duplicates | ❌ Broken 0/1 | `record.types_array` setup failed |
| Maps round-trip, including nested values | ❌ Broken 0/1 | `record.types_map` setup failed |
| Embedded resources round-trip | ❌ Broken 0/1 | `record.types_embedded` setup failed |

## 3. Querying

| Feature | clickhouse | Not working |
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
| Distinct records by a field | ❌ Broken 0/1 | `query.distinct` crashed |
| Combine queries with union | ⛔ Not supported 0/1 | `query.union` rejected |
| Combine queries with union all and intersection | ⚪ Untested |  |
| Load expression calculations, with arguments | 🟡 Partial 1/3 | `record.calculation_argument` setup failed, `record.calculation_load` setup failed |
| Offset pagination with counts | ❌ Broken 0/1 | `record.offset_pages` setup failed |
| Keyset pagination, forwards and backwards | ❌ Broken 0/1 | `record.keyset_pages` setup failed |
| Pagination while records change | ⚪ Untested |  |

## 4. Relationships

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

## 5. Aggregates

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Load each aggregate kind on records | 🟡 Partial 4/9 | `loaded.avg` wrong, `loaded.custom` rejected, `loaded.exists` rejected, `loaded.first` rejected, `loaded.list` rejected |
| Run each aggregate kind over a whole query | 🟡 Partial 5/15 | `root.custom` rejected, `root.custom_empty` rejected, `root.exists` rejected, `root.first` rejected, `root.list` rejected, `root.list_default_empty` rejected, `root.list_empty` rejected, `root.list_unsorted` rejected, `root.unsorted_first_empty` rejected, `values.root_empty` rejected |
| Defaults, nils, uniqueness and field counts | 🟡 Partial 4/12 | `values.distinct_count` wrong, `values.distinct_list` rejected, `values.filtered_first_default` rejected, `values.include_nil_first` rejected, `values.include_nil_list` rejected, `values.list_default` rejected, `values.list_unsorted` rejected, `values.same_name_distinct_definitions` wrong |
| Aggregate decimals, dates, times and constrained types | 🟡 Partial 4/15 | `root.decimal_sum` wrong, `values.constrained_scalar` wrong, `values.date_list` rejected, `values.date_list_desc` rejected, `values.date_max` wrong, `values.date_min` wrong, `values.datetime_first` rejected, `values.decimal_avg` wrong, `values.decimal_max` wrong, `values.decimal_sum` wrong, `values.string_constraints` rejected |
| Order first and list aggregates, including nils and ties | ⛔ Not supported 0/9 | `ordering.asc_nils_first` rejected, `ordering.asc_nils_last` rejected, `ordering.desc_nils_first` rejected, `ordering.desc_nils_last` rejected, `ordering.expression_first` rejected, `ordering.expression_list` rejected, `ordering.list_desc` rejected, `ordering.ties` rejected, `ordering.unique_other_field` open question |
| Aggregate calculations and other aggregates | ❌ Broken 0/3 | `field.aggregate` crashed, `field.calculation` crashed, `field.root_aggregate` crashed |
| Filter the records an aggregate uses | ❌ Broken 0/6 | `filter.exists` wrong, `filter.join` wrong, `filter.not_exists` wrong, `filter.or_exists` wrong, `filter.ordinary` wrong, `filter.sibling_independence` wrong |
| Aggregate filters through to-many relationships count each record once | ❌ Broken 0/11 | `filter.fanout_and` crashed, `filter.fanout_avg` crashed, `filter.fanout_count` crashed, `filter.fanout_count_records` crashed, `filter.fanout_custom` rejected, `filter.fanout_list` rejected, `filter.fanout_nil_count` crashed, `filter.fanout_not_count` crashed, `filter.fanout_or` crashed, `filter.fanout_sum` crashed, `identity.composite_fanout_count` crashed |
| Aggregate filters that use other aggregates | ❌ Broken 0/5 | `filter.aggregate_dependency` wrong, `filter.aggregate_dependency_calculation` wrong, `filter.aggregate_dependency_filtered` wrong, `filter.aggregate_dependency_many_to_many` wrong, `filter.aggregate_dependency_to_one` crashed |
| Aggregate filters that reference the parent record | ❌ Broken 0/8 | `filter.nested_parent` wrong, `filter.parent` wrong, `filter.parent_join` wrong, `filter.parent_relationship` wrong, `filter.parent_through` wrong, `filter.parent_unrelated` rejected, `use.parent_filter` crashed, `use.parent_sort` crashed |
| Aggregate over to-one, multi-hop and many-to-many paths | ❌ Broken 0/17 | `path.final_many_to_many_custom` rejected, `path.final_many_to_many_first` rejected, `path.final_many_to_many_list` rejected, `path.final_many_to_many_scalar` wrong, `path.intermediate_many_to_many` wrong, `path.many_to_many` wrong, `path.many_to_many_first` rejected, `path.many_to_many_list` rejected, `path.multi_hop` wrong, `path.repeated_many_to_many` open question, `path.root_relationship` crashed, `path.through_count` crashed, `path.to_one` crashed, `path.to_one_to_many_first` rejected, `path.to_one_to_many_list` rejected, `path.to_one_to_many_sum` wrong, `path.unrelated` rejected |
| Aggregate over manual and attribute-free relationships | 🟡 Partial 1/3 | `path.no_attributes` wrong, `path.no_attributes_parent` wrong |
| Aggregate over limited, offset and from-many relationships | ❌ Broken 0/9 | `bounds.default_sort` rejected, `bounds.filter_after_limit` wrong, `bounds.from_many` wrong, `bounds.list_filter_after_limit` rejected, `bounds.many_to_many_query_limit` open question, `bounds.relationship_limit` wrong, `bounds.relationship_offset` wrong, `bounds.relationship_offset_only` wrong, `bounds.unsorted_limit` wrong |
| Root aggregates over sorted, limited and offset queries | ❌ Broken 0/7 | `bounds.root_custom_limit` rejected, `bounds.root_first_distinct_sort` rejected, `bounds.root_limit` wrong, `bounds.root_list_limit` rejected, `bounds.root_offset_only` wrong, `bounds.root_order_then_limit` wrong, `bounds.root_zero` rejected |
| Distinct counts over composite and missing keys | 🟡 Partial 3/5 | `identity.keyless_distinct` open question, `identity.keyless_source` crashed |
| Filter, sort, paginate and calculate with aggregates | ❌ Broken 0/10 | `use.calculation` crashed, `use.filter` crashed, `use.keyset_pagination` crashed, `use.nested_limited_load` wrong, `use.pagination` crashed, `use.related_exists` crashed, `use.related_filter` crashed, `use.sort` crashed, `use.to_one_filter` crashed, `use.to_one_sort` crashed |
| Aggregates respect read actions, arguments, actor and context | ❌ Broken 0/9 | `context.actor` wrong, `context.arguments` wrong, `context.intermediate_action` wrong, `context.intermediate_actor` wrong, `context.prepared_query_arguments` wrong, `context.read_action` wrong, `context.relationship_context` wrong, `context.shared` wrong, `context.through_arguments` wrong |
| Seeded filtered aggregates match an in-memory reference | ⛔ Not supported 0/1 | `generated.filtered_aggregates` rejected |

## 6. Writes

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Upsert on an identity, in bulk, with conditions | ❌ Broken 0/4 | `upsert.bulk` crashed, `upsert.condition` crashed, `upsert.skipped_record` wrong, `upsert.tenant_identity` rejected |
| Bulk create with partial success | ❌ Broken 0/1 | `bulk.partial_success` wrong |
| Bulk update atomically | ❌ Broken 0/1 | `bulk.atomic_increment` crashed |
| Writes that filter by or read aggregates | ❌ Broken 0/4 | `write.atomic_update` crashed, `write.bulk_destroy_filter` crashed, `write.bulk_update_filter` crashed, `write.single_atomic_update` rejected |

## 7. Transactions and locks

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Failed actions and transactions roll back | 🟡 Partial 1/4 | `txn.after_action_rollback` wrong, `txn.explicit_rollback` crashed, `txn.raise_rollback` wrong |
| Lock rows for update | ⛔ Not supported 0/1 | `query.lock_for_update` rejected |
| Isolation between concurrent transactions | ⚪ Untested |  |

## 8. Multitenancy

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Attribute tenancy scopes reads and requires a tenant | 🟡 Partial 5/6 | `tenant.invalid` wrong |
| Tenancy scopes related records and their bounds | 🟡 Partial 3/4 | `tenant.relationship_filter` crashed |
| Tenancy scopes aggregates, including explicit bypass | 🟡 Partial 2/8 | `context.attribute_tenant` wrong, `context.bypass_sibling` wrong, `context.through_bypass` wrong, `context.through_tenant` wrong, `tenant.aggregate_filter_sort` crashed, `tenant.loaded_aggregates` wrong |
| Tenancy scopes pages and counts | ❌ Broken 0/2 | `tenant.aggregate_keyset_pages` crashed, `tenant.aggregate_offset_page` crashed |
| Tenancy scopes creates, updates and destroys | ✅ Works 3/3 |  |
| Schema-based (context) tenancy | ➖ Not applicable |  |

## 9. Authorization

| Feature | clickhouse | Not working |
| --- | --- | --- |
| Policies filter reads | ✅ Works 3/3 |  |
| Policies filter related records before bounds | ✅ Works 5/5 |  |
| Policies filter what aggregates count | 🟡 Partial 2/8 | `auth.aggregate_filter` crashed, `auth.aggregate_sort` crashed, `auth.context_aggregates` wrong, `auth.loaded_aggregates` wrong, `context.authorization` wrong, `context.authorization_before_bounds` wrong |
| Policies filter pages and counts | ❌ Broken 0/3 | `auth.keyset_pages` crashed, `auth.offset_page` crashed, `auth.tenant_interaction` wrong |
| Policies filter and forbid writes | 🟡 Partial 3/4 | `auth.write_bulk_update_stream` wrong |

## 10. Consistency checks

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
| Read records | clickhouse | Advertised, but ❌ Broken |
| Get one record by primary key or identity | clickhouse | Advertised, but ❌ Broken |
| Select only some attributes | clickhouse | Advertised, but ❌ Broken |
| Create a record | clickhouse | Advertised, but ❌ Broken |
| Update a record, including to nil | clickhouse | Advertised, but ❌ Broken |
| Destroy a record | clickhouse | Advertised, but ❌ Broken |
| Update a record atomically from its current value | clickhouse | Not advertising `record: {:atomic, :update}`, but not rejected either: wrong answers |
| Not found, invalid, missing and duplicate values are errors | clickhouse | Advertised, but ❌ Broken |
| Strings, integers, booleans, atoms and nil round-trip | clickhouse | Advertised, but ❌ Broken |
| Large integers, floats and decimals round-trip | clickhouse | Advertised, but ❌ Broken |
| Dates, microsecond datetimes and times round-trip | clickhouse | Advertised, but ❌ Broken |
| UUIDs round-trip | clickhouse | Advertised, but ❌ Broken |
| Arrays round-trip, keeping order and duplicates | clickhouse | Advertised, but ❌ Broken |
| Maps round-trip, including nested values | clickhouse | Advertised, but ❌ Broken |
| Embedded resources round-trip | clickhouse | Advertised, but ❌ Broken |
| Filter with comparisons on numbers, decimals and dates | clickhouse | Advertised, but ❌ Broken |
| Nil behaves like SQL NULL in filters | clickhouse | Advertised, but ❌ Broken |
| Filter booleans and atoms, including atoms as strings | clickhouse | Advertised, but ❌ Broken |
| Filter strings: contains, case, unicode and empty | clickhouse | Advertised, but ❌ Broken |
| Filter inside arrays, maps and embedded resources | clickhouse | Advertised, but ❌ Broken |
| Filter by a calculation | clickhouse | Advertised, but ❌ Broken |
| Sort by one or more fields, with explicit nil order | clickhouse | Advertised, but ❌ Broken |
| Sort by a calculation | clickhouse | Not advertising `record: :expression_calculation_sort`, but not rejected either: wrong answers |
| Limit and offset a query | clickhouse | Advertised, but ❌ Broken |
| Count and check existence | clickhouse | Not advertising `record: {:query_aggregate, :exists}`, but not rejected either: wrong answers |
| Stream records in batches | clickhouse | Not advertising `record: :keyset`, but not rejected either: wrong answers |
| Distinct records by a field | clickhouse | Not advertising `child: :distinct_sort`, but not rejected either: wrong answers |
| Offset pagination with counts | clickhouse | Advertised, but ❌ Broken |
| Keyset pagination, forwards and backwards | clickhouse | Not advertising `record: :keyset`, but not rejected either: wrong answers |
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

