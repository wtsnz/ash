# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Benchmark do
  @moduledoc "Warm single-client timing, validated before timing and after every sample."
  alias Ash.Conformance.Benchmark.{Dataset, Workloads}

  def run(adapter, parameters, opts) do
    :ok = adapter.checkout!()

    metadata =
      try do
        environment(adapter)
      after
        adapter.checkin!()
      end

    # Two datasets keep selected parents fixed while unrelated children increase.
    results =
      for unrelated <- Enum.uniq([0, parameters.unrelated]) do
        p = %{parameters | unrelated: unrelated}
        data = Dataset.build(p)
        :ok = adapter.checkout!()

        try do
          Dataset.seed!(adapter, data)
          workloads = Workloads.all(adapter, p, data)
          # On the larger dataset only repeat selectivity-sensitive loaded aggregates.
          workloads =
            if unrelated == 0,
              do: workloads,
              else: Enum.filter(workloads, &(&1.id == "loaded_counts_sums"))

          Enum.map(workloads, &measure(&1, adapter, p, opts))
        after
          adapter.checkin!()
        end
      end
      |> List.flatten()

    %{
      schema_version: 1,
      workload_version: 1,
      adapter: adapter.id(),
      environment: metadata,
      methodology:
        "Warm single client. Timing includes public Ash call, query, decoding and resource materialization. Setup, oracle/projection assertions and telemetry are outside timing. No regression threshold.",
      results: results
    }
  end

  def measure(workload, adapter, parameters, opts) do
    validate!(workload, workload.operation.())
    for _ <- 1..opts.warmup, do: workload.operation.()

    samples =
      for _ <- 1..opts.samples do
        {microseconds, result} = :timer.tc(workload.operation)
        validate!(workload, result)
        microseconds
      end

    instrumentation =
      if module = adapter.instrumentation() do
        {result, measurement} = module.measure(adapter, workload.operation)
        validate!(workload, result)
        measurement
      else
        %{
          limitation: "Adapter provides no query instrumentation",
          query_count: nil,
          driver_query_us: nil
        }
      end

    %{
      workload: workload.id,
      parameters: parameters,
      validation: :passed,
      samples: length(samples),
      raw_samples_us: samples,
      warmup: opts.warmup,
      latency_us: statistics(samples),
      instrumentation: instrumentation
    }
  end

  def validate!(workload, actual) do
    projected = workload.project.(actual)

    unless projected == workload.expected do
      raise "#{workload.id}: benchmark validation failed; expected #{inspect(workload.expected)}, got #{inspect(projected)}"
    end
  end

  def statistics(samples) when samples != [] do
    sorted = Enum.sort(samples)
    n = length(sorted)
    base = %{min: hd(sorted), median: median(sorted), max: List.last(sorted)}
    base = if n >= 100, do: Map.put(base, :p95, Enum.at(sorted, ceil(n * 0.95) - 1)), else: base
    if n >= 1000, do: Map.put(base, :p99, Enum.at(sorted, ceil(n * 0.99) - 1)), else: base
  end

  defp median(sorted) do
    n = length(sorted)

    if rem(n, 2) == 1,
      do: Enum.at(sorted, div(n, 2)),
      else: (Enum.at(sorted, div(n, 2) - 1) + Enum.at(sorted, div(n, 2))) / 2
  end

  def environment(adapter) do
    {revision, 0} = System.cmd("git", ["rev-parse", "HEAD"])
    {dirty, 0} = System.cmd("git", ["status", "--porcelain"])

    %{
      elixir: System.version(),
      otp: to_string(:erlang.system_info(:otp_release)),
      erts: to_string(:erlang.system_info(:version)),
      os: inspect(:os.type()),
      architecture: to_string(:erlang.system_info(:system_architecture)),
      schedulers: :erlang.system_info(:schedulers_online),
      hardware: hardware(),
      ash_revision: String.trim(revision),
      source_dirty: String.trim(dirty) != "",
      dependencies: dependencies(),
      database:
        if(adapter.instrumentation(),
          do: adapter.instrumentation().metadata(adapter),
          else: %{limitation: "Adapter provides no database metadata"}
        ),
      client_concurrency: 1
    }
  end

  defp dependencies do
    Mix.Dep.Lock.read()
    |> Map.new(fn {name, lock} ->
      value =
        case lock do
          {:git, _, ref, _} -> ref
          {:hex, _, version, _, _, _, _, _} -> version
        end

      {name, value}
    end)
    |> Map.put(:ash, to_string(Application.spec(:ash, :vsn)))
  end

  defp hardware do
    {:ok, hostname} = :inet.gethostname()
    machine = System.get_env("BENCHMARK_MACHINE", to_string(hostname))

    case :os.type() do
      {:unix, :darwin} ->
        {cpu, 0} = System.cmd("sysctl", ["-n", "machdep.cpu.brand_string"])
        {memory, 0} = System.cmd("sysctl", ["-n", "hw.memsize"])

        %{
          machine: machine,
          cpu: String.trim(cpu),
          memory_bytes: String.to_integer(String.trim(memory))
        }

      {:unix, :linux} ->
        cpu =
          File.read!("/proc/cpuinfo")
          |> String.split("\n")
          |> Enum.find(&String.starts_with?(&1, "model name"))

        memory = File.read!("/proc/meminfo") |> String.split("\n") |> hd()
        %{machine: machine, cpu: cpu, memory: memory}

      _ ->
        %{machine: machine, limitation: "CPU/RAM description unavailable"}
    end
  end

  def summary(report) do
    rows =
      Enum.map_join(report.results, "\n", fn row ->
        "| #{row.workload} | #{row.parameters.unrelated} | #{row.samples} | #{row.latency_us.median} | #{Map.get(row.latency_us, :p95, "not estimated")} | #{row.instrumentation.query_count} | #{row.instrumentation.driver_query_us} |"
      end)

    """
    # #{report.adapter} benchmark

    #{report.methodology}

    | Workload | Unrelated children | Samples | Median µs | p95 µs | Queries, separate run | Driver query µs, separate run |
    | --- | ---: | ---: | ---: | ---: | ---: | ---: |
    #{rows}

    p95 requires at least 100 samples; p99 requires 1000. Smoke runs make no tail-latency claim.
    Full runtime, database, dependency and hardware metadata are in the JSON report.
    SQLite is embedded; PostgreSQL uses TCP. Compare each with its own compatible baseline.
    """
  end

  def compare!(base, current) do
    keys = ~w(schema_version workload_version adapter)

    for key <- keys,
        base[key] != current[key],
        do: raise(ArgumentError, "Incompatible benchmark #{key}")

    # Source revisions may differ; all runtime, database and hardware settings must match.
    for key <- ~w(elixir otp erts os architecture schedulers hardware database client_concurrency),
        base["environment"][key] != current["environment"][key],
        do: raise(ArgumentError, "Incompatible benchmark environment: #{key}")

    base_deps = Map.delete(base["environment"]["dependencies"], "ash")
    current_deps = Map.delete(current["environment"]["dependencies"], "ash")

    if base_deps != current_deps,
      do: raise(ArgumentError, "Incompatible adapter/dependency revisions")

    index = fn report -> Map.new(report["results"], &{{&1["workload"], &1["parameters"]}, &1}) end
    baseline = index.(base)
    proposed = index.(current)

    if MapSet.new(Map.keys(baseline)) != MapSet.new(Map.keys(proposed)),
      do: raise(ArgumentError, "Incompatible workloads or dataset parameters")

    for {key, row} <- proposed do
      old = baseline[key]

      if row["validation"] != "passed" or old["validation"] != "passed",
        do: raise(ArgumentError, "Cannot compare unvalidated workload")

      if row["samples"] != old["samples"] or row["warmup"] != old["warmup"],
        do: raise(ArgumentError, "Incompatible sample/warmup configuration")

      before = old["latency_us"]["median"]

      %{
        workload: row["workload"],
        parameters: row["parameters"],
        median_change_percent:
          if(before > 0,
            do: Float.round((row["latency_us"]["median"] / before - 1) * 100, 1),
            else: nil
          )
      }
    end
    |> Enum.sort_by(&{&1.workload, &1.parameters})
  end
end
