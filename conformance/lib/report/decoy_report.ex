# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Report.DecoyReport do
  @moduledoc """
  The decoy variant (`Ash.Conformance.Variant`, `Ash.Conformance.Decoy`) in
  each report: the recorded contracts in `FEATURES.md`, and the surveyed
  results in `ECOSYSTEM.md` and each `surveys/features-<adapter>.md`.

  A surveyed scenario's decoy result is one of:

  - `same`: the decoys changed nothing;
  - `leaked`: a decoy id, value or marker appears in the outcome;
  - `changed`: the outcome differs from the scenario's own, with no decoy in
    it, such as a count of hidden rows or a wrong record;
  - `opted out`: the scenario's answer rightly changes, for the reason it
    declares;
  - `not run`: the data layer has no decoy resource set, or the scenario's
    own fixture could not be stored.
  """
  alias Ash.Conformance.{Adapter, Catalog, Contracts.Gaps, Decoy, Runner, Variant}

  @statuses [:same, :leaked, :changed, :opted_out, :not_run]

  @doc "A survey row's decoy result, from the scenario's own outcome."
  def observe(scenario, adapter, base_outcome, setup_failed?) do
    cond do
      not Variant.supported?(adapter, :decoy) or setup_failed? ->
        %{status: :not_run}

      Variant.applies?(scenario, :decoy) != true ->
        %{status: :opted_out}

      true ->
        outcome =
          try do
            Variant.run(:decoy, fn ->
              scenario |> Runner.observe_both_orders(adapter) |> Variant.normalize()
            end)
          rescue
            exception ->
              {:error, exception.__struct__, "Setup failed: " <> Exception.message(exception)}
          end

        status =
          cond do
            Decoy.leaks(outcome) != [] -> :leaked
            Runner.same_outcome?(base_outcome, outcome) -> :same
            true -> :changed
          end

        %{status: status, actual: Ash.Conformance.Report.outcome(outcome)}
    end
  end

  defp label(status), do: status |> to_string() |> String.replace("_", " ")

  @doc "`ECOSYSTEM.md`'s decoy section: counts per data layer, then every decoy that showed."
  def markdown(results) do
    ran = Enum.reject(results, & &1.unavailable)

    counts =
      Enum.map_join(ran, "\n", fn %{adapter: adapter, rows: rows} ->
        frequencies = Enum.frequencies_by(rows, &status/1)
        "| #{adapter.id()} | #{Enum.map_join(@statuses, " | ", &Map.get(frequencies, &1, 0))} |"
      end)

    """
    ## Decoy variant

    Every scenario also runs with a hidden copy of each fixture row stored
    next to the real ones: in a mirror tenant, with colliding local ids, where
    the table is multitenant by attribute, and otherwise with a reserved id a
    read policy hides. The answer must not change, and no decoy may appear in
    it (`Ash.Conformance.Decoy`). Data layers without the decoy resource set
    are not run. Scenarios whose answer rightly changes, such as reads across
    tenants or plain relationship filters, which policies don't authorize,
    opt out.

    | Data layer | #{Enum.map_join(@statuses, " | ", &(&1 |> label() |> String.capitalize()))} |
    | --- | #{Enum.map_join(@statuses, " | ", fn _ -> "---:" end)} |
    #{counts}

    #{Enum.map_join(ran, "\n", &shown_section/1)}
    """
  end

  defp shown_section(%{adapter: adapter, rows: rows}) do
    shown = Enum.filter(rows, &(status(&1) in [:leaked, :changed]))

    body =
      if shown == [] do
        "No decoy changed an answer.\n"
      else
        "| Scenario | Decoy | Recorded |\n| --- | --- | --- |\n" <>
          Enum.map_join(shown, "\n", fn row ->
            "| `#{row.scenario}` | #{label(status(row))} | #{recorded(adapter, row.scenario)} |"
          end) <> "\n"
      end

    "### #{adapter.label()}\n\n#{body}"
  end

  defp recorded(adapter, id) do
    if Adapter.reviewed?(adapter) do
      case Map.get(adapter.variant_expectations(), {id, :decoy}) do
        {_status, _signature, task} -> gap_link(task)
        :supported -> "supported"
        nil -> "–"
      end
    else
      "unreviewed"
    end
  end

  defp status(row), do: get_in(row, [:decoy, :status]) || :not_run

  @doc "A survey file's decoy section: every decoy that showed, with what was returned."
  def detail(rows) do
    shown = Enum.filter(rows, &(status(&1) in [:leaked, :changed]))
    frequencies = Enum.frequencies_by(rows, &status/1)

    summary =
      Enum.map_join(@statuses, ", ", &"#{Map.get(frequencies, &1, 0)} #{label(&1)}")

    body =
      if shown == [] do
        "No decoy changed an answer."
      else
        Enum.map_join(shown, "\n", fn row ->
          "- `#{row.scenario}` (#{label(status(row))}): `#{one_line(row.decoy.actual)}`; " <>
            "without decoys `#{one_line(row.actual)}`"
        end)
      end

    """
    ## Decoy variant

    #{summary}.

    #{body}
    """
  end

  defp one_line(text) do
    text = text |> String.replace(~r/\s+/, " ") |> String.replace("`", "'")
    if String.length(text) > 240, do: String.slice(text, 0, 240) <> "…", else: text
  end

  @doc "`FEATURES.md`'s decoy section, from the reviewed adapters' variant records."
  def declared(adapters) do
    sections =
      Enum.map_join(adapters, "\n", fn adapter ->
        scenarios = Catalog.for_adapter(adapter)
        runs = Enum.count(scenarios, &(Variant.applies?(&1, :decoy) == true))

        variants = adapter.variant_expectations()

        # Records the filter-policy variant shares are about authorization
        # itself, not about what the decoys hide.
        {shared, own} =
          for({{id, :decoy}, record} <- variants, record != :supported, do: {id, record})
          |> Enum.sort()
          |> Enum.split_with(fn {id, record} ->
            Map.get(variants, {id, :filter_policy}) == record
          end)

        rows =
          Enum.map_join(own, "\n", fn {id, {status, _signature, task}} ->
            "| `#{id}` | #{label(status)} | #{gap_link(task)} |"
          end)

        table =
          if rows == "",
            do: "Every scenario's answer is unchanged.",
            else: "| Scenario | Status | Gap |\n| --- | --- | --- |\n" <> rows

        shared_gaps =
          shared
          |> Enum.map(fn {_id, {_status, _signature, task}} -> gap_link(task) end)
          |> Enum.uniq()
          |> Enum.join(", ")

        shared_line =
          if shared == [],
            do: "",
            else:
              "\n#{length(shared)} more scenarios behave differently under every " <>
                "authorization variant, decoys included: #{shared_gaps}.\n"

        """
        ### #{adapter.label()}

        #{runs} of #{length(scenarios)} scenarios run with decoys. These behave
        differently with decoys than without:

        #{table}
        #{shared_line}
        """
      end)

    """
    ## Decoy variant

    Each scenario also runs with hidden decoy rows next to its fixture
    (`Ash.Conformance.Decoy`), and must give the same answer with no decoy in
    it. A reviewed data layer records where it doesn't, linked to a gap like
    any other record.

    #{sections}
    """
  end

  defp gap_link(task) do
    id = Gaps.id(task)
    "[#{Gaps.fetch!(id).title}](GAPS.md##{id})"
  end
end
