# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Transactions do
  @moduledoc """
  Atomicity of actions and explicit transactions.

  Hooks inside an action run in its transaction, so a failing `after_action`
  undoes the insert. Each scenario reports whether the operation failed and
  which ledger rows remain. A data layer's transaction support can depend on
  configuration: AshSQLite enables it on the repo, as its installer does.
  """
  import Ash.Conformance.Scenario, only: [new: 5]

  @opts [
    fixture: :empty,
    semantic_basis: "../documentation/topics/advanced/multi-step-actions.md",
    capabilities: [ledger: :transact]
  ]

  def all do
    [
      new(
        "txn.after_action_rollback",
        :transactions,
        {:error, []},
        fn ctx ->
          result =
            Ash.create(ledger(ctx), %{id: 1, amount: 5},
              action: :create_then_fail,
              authorize?: false
            )

          {elem(result, 0), ids(ctx)}
        end,
        @opts
      ),
      new(
        "txn.raise_rollback",
        :transactions,
        {:raised, []},
        fn ctx ->
          raised =
            try do
              Ash.transact(ledger(ctx), fn ->
                Ash.create!(ledger(ctx), %{id: 2, amount: 5}, authorize?: false)
                raise "abort"
              end)
            rescue
              RuntimeError -> :raised
            end

          {raised, ids(ctx)}
        end,
        @opts
      ),
      new(
        "txn.explicit_rollback",
        :transactions,
        {:error, []},
        fn ctx ->
          result =
            Ash.transact(ledger(ctx), fn ->
              Ash.create!(ledger(ctx), %{id: 3, amount: 5}, authorize?: false)
              Ash.DataLayer.rollback(ledger(ctx), :abort)
            end)

          {elem(result, 0), ids(ctx)}
        end,
        @opts
      ),
      new(
        "txn.commit",
        :transactions,
        {:ok, [4, 5]},
        fn ctx ->
          result =
            Ash.transact(ledger(ctx), fn ->
              Ash.create!(ledger(ctx), %{id: 4, amount: 5}, authorize?: false)
              Ash.create!(ledger(ctx), %{id: 5, amount: 6}, authorize?: false)
            end)

          {elem(result, 0), ids(ctx)}
        end,
        @opts
      )
    ]
  end

  defp ledger(ctx), do: ctx.adapter.resource(:ledger)

  defp ids(ctx) do
    ledger(ctx) |> Ash.read!(authorize?: false) |> Enum.map(& &1.id) |> Enum.sort()
  end
end
