# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Contracts.Expectations do
  @moduledoc """
  Expectation records, gathered from each adapter's `expectations/0`.

  Every adapter returns its own map from `expectations/0`, kept next to the
  adapter (for example `lib/adapters/sqlite/expectations.ex`), so adding or
  reviewing an adapter never edits this module. `Ash.Conformance.Contracts.Records`
  builds the records. New scenarios and adapters have no implicit status.
  A gap has a narrow error or wrong-result signature and a local task.
  Updating a record never changes the shared scenario's expected answer.
  """

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
end
