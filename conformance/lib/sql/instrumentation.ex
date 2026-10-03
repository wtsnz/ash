# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Instrumentation do
  @moduledoc "Untimed Ecto telemetry observation; never attached during primary latency samples."

  def measure(adapter, operation) do
    id = {__MODULE__, make_ref()}
    event = adapter.repo().config()[:telemetry_prefix] ++ [:query]
    :ok = :telemetry.attach(id, event, &__MODULE__.handle/4, self())

    try do
      result = operation.()
      {result, collect(%{query_count: 0, driver_query_us: 0})}
    after
      :telemetry.detach(id)
    end
  end

  def handle(_event, measurements, _metadata, owner),
    do: send(owner, {:conformance_query, measurements})

  defp collect(totals) do
    receive do
      {:conformance_query, measurements} ->
        collect(%{
          query_count: totals.query_count + 1,
          driver_query_us:
            totals.driver_query_us +
              System.convert_time_unit(measurements.query_time, :native, :microsecond)
        })
    after
      0 ->
        Map.put(
          totals,
          :limitation,
          "Ecto driver query_time includes driver/network wait; not exclusive server CPU. One separate instrumented operation, not timing samples."
        )
    end
  end

  @doc """
  Environment facts for the benchmark report. The adapter's `server_info/0`
  supplies the database-specific ones: version, settings, transport and
  whether writes run in transactions.
  """
  def metadata(adapter) do
    Map.merge(adapter.server_info(), %{
      pool_size: adapter.repo().config()[:pool_size],
      transaction: "SQL sandbox, one transaction per dataset"
    })
  end
end
