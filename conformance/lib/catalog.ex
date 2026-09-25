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

    if Enum.sort(ids) != Enum.sort(Map.keys(expectations)),
      do: raise(ArgumentError, "Missing or stale expectation records")

    for scenario <- scenarios, adapter <- adapters, scenario.profile in adapter.profiles() do
      _ = expectations |> Map.fetch!(scenario.id) |> Map.fetch!(adapter.id())
    end

    :ok
  end

  def all do
    [
      Scenarios.Operations,
      Scenarios.Relationships,
      Scenarios.Filters,
      Scenarios.Bounds,
      Scenarios.Context,
      Scenarios.Isolation,
      Scenarios.Schema
    ]
    |> Enum.flat_map(& &1.all())
    |> Enum.sort_by(& &1.id)
  end
end
