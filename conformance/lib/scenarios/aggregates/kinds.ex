# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Aggregates.Kinds do
  @moduledoc "Every aggregate kind, loaded on records and run over a whole query."
  import Ash.Conformance.Scenario, only: [new: 4]
  import Ash.Conformance.Scenarios.Aggregates.Helpers

  def all, do: loaded_kinds() ++ root_kinds()

  defp loaded_kinds do
    for {kind, expected, opts} <- [
          {:count, %{1 => 4, 2 => 1, 3 => 0}, []},
          {:sum, %{1 => 11, 2 => 4, 3 => nil}, [field: :value]},
          {:avg, %{1 => 3.666667, 2 => 4.0, 3 => nil}, [field: :value]},
          {:min, %{1 => 2, 2 => 4, 3 => nil}, [field: :value]},
          {:max, %{1 => 7, 2 => 4, 3 => nil}, [field: :value]},
          {:exists, %{1 => true, 2 => true, 3 => false}, []},
          {:first, %{1 => 2, 2 => 4, 3 => nil}, [field: :value, query: [sort: [value: :asc]]]},
          {:list, %{1 => [2, 2, 7], 2 => [4], 3 => []},
           [field: :value, query: [sort: [value: :asc]]]},
          {:custom, %{1 => 11, 2 => 4, 3 => nil}, []}
        ] do
      new("loaded.#{kind}", :operations, expected, fn ctx ->
        opts =
          if kind == :custom,
            do: [type: :integer, implementation: {ctx.adapter.custom_aggregate(), field: :value}],
            else: opts

        loaded(ctx, kind, :children, opts)
      end)
    end
  end

  defp root_kinds do
    for {kind, expected, opts} <- [
          {:count, 5, []},
          {:sum, 15, [field: :value]},
          {:avg, 3.75, [field: :value]},
          {:min, 2, [field: :value]},
          {:max, 7, [field: :value]},
          {:exists, true, []},
          {:first, 7, [field: :value, query: [sort: [value: :desc]]]},
          {:list, [2, 2, 4, 7], [field: :value, query: [sort: [value: :asc]]]},
          {:custom, 15, []}
        ] do
      new("root.#{kind}", :operations, expected, fn ctx ->
        opts =
          if kind == :custom,
            do: [type: :integer, implementation: {ctx.adapter.custom_aggregate(), field: :value}],
            else: opts

        root(ctx, kind, opts)
      end)
    end
  end
end
