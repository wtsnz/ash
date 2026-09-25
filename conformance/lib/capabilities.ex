# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Capabilities do
  @moduledoc "Resource-specific claims. A claim is never evidence that an operation worked."

  @kinds [:count, :sum, :avg, :min, :max, :exists, :first, :list, :custom]
  @scalar [
    :read,
    :filter,
    :boolean_filter,
    :select,
    :sort,
    :limit,
    :offset,
    :keyset,
    :calculate,
    :expression_calculation,
    :expression_calculation_sort,
    :aggregate_filter,
    :aggregate_sort,
    :create,
    :update,
    :destroy,
    :upsert,
    :bulk_create,
    :bulk_create_with_partial_success,
    :bulk_upsert_return_skipped,
    :update_query,
    :destroy_query,
    :update_many,
    :transact,
    :multitenancy,
    :combine,
    :composite_type,
    :composite_primary_key,
    :through_relationship,
    :expr_error,
    :async_engine
  ]
  # These names occur in dispatch/query/action call sites but not feature().
  @callsite_only [
    :distinct,
    :distinct_sort,
    :timeout,
    :nested_expressions,
    :action_select,
    :changeset_filter,
    :atomic_update
  ]

  def scalar, do: @scalar
  def callsite_only, do: @callsite_only

  def probe(adapter, role, feature) do
    resource = adapter.resource(role)

    %{
      resource: inspect(resource),
      role: role,
      feature: inspect(feature),
      advertised: Ash.DataLayer.data_layer_can?(resource, feature)
    }
  end

  def for_scenario(adapter, scenario) do
    requests = if scenario.capabilities == [], do: defaults(scenario), else: scenario.capabilities
    Enum.map(requests, fn {role, feature} -> probe(adapter, role, feature) end)
  end

  def matrix(adapter) do
    simple =
      for role <- [:parent, :child, :tenant_parent, :secure_parent],
          feature <- @scalar ++ @callsite_only,
          do: probe(adapter, role, feature)

    aggregates =
      for role <- [:parent, :child],
          kind <- @kinds,
          type <- [:aggregate, :query_aggregate],
          do: probe(adapter, role, {type, kind})

    variants =
      for feature <- [
            {:atomic, :create},
            {:atomic, :update},
            {:atomic, :upsert},
            {:combine, :union},
            {:combine, :union_all},
            {:combine, :intersection},
            {:aggregate, :unrelated},
            {:exists, :unrelated},
            {:lock, :for_update},
            {:sort, Ash.Type.Integer}
          ],
          do: probe(adapter, :parent, feature)

    parent = adapter.resource(:parent)

    relationships =
      for name <- [:children, :top_children, :tags, :manual_children, :all_children],
          type <- [:aggregate_relationship, :filter_relationship] do
        relationship = Ash.Resource.Info.relationship(parent, name)

        probe(adapter, :parent, {type, relationship})
        |> Map.put(:feature, "{#{inspect(type)}, relationship(:#{name})}")
      end

    joins =
      for role <- [:child, :tag] do
        resource = adapter.resource(role)

        [
          probe(adapter, :parent, {:join, resource})
          |> Map.put(:feature, "{:join, resource(:#{role})}"),
          probe(adapter, :parent, {:lateral_join, [parent, resource]})
          |> Map.put(:feature, "{:lateral_join, [resource(:parent), resource(:#{role})]}")
        ]
      end
      |> List.flatten()

    filter = Ash.Filter.parse!(adapter.resource(:child), value: 2)

    expression =
      probe(adapter, :child, {:filter_expr, filter.expression})
      |> Map.put(:feature, "{:filter_expr, child.value == 2}")

    simple ++ aggregates ++ variants ++ relationships ++ joins ++ [expression]
  end

  def callbacks(adapter) do
    data_layer = Ash.DataLayer.data_layer(adapter.resource(:parent))
    optional = Ash.DataLayer.behaviour_info(:optional_callbacks)

    for {name, arity} <- Enum.sort(Ash.DataLayer.behaviour_info(:callbacks)) do
      %{
        callback: "#{name}/#{arity}",
        optional: {name, arity} in optional,
        exported: function_exported?(data_layer, name, arity),
        behavioral_coverage: :not_implied_by_export
      }
    end
  end

  def markdown do
    adapters = Ash.Conformance.Adapter.all()
    ids = Enum.map(adapters, & &1.id())

    claims =
      for adapter <- adapters,
          claim <- matrix(adapter),
          do: Map.put(claim, :adapter, adapter.id())

    rows =
      claims
      |> Enum.group_by(&{&1.role, &1.feature})
      |> Enum.sort()
      |> Enum.map_join("\n", fn {{role, feature}, claims} ->
        values =
          Enum.map_join(ids, " | ", fn id ->
            claims |> Enum.find(&(&1.adapter == id)) |> Map.fetch!(:advertised) |> to_string()
          end)

        "| #{role} | `#{feature}` | #{values} |"
      end)

    callbacks =
      for adapter <- adapters,
          callback <- callbacks(adapter),
          do: Map.put(callback, :adapter, adapter.id())

    callback_rows =
      callbacks
      |> Enum.group_by(& &1.callback)
      |> Enum.sort()
      |> Enum.map_join("\n", fn {callback, entries} ->
        values =
          Enum.map_join(ids, " | ", fn id ->
            entries |> Enum.find(&(&1.adapter == id)) |> Map.fetch!(:exported) |> to_string()
          end)

        "| `#{callback}` | #{hd(entries).optional} | #{values} |"
      end)

    """
    <!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
    <!-- SPDX-License-Identifier: MIT -->
    # Resource capability claims

    Generated by `mix conformance.inventory`. These are declarations, not test outcomes.
    Each role maps to that adapter's resource module. Relationship and expression probes
    use the concrete objects for the named resource. A claim never causes a test skip.
    See [MATRIX.md](MATRIX.md) for behavior contracts and `results/` for actual execution.

    | Resource role | Feature or concrete probe | #{Enum.join(ids, " | ")} |
    | --- | --- | #{Enum.map_join(ids, " | ", fn _ -> "---" end)} |
    #{rows}

    ## Callback exports

    Exported does not imply correct behavior. Optional callbacks may use framework paths;
    dedicated core tests establish only the paths they instrument. Adapter fallback
    execution is otherwise unobserved.

    | Callback | Optional | #{Enum.join(ids, " | ")} |
    | --- | --- | #{Enum.map_join(ids, " | ", fn _ -> "---" end)} |
    #{callback_rows}
    """
  end

  defp defaults(%{fixture: :isolation, id: id}) do
    role =
      cond do
        id in ["auth.context_root", "auth.context_read"] ->
          :context_item

        String.starts_with?(id, "auth.context_") ->
          :context_parent

        id in ["auth.root_aggregates", "auth.children", "equivalence.root_reference"] ->
          :secure_item

        String.starts_with?(id, "auth.") or id == "equivalence.visible_count_load" ->
          :secure_parent

        id == "tenant.root_aggregates" ->
          :tenant_item

        true ->
          :tenant_parent
      end

    features =
      cond do
        id == "write.lifecycle" ->
          [:create, :update, :destroy]

        id == "read.selection_expression" ->
          [:filter, :select, :expression_calculation]

        id in [
          "auth.root_aggregates",
          "auth.context_root",
          "tenant.root_aggregates",
          "equivalence.root_reference"
        ] ->
          [{:query_aggregate, :count}, {:query_aggregate, :sum}]

        String.contains?(id, "aggregate") ->
          [{:aggregate, :count}, {:aggregate, :sum}]

        String.contains?(id, "keyset") ->
          [:keyset, :aggregate_sort]

        true ->
          [:read, :filter]
      end

    Enum.map(features, &{role, &1})
  end

  defp defaults(%{id: "loaded." <> kind}),
    do: [{:parent, {:aggregate, String.to_existing_atom(kind)}}]

  defp defaults(%{id: "root." <> kind})
       when kind in ~w(count sum avg min max exists first list custom),
       do: [{:child, {:query_aggregate, String.to_existing_atom(kind)}}]

  defp defaults(_scenario), do: [{:parent, :read}]
end
