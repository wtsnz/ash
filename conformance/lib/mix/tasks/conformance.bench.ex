# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Mix.Tasks.Conformance.Bench do
  @moduledoc false
  use Mix.Task
  @shortdoc "Run validated warm read benchmarks (smoke by default)"
  def run(args) do
    {options, rest, invalid} =
      OptionParser.parse(args,
        strict: [
          profile: :string,
          parents: :integer,
          children: :integer,
          selected: :integer,
          tenants: :integer,
          tenant_size: :integer,
          skew: :integer,
          unrelated: :integer,
          samples: :integer,
          warmup: :integer,
          output: :string
        ]
      )

    if rest != [] or invalid != [], do: Mix.raise("Unknown benchmark arguments")

    profile =
      case options[:profile] || "smoke" do
        "smoke" -> :smoke
        "large" -> :large
        other -> Mix.raise("Unknown profile #{other}")
      end

    dimensions = ~w(parents children selected tenants tenant_size skew unrelated)a

    parameters =
      Map.merge(
        Ash.Conformance.Benchmark.Dataset.parameters(profile),
        Map.new(Keyword.take(options, dimensions))
      )

    for {key, value} <- parameters do
      minimum = if key in [:skew, :unrelated], do: 0, else: 1
      if value < minimum, do: Mix.raise("#{key} must be >= #{minimum}")
    end

    if parameters.selected >= parameters.parents,
      do:
        Mix.raise("selected must be smaller than parents so selectivity has an unrelated parent")

    opts = %{
      samples: options[:samples] || if(profile == :smoke, do: 10, else: 100),
      warmup: options[:warmup] || 3
    }

    if opts.samples < 1 or opts.warmup < 1, do: Mix.raise("samples and warmup must be positive")
    Mix.Task.run("app.start")
    directory = options[:output] || "results/bench"
    File.mkdir_p!(directory)

    for adapter <- Ash.Conformance.Adapter.selected() do
      adapter.setup!()
      report = Ash.Conformance.Benchmark.run(adapter, parameters, opts)

      File.write!(
        Path.join(directory, "#{adapter.id()}.json"),
        Jason.encode!(report, pretty: true) <> "\n"
      )

      summary = Ash.Conformance.Benchmark.summary(report)
      File.write!(Path.join(directory, "#{adapter.id()}.md"), summary)
      Mix.shell().info(summary)
    end
  end
end
