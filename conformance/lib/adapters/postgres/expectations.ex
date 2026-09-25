# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Postgres.Expectations do
  @moduledoc """
  AshPostgres's expectations: every scenario it runs is supported, except where
  a rule below records the gap it has instead, pinned to exactly what
  happens. Gaps link to `GAPS.md`. See `Ash.Conformance.Contracts.Records`
  for how rules resolve.
  """
  import Ash.Conformance.Contracts.Records

  def rules do
    [
      supported("*"),
      expect(
        "bounds.default_sort",
        defect_orders(
          [
            forward: %{1 => 2, 2 => 4, 3 => nil},
            reverse: %{1 => 7, 2 => 4, 3 => nil},
            rotated: %{1 => 7, 2 => 4, 3 => nil}
          ],
          "default-sort"
        )
      ),
      expect("bounds.from_many", defect_value(%{1 => 4, 2 => 1, 3 => 0}, "from-many")),
      expect(
        "bounds.many_to_many_query_limit",
        unresolved_error(~r/Cannot set limit on aggregate query/, "many-to-many-bounds-api")
      ),
      expect(
        "bounds.root_custom_limit",
        defect_orders([forward: 4, reverse: 4, rotated: 7], "root-bounds")
      ),
      expect(
        ~w(bounds.root_first_distinct_sort bounds.root_order_then_limit),
        defect_orders([forward: 2, reverse: 4, rotated: 7], "root-bounds")
      ),
      expect(
        "bounds.root_list_limit",
        defect_orders([forward: [2, 2], reverse: [4], rotated: [7]], "root-bounds")
      ),
      expect(
        "bounds.root_offset_only",
        defect_error(
          ~r/\*\* \(BadMapError\) expected a map, got:\n\n    nil\n\n  \(stdlib [^)]+\) :maps\.merge\(%\{\}, nil\)\n  \(ash_sql [^)]+\) lib\/aggregate\/lateral\/query\.ex:\d+: anonymous fn\/5 in AshSql\.Aggregate\.Lateral\.Query\.add_single_aggs\/5\n/,
          "root-bounds"
        )
      ),
      expect(
        "context.authorization_before_bounds",
        defect_value(%{1 => nil, 2 => 4, 3 => nil}, "authorization-bounds")
      ),
      expect("context.bypass_sibling", defect_value({3, 3}, "tenant-bypass")),
      expect(
        "context.prepared_query_arguments",
        defect_error(
          ~r/no function clause matching in Enumerable\.List\.reduce\/3\n.*\{:error, \[%Ash\.Error\.Query\.Required\{field: :label, type: :argument.*in AshSql\.Aggregate\.Lateral\.add_aggregates\/6/s,
          "prepared-query"
        )
      ),
      expect(
        "context.relationship_context",
        defect_value(%{1 => 0, 2 => 0, 3 => 0}, "relationship-context")
      ),
      expect(
        "context.relationship_context_control",
        defect_value(%{1 => [], 2 => [], 3 => []}, "relationship-context")
      ),
      expect("context.tenant_bypass", defect_value(%{1 => 3, 2 => 0, 3 => 0}, "tenant-bypass")),
      expect(
        "context.through_bypass",
        defect_value(%{1 => 3, 2 => 3, 3 => nil}, "tenant-bypass")
      ),
      expect("filter.fanout_and", defect_value(%{1 => 6, 2 => nil, 3 => nil}, "filter-fanout")),
      expect("filter.fanout_avg", defect_value(3.25, "filter-fanout")),
      expect("filter.fanout_count", defect_value(3, "filter-fanout")),
      expect(
        "filter.fanout_count_records",
        defect_value(%{1 => 3, 2 => 0, 3 => 0}, "filter-fanout")
      ),
      expect(~w(filter.fanout_custom filter.fanout_sum), defect_value(6, "filter-fanout")),
      expect("filter.fanout_list", defect_value([2, 2, 2], "filter-fanout")),
      expect("filter.fanout_or", defect_value(%{1 => 13, 2 => nil, 3 => nil}, "filter-fanout")),
      expect(
        "filter.nested_parent",
        defect_error(
          ~r/Unsupported expression in Elixir\.AshPostgres\.SqlImplementation query/,
          "nested-parent"
        )
      ),
      expect(
        "filter.nested_parent_control",
        defect_error(~r/\*\* \(KeyError\) key :parent_bindings not found/, "nested-parent")
      ),
      expect(
        "filter.parent_through_control",
        defect_error(~r/\*\* \(KeyError\) key :parent_bindings not found/, "parent-through-load")
      ),
      expect(
        "identity.composite_fanout_count",
        defect_value(%{1 => 6, 2 => 1, 3 => 0}, "filter-fanout")
      ),
      expect(
        "identity.keyless_distinct",
        unresolved_value(%{1 => 2, 2 => 0, 3 => 0}, "keyless-identity")
      ),
      expect(
        "ordering.unique_other_field",
        unresolved_error(
          ~r/ERROR 42P10 .*in an aggregate with DISTINCT, ORDER BY expressions must appear in argument list/,
          "unique-list-order"
        )
      ),
      expect(
        "path.no_attributes",
        defect_error(
          ~r/field `result` in `select` does not exist in schema Ash\.Conformance\.Postgres\.Child/,
          "no-attributes"
        )
      ),
      expect(
        "path.repeated_many_to_many",
        unresolved_value(%{1 => 3, 2 => 2, 3 => 0}, "path-multiplicity")
      ),
      expect(
        "path.root_relationship",
        defect_error(
          ~r/no such aggregate field: Ash\.Conformance\.Postgres\.Parent\.value/,
          "root-relationship"
        )
      ),
      expect("record.filter_true_or_nil", unresolved_value([1, 4, 5, 7], "true-or-nil")),
      expect("root.list_unsorted", defect_value([2, 2, 4, 7, nil], "unsorted-list-nil")),
      expect(
        "root.unsorted_first_empty",
        defect_error(
          ~r/\*\* \(BadMapError\) expected a map, got:\n\n    nil\n\n  \(ash_sql [^)]+\) lib\/aggregate\/lateral\.ex:\d+: AshSql\.Aggregate\.Lateral\.add_subquery_aggregate_select\/6\n/,
          "root-first"
        )
      ),
      expect(
        "storage.duration.edge",
        defect_value(
          [
            create: :ok,
            read: {:changed, %Duration{year: 1, month: 2, day: 3, hour: 4, microsecond: {0, 6}}},
            update: :skipped,
            clear: :skipped
          ],
          "value-representation"
        )
      ),
      expect(
        "storage.duration.ordinary",
        defect_value(
          [
            create: :ok,
            read: {:changed, %Duration{hour: 1, minute: 30, microsecond: {0, 6}}},
            update: :skipped,
            clear: :skipped
          ],
          "value-representation"
        )
      ),
      expect(
        "storage.string.edge",
        {:unsupported,
         {:value,
          [
            create: {:error, "invalid byte sequence for encoding \"UTF8\": 0x00"},
            read: :skipped,
            update: :skipped,
            clear: :skipped
          ]}, task("nul-in-text")}
      ),
      expect(
        "storage.union.ordinary",
        defect_value(
          [
            create: :ok,
            read: :ok,
            update: :ok,
            clear: {:lost, %Ash.Union{value: nil, type: :text}}
          ],
          "union-nil"
        )
      ),
      expect(
        "upsert.skipped_record",
        defect_orders(
          [
            forward: [{2001, 2, 1, 700, true}],
            reverse: [{1001, 1, 1, 2, true}],
            rotated: [{1001, 1, 1, 2, true}]
          ],
          "skipped-upsert-tenant"
        )
      ),
      expect(
        "values.list_unsorted",
        defect_value(%{1 => [2, 2, 7, nil], 2 => [4], 3 => []}, "unsorted-list-nil")
      )
    ]
  end
end
