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
    @moduledoc """
    A fixture row the data layer could not store or read back. `cells` are
    the tier-1 storage cells the row's values depend on. `own_table` is set
    when the row went into the tier-1 table itself, so a table tier 1 could
    not create also explains the failure.
    """
    defexception [:role, :row, :reason, cells: [], own_table: false]

    @impl true
    def message(%{role: role, row: row, reason: reason}),
      do: "Could not store #{role} row #{row}: #{reason}"
  end

  @doc """
  Persists `rows` for `role` one at a time, so a failure names the role, the
  row, the reason and the storage cells the row depends on, instead of
  failing the whole batch anonymously.
  """
  def seed!(adapter, role, rows, opts \\ []) do
    for row <- rows do
      try do
        adapter.persist!(role, [row], opts)
      rescue
        exception ->
          reraise SetupError,
                  [
                    role: role,
                    row: row_key(row),
                    reason: reason(exception),
                    cells: cells(adapter, role, row)
                  ],
                  __STACKTRACE__
      end
    end

    :ok
  end

  defp cells(adapter, role, row) do
    resource = adapter.resource(role)

    row
    |> Enum.flat_map(fn {key, value} ->
      case Ash.Resource.Info.attribute(resource, key) do
        nil -> []
        attribute -> List.wrap(Ash.Conformance.Storage.cell(attribute, value))
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp raise_no_table!(role, name, reason) do
    raise SetupError,
      role: role,
      row: "table",
      reason: "its table could not be created: #{reason}",
      cells: Ash.Conformance.Storage.stored(name),
      own_table: true
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

  defp build_fixture!(adapter, :combination),
    do: Ash.Conformance.Fixtures.Combination.seed!(adapter)

  # Tier 2: one type's operation rows, in its tier-1 table.
  defp build_fixture!(adapter, {:operations, name}) do
    alias Ash.Conformance.Storage
    role = Storage.role(name)

    case Storage.provisioned(adapter, name) do
      {:error, reason} -> raise_no_table!(role, name, reason)
      {:error, reason, _column} -> raise_no_table!(role, name, reason)
      _provisioned -> :ok
    end

    try do
      seed!(adapter, role, ordered(Ash.Conformance.Operations.rows(name)))
    rescue
      error in SetupError -> reraise %{error | own_table: true}, __STACKTRACE__
    end

    %{adapter: adapter}
  end
end
