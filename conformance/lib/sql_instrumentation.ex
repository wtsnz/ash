# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQLInstrumentation do
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

  def metadata(adapter) do
    version_sql =
      if adapter.id() == :sqlite, do: "select sqlite_version()", else: "show server_version"

    [[version]] = adapter.repo().query!(version_sql).rows

    settings =
      if adapter.id() == :sqlite do
        Map.new(~w(journal_mode synchronous cache_size), fn name ->
          {name, adapter.repo().query!("PRAGMA #{name}").rows}
        end)
      else
        Map.new(~w(shared_buffers work_mem max_connections), fn name ->
          {name, adapter.repo().query!("SHOW #{name}").rows}
        end)
      end

    %{
      version: version,
      settings: settings,
      transport: if(adapter.id() == :sqlite, do: "embedded", else: "TCP"),
      pool_size: adapter.repo().config()[:pool_size],
      transaction: "SQL sandbox, one transaction per dataset",
      write_transactions?:
        if(adapter.id() == :sqlite, do: adapter.repo().write_transactions?(), else: :always)
    }
  end
end
