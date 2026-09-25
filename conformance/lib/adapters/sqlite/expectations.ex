# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Sqlite.Expectations do
  @moduledoc """
  AshSqlite's expectation record for every scenario it runs: supported, or
  the gap it has instead, pinned to exactly what happens. Gaps link to
  `GAPS.md`; each record here is reviewed, never accepted automatically.
  """
  import Ash.Conformance.Contracts.Records

  @supported ~w(
    auth.aggregate_filter auth.aggregate_sort auth.bounds auth.children
    auth.context_aggregates auth.context_read auth.context_relationship auth.context_root
    auth.from_many auth.keyset_pages auth.loaded_aggregates auth.offset_page
    auth.read auth.relationship_load auth.root_aggregates auth.tenant_interaction
    auth.write_bulk_destroy auth.write_bulk_update_atomic auth.write_bulk_update_stream auth.write_forbidden
    bounds.default_sort_control bounds.filter_after_limit bounds.list_filter_after_limit bounds.relationship_limit
    bounds.relationship_offset bounds.relationship_offset_only bounds.root_first_distinct_sort bounds.root_limit
    bounds.root_offset_only bounds.root_order_then_limit bounds.root_zero bulk.atomic_increment
    bulk.partial_success calc.in_memory context.actor context.arguments
    context.attribute_tenant context.authorization context.authorization_bounds_control context.bypass_sibling
    context.intermediate_action context.intermediate_actor context.prepared_context_control context.prepared_query_arguments
    context.read_action context.shared context.tenant_bypass context.through_arguments
    context.through_bypass context.through_tenant equivalence.root_reference equivalence.visible_count_load
    field.aggregate field.calculation field.root_aggregate filter.aggregate_dependency_to_one
    filter.exists filter.fanout_count_records filter.fanout_nil_count filter.fanout_not_count
    filter.join filter.not_exists filter.or_exists filter.ordinary
    filter.sibling_independence generated.filtered_aggregates identity.keyless_count load.belongs_to
    load.has_many load.has_one load.limit_per_parent load.many_to_many
    load.offset_per_parent loaded.avg loaded.count loaded.custom
    loaded.exists loaded.first loaded.list loaded.max
    loaded.min loaded.sum ordering.asc_nils_first ordering.asc_nils_last
    ordering.desc_nils_first ordering.desc_nils_last ordering.expression_first ordering.expression_list
    ordering.list_desc ordering.ties path.final_many_to_many_scalar path.many_to_many
    path.many_to_many_first path.many_to_many_list path.multi_hop path.no_attributes_control
    path.to_one path.to_one_to_many_first path.to_one_to_many_list path.to_one_to_many_sum
    path.unrelated query.uniq_sum_rejected read.selection_expression record.atomic_update
    record.calculation_argument record.calculation_load record.count record.create
    record.destroy record.filter_array_member record.filter_atom record.filter_atom_as_string
    record.filter_boolean record.filter_calculation record.filter_case_insensitive record.filter_contains
    record.filter_date record.filter_datetime_precision record.filter_decimal record.filter_embedded
    record.filter_empty_string record.filter_equal record.filter_in_with_nil record.filter_is_nil
    record.filter_map_key record.filter_not record.filter_not_equal record.filter_not_nil
    record.filter_range record.filter_unicode record.get_identity record.get_primary_key
    record.identity_conflict record.invalid_value record.keyset_pages record.limit_offset
    record.not_found record.offset_pages record.read_all record.required
    record.select record.sort_asc_nils_first record.sort_calculation record.sort_date
    record.sort_decimal record.sort_desc_nils_last record.sort_string record.sort_tie_break
    record.stream record.types_array record.types_embedded record.types_map
    record.types_nil record.types_numeric record.types_scalar record.types_strings
    record.types_temporal record.types_uuid record.update record.update_to_nil
    root.avg root.count root.datetime_max root.exists
    root.first root.max root.min root.sum
    root.unsorted_first_empty storage.atom.null storage.atom.ordinary storage.binary.edge
    storage.binary.null storage.binary.ordinary storage.boolean.null storage.boolean.ordinary
    storage.ci_string.edge storage.ci_string.null storage.ci_string.ordinary storage.date.edge
    storage.date.null storage.date.ordinary storage.decimal.null storage.decimal.ordinary
    storage.duration.null storage.embedded.edge storage.embedded.null storage.embedded.ordinary
    storage.embeddeds.edge storage.embeddeds.null storage.embeddeds.ordinary storage.float.edge
    storage.float.null storage.float.ordinary storage.integer.edge storage.integer.null
    storage.integer.ordinary storage.integers.edge storage.integers.null storage.integers.ordinary
    storage.map.edge storage.map.null storage.map.ordinary storage.naive_datetime.edge
    storage.naive_datetime.null storage.naive_datetime.ordinary storage.string.edge storage.string.null
    storage.string.ordinary storage.strings.edge storage.strings.null storage.strings.ordinary
    storage.time.edge storage.time.null storage.time.ordinary storage.time_usec.edge
    storage.time_usec.null storage.time_usec.ordinary storage.union.null storage.utc_datetime.edge
    storage.utc_datetime.null storage.utc_datetime.ordinary storage.utc_datetime_usec.edge storage.utc_datetime_usec.null
    storage.utc_datetime_usec.ordinary storage.uuid.edge storage.uuid.null storage.uuid.ordinary
    storage.uuid_v7.null storage.uuid_v7.ordinary tenant.aggregate_filter_sort tenant.aggregate_keyset_pages
    tenant.aggregate_offset_page tenant.bounds tenant.explicit_global tenant.from_many
    tenant.identities tenant.invalid tenant.loaded_aggregates tenant.missing
    tenant.read tenant.relationship_filter tenant.relationship_load tenant.root_aggregates
    tenant.unknown tenant.write_bulk_destroy tenant.write_local_identity txn.after_action_rollback
    txn.commit txn.explicit_rollback txn.raise_rollback upsert.bulk
    upsert.tenant_identity use.calculation use.fanout_count use.filter
    use.keyset_pagination use.nested_limited_load use.pagination use.related_exists
    use.related_filter use.sort use.to_one_filter use.to_one_sort
    values.constrained_scalar values.date_list values.date_list_desc values.date_max
    values.date_min values.datetime_first values.datetime_max values.datetime_min
    values.decimal_avg values.distinct_count values.distinct_list values.field_count
    values.filtered_first_default values.include_nil_first values.include_nil_list values.list_default
    values.list_unsorted values.root_empty values.same_name_distinct_definitions values.scalar_default
    values.string_constraints values.string_name values.time_min write.atomic_update
    write.bulk_destroy_filter write.bulk_update_filter write.lifecycle write.single_atomic_update
  )

  def all, do: Map.new(@supported, &{&1, :supported}) |> Map.merge(gaps())

  defp gaps do
    %{
      "bounds.default_sort" => defect_value(%{1 => 2, 2 => 4, 3 => nil}, "default-sort"),
      "bounds.from_many" => defect_value(%{1 => 4, 2 => 1, 3 => 0}, "from-many"),
      "bounds.many_to_many_query_limit" =>
        unresolved_error(~r/Cannot set limit on aggregate query/, "many-to-many-bounds-api"),
      "bounds.root_custom_limit" =>
        unsupported(
          ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support using query aggregates/,
          "root-kinds",
          Ash.Error.Invalid
        ),
      "bounds.root_list_limit" =>
        unsupported(
          ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support using query aggregates/,
          "root-kinds",
          Ash.Error.Invalid
        ),
      "bounds.unsorted_limit" =>
        defect_error(~r/\*\* \(Exqlite.Error\) near "\)": syntax error/, "unsorted-bounds"),
      "context.authorization_before_bounds" =>
        defect_value(%{1 => nil, 2 => 4, 3 => nil}, "authorization-bounds"),
      "context.relationship_context" =>
        defect_value(%{1 => 0, 2 => 0, 3 => 0}, "relationship-context"),
      "context.relationship_context_control" =>
        defect_value(%{1 => [], 2 => [], 3 => []}, "relationship-context"),
      "filter.aggregate_dependency" =>
        unsupported(
          ~r/AshSql does not support loading aggregates with aggregate filters that reference other aggregates/,
          "filter-dependencies"
        ),
      "filter.aggregate_dependency_calculation" =>
        unsupported(
          ~r/AshSql does not support loading aggregates with aggregate filters that reference other aggregates/,
          "filter-dependencies"
        ),
      "filter.aggregate_dependency_filtered" =>
        unsupported(
          ~r/AshSql does not support loading aggregates with aggregate filters that reference other aggregates/,
          "filter-dependencies"
        ),
      "filter.aggregate_dependency_many_to_many" =>
        unsupported(
          ~r/AshSql does not support loading aggregates with aggregate filters that reference other aggregates/,
          "filter-dependencies"
        ),
      "filter.fanout_and" =>
        unsupported(
          ~r/AshSql does not support loading sum, avg, list, custom, or field-based count aggregates with filters that reference to-many relationships/,
          "filter-fanout"
        ),
      "filter.fanout_avg" =>
        unsupported(
          ~r/AshSql does not support loading sum, avg, list, custom, or field-based count aggregates with filters that reference to-many relationships/,
          "filter-fanout"
        ),
      "filter.fanout_count" =>
        unsupported(
          ~r/AshSql does not support loading sum, avg, list, custom, or field-based count aggregates with filters that reference to-many relationships/,
          "filter-fanout"
        ),
      "filter.fanout_custom" =>
        unsupported(
          ~r/AshSql does not support loading sum, avg, list, custom, or field-based count aggregates with filters that reference to-many relationships/,
          "filter-fanout"
        ),
      "filter.fanout_list" =>
        unsupported(
          ~r/AshSql does not support loading sum, avg, list, custom, or field-based count aggregates with filters that reference to-many relationships/,
          "filter-fanout"
        ),
      "filter.fanout_or" =>
        unsupported(
          ~r/AshSql does not support loading sum, avg, list, custom, or field-based count aggregates with filters that reference to-many relationships/,
          "filter-fanout"
        ),
      "filter.fanout_read_control" => defect_value(~c"\v\v\f", "sorted-distinct-reads"),
      "filter.fanout_sum" =>
        unsupported(
          ~r/AshSql does not support loading sum, avg, list, custom, or field-based count aggregates with filters that reference to-many relationships/,
          "filter-fanout"
        ),
      "filter.nested_parent" =>
        unsupported(
          ~r/AshSql does not support loading aggregates with parent-dependent aggregate filters/,
          "parent-correlation"
        ),
      "filter.nested_parent_control" =>
        defect_error(~r/\*\* \(KeyError\) key :parent_bindings not found/, "nested-parent"),
      "filter.parent" =>
        unsupported(
          ~r/AshSql does not support loading aggregates with parent-dependent aggregate filters/,
          "parent-correlation"
        ),
      "filter.parent_join" =>
        unsupported(
          ~r/AshSql does not support loading aggregates with parent-dependent join filters/,
          "parent-correlation"
        ),
      "filter.parent_relationship" =>
        unsupported(
          ~r/AshSql does not support loading aggregates over relationships with parent-dependent filters/,
          "parent-correlation"
        ),
      "filter.parent_through" =>
        unsupported(
          ~r/AshSql does not support loading aggregates over many_to_many relationships with parent-dependent join filters/,
          "parent-correlation"
        ),
      "filter.parent_through_control" =>
        defect_error(~r/\*\* \(KeyError\) key :parent_bindings not found/, "parent-through-load"),
      "filter.parent_unrelated" =>
        unsupported(
          ~r/AshSql does not support loading aggregates with parent-dependent aggregate filters/,
          "parent-correlation"
        ),
      "identity.composite_count" =>
        unsupported(
          ~r/requires a single primary key to count distinct records, but Ash\.Conformance\.Sqlite\.Link has composite primary key/,
          "record-identity"
        ),
      "identity.composite_fanout_count" =>
        unsupported(
          ~r/requires a single primary key to count distinct records, but Ash\.Conformance\.Sqlite\.Link has composite primary key/,
          "record-identity"
        ),
      "identity.keyless_distinct" =>
        unresolved_error(
          ~r/requires a single primary key to count distinct records, but Ash\.Conformance\.Sqlite\.Event has no primary key/,
          "keyless-identity"
        ),
      "identity.keyless_source" =>
        unsupported(
          ~r/AshSql cannot load aggregates on resources with no primary key/,
          "record-identity"
        ),
      "identity.root_composite_count" =>
        unsupported(
          ~r/requires a single primary key to count distinct records, but Ash\.Conformance\.Sqlite\.Link has composite primary key/,
          "record-identity"
        ),
      "load.many_to_many_limit_per_parent" =>
        defect_value(%{1 => [202], 2 => [], 3 => []}, "many-to-many-load-limit"),
      "load.through" =>
        defect_value({true, %{1 => ~c"efgh", 2 => ~c"efgh", 3 => ~c"efgh"}}, "through-fallback"),
      "ordering.unique_other_field" =>
        unresolved_error(
          ~r/AshSql only supports uniq list aggregates when sorting by the list aggregate field/,
          "unique-list-order"
        ),
      "path.final_many_to_many_custom" =>
        unsupported(
          ~r/AshSql does not support loading aggregates over multi-hop paths that include many_to_many relationships/,
          "many-to-many-paths"
        ),
      "path.final_many_to_many_first" =>
        unsupported(
          ~r/AshSql does not support loading aggregates over multi-hop paths that include many_to_many relationships/,
          "many-to-many-paths"
        ),
      "path.final_many_to_many_list" =>
        unsupported(
          ~r/AshSql does not support loading aggregates over multi-hop paths that include many_to_many relationships/,
          "many-to-many-paths"
        ),
      "path.intermediate_many_to_many" =>
        unsupported(
          ~r/AshSql does not support loading aggregates over multi-hop paths that include many_to_many relationships/,
          "many-to-many-paths"
        ),
      "path.manual" =>
        unsupported(
          ~r/AshSql does not support loading aggregates over manual relationships/,
          "manual"
        ),
      "path.no_attributes" =>
        unsupported(
          ~r/AshSql does not support loading aggregates over no_attributes\? relationships/,
          "no-attributes"
        ),
      "path.no_attributes_parent" =>
        unsupported(
          ~r/AshSql does not support loading aggregates over no_attributes\? relationships/,
          "no-attributes"
        ),
      "path.repeated_many_to_many" =>
        unresolved_error(
          ~r/AshSql does not support loading aggregates over multi-hop paths that include many_to_many relationships/,
          "path-multiplicity"
        ),
      "path.root_relationship" =>
        unsupported(
          ~r/AshSql grouped query aggregates do not yet support relationship aggregate :result/,
          "root-relationship"
        ),
      "path.through_count" => defect_value({true, %{1 => 4, 2 => 0, 3 => 0}}, "through-fallback"),
      "query.distinct" =>
        unsupported(~r/Data layer does not support distincting/, "query-distinct"),
      "query.lock_for_update" =>
        unsupported(
          ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support lock: :for_update/,
          "row-locks",
          Ash.Error.Invalid
        ),
      "query.union" =>
        unsupported(~r/Data layer does not support combining queries/, "query-combinations"),
      "record.filter_true_or_nil" => unresolved_value([1, 4, 5, 7], "true-or-nil"),
      "root.custom" =>
        unsupported(
          ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support using query aggregates/,
          "root-kinds",
          Ash.Error.Invalid
        ),
      "root.custom_empty" =>
        unsupported(
          ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support using query aggregates/,
          "root-kinds",
          Ash.Error.Invalid
        ),
      "root.decimal_sum" => defect_value("12345678901234568", "decimal-precision"),
      "root.list" =>
        unsupported(
          ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support using query aggregates/,
          "root-kinds",
          Ash.Error.Invalid
        ),
      "root.list_default_empty" =>
        unsupported(
          ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support using query aggregates/,
          "root-kinds",
          Ash.Error.Invalid
        ),
      "root.list_empty" =>
        unsupported(
          ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support using query aggregates/,
          "root-kinds",
          Ash.Error.Invalid
        ),
      "root.list_unsorted" =>
        unsupported(
          ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support using query aggregates/,
          "root-kinds",
          Ash.Error.Invalid
        ),
      "storage.decimal.edge" =>
        defect_value(
          [
            create: :ok,
            read: {:lost, Decimal.new("12345678901234568")},
            update: :skipped,
            clear: :skipped
          ],
          "decimal-precision"
        ),
      "storage.duration.edge" =>
        defect_value(
          [
            create:
              {:error,
               "** (Exqlite.Error) unsupported type: %Duration{year: 1, month: 2, day: 3, hour: 4}"},
            read: :skipped,
            update: :skipped,
            clear: :skipped
          ],
          "duration-storage"
        ),
      "storage.duration.ordinary" =>
        defect_value(
          [
            create:
              {:error, "** (Exqlite.Error) unsupported type: %Duration{hour: 1, minute: 30}"},
            read: :skipped,
            update: :skipped,
            clear: :skipped
          ],
          "duration-storage"
        ),
      "storage.union.ordinary" =>
        defect_value(
          [
            create: :ok,
            read: :ok,
            update: :ok,
            clear: {:lost, %Ash.Union{value: nil, type: :text}}
          ],
          "union-nil"
        ),
      "upsert.condition" =>
        defect_error(
          ~r/Unsupported expression in Elixir\.AshSqlite\.SqlImplementation query: %\{attribute: :value, __struct__: Ash\.Query\.UpsertConflict\}/,
          "upsert-conditions"
        ),
      "upsert.skipped_record" =>
        defect_error(
          ~r/\*\* \(Exqlite\.Error\) unsupported type: upsert_conflict\(:value\)/,
          "upsert-conditions"
        ),
      "use.fanout_read_page" => defect_value({~c"\v\v", 2}, "sorted-distinct-reads"),
      "use.parent_filter" =>
        unsupported(
          ~r/AshSql does not support loading aggregates over relationships with parent-dependent filters/,
          "parent-correlation"
        ),
      "use.parent_sort" =>
        unsupported(
          ~r/AshSql does not support loading aggregates over relationships with parent-dependent filters/,
          "parent-correlation"
        ),
      "values.decimal_max" =>
        defect_value(%{1 => "0.2", 2 => "12345678901234568", 3 => nil}, "decimal-precision"),
      "values.decimal_read_control" =>
        defect_value(
          %{301 => "0.1", 302 => "0.2", 303 => "12345678901234568", 304 => "0.01"},
          "decimal-precision"
        ),
      "values.decimal_sum" =>
        defect_value(
          %{1 => "0.30000000000000004", 2 => "12345678901234568", 3 => nil},
          "decimal-precision"
        )
    }
  end
end
