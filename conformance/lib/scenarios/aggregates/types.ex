# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Aggregates.Types do
  @moduledoc false
  import Ash.Conformance.Scenario, only: [new: 4]
  import Ash.Conformance.Scenarios.Aggregates.Helpers

  # Readings: parent 1 has amounts 0.1 and 0.2, parent 2 has
  # 12345678901234567.89 and 0.01, and parent 3 has none. Times differ by a
  # microsecond around midnight and the hour.
  def all do
    decimals() ++ temporal()
  end

  defp decimals do
    [
      new(
        "values.decimal_read_control",
        :results,
        %{301 => "0.1", 302 => "0.2", 303 => "12345678901234567.89", 304 => "0.01"},
        fn ctx ->
          ctx.adapter.resource(:reading)
          |> Ash.read!(authorize?: false)
          |> Map.new(&{&1.id, exact(&1.amount)})
        end
      ),
      new(
        "values.decimal_sum",
        :results,
        %{1 => "0.3", 2 => "12345678901234567.9", 3 => nil},
        fn ctx ->
          loaded_exact(ctx, :sum, :readings, field: :amount)
        end
      ),
      new(
        "values.decimal_max",
        :results,
        %{1 => "0.2", 2 => "12345678901234567.89", 3 => nil},
        fn ctx ->
          loaded_exact(ctx, :max, :readings, field: :amount)
        end
      ),
      # Ash averages are floats, so they are compared rounded.
      new(
        "values.decimal_avg",
        :results,
        %{1 => 0.15, 2 => 6_172_839_450_617_284.0, 3 => nil},
        fn ctx ->
          loaded(ctx, :avg, :readings, field: :amount)
        end
      ),
      new("root.decimal_sum", :results, "12345678901234568.2", fn ctx ->
        Ash.aggregate!(ctx.adapter.resource(:reading), [{:result, :sum, field: :amount}],
          authorize?: false
        ).result
        |> exact()
      end)
    ]
  end

  defp temporal do
    [
      new(
        "values.date_min",
        :results,
        %{1 => ~D[2024-01-09], 2 => ~D[2023-12-31], 3 => nil},
        fn ctx ->
          loaded(ctx, :min, :readings, field: :taken_on)
        end
      ),
      new(
        "values.date_max",
        :results,
        %{1 => ~D[2024-01-10], 2 => ~D[2024-02-01], 3 => nil},
        fn ctx ->
          loaded(ctx, :max, :readings, field: :taken_on)
        end
      ),
      new(
        "values.date_list",
        :results,
        %{1 => [~D[2024-01-09], ~D[2024-01-10]], 2 => [~D[2023-12-31], ~D[2024-02-01]], 3 => []},
        fn ctx ->
          loaded(ctx, :list, :readings, field: :taken_on, query: [sort: [taken_on: :asc]])
        end
      ),
      new(
        "values.date_list_desc",
        :results,
        %{1 => [~D[2024-01-10], ~D[2024-01-09]], 2 => [~D[2024-02-01], ~D[2023-12-31]], 3 => []},
        fn ctx ->
          loaded(ctx, :list, :readings, field: :taken_on, query: [sort: [taken_on: :desc]])
        end
      ),
      new(
        "values.datetime_min",
        :results,
        %{1 => ~U[2024-01-01 09:59:59.999999Z], 2 => ~U[2023-12-31 23:59:59.000001Z], 3 => nil},
        fn ctx ->
          loaded(ctx, :min, :readings, field: :taken_at)
        end
      ),
      new(
        "values.datetime_max",
        :results,
        %{1 => ~U[2024-01-01 10:00:00.000000Z], 2 => ~U[2024-02-01 00:00:00.000000Z], 3 => nil},
        fn ctx ->
          loaded(ctx, :max, :readings, field: :taken_at)
        end
      ),
      new(
        "values.datetime_first",
        :results,
        %{1 => ~U[2024-01-01 10:00:00.000000Z], 2 => ~U[2024-02-01 00:00:00.000000Z], 3 => nil},
        fn ctx ->
          loaded(ctx, :first, :readings, field: :taken_at, query: [sort: [taken_at: :desc]])
        end
      ),
      new(
        "values.time_min",
        :results,
        %{1 => ~T[09:30:00], 2 => ~T[00:00:00], 3 => nil},
        fn ctx ->
          loaded(ctx, :min, :readings, field: :taken_time)
        end
      ),
      new("root.datetime_max", :results, ~U[2024-02-01 00:00:00.000000Z], fn ctx ->
        Ash.aggregate!(ctx.adapter.resource(:reading), [{:result, :max, field: :taken_at}],
          authorize?: false
        ).result
      end)
    ]
  end
end
