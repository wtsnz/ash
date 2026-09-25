# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Sqlite.Expectations do
  @moduledoc """
  AshSqlite's expectations: every scenario it runs is supported, except where
  a rule below records the gap it has instead, pinned to exactly what
  happens. Gaps link to `GAPS.md`. See `Ash.Conformance.Contracts.Records`
  for how rules resolve.
  """
  import Ash.Conformance.Contracts.Records

  def rules do
    [
      supported("*"),
      expect("bounds.default_sort", defect_value(%{1 => 2, 2 => 4, 3 => nil}, "default-sort")),
      expect("bounds.from_many", defect_value(%{1 => 4, 2 => 1, 3 => 0}, "from-many")),
      expect(
        "bounds.many_to_many_query_limit",
        unresolved_error(~r/Cannot set limit on aggregate query/, "many-to-many-bounds-api")
      ),
      expect(
        ~w(bounds.root_custom_limit bounds.root_list_limit root.custom root.custom_empty root.list root.list_default_empty root.list_empty root.list_unsorted),
        unsupported(
          ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support using query aggregates/,
          "root-kinds",
          Ash.Error.Invalid
        )
      ),
      expect(
        "bounds.unsorted_limit",
        defect_error(~r/\*\* \(Exqlite.Error\) near "\)": syntax error/, "unsorted-bounds")
      ),
      expect(
        "context.authorization_before_bounds",
        defect_value(%{1 => nil, 2 => 4, 3 => nil}, "authorization-bounds")
      ),
      expect(
        "context.relationship_context",
        defect_value(%{1 => 0, 2 => 0, 3 => 0}, "relationship-context")
      ),
      expect(
        "context.relationship_context_control",
        defect_value(%{1 => [], 2 => [], 3 => []}, "relationship-context")
      ),
      expect(
        ~w(filter.aggregate_dependency filter.aggregate_dependency_calculation filter.aggregate_dependency_filtered filter.aggregate_dependency_many_to_many),
        unsupported(
          ~r/AshSql does not support loading aggregates with aggregate filters that reference other aggregates/,
          "filter-dependencies"
        )
      ),
      expect(
        ~w(filter.fanout_and filter.fanout_avg filter.fanout_count filter.fanout_custom filter.fanout_list filter.fanout_or filter.fanout_sum),
        unsupported(
          ~r/AshSql does not support loading sum, avg, list, custom, or field-based count aggregates with filters that reference to-many relationships/,
          "filter-fanout"
        )
      ),
      expect("filter.fanout_read_control", defect_value([11, 11, 12], "sorted-distinct-reads")),
      expect(
        ~w(filter.nested_parent filter.parent filter.parent_unrelated),
        unsupported(
          ~r/AshSql does not support loading aggregates with parent-dependent aggregate filters/,
          "parent-correlation"
        )
      ),
      expect(
        "filter.nested_parent_control",
        defect_error(~r/\*\* \(KeyError\) key :parent_bindings not found/, "nested-parent")
      ),
      expect(
        "filter.parent_join",
        unsupported(
          ~r/AshSql does not support loading aggregates with parent-dependent join filters/,
          "parent-correlation"
        )
      ),
      expect(
        ~w(filter.parent_relationship use.parent_filter use.parent_sort),
        unsupported(
          ~r/AshSql does not support loading aggregates over relationships with parent-dependent filters/,
          "parent-correlation"
        )
      ),
      expect(
        "filter.parent_through",
        unsupported(
          ~r/AshSql does not support loading aggregates over many_to_many relationships with parent-dependent join filters/,
          "parent-correlation"
        )
      ),
      expect(
        "filter.parent_through_control",
        defect_error(~r/\*\* \(KeyError\) key :parent_bindings not found/, "parent-through-load")
      ),
      expect(
        ~w(identity.composite_count identity.composite_fanout_count identity.root_composite_count),
        unsupported(
          ~r/requires a single primary key to count distinct records, but Ash\.Conformance\.Sqlite\.Link has composite primary key/,
          "record-identity"
        )
      ),
      expect(
        "identity.keyless_distinct",
        unresolved_error(
          ~r/requires a single primary key to count distinct records, but Ash\.Conformance\.Sqlite\.Event has no primary key/,
          "keyless-identity"
        )
      ),
      expect(
        "identity.keyless_source",
        unsupported(
          ~r/AshSql cannot load aggregates on resources with no primary key/,
          "record-identity"
        )
      ),
      expect(
        "load.many_to_many_limit_per_parent",
        defect_value(%{1 => [202], 2 => [], 3 => []}, "many-to-many-load-limit")
      ),
      expect(
        "load.through",
        defect_value(
          {true,
           %{1 => [101, 102, 103, 104], 2 => [101, 102, 103, 104], 3 => [101, 102, 103, 104]}},
          "through-fallback"
        )
      ),
      expect(
        "ordering.unique_other_field",
        unresolved_error(
          ~r/AshSql only supports uniq list aggregates when sorting by the list aggregate field/,
          "unique-list-order"
        )
      ),
      expect(
        ~w(path.final_many_to_many_custom path.final_many_to_many_first path.final_many_to_many_list path.intermediate_many_to_many),
        unsupported(
          ~r/AshSql does not support loading aggregates over multi-hop paths that include many_to_many relationships/,
          "many-to-many-paths"
        )
      ),
      expect(
        "path.manual",
        unsupported(
          ~r/AshSql does not support loading aggregates over manual relationships/,
          "manual"
        )
      ),
      expect(
        ~w(path.no_attributes path.no_attributes_parent),
        unsupported(
          ~r/AshSql does not support loading aggregates over no_attributes\? relationships/,
          "no-attributes"
        )
      ),
      expect(
        "path.repeated_many_to_many",
        unresolved_error(
          ~r/AshSql does not support loading aggregates over multi-hop paths that include many_to_many relationships/,
          "path-multiplicity"
        )
      ),
      expect(
        "path.root_relationship",
        unsupported(
          ~r/AshSql grouped query aggregates do not yet support relationship aggregate :result/,
          "root-relationship"
        )
      ),
      expect(
        "path.through_count",
        defect_value({true, %{1 => 4, 2 => 0, 3 => 0}}, "through-fallback")
      ),
      expect(
        ~w(policy.all_of.get_error policy.any_of.get_error policy.bypass.get_error policy.can_read.get_error policy.forbid.get_error policy.member.get_error policy.owner.get_error policy.related.get_error),
        unsupported(
          ~r/Cannot use `error\/2` without adding the extension `ash-functions`/,
          "error-expressions"
        )
      ),
      expect(
        ~w(policy.bypass_admin.exists_filter_input policy.can_read.exists_filter_input policy.control.exists_filter_input policy.related.exists_filter_input policy.strict_admin.exists_filter_input),
        defect_value([1, 1, 2], "sorted-distinct-reads")
      ),
      expect("policy.member.exists_filter_input", defect_value([1, 1], "sorted-distinct-reads")),
      expect(
        ~w(policy.owner_nil_actor.bulk_destroy policy.strict.bulk_destroy),
        defect_value(:forbidden, "bulk-stream-forbidden")
      ),
      expect(
        "query.distinct",
        unsupported(~r/Data layer does not support distincting/, "query-distinct")
      ),
      expect(
        "query.lock_for_update",
        unsupported(
          ~r/Data layer for Ash\.Conformance\.Sqlite\.Child does not support lock: :for_update/,
          "row-locks",
          Ash.Error.Invalid
        )
      ),
      expect(
        "query.union",
        unsupported(~r/Data layer does not support combining queries/, "query-combinations")
      ),
      expect("record.filter_true_or_nil", unresolved_value([1, 4, 5, 7], "true-or-nil")),
      expect("root.decimal_sum", defect_value("12345678901234568", "decimal-precision")),
      expect(
        "storage.decimal.edge",
        defect_value(
          [
            create: :ok,
            read: {:lost, Decimal.new("12345678901234568")},
            update: :skipped,
            clear: :skipped
          ],
          "decimal-precision"
        )
      ),
      expect(
        "storage.duration.edge",
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
        )
      ),
      expect(
        "storage.duration.ordinary",
        defect_value(
          [
            create:
              {:error, "** (Exqlite.Error) unsupported type: %Duration{hour: 1, minute: 30}"},
            read: :skipped,
            update: :skipped,
            clear: :skipped
          ],
          "duration-storage"
        )
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
        "upsert.condition",
        defect_error(
          ~r/Unsupported expression in Elixir\.AshSqlite\.SqlImplementation query: %\{attribute: :value, __struct__: Ash\.Query\.UpsertConflict\}/,
          "upsert-conditions"
        )
      ),
      expect(
        "upsert.skipped_record",
        defect_error(
          ~r/\*\* \(Exqlite\.Error\) unsupported type: upsert_conflict\(:value\)/,
          "upsert-conditions"
        )
      ),
      expect("use.fanout_read_page", defect_value({[11, 11], 2}, "sorted-distinct-reads")),
      expect(
        "values.decimal_max",
        defect_value(%{1 => "0.2", 2 => "12345678901234568", 3 => nil}, "decimal-precision")
      ),
      expect(
        "values.decimal_read_control",
        defect_value(
          %{301 => "0.1", 302 => "0.2", 303 => "12345678901234568", 304 => "0.01"},
          "decimal-precision"
        )
      ),
      expect(
        "values.decimal_sum",
        defect_value(
          %{1 => "0.30000000000000004", 2 => "12345678901234568", 3 => nil},
          "decimal-precision"
        )
      )
    ]
  end
end
