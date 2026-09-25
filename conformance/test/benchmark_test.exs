# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.BenchmarkTest do
  use ExUnit.Case, async: true
  alias Ash.Conformance.Benchmark
  alias Ash.Conformance.Benchmark.Dataset

  test "small samples report no spurious tail percentiles" do
    assert %{min: 1, median: 2.5, max: 4} == Benchmark.statistics([4, 1, 3, 2])
    assert %{p95: 95} = Benchmark.statistics(Enum.to_list(1..100))
    refute Map.has_key?(Benchmark.statistics(Enum.to_list(1..100)), :p99)
  end

  test "wrong answers fail before any timed samples or instrumentation" do
    workload = %{
      id: "broken",
      operation: fn ->
        send(self(), :operation)
        2
      end,
      project: & &1,
      expected: 1
    }

    assert_raise RuntimeError, ~r/benchmark validation failed/, fn ->
      Benchmark.measure(workload, :unused_adapter, %{}, %{samples: 10, warmup: 3})
    end

    assert_received :operation
    refute_received :operation
  end

  test "selectivity changes only unrelated children" do
    p = Dataset.parameters(:smoke)
    base = Dataset.build(%{p | unrelated: 0})
    larger = Dataset.build(p)
    selected = fn data -> Enum.filter(data.children, &(&1.parent_id <= p.selected)) end
    assert selected.(base) == selected.(larger)
    assert length(larger.children) - length(base.children) == p.unrelated
    assert base.tenant_items == larger.tenant_items
  end

  defp report do
    %{
      "schema_version" => 1,
      "workload_version" => 1,
      "adapter" => "sqlite",
      "environment" => %{
        "hardware" => "machine-a",
        "dependencies" => %{"ash_sql" => "abc", "ash" => "3.0"}
      },
      "results" => [
        %{
          "workload" => "loaded",
          "parameters" => %{"parents" => 10},
          "validation" => "passed",
          "samples" => 10,
          "warmup" => 3,
          "latency_us" => %{"median" => 100}
        }
      ]
    }
  end

  test "comparison rejects incompatible environment, dataset and validation" do
    base = report()
    assert [%{median_change_percent: 0.0}] = Benchmark.compare!(base, base)

    for modified <- [
          put_in(base, ["environment", "hardware"], "machine-b"),
          put_in(base, ["environment", "dependencies", "ash_sql"], "other"),
          Map.put(base, "adapter", "postgres"),
          Map.put(base, "results", [put_in(hd(base["results"]), ["parameters", "parents"], 11)])
        ] do
      assert_raise ArgumentError, ~r/Incompatible/, fn -> Benchmark.compare!(base, modified) end
    end

    invalid = Map.put(base, "results", [Map.put(hd(base["results"]), "validation", "failed")])
    assert_raise ArgumentError, ~r/unvalidated/, fn -> Benchmark.compare!(base, invalid) end
  end
end
