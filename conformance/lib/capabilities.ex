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
      advertised: Ash.DataLayer.data_layer_can?(resource, resolve(resource, feature))
    }
  end

  # Claims can name a relationship; it is resolved on each adapter's resource.
  defp resolve(resource, {type, name})
       when type in [:aggregate_relationship, :filter_relationship] and is_atom(name) do
    {type, relationship!(resource, name)}
  end

  defp resolve(resource, {:lateral_join, name}) when is_atom(name) do
    relationship = relationship!(resource, name)
    through = if relationship.type == :many_to_many, do: [relationship.through], else: []
    {:lateral_join, [resource] ++ through ++ [relationship.destination]}
  end

  defp resolve(_resource, feature), do: feature

  defp relationship!(resource, name) do
    Ash.Resource.Info.relationship(resource, name) ||
      raise ArgumentError, "#{inspect(resource)} has no relationship #{inspect(name)}"
  end

  @doc """
  The claims recorded for a scenario: its own, plus those of its feature in the
  catalog. Claims are reported beside results and never skip anything.
  """
  def for_scenario(adapter, scenario) do
    (scenario.capabilities ++ Ash.Conformance.Features.claims_for(scenario.id))
    |> Enum.uniq()
    |> Enum.map(fn {role, feature} -> probe(adapter, role, feature) end)
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
end
