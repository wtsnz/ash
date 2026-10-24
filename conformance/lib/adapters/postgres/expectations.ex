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
        "edge.plus.integer_overflow",
        unresolved_error(
          ~r/ERROR 22003 \(numeric_value_out_of_range\) bigint out of range/,
          "integer-overflow"
        )
      ),
      expect(
        "edge.at.negative_index",
        unresolved_value(%{11 => nil, 12 => nil, 13 => nil}, "at-negative-index")
      ),
      expect(
        "edge.string_length.graphemes",
        unsupported(
          ~r/Unsupported expression in Elixir\.AshPostgres\.SqlImplementation query: .*name: :string_length/s,
          "grapheme-length"
        )
      ),
      # Ash stops at `/`'s first signature before any query runs.
      expect(
        ~w(sig.div.decimal_decimal sig.div.float_decimal sig.div.integer_decimal),
        defect_error(
          ~r/Could not cast Decimal\.new\("0\.5"\) as :float/,
          "operator-signature-cast"
        )
      ),
      expect(
        ~w(sig.minus.datetime_datetime sig.minus.utc_datetime_utc_datetime sig.minus.usec_usec
           sig.minus.naive_naive sig.minus.time_time sig.minus.time_usec_time_usec),
        defect_error(
          ~r/ERROR 42846 \(cannot_coerce\) cannot cast type interval to bigint/,
          "temporal-difference"
        )
      ),
      expect(
        "sig.string_split.default",
        defect_value(%{1 => ["Hello", "World"], 2 => [], 3 => nil}, "string-split-empty")
      ),
      expect(
        "sig.string_split.separator",
        defect_value(%{1 => ["Hell", " W", "rld"], 2 => [], 3 => nil}, "string-split-empty")
      ),
      expect(
        "sig.string_split.ci",
        defect_value(%{1 => ["HeLLo"], 2 => [], 3 => nil}, "string-split-empty")
      ),
      expect(
        ~w(sig.string_split.ci_separator sig.string_split.ci_ci),
        defect_value(%{1 => ["H", "LLo"], 2 => [], 3 => nil}, "string-split-empty")
      ),
      expect(
        ~w(sig.string_split.trim sig.string_split.ci_separator_trim),
        defect_value(%{1 => ["Hell", " W", "rld"], 2 => nil, 3 => nil}, "string-split-empty")
      ),
      expect(
        ~w(sig.string_split.ci_trim sig.string_split.ci_ci_trim),
        defect_value(%{1 => ["H", "LLo"], 2 => nil, 3 => nil}, "string-split-empty")
      ),
      expect(
        "sig.string_position.string_ci",
        defect_value(%{1 => nil, 2 => nil, 3 => nil}, "string-position-ci")
      ),
      expect(
        "sig.start_of_day.datetime_zone",
        defect_value(
          %{
            1 => {:datetime, 1_706_641_200_000_000},
            2 => {:datetime, 1_709_233_200_000_000},
            3 => nil
          },
          "start-of-day-zone"
        )
      ),
      expect(
        "sig.start_of_day.date_zone",
        defect_value(
          %{
            1 => {:datetime, 1_706_590_800_000_000},
            2 => {:datetime, 1_709_096_400_000_000},
            3 => nil
          },
          "start-of-day-zone"
        )
      ),
      expect("nil.not_contradictory_in", defect_value([1, 2, 3, 4], "in-simplification")),
      expect("large.bulk_create_parameters", defect_value({:error, 0}, "bind-parameter-limit")),
      expect("nil.not_in_with_nil", unresolved_value([], "in-list-nil")),
      expect("nil.or", unresolved_value([1, 3], "true-or-nil")),
      # The item policy applies after the relationship's limit, as in
      # context.authorization_before_bounds.
      expect(
        "combo.list.top_items.value_gt.global.actor.loaded",
        defect_value(%{1 => [5], 2 => [7], 3 => []}, "authorization-bounds")
      ),
      expect(
        "values.decimal_avg",
        unresolved_value(%{1 => 0.15, 2 => 6_172_839_450_617_284.0, 3 => nil}, "decimal-avg")
      ),
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
    ] ++ adversarial_rules()
  end

  @doc """
  Where an `Ash.Conformance.Variant` run behaves differently from the
  scenario's own record.
  """
  def variant_rules do
    [
      expect_variant(
        ~w(shape.exists.*.depth_2.*.sort shape.exists.*.depth_2.*.filter
           shape.exists.*.depth_3.*.sort shape.exists.*.depth_3.*.filter),
        [:filter_policy, :decoy],
        defect_error(
          ~r/no such relationship Ash\.Conformance\.\w+\.Shape(Integer|Uuid)(Leaf|Tip)\.(integer|uuid)_mids/,
          "exists-path-authorization"
        )
      ),
      # With authorization on, Ash raises before AshSQL's KeyError.
      expect_variant(
        "filter.nested_parent_control",
        Ash.Conformance.Variant.all(),
        defect_error(
          ~r/\(MatchError\) no match of right hand side value:\s+\[\]/,
          "nested-parent"
        )
      ),
      # With authorization on, Ash raises before AshSQL's own prepared-query defect.
      expect_variant(
        "context.prepared_query_arguments",
        Ash.Conformance.Variant.all(),
        defect_error(
          ~r/argument label is required/,
          "authorized-action-arguments",
          Ash.Error.Invalid
        )
      ),
      # The policy filter changes the query AshSQL builds, and the aggregate over
      # the no_attributes? relationship then works (see the no-attributes gap).
      expect_variant("path.no_attributes", [:filter_policy, :decoy], :supported)
    ] ++ decoy_rules()
  end

  # The adversarial scenarios (`Ash.Conformance.Scenarios.Adversarial`).
  defp adversarial_rules do
    leaked_loads = %{1 => [1, 2, 3, 4], 2 => [4, 5], 3 => [2]}
    first_of_all = %{1 => 5, 2 => 5, 3 => 5}
    joined = %{1 => {4, [1, 2, 3, 4], 4}, 2 => {2, [4, 5], 5}, 3 => {1, [2], 2}}
    tenant_a = %{1 => {2, [1, 3], 3}, 2 => {1, [4], 4}, 3 => {0, [], nil}}

    [
      expect(
        ~w(adv.tenant.m2m_load adv.tenant.through_load adv.tenant.through_long_load),
        defect_value({leaked_loads, leaked_loads}, "through-tenant")
      ),
      expect(
        "adv.tenant.has_one_sorted",
        defect_value({%{1 => 4, 2 => 5, 3 => 2}, %{1 => 4, 2 => 5, 3 => 2}}, "through-tenant")
      ),
      expect(
        "adv.tenant.has_one_unsorted",
        defect_value(
          {%{1 => true, 2 => true, 3 => false}, %{1 => false, 2 => false, 3 => true}},
          "through-tenant"
        )
      ),
      expect("adv.tenant.m2m_limit_one", defect_value({[4], [4]}, "through-tenant")),
      expect(
        "adv.tenant.through_many_to_many_load",
        defect_value(
          {%{1 => [1], 2 => [2], 3 => [3]}, %{1 => [1], 2 => [2], 3 => [3]}},
          "through-many-to-many-step"
        )
      ),
      expect(
        ~w(adv.tenant.through_limit_one adv.schema.through_limit_one),
        defect_value({[5], [5]}, "through-limit-one")
      ),
      expect("adv.tenant.through_offset", defect_value({[6], [6]}, "through-limit-one")),
      expect(
        "adv.tenant.has_one_limit",
        defect_value({first_of_all, first_of_all}, "through-limit-one")
      ),
      expect("adv.plain.has_one_limit", defect_value(first_of_all, "through-limit-one")),
      expect("adv.plain.through_limit_one", defect_value([5], "through-limit-one")),
      expect("adv.plain.through_offset", defect_value([6], "through-limit-one")),
      expect(
        ~w(adv.join_policy.m2m_aggregates adv.join_policy.through_aggregates),
        defect_value(joined, "join-resource-policies")
      ),
      expect(
        "adv.join_policy.m2m_exists_aggregate",
        defect_value(%{1 => true, 2 => false, 3 => false}, "join-resource-policies")
      ),
      expect("adv.join_policy.m2m_aggregate_filter", defect_value([], "join-resource-policies")),
      expect("adv.join_policy.m2m_filter_input", defect_value([1], "join-resource-policies")),
      expect(
        "adv.join_policy.through_exists_aggregate",
        defect_value(%{1 => true, 2 => true, 3 => true}, "through-exists-aggregate")
      ),
      expect(
        "adv.schema.m2m_aggregates",
        defect_value({tenant_a, tenant_a}, "joined-prefix-cache")
      ),
      expect("adv.schema.m2m_exists", defect_value({[], []}, "joined-prefix-cache")),
      expect(
        "adv.schema.through_load",
        defect_error(
          ~r/relation "dc_tenant_a\.adv_customers" does not exist/,
          "schema-through-destination"
        )
      ),
      expect(
        ~w(adv.field_write.create adv.field_write.update adv.field_write.destroy
           adv.field_write.bulk_create adv.field_write.bulk_update.atomic
           adv.field_write.bulk_update.atomic_batches adv.field_write.bulk_destroy.atomic),
        defect_value(Ash.Conformance.Adversarial.leaked_fields(), "write-result-field-policies")
      ),
      expect(
        "adv.field_write.update_load",
        defect_value(
          Map.put(Ash.Conformance.Adversarial.leaked_fields(), :order_count, :forbidden),
          "write-result-field-policies"
        )
      ),
      expect(
        ~w(adv.foreign.bulk_update.stream adv.foreign.bulk_update.fallback
           adv.foreign.bulk_update.stream_global_records),
        defect_value(
          {[101, 201], Ash.Conformance.Adversarial.notes_after([101, 201], :update)},
          "bulk-stream-tenant"
        )
      ),
      expect(
        ~w(adv.foreign.bulk_destroy.stream adv.foreign.bulk_destroy.fallback),
        defect_value(
          {[101, 201], Ash.Conformance.Adversarial.notes_after([101, 201], :destroy)},
          "bulk-stream-tenant"
        )
      ),
      expect(
        "adv.foreign.destroy_changeset",
        defect_value(
          {:ok, Ash.Conformance.Adversarial.notes_after([201], :destroy)},
          "destroy-record-tenant"
        )
      ),
      expect(
        "adv.upsert.all_tenants",
        unresolved_value(
          {{201, 2, 1, "mine"}, Ash.Conformance.Adversarial.notes_after([201], {:body, "mine"})},
          "all-tenants-upsert"
        )
      ),
      expect(
        "adv.upsert.all_tenants_skipped_bulk",
        unresolved_value(
          {[{201, 2, 1, "b1"}], Ash.Conformance.Adversarial.notes()},
          "all-tenants-upsert"
        )
      ),
      # Which tenant's row the lookup returns depends on row order.
      expect(
        "adv.upsert.skipped_bulk",
        defect_orders(
          [
            forward: {[{201, 2, 1, "b1"}], Ash.Conformance.Adversarial.notes()},
            reverse: {[{101, 1, 1, "a1"}], Ash.Conformance.Adversarial.notes()},
            rotated: {[{101, 1, 1, "a1"}], Ash.Conformance.Adversarial.notes()}
          ],
          "skipped-upsert-tenant"
        )
      )
    ]
  end

  # What the decoy variant's hidden rows change (`Ash.Conformance.Decoy`).
  defp decoy_rules do
    [
      expect_variant(
        ~w(bounds.filter_after_limit bounds.relationship_limit bounds.relationship_offset),
        :decoy,
        defect_value(%{1 => nil, 2 => 4, 3 => nil}, "authorization-bounds")
      ),
      expect_variant(
        "bounds.list_filter_after_limit",
        :decoy,
        defect_value(%{1 => [], 2 => [4], 3 => []}, "authorization-bounds")
      ),
      expect_variant(
        "bounds.relationship_offset_only",
        :decoy,
        defect_value(%{1 => 11, 2 => 4, 3 => nil}, "authorization-bounds")
      ),
      expect_variant(
        "bounds.unsorted_limit",
        :decoy,
        defect_value(%{1 => 0, 2 => 0, 3 => 0}, "authorization-bounds")
      ),
      expect_variant(
        "context.authorization_before_bounds",
        :decoy,
        defect_value(%{1 => nil, 2 => nil, 3 => nil}, "authorization-bounds")
      ),
      expect_variant(
        "write.atomic_update",
        :decoy,
        defect_value([{1, 8}, {2, 2}, {3, 0}], "aggregate-reference-authorization")
      ),
      expect_variant(
        "write.single_atomic_update",
        :decoy,
        defect_value(2, "aggregate-reference-authorization")
      ),
      expect_variant(
        "write.bulk_update_filter",
        :decoy,
        defect_value([{1, "big"}, {2, "big"}, {3, "empty"}], "aggregate-reference-authorization")
      ),
      expect_variant(
        "field.root_aggregate",
        :decoy,
        defect_value(10, "aggregate-reference-authorization")
      ),
      expect_variant(
        ~w(filter.aggregate_dependency filter.aggregate_dependency_calculation),
        :decoy,
        defect_value(%{1 => 3, 2 => 0, 3 => 0}, "aggregate-reference-authorization")
      ),
      expect_variant(
        "filter.aggregate_dependency_filtered",
        :decoy,
        defect_value(%{1 => 4, 2 => nil, 3 => nil}, "aggregate-reference-authorization")
      ),
      expect_variant(
        ~w(adv.join_policy.m2m_aggregates adv.join_policy.through_aggregates),
        :decoy,
        defect_value(Ash.Conformance.Adversarial.doubled_join(), "join-resource-policies")
      )
    ]
  end
end
