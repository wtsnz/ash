# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Test.DataLayer.DispatchContractTest do
  use ExUnit.Case, async: true

  defmodule SingleCallbacks do
    use Spark.Dsl.Extension
    @behaviour Ash.DataLayer
    def can?(_, _), do: false
    def resource_to_query(_, _), do: []

    def add_aggregate(query, aggregate, _) do
      send(self(), {:aggregate, aggregate})

      if aggregate == :invalid,
        do: {:error, :invalid_aggregate},
        else: {:ok, query ++ [aggregate]}
    end

    def add_calculation(query, calculation, expression, _) do
      send(self(), {:calculation, calculation, expression})
      {:ok, query ++ [{calculation, expression}]}
    end
  end

  defmodule BatchCallbacks do
    use Spark.Dsl.Extension
    @behaviour Ash.DataLayer
    def can?(_, _), do: false
    def resource_to_query(_, _), do: []

    def add_aggregates(query, aggregates, _) do
      send(self(), {:batch, aggregates})
      {:ok, query ++ aggregates}
    end

    def add_aggregate(_, _, _), do: raise("batch must take precedence")
  end

  defmodule Single do
    use Ash.Resource, domain: nil, data_layer: SingleCallbacks

    attributes do
      integer_primary_key(:id)
    end
  end

  defmodule Batch do
    use Ash.Resource, domain: nil, data_layer: BatchCallbacks

    attributes do
      integer_primary_key(:id)
    end
  end

  defmodule InvalidCallback do
    def can?(_, _), do: :yes
    def run_query(_, _), do: :invalid
  end

  test "batch aggregate fallback invokes single callbacks in order and stops on errors" do
    assert {:ok, [:one, :two]} = Ash.DataLayer.add_aggregates([], [:one, :two], Single)
    assert_received {:aggregate, :one}
    assert_received {:aggregate, :two}

    assert {:error, :invalid_aggregate} =
             Ash.DataLayer.add_aggregates([], [:invalid, :never], Single)

    assert_received {:aggregate, :invalid}
    refute_received {:aggregate, :never}
  end

  test "batch callback takes precedence over the single callback fallback" do
    assert {:ok, [:one, :two]} = Ash.DataLayer.add_aggregates([], [:one, :two], Batch)
    assert_received {:batch, [:one, :two]}
    refute_received {:aggregate, _}
  end

  test "calculation fallback preserves the expression paired with each calculation" do
    assert {:ok, [one: 1, two: 2]} = Ash.DataLayer.add_calculations([], [one: 1, two: 2], Single)
    assert_received {:calculation, :one, 1}
    assert_received {:calculation, :two, 2}
  end

  test "missing optional query callbacks use documented wrapper defaults" do
    assert {:ok, :query} = Ash.DataLayer.return_query(:query, Single)
    assert %{} = Ash.DataLayer.functions(Single)
    assert nil == Ash.DataLayer.default_bulk_batch_size(Single, nil)

    assert {:error, "Aggregate queries not supported by " <> _} =
             Ash.DataLayer.run_aggregate_query(:query, [], Single)
  end

  test "capability and query results are validated at the dispatch boundary" do
    assert_raise Ash.Error.Framework.InvalidReturnType, ~r/can\?\/2 expects a boolean/, fn ->
      Ash.DataLayer.can?(InvalidCallback, Single, :read)
    end

    assert_raise Ash.Error.Framework.InvalidReturnType, ~r/run_query\/2/, fn ->
      Ash.DataLayer.run_query(InvalidCallback, :query, Single)
    end
  end

  test "nontransactional execution runs the operation once without claiming a transaction" do
    assert {:ok, :result} =
             Ash.DataLayer.transaction(Single, fn ->
               send(self(), :executed)
               :result
             end)

    assert_received :executed
    refute_received :executed
    refute Ash.DataLayer.in_transaction?(Single)
  end
end
