# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Report.StorageGrid do
  @moduledoc """
  The tier-1 storage grid: which types each data layer stores and gives back
  unchanged. `markdown/1` is the overview across data layers; `detail/1` is
  one data layer's table, with the column type and the first problem.
  """
  alias Ash.Conformance.Storage

  @markers %{
    "ok" => "✅",
    "changed" => "≈",
    "lost" => "❌",
    "error" => "❌",
    "no_table" => "🚫",
    "order_dependent" => "🔀",
    "unknown" => "❔"
  }

  @legend """
  Each cell shows the ordinary, edge and nil values, in that order. ✅ reads
  back unchanged; ≈ reads back equal but in another representation, such as
  `1.5` as `1.5000000000`; ❌ is lost or rejected; 🚫 the table could not be
  created; 🔀 differs between seed orders; ❔ did not run; – the type has no
  values of that class.
  """

  @doc "Type × data layer overview, from each data layer's survey rows."
  def markdown(results) do
    ran = Enum.reject(results, & &1.unavailable)

    rows =
      Enum.map_join(Storage.types(), "\n", fn type ->
        cells = Enum.map_join(ran, " | ", &cell(cells(&1.rows, type)))
        "| #{type.label} | #{cells} |"
      end)

    """
    ## Storage

    Tier 1: every type has its own resource and table, so a type a data layer
    cannot store fails only its own row. Tables use the column type the data
    layer's migration generator chooses; each data layer's survey file lists
    them, with the first problem in each cell.

    #{String.trim(@legend)}

    | Type | #{Enum.map_join(ran, " | ", & &1.adapter.id())} |
    | --- | #{Enum.map_join(ran, " | ", fn _ -> "---" end)} |
    #{rows}
    """
  end

  @doc "One data layer's storage table."
  def detail(rows) do
    body =
      Enum.map_join(Storage.types(), "\n", fn type ->
        cells = cells(rows, type)
        column = cells |> Enum.find_value(&(&1 && &1[:column])) || "—"

        problem =
          cells
          |> Enum.zip(Storage.classes())
          |> Enum.find_value("", fn
            {%{result: result} = detail, class} when result != "ok" ->
              "#{class}, #{detail.step || "run"}: #{escape(detail.note)}"

            _ ->
              nil
          end)

        marks = Enum.map_join(cells, " | ", &marker/1)
        "| #{type.label} | `#{column}` | #{marks} | #{problem} |"
      end)

    """
    ## Storage

    #{String.trim(@legend)}

    | Type | Column | Ordinary | Edge | Nil | First problem |
    | --- | --- | --- | --- | --- | --- |
    #{body}
    """
  end

  # The detail of each class's row, in class order; nil where the type has
  # no values of that class.
  defp cells(rows, type) do
    by_id = Map.new(rows, &{&1.scenario, &1})

    for class <- Storage.classes() do
      case Map.get(by_id, Storage.scenario_id(type.name, class)) do
        nil -> nil
        %{classification: :setup_failed} -> %{result: "unknown", step: nil, note: nil}
        row -> Map.get(row, :detail) || %{result: "unknown", step: nil, note: nil}
      end
    end
  end

  defp cell(cells) do
    present = Enum.reject(cells, &is_nil/1)

    if present != [] and Enum.all?(present, &(&1.result == "no_table")),
      do: "🚫 no table",
      else: Enum.map_join(cells, " ", &marker/1)
  end

  defp marker(nil), do: "–"
  defp marker(%{result: result}), do: Map.fetch!(@markers, result)

  defp escape(nil), do: ""

  defp escape(note),
    do: note |> String.replace("|", "\\|") |> String.replace("\n", " ") |> String.slice(0, 160)
end
