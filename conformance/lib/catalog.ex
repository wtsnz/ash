# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Catalog do
  @moduledoc false
  alias Ash.Conformance.Scenarios

  def for_adapter(adapter), do: Enum.filter(all(), &(&1.profile in adapter.profiles()))

  def validate!(scenarios, expectations, adapters) do
    ids = Enum.map(scenarios, & &1.id)
    if length(ids) != length(Enum.uniq(ids)), do: raise(ArgumentError, "Duplicate scenario IDs")

    if Enum.sort(ids) != Enum.sort(Map.keys(expectations)) do
      missing = ids -- Map.keys(expectations)
      stale = Map.keys(expectations) -- ids

      raise ArgumentError,
            "Missing or stale expectation records. Missing: #{inspect(Enum.take(missing, 10))}; " <>
              "stale: #{inspect(Enum.take(stale, 10))}"
    end

    for scenario <- scenarios, adapter <- adapters, scenario.profile in adapter.profiles() do
      case expectations |> Map.fetch!(scenario.id) |> Map.fetch!(adapter.id()) do
        {_status, _signature, "GAPS.md#" <> gap} ->
          unless gap in Ash.Conformance.Contracts.Gaps.ids(),
            do: raise(ArgumentError, "#{scenario.id} links to unknown gap #{gap}")

        _ ->
          :ok
      end
    end

    :ok
  end

  def all do
    [
      Scenarios.Storage,
      Scenarios.Records,
      Scenarios.Types,
      Scenarios.Querying,
      Scenarios.Relationships,
      Scenarios.Aggregates.Kinds,
      Scenarios.Aggregates.Results,
      Scenarios.Aggregates.Types,
      Scenarios.Aggregates.Usage,
      Scenarios.Aggregates.Filters,
      Scenarios.Aggregates.Paths,
      Scenarios.Aggregates.Bounds,
      Scenarios.Aggregates.Context,
      Scenarios.Aggregates.Writes,
      Scenarios.Aggregates.Generated,
      Scenarios.Writes,
      Scenarios.Transactions,
      Scenarios.Tenancy,
      Scenarios.ContextTenancy,
      Scenarios.Authorization,
      Scenarios.Policies,
      Scenarios.Consistency
    ]
    |> Enum.flat_map(& &1.all())
    |> Enum.sort_by(& &1.id)
  end
end
