# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures.Large do
  @moduledoc """
  2,000 rows, `value` equal to `id` and `label` `"row-<id>"`, stored with the
  adapter's bulk insert. Only data layers that opt in to `:large` run it.
  """

  @count 2_000

  def count, do: @count
  def rows, do: for(id <- 1..@count, do: %{id: id, value: id, label: "row-#{id}"})

  def seed!(adapter) do
    rows()
    |> Ash.Conformance.Fixtures.ordered()
    |> Enum.chunk_every(500)
    |> Enum.each(&adapter.benchmark_persist!(:large_row, &1))

    %{adapter: adapter}
  end
end
