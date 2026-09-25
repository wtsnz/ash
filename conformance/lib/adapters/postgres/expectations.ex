# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Postgres.Expectations do
  @moduledoc """
  AshPostgres's expectation record for every scenario it runs: supported, or
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
    bounds.relationship_offset bounds.relationship_offset_only bounds.root_limit bounds.root_zero
    bounds.unsorted_limit bulk.atomic_increment bulk.partial_success calc.in_memory
    context.actor context.arguments context.attribute_tenant context.authorization
    context.authorization_bounds_control context.intermediate_action context.intermediate_actor context.prepared_context_control
    context.read_action context.shared context.through_arguments context.through_tenant
    equivalence.root_reference equivalence.visible_count_load field.aggregate field.calculation
    field.root_aggregate filter.aggregate_dependency filter.aggregate_dependency_calculation filter.aggregate_dependency_filtered
    filter.aggregate_dependency_many_to_many filter.aggregate_dependency_to_one filter.exists filter.fanout_nil_count
    filter.fanout_not_count filter.fanout_read_control filter.join filter.not_exists
    filter.or_exists filter.ordinary filter.parent filter.parent_join
    filter.parent_relationship filter.parent_through filter.parent_unrelated filter.sibling_independence
    generated.filtered_aggregates identity.composite_count identity.keyless_count identity.keyless_source
    identity.root_composite_count load.belongs_to load.has_many load.has_one
    load.limit_per_parent load.many_to_many load.many_to_many_limit_per_parent load.offset_per_parent
    load.through loaded.avg loaded.count loaded.custom
    loaded.exists loaded.first loaded.list loaded.max
    loaded.min loaded.sum ordering.asc_nils_first ordering.asc_nils_last
    ordering.desc_nils_first ordering.desc_nils_last ordering.expression_first ordering.expression_list
    ordering.list_desc ordering.ties path.final_many_to_many_custom path.final_many_to_many_first
    path.final_many_to_many_list path.final_many_to_many_scalar path.intermediate_many_to_many path.manual
    path.many_to_many path.many_to_many_first path.many_to_many_list path.multi_hop
    path.no_attributes_control path.no_attributes_parent path.through_count path.to_one
    path.to_one_to_many_first path.to_one_to_many_list path.to_one_to_many_sum path.unrelated
    query.distinct query.lock_for_update query.union query.uniq_sum_rejected
    read.selection_expression record.atomic_update record.calculation_argument record.calculation_load
    record.count record.create record.destroy record.filter_array_member
    record.filter_atom record.filter_atom_as_string record.filter_boolean record.filter_calculation
    record.filter_case_insensitive record.filter_contains record.filter_date record.filter_datetime_precision
    record.filter_decimal record.filter_embedded record.filter_empty_string record.filter_equal
    record.filter_in_with_nil record.filter_is_nil record.filter_map_key record.filter_not
    record.filter_not_equal record.filter_not_nil record.filter_range record.filter_unicode
    record.get_identity record.get_primary_key record.identity_conflict record.invalid_value
    record.keyset_pages record.limit_offset record.not_found record.offset_pages
    record.read_all record.required record.select record.sort_asc_nils_first
    record.sort_calculation record.sort_date record.sort_decimal record.sort_desc_nils_last
    record.sort_string record.sort_tie_break record.stream record.types_array
    record.types_embedded record.types_map record.types_nil record.types_numeric
    record.types_scalar record.types_strings record.types_temporal record.types_uuid
    record.update record.update_to_nil root.avg root.count
    root.custom root.custom_empty root.datetime_max root.decimal_sum
    root.exists root.first root.list root.list_default_empty
    root.list_empty root.max root.min root.sum
    schema.direct schema.filtered_page schema.loaded_aggregates schema.relationships
    schema.root_aggregate storage.atom.null storage.atom.ordinary storage.binary.edge
    storage.binary.null storage.binary.ordinary storage.boolean.null storage.boolean.ordinary
    storage.ci_string.edge storage.ci_string.null storage.ci_string.ordinary storage.date.edge
    storage.date.null storage.date.ordinary storage.decimal.edge storage.decimal.null
    storage.decimal.ordinary storage.duration.null storage.embedded.edge storage.embedded.null
    storage.embedded.ordinary storage.embeddeds.edge storage.embeddeds.null storage.embeddeds.ordinary
    storage.float.edge storage.float.null storage.float.ordinary storage.integer.edge
    storage.integer.null storage.integer.ordinary storage.integers.edge storage.integers.null
    storage.integers.ordinary storage.map.edge storage.map.null storage.map.ordinary
    storage.naive_datetime.edge storage.naive_datetime.null storage.naive_datetime.ordinary storage.string.null
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
    upsert.condition upsert.tenant_identity use.calculation use.fanout_count
    use.fanout_read_page use.filter use.keyset_pagination use.nested_limited_load
    use.pagination use.parent_filter use.parent_sort use.related_exists
    use.related_filter use.sort use.to_one_filter use.to_one_sort
    values.constrained_scalar values.date_list values.date_list_desc values.date_max
    values.date_min values.datetime_first values.datetime_max values.datetime_min
    values.decimal_avg values.decimal_max values.decimal_read_control values.decimal_sum
    values.distinct_count values.distinct_list values.field_count values.filtered_first_default
    values.include_nil_first values.include_nil_list values.list_default values.root_empty
    values.same_name_distinct_definitions values.scalar_default values.string_constraints values.string_name
    values.time_min write.atomic_update write.bulk_destroy_filter write.bulk_update_filter
    write.lifecycle write.single_atomic_update
  )

  def all, do: Map.new(@supported, &{&1, :supported}) |> Map.merge(gaps())

  defp gaps do
    %{
      "bounds.default_sort" =>
        defect_orders(
          [
            forward: %{1 => 2, 2 => 4, 3 => nil},
            reverse: %{1 => 7, 2 => 4, 3 => nil},
            rotated: %{1 => 7, 2 => 4, 3 => nil}
          ],
          "default-sort"
        ),
      "bounds.from_many" => defect_value(%{1 => 4, 2 => 1, 3 => 0}, "from-many"),
      "bounds.many_to_many_query_limit" =>
        unresolved_error(~r/Cannot set limit on aggregate query/, "many-to-many-bounds-api"),
      "bounds.root_custom_limit" =>
        defect_orders([forward: 4, reverse: 4, rotated: 7], "root-bounds"),
      "bounds.root_first_distinct_sort" =>
        defect_orders([forward: 2, reverse: 4, rotated: 7], "root-bounds"),
      "bounds.root_list_limit" =>
        defect_orders([forward: [2, 2], reverse: [4], rotated: ~c"\a"], "root-bounds"),
      "bounds.root_offset_only" =>
        defect_error(
          ~r/\*\* \(BadMapError\) expected a map, got:\n\n    nil\n\n  \(stdlib [^)]+\) :maps\.merge\(%\{\}, nil\)\n  \(ash_sql [^)]+\) lib\/aggregate\/lateral\/query\.ex:\d+: anonymous fn\/5 in AshSql\.Aggregate\.Lateral\.Query\.add_single_aggs\/5\n/,
          "root-bounds"
        ),
      "bounds.root_order_then_limit" =>
        defect_orders([forward: 2, reverse: 4, rotated: 7], "root-bounds"),
      "context.authorization_before_bounds" =>
        defect_value(%{1 => nil, 2 => 4, 3 => nil}, "authorization-bounds"),
      "context.bypass_sibling" => defect_value({3, 3}, "tenant-bypass"),
      "context.prepared_query_arguments" =>
        defect_error(
          ~r/no function clause matching in Enumerable\.List\.reduce\/3\n.*\{:error, \[%Ash\.Error\.Query\.Required\{field: :label, type: :argument.*in AshSql\.Aggregate\.Lateral\.add_aggregates\/6/s,
          "prepared-query"
        ),
      "context.relationship_context" =>
        defect_value(%{1 => 0, 2 => 0, 3 => 0}, "relationship-context"),
      "context.relationship_context_control" =>
        defect_value(%{1 => [], 2 => [], 3 => []}, "relationship-context"),
      "context.tenant_bypass" => defect_value(%{1 => 3, 2 => 0, 3 => 0}, "tenant-bypass"),
      "context.through_bypass" => defect_value(%{1 => 3, 2 => 3, 3 => nil}, "tenant-bypass"),
      "filter.fanout_and" => defect_value(%{1 => 6, 2 => nil, 3 => nil}, "filter-fanout"),
      "filter.fanout_avg" => defect_value(3.25, "filter-fanout"),
      "filter.fanout_count" => defect_value(3, "filter-fanout"),
      "filter.fanout_count_records" => defect_value(%{1 => 3, 2 => 0, 3 => 0}, "filter-fanout"),
      "filter.fanout_custom" => defect_value(6, "filter-fanout"),
      "filter.fanout_list" => defect_value([2, 2, 2], "filter-fanout"),
      "filter.fanout_or" => defect_value(%{1 => 13, 2 => nil, 3 => nil}, "filter-fanout"),
      "filter.fanout_sum" => defect_value(6, "filter-fanout"),
      "filter.nested_parent" =>
        defect_error(
          ~r/Unsupported expression in Elixir\.AshPostgres\.SqlImplementation query/,
          "nested-parent"
        ),
      "filter.nested_parent_control" =>
        defect_error(~r/\*\* \(KeyError\) key :parent_bindings not found/, "nested-parent"),
      "filter.parent_through_control" =>
        defect_error(~r/\*\* \(KeyError\) key :parent_bindings not found/, "parent-through-load"),
      "identity.composite_fanout_count" =>
        defect_value(%{1 => 6, 2 => 1, 3 => 0}, "filter-fanout"),
      "identity.keyless_distinct" =>
        unresolved_value(%{1 => 2, 2 => 0, 3 => 0}, "keyless-identity"),
      "ordering.unique_other_field" =>
        unresolved_error(
          ~r/ERROR 42P10 .*in an aggregate with DISTINCT, ORDER BY expressions must appear in argument list/,
          "unique-list-order"
        ),
      "path.no_attributes" =>
        defect_error(
          ~r/field `result` in `select` does not exist in schema Ash\.Conformance\.Postgres\.Child/,
          "no-attributes"
        ),
      "path.repeated_many_to_many" =>
        unresolved_value(%{1 => 3, 2 => 2, 3 => 0}, "path-multiplicity"),
      "path.root_relationship" =>
        defect_error(
          ~r/no such aggregate field: Ash\.Conformance\.Postgres\.Parent\.value/,
          "root-relationship"
        ),
      "record.filter_true_or_nil" => unresolved_value([1, 4, 5, 7], "true-or-nil"),
      "root.list_unsorted" => defect_value([2, 2, 4, 7, nil], "unsorted-list-nil"),
      "root.unsorted_first_empty" =>
        defect_error(
          ~r/\*\* \(BadMapError\) expected a map, got:\n\n    nil\n\n  \(ash_sql [^)]+\) lib\/aggregate\/lateral\.ex:\d+: AshSql\.Aggregate\.Lateral\.add_subquery_aggregate_select\/6\n/,
          "root-first"
        ),
      "storage.duration.edge" =>
        defect_value(
          [
            create: :ok,
            read: {:changed, %Duration{year: 1, month: 2, day: 3, hour: 4, microsecond: {0, 6}}},
            update: :skipped,
            clear: :skipped
          ],
          "value-representation"
        ),
      "storage.duration.ordinary" =>
        defect_value(
          [
            create: :ok,
            read: {:changed, %Duration{hour: 1, minute: 30, microsecond: {0, 6}}},
            update: :skipped,
            clear: :skipped
          ],
          "value-representation"
        ),
      "storage.string.edge" =>
        {:unsupported,
         {:value,
          [
            create: {:error, "invalid byte sequence for encoding \"UTF8\": 0x00"},
            read: :skipped,
            update: :skipped,
            clear: :skipped
          ]}, task("nul-in-text")},
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
      "upsert.skipped_record" =>
        defect_orders(
          [
            forward: [{2001, 2, 1, 700, true}],
            reverse: [{1001, 1, 1, 2, true}],
            rotated: [{1001, 1, 1, 2, true}]
          ],
          "skipped-upsert-tenant"
        ),
      "values.list_unsorted" =>
        defect_value(%{1 => [2, 2, 7, nil], 2 => [4], 3 => []}, "unsorted-list-nil")
    }
  end
end
