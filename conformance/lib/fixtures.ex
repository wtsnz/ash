# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures do
  @moduledoc """
  Builds a scenario's fixture on an adapter, in a given seed order.

  The data for each fixture lives in `Ash.Conformance.Fixtures.*`.
  """

  @doc """
  Builds a fixture, seeding each role's rows in `order`.

  The runner seeds every scenario forward and in reverse. Where the data layer
  keeps rows in insertion order, a result that depends on unspecified order
  then differs between the runs.
  """

  def build!(adapter, fixture, order \\ :forward) do
    Process.put({__MODULE__, :order}, order)

    try do
      build_fixture!(adapter, fixture)
    after
      Process.delete({__MODULE__, :order})
    end
  end

  defmodule SetupError do
    @moduledoc "A fixture row the data layer could not store or read back."
    defexception [:role, :row, :reason]

    @impl true
    def message(%{role: role, row: row, reason: reason}),
      do: "Could not store #{role} row #{row}: #{reason}"
  end

  @doc """
  Persists `rows` for `role` one at a time, so a failure names the role, the
  row and the reason instead of failing the whole batch anonymously.
  """
  def seed!(adapter, role, rows, opts \\ []) do
    for row <- rows do
      try do
        adapter.persist!(role, [row], opts)
      rescue
        exception ->
          reraise SetupError,
                  [role: role, row: row_key(row), reason: reason(exception)],
                  __STACKTRACE__
      end
    end

    :ok
  end

  defp row_key(row), do: Map.get(row, :id) || inspect(row, limit: 3)

  @doc "An exception's first informative line; Ash errors put the cause after a header."
  def reason(exception) do
    exception
    |> Exception.message()
    |> String.split("\n")
    |> Enum.map(&(&1 |> String.trim() |> String.trim_leading("* ")))
    |> Enum.find(
      "",
      &(&1 not in ["", "Unknown Error", "Invalid Error"] and
          not String.starts_with?(&1, ["Bread Crumbs", ">"]))
    )
    |> String.split(". This protocol", parts: 2)
    |> hd()
  end

  @doc "Rows in the order the current fixture build seeds them."

  def ordered(rows) do
    case Process.get({__MODULE__, :order}, :forward) do
      :forward ->
        rows

      :reverse ->
        Enum.reverse(rows)

      :rotated ->
        {head, tail} = Enum.split(rows, div(length(rows), 2))
        tail ++ head
    end
  end

  defp build_fixture!(adapter, :context_tenancy),
    do: Ash.Conformance.Fixtures.ContextTenancy.seed!(adapter)

  defp build_fixture!(adapter, :aggregate), do: Ash.Conformance.Fixtures.Aggregate.seed!(adapter)

  defp build_fixture!(adapter, :isolation), do: Ash.Conformance.Fixtures.Isolation.seed!(adapter)

  defp build_fixture!(adapter, :empty), do: %{adapter: adapter}

  defp build_fixture!(adapter, :records), do: Ash.Conformance.Fixtures.Records.seed!(adapter)
  defp build_fixture!(adapter, :policy), do: Ash.Conformance.Fixtures.Policy.seed!(adapter)

  def prepare!(context, "values.string_constraints") do
    seed!(context.adapter, :child, [
      %{id: 15, parent_id: 1, label: ""},
      %{id: 16, parent_id: 1, label: " padded "}
    ])
  end

  def prepare!(context, "filter.fanout_avg"),
    do: seed!(context.adapter, :rating, [%{id: 105, child_id: 13, score: 8}])

  def prepare!(_context, _id), do: :ok
end
