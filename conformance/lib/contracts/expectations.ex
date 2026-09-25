# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Contracts.Expectations do
  @moduledoc """
  Expectation records, gathered from each adapter's `expectations/0`.

  The built-in SQLite and Postgres records live in this module. An adapter
  from another repository returns its own map from `expectations/0`, so it
  never edits this file. New scenarios and adapters have no implicit status.
  A gap has a narrow error or wrong-result signature and a local task.
  Updating a record never changes the shared scenario's expected answer.
  """

  @supported_both ~w(
    tenant.read tenant.identities tenant.relationship_load tenant.relationship_filter
    tenant.loaded_aggregates tenant.root_aggregates tenant.aggregate_filter_sort
    tenant.aggregate_offset_page tenant.aggregate_keyset_pages tenant.missing tenant.invalid
    tenant.unknown tenant.explicit_global tenant.bounds tenant.from_many
    auth.read auth.children auth.relationship_load auth.loaded_aggregates auth.root_aggregates
    auth.aggregate_filter auth.aggregate_sort auth.offset_page auth.keyset_pages auth.bounds
    auth.from_many auth.tenant_interaction auth.context_read auth.context_relationship
    auth.context_aggregates auth.context_root equivalence.visible_count_load
    equivalence.root_reference read.selection_expression write.lifecycle
    tenant.write_local_identity tenant.write_bulk_destroy auth.write_bulk_update_atomic
    auth.write_bulk_update_stream auth.write_bulk_destroy auth.write_forbidden
    bounds.default_sort_control bounds.filter_after_limit bounds.list_filter_after_limit
    bounds.relationship_limit bounds.relationship_offset bounds.relationship_offset_only
    bounds.root_limit bounds.root_zero
    context.actor context.arguments context.attribute_tenant context.authorization
    context.authorization_bounds_control context.intermediate_action context.intermediate_actor
    context.prepared_context_control context.read_action context.shared context.through_arguments
    context.through_tenant
    field.aggregate field.calculation field.root_aggregate
    filter.aggregate_dependency_to_one
    filter.exists filter.fanout_nil_count filter.fanout_not_count filter.join filter.not_exists
    filter.or_exists filter.ordinary filter.sibling_independence
    identity.keyless_count
    loaded.avg loaded.count loaded.custom loaded.exists loaded.first loaded.list loaded.max loaded.min loaded.sum
    ordering.asc_nils_first ordering.asc_nils_last ordering.desc_nils_first ordering.desc_nils_last
    ordering.expression_first ordering.expression_list ordering.ties
    path.final_many_to_many_scalar path.many_to_many path.many_to_many_first path.many_to_many_list
    path.to_one_to_many_first path.to_one_to_many_list path.to_one_to_many_sum
    path.multi_hop path.no_attributes_control path.to_one path.unrelated
    root.avg root.count root.exists root.first root.max root.min root.sum
    use.calculation use.fanout_count use.filter use.keyset_pagination use.nested_limited_load
    use.pagination use.related_exists use.related_filter use.sort use.to_one_filter use.to_one_sort
    root.datetime_max
    values.date_list values.date_max values.date_min values.datetime_first values.datetime_max
    values.datetime_min values.decimal_avg values.time_min
    write.atomic_update write.bulk_destroy_filter write.bulk_update_filter
    write.single_atomic_update
    load.limit_per_parent load.offset_per_parent query.uniq_sum_rejected calc.in_memory
    txn.after_action_rollback txn.raise_rollback txn.explicit_rollback txn.commit
    upsert.tenant_identity upsert.bulk bulk.partial_success bulk.atomic_increment
    generated.filtered_aggregates
    ordering.list_desc values.date_list_desc
    load.belongs_to load.has_one load.has_many load.many_to_many
    record.read_all record.get_primary_key record.get_identity record.select record.create record.update
    record.update_to_nil record.destroy record.atomic_update record.types_scalar record.types_numeric
    record.types_temporal record.types_uuid record.types_strings record.types_array record.types_map
    record.types_embedded record.types_nil record.not_found record.invalid_value record.required
    record.identity_conflict record.filter_equal record.filter_not_equal record.filter_range
    record.filter_in_with_nil record.filter_is_nil record.filter_not_nil record.filter_not
    record.filter_boolean record.filter_atom record.filter_atom_as_string record.filter_decimal
    record.filter_date record.filter_datetime_precision record.filter_contains
    record.filter_case_insensitive record.filter_unicode record.filter_empty_string
    record.filter_array_member record.filter_map_key record.filter_embedded record.filter_calculation
    record.sort_desc_nils_last record.sort_asc_nils_first record.sort_tie_break record.sort_string
    record.sort_decimal record.sort_date record.sort_calculation record.limit_offset record.count
    record.stream record.offset_pages record.keyset_pages record.calculation_load
    record.calculation_argument
    values.constrained_scalar values.distinct_count values.distinct_list values.field_count
    values.filtered_first_default values.include_nil_first values.include_nil_list values.list_default
    values.root_empty values.same_name_distinct_definitions values.scalar_default
    values.string_constraints values.string_name
  )

  def for(id, adapter), do: all() |> Map.fetch!(id) |> Map.fetch!(adapter)

  @doc "Every adapter's records, by scenario ID and then adapter ID."
  def all do
    for adapter <- Ash.Conformance.Adapter.all(),
        {id, expectation} <- adapter.expectations(),
        reduce: %{} do
      acc ->
        Map.update(
          acc,
          id,
          %{adapter.id() => expectation},
          &Map.put(&1, adapter.id(), expectation)
        )
    end
  end

  @doc "The built-in records for `:sqlite` or `:postgres`."
  def builtin(adapter_id) do
    for {id, statuses} <- builtin_table(), Map.has_key?(statuses, adapter_id), into: %{} do
      {id, Map.fetch!(statuses, adapter_id)}
    end
  end

  defp builtin_table do
    Map.merge(Map.new(@supported_both, &{&1, both(:supported)}), gaps())
    |> Map.merge(
      Map.new(
        ~w(schema.direct schema.relationships schema.loaded_aggregates schema.root_aggregate schema.filtered_page),
        &{&1, %{postgres: :supported}}
      )
    )
  end

  defp gaps do
    %{
      "record.filter_true_or_nil" => both(unresolved_value([1, 4, 5, 7], "true-or-nil")),
      "query.distinct" =>
        sqlite(unsupported(~r/Data layer does not support distincting/, "query-distinct")),
      "query.union" =>
        sqlite(
          unsupported(~r/Data layer does not support combining queries/, "query-combinations")
        ),
      "query.lock_for_update" =>
        sqlite(
          {:unsupported,
           {:error, Ash.Error.Invalid,
            ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support lock: :for_update/},
           task("row-locks")}
        ),
      "load.many_to_many_limit_per_parent" =>
        sqlite(defect_value(%{1 => [202], 2 => [], 3 => []}, "many-to-many-load-limit")),
      "load.through" =>
        sqlite(
          defect_value(
            {true,
             %{1 => [101, 102, 103, 104], 2 => [101, 102, 103, 104], 3 => [101, 102, 103, 104]}},
            "through-fallback"
          )
        ),
      # The aggregate is correct; only the definition warning differs.
      "path.through_count" =>
        sqlite(defect_value({true, %{1 => 4, 2 => 0, 3 => 0}}, "through-fallback")),
      "upsert.condition" =>
        sqlite(
          defect_error(
            ~r/Unsupported expression in Elixir\.AshSqlite\.SqlImplementation query: %\{attribute: :value, __struct__: Ash\.Query\.UpsertConflict\}/,
            "upsert-conditions"
          )
        ),
      "upsert.skipped_record" => %{
        sqlite:
          defect_error(
            ~r/\*\* \(Exqlite\.Error\) unsupported type: upsert_conflict\(:value\)/,
            "upsert-conditions"
          ),
        postgres:
          defect_orders(
            %{
              forward: [{2001, 2, 1, 700, true}],
              reverse: [{1001, 1, 1, 2, true}],
              rotated: [{1001, 1, 1, 2, true}]
            },
            "skipped-upsert-tenant"
          )
      },
      "values.decimal_read_control" =>
        sqlite(
          defect_value(
            %{301 => "0.1", 302 => "0.2", 303 => "12345678901234568", 304 => "0.01"},
            "decimal-precision"
          )
        ),
      "values.decimal_sum" =>
        sqlite(
          defect_value(
            %{1 => "0.30000000000000004", 2 => "12345678901234568", 3 => nil},
            "decimal-precision"
          )
        ),
      "values.decimal_max" =>
        sqlite(
          defect_value(%{1 => "0.2", 2 => "12345678901234568", 3 => nil}, "decimal-precision")
        ),
      "root.decimal_sum" => sqlite(defect_value("12345678901234568", "decimal-precision")),
      "root.custom" => sqlite(root_unsupported()),
      "values.list_unsorted" =>
        postgres(defect_value(%{1 => [2, 2, 7, nil], 2 => [4], 3 => []}, "unsorted-list-nil")),
      "root.list_unsorted" => %{
        sqlite: root_unsupported(),
        postgres: defect_value([2, 2, 4, 7, nil], "unsorted-list-nil")
      },
      "root.list" => sqlite(root_unsupported()),
      "root.list_empty" => sqlite(root_unsupported()),
      "root.list_default_empty" => sqlite(root_unsupported()),
      "root.custom_empty" => sqlite(root_unsupported()),
      "bounds.root_custom_limit" => %{
        sqlite: root_unsupported(),
        postgres: defect_orders(%{forward: 4, reverse: 4, rotated: 7}, "root-bounds")
      },
      "bounds.root_list_limit" => %{
        sqlite: root_unsupported(),
        postgres: defect_orders(%{forward: [2, 2], reverse: [4], rotated: [7]}, "root-bounds")
      },
      "root.unsorted_first_empty" =>
        postgres(
          defect_error(
            ~r/\*\* \(BadMapError\) expected a map, got:\n\n    nil\n\n  \(ash_sql [^)]+\) lib\/aggregate\/lateral\.ex:\d+: AshSql\.Aggregate\.Lateral\.add_subquery_aggregate_select\/6\n/,
            "root-first"
          )
        ),
      "path.root_relationship" => %{
        sqlite:
          unsupported(
            ~r/AshSql grouped query aggregates do not yet support relationship aggregate :result/,
            "root-relationship"
          ),
        postgres:
          defect_error(
            ~r/no such aggregate field: Ash\.Conformance\.Postgres\.Parent\.value/,
            "root-relationship"
          )
      },
      "path.final_many_to_many_first" => sqlite(many_to_many()),
      "path.final_many_to_many_list" => sqlite(many_to_many()),
      "path.final_many_to_many_custom" => sqlite(many_to_many()),
      "path.intermediate_many_to_many" => sqlite(many_to_many()),
      "path.repeated_many_to_many" => %{
        sqlite:
          unresolved_error(
            ~r/AshSql does not support loading aggregates over multi-hop paths that include many_to_many relationships/,
            "path-multiplicity"
          ),
        postgres: unresolved_value(%{1 => 3, 2 => 2, 3 => 0}, "path-multiplicity")
      },
      "path.manual" =>
        sqlite(
          unsupported(
            ~r/AshSql does not support loading aggregates over manual relationships/,
            "manual"
          )
        ),
      "path.no_attributes" => %{
        sqlite: no_attributes(),
        postgres:
          defect_error(
            ~r/field `result` in `select` does not exist in schema Ash\.Conformance\.Postgres\.Child/,
            "no-attributes"
          )
      },
      "path.no_attributes_parent" => sqlite(no_attributes()),
      "filter.parent" => sqlite(parent_filter()),
      "filter.parent_unrelated" => sqlite(parent_filter()),
      "filter.parent_relationship" => sqlite(parent_relationship()),
      "filter.parent_through" =>
        sqlite(
          unsupported(
            ~r/AshSql does not support loading aggregates over many_to_many relationships with parent-dependent join filters/,
            "parent-correlation"
          )
        ),
      "filter.parent_through_control" =>
        both(
          defect_error(
            ~r/\*\* \(KeyError\) key :parent_bindings not found/,
            "parent-through-load"
          )
        ),
      "use.parent_filter" => sqlite(parent_relationship()),
      "use.parent_sort" => sqlite(parent_relationship()),
      "filter.parent_join" =>
        sqlite(
          unsupported(
            ~r/AshSql does not support loading aggregates with parent-dependent join filters/,
            "parent-correlation"
          )
        ),
      "filter.aggregate_dependency" => sqlite(filter_dependency()),
      "filter.aggregate_dependency_many_to_many" => sqlite(filter_dependency()),
      "filter.aggregate_dependency_filtered" => sqlite(filter_dependency()),
      "filter.aggregate_dependency_calculation" => sqlite(filter_dependency()),
      "filter.nested_parent" => %{
        sqlite: parent_filter(),
        postgres:
          defect_error(
            ~r/Unsupported expression in Elixir\.AshPostgres\.SqlImplementation query/,
            "nested-parent"
          )
      },
      "filter.nested_parent_control" =>
        both(defect_error(~r/\*\* \(KeyError\) key :parent_bindings not found/, "nested-parent")),
      "filter.fanout_sum" => fanout(6),
      "filter.fanout_avg" => fanout(3.25),
      "filter.fanout_count" => fanout(3),
      "filter.fanout_list" => fanout([2, 2, 2]),
      "filter.fanout_custom" => fanout(6),
      "filter.fanout_and" => fanout(%{1 => 6, 2 => nil, 3 => nil}),
      "filter.fanout_or" => fanout(%{1 => 13, 2 => nil, 3 => nil}),
      "filter.fanout_count_records" =>
        postgres(defect_value(%{1 => 3, 2 => 0, 3 => 0}, "filter-fanout")),
      "filter.fanout_read_control" => sqlite(defect_value([11, 11, 12], "sorted-distinct-reads")),
      "use.fanout_read_page" => sqlite(defect_value({[11, 11], 2}, "sorted-distinct-reads")),
      "identity.composite_count" => sqlite(composite_count()),
      "identity.composite_fanout_count" => %{
        sqlite: composite_count(),
        postgres: defect_value(%{1 => 6, 2 => 1, 3 => 0}, "filter-fanout")
      },
      "identity.root_composite_count" => sqlite(composite_count()),
      "identity.keyless_source" =>
        sqlite(
          unsupported(
            ~r/AshSql cannot load aggregates on resources with no primary key/,
            "record-identity"
          )
        ),
      "identity.keyless_distinct" => %{
        sqlite:
          unresolved_error(
            ~r/requires a single primary key to count distinct records, but Ash\.Conformance\.Sqlite\.Event has no primary key/,
            "keyless-identity"
          ),
        postgres: unresolved_value(%{1 => 2, 2 => 0, 3 => 0}, "keyless-identity")
      },
      "bounds.from_many" => both(defect_value(%{1 => 4, 2 => 1, 3 => 0}, "from-many")),
      "bounds.default_sort" => %{
        sqlite: defect_value(%{1 => 2, 2 => 4, 3 => nil}, "default-sort"),
        postgres:
          defect_orders(
            %{
              forward: %{1 => 2, 2 => 4, 3 => nil},
              reverse: %{1 => 7, 2 => 4, 3 => nil},
              rotated: %{1 => 7, 2 => 4, 3 => nil}
            },
            "default-sort"
          )
      },
      "bounds.unsorted_limit" =>
        sqlite(
          defect_error(~r/\*\* \(Exqlite.Error\) near "\)": syntax error/, "unsorted-bounds")
        ),
      "bounds.root_order_then_limit" =>
        postgres(defect_orders(%{forward: 2, reverse: 4, rotated: 7}, "root-bounds")),
      "bounds.root_first_distinct_sort" =>
        postgres(defect_orders(%{forward: 2, reverse: 4, rotated: 7}, "root-bounds")),
      "bounds.root_offset_only" =>
        postgres(
          defect_error(
            ~r/\*\* \(BadMapError\) expected a map, got:\n\n    nil\n\n  \(stdlib [^)]+\) :maps\.merge\(%\{\}, nil\)\n  \(ash_sql [^)]+\) lib\/aggregate\/lateral\/query\.ex:\d+: anonymous fn\/5 in AshSql\.Aggregate\.Lateral\.Query\.add_single_aggs\/5\n/,
            "root-bounds"
          )
        ),
      "bounds.many_to_many_query_limit" =>
        both(unresolved_error(~r/Cannot set limit on aggregate query/, "many-to-many-bounds-api")),
      "ordering.unique_other_field" => %{
        sqlite:
          unresolved_error(
            ~r/AshSql only supports uniq list aggregates when sorting by the list aggregate field/,
            "unique-list-order"
          ),
        postgres:
          unresolved_error(
            ~r/ERROR 42P10 .*in an aggregate with DISTINCT, ORDER BY expressions must appear in argument list/,
            "unique-list-order"
          )
      },
      "context.relationship_context" =>
        both(defect_value(%{1 => 0, 2 => 0, 3 => 0}, "relationship-context")),
      "context.relationship_context_control" =>
        both(defect_value(%{1 => [], 2 => [], 3 => []}, "relationship-context")),
      "context.authorization_before_bounds" =>
        both(defect_value(%{1 => nil, 2 => 4, 3 => nil}, "authorization-bounds")),
      "context.prepared_query_arguments" =>
        postgres(
          defect_error(
            ~r/no function clause matching in Enumerable\.List\.reduce\/3\n.*\{:error, \[%Ash\.Error\.Query\.Required\{field: :label, type: :argument.*in AshSql\.Aggregate\.Lateral\.add_aggregates\/6/s,
            "prepared-query"
          )
        ),
      "context.tenant_bypass" =>
        postgres(defect_value(%{1 => 3, 2 => 0, 3 => 0}, "tenant-bypass")),
      "context.bypass_sibling" => postgres(defect_value({3, 3}, "tenant-bypass")),
      "context.through_bypass" =>
        postgres(defect_value(%{1 => 3, 2 => 3, 3 => nil}, "tenant-bypass"))
    }
  end

  defp both(status), do: %{sqlite: status, postgres: status}
  defp sqlite(status), do: %{sqlite: status, postgres: :supported}
  defp postgres(status), do: %{sqlite: :supported, postgres: status}
  defp task(id), do: "GAPS.md##{id}"

  defp unsupported(pattern, id),
    do: {:unsupported, {:error, Ash.Error.Unknown, pattern}, task(id)}

  defp defect_error(pattern, id),
    do: {:known_defect, {:error, Ash.Error.Unknown, pattern}, task(id)}

  defp defect_value(value, id), do: {:known_defect, {:value, value}, task(id)}

  # A wrong answer that changes with the order rows were stored in. Each seed
  # order's observation is pinned, so any change still fails.
  defp defect_orders(values, id),
    do:
      {:known_defect,
       {:order_dependent, Map.new(values, fn {order, value} -> {order, {:value, value}} end)},
       task(id)}

  defp unresolved_error(pattern, id),
    do: {:unresolved, {:error, Ash.Error.Unknown, pattern}, task(id)}

  defp unresolved_value(value, id), do: {:unresolved, {:value, value}, task(id)}

  defp root_unsupported,
    do:
      {:unsupported,
       {:error, Ash.Error.Invalid,
        ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support using query aggregates/},
       task("root-kinds")}

  defp many_to_many,
    do:
      unsupported(
        ~r/AshSql does not support loading aggregates over multi-hop paths that include many_to_many relationships/,
        "many-to-many-paths"
      )

  defp no_attributes,
    do:
      unsupported(
        ~r/AshSql does not support loading aggregates over no_attributes\? relationships/,
        "no-attributes"
      )

  defp parent_filter,
    do:
      unsupported(
        ~r/AshSql does not support loading aggregates with parent-dependent aggregate filters/,
        "parent-correlation"
      )

  defp filter_dependency,
    do:
      unsupported(
        ~r/AshSql does not support loading aggregates with aggregate filters that reference other aggregates/,
        "filter-dependencies"
      )

  defp parent_relationship,
    do:
      unsupported(
        ~r/AshSql does not support loading aggregates over relationships with parent-dependent filters/,
        "parent-correlation"
      )

  defp composite_count,
    do:
      unsupported(
        ~r/requires a single primary key to count distinct records, but Ash\.Conformance\.Sqlite\.Link has composite primary key/,
        "record-identity"
      )

  defp fanout(value) do
    %{
      sqlite:
        unsupported(
          ~r/AshSql does not support loading sum, avg, list, custom, or field-based count aggregates with filters that reference to-many relationships/,
          "filter-fanout"
        ),
      postgres: defect_value(value, "filter-fanout")
    }
  end
end
