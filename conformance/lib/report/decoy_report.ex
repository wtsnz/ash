# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Report.DecoyReport do
  @moduledoc """
  The decoy variant (`Ash.Conformance.Variant`, `Ash.Conformance.Decoy`) in
  each report: the recorded contracts in `FEATURES.md`, and the surveyed
  results in `ECOSYSTEM.md` and each `surveys/features-<adapter>.md`.

  Each scenario's decoy run is classified against its intended answer as
  well as its own run:

  - `leaked` (issue): a decoy id, value or marker is in the outcome;
  - `influenced` (issue): the scenario's own run is right, and with decoys
    the answer differs with no decoy in it: a hidden row changed a visible
    answer. A hint says which way, when every difference agrees: higher
    numbers or more rows suggest the answer counts hidden rows; nil, 0 or
    fewer rows suggest hidden rows took a limit or offset slot;
  - `decoy error` (triage): the scenario's own run is right, and with
    decoys it raises;
  - `base failing`: the scenario's own run is already wrong or raises, so a
    difference isn't a decoy signal. Two errors of the same exception, with
    the same first line once numbers are removed, count as `same`;
  - `same`, `opted out` (the scenario declares why its answer rightly
    changes), `not run` (no decoy resource set, or a fixture, decoys
    included, that couldn't be stored).

  Issues and triage rows need a recorded gap: a reviewed data layer's
  `expect_variant/3` record for the decoy variant. The variant tests enforce
  it, as `Ash.Conformance.Runner.execute_variant!/3` fails a decoy run that
  differs from the scenario's own record without one, and
  `test/decoy_report_test.exs` checks the reviewed data layers' records
  leave none unrecorded. So a reviewed data layer's "0 unrecorded" is the
  green signal.
  """
  alias Ash.Conformance.{
    Adapter,
    Catalog,
    Compare,
    Contracts.Gaps,
    Decoy,
    Fixtures,
    Runner,
    Variant
  }

  @issues [:leaked, :influenced]

  # Classification

  @doc "A survey row's decoy result, from the scenario's own outcome."
  def observe(scenario, adapter, base_outcome, setup_failed?) do
    cond do
      not Variant.supported?(adapter, :decoy) ->
        %{status: :not_run, reason: "no decoy resource set"}

      setup_failed? ->
        %{status: :not_run, reason: "the scenario's own fixture could not be stored"}

      (applies = Variant.applies?(scenario, :decoy)) != true ->
        %{status: :opted_out, reason: elem(applies, 1)}

      true ->
        case run(scenario, adapter) do
          {:not_stored, reason} ->
            %{status: :not_run, reason: "decoys could not be stored: " <> reason}

          outcome ->
            scenario
            |> classify(base_outcome, outcome)
            |> Map.put(:actual, Ash.Conformance.Report.outcome(outcome))
        end
    end
  end

  defp run(scenario, adapter) do
    Variant.run(:decoy, fn ->
      scenario |> Runner.observe_both_orders(adapter) |> Variant.normalize()
    end)
  rescue
    error in Fixtures.SetupError -> {:not_stored, error.reason}
  end

  @doc "Classifies a decoy outcome against the scenario and its own outcome."
  def classify(scenario, base, decoy) do
    {base, decoy} = {collapse(base), collapse(decoy)}
    base_right? = Runner.semantic_pass?(scenario, base)

    cond do
      Decoy.leaks(decoy) != [] ->
        %{status: :leaked, diff: diff(base, decoy), hint: nil}

      same?(base, decoy) ->
        %{status: :same}

      base_right? and match?({:error, _, _}, decoy) ->
        %{status: :decoy_error, error: error_line(decoy)}

      base_right? ->
        %{status: :influenced, diff: diff(base, decoy), hint: hint(base, decoy)}

      true ->
        %{status: :base_failing}
    end
  end

  # The same error in every seed order, whose messages differ only past
  # their first line (a stack trace, SQL), is that error.
  defp collapse({:order_dependent, outcomes} = outcome) do
    case outcomes |> Map.values() |> Enum.uniq_by(&error_key/1) do
      [{:error, _, _} = error] -> error
      _ -> outcome
    end
  end

  defp collapse(outcome), do: outcome

  defp same?(base, decoy) do
    Runner.same_outcome?(base, decoy) or
      (match?({:error, _, _}, base) and match?({:error, _, _}, decoy) and
         error_key(base) == error_key(decoy))
  end

  defp error_key({:error, exception, message}), do: {exception, first_line(message)}
  defp error_key(outcome), do: outcome

  defp error_line({:error, exception, message}),
    do: "#{inspect(exception)}: #{first_line(message)}"

  @doc """
  An error's first informative line, without numbers, since the same
  error's SQL, parameters and ids differ between runs.
  """
  def first_line(message) do
    message
    |> String.split("\n")
    |> Enum.map(&(&1 |> String.trim() |> String.trim_leading("* ")))
    |> Enum.reject(
      &(&1 in ["", "Unknown Error", "Invalid Error", "Forbidden Error"] or
          String.starts_with?(&1, ["Bread Crumbs", ">"]))
    )
    |> List.first("")
    |> String.replace(~r/\d+/, "N")
  end

  # Differences

  @doc """
  The parts of two outcomes that differ, as `path: before → after`, where
  map keys and tuple positions (`#0`) make the path.
  """
  def diff({:ok, before}, {:ok, value}) do
    case leaves(before, value, []) do
      [] -> ""
      pairs -> pairs |> Enum.map(&render/1) |> join_capped()
    end
  end

  def diff({:error, _, _} = before, {:error, _, _} = value),
    do: "#{error_line(before)} → #{error_line(value)}"

  def diff(before, {:order_dependent, _}), do: "#{short(before)} → varies by seed order"
  def diff({:order_dependent, _}, value), do: "varies by seed order → #{short(value)}"
  def diff(before, value), do: "#{short(before)} → #{short(value)}"

  defp leaves(a, b, path) do
    cond do
      Compare.equal?(a, b) ->
        []

      plain_map?(a) and plain_map?(b) ->
        (Map.keys(a) ++ Map.keys(b))
        |> Enum.uniq()
        |> Enum.sort()
        |> Enum.flat_map(
          &leaves(Map.get(a, &1, :missing), Map.get(b, &1, :missing), path ++ [inspect(&1)])
        )

      is_tuple(a) and is_tuple(b) and tuple_size(a) == tuple_size(b) ->
        positions(Tuple.to_list(a), Tuple.to_list(b), path, &"##{&1}")

      # Lists of the same length, element by element, unless the elements
      # are plain values, where the list itself is the clearer difference.
      is_list(a) and is_list(b) and length(a) == length(b) and
          Enum.any?(a ++ b, &(is_tuple(&1) or plain_map?(&1))) ->
        positions(a, b, path, &"[#{&1}]")

      true ->
        [{path, a, b}]
    end
  end

  defp plain_map?(value), do: is_map(value) and not is_struct(value)

  defp positions(a, b, path, label) do
    a
    |> Enum.zip(b)
    |> Enum.with_index()
    |> Enum.flat_map(fn {{x, y}, i} -> leaves(x, y, path ++ [label.(i)]) end)
  end

  defp render({[], a, b}), do: "#{short(a)} → #{short(b)}"
  defp render({path, a, b}), do: "#{Enum.join(path, " ")}: #{short(a)} → #{short(b)}"

  defp join_capped(parts) do
    {shown, rest} = Enum.split(parts, 4)
    more = if rest == [], do: "", else: ", and #{length(rest)} more"
    Enum.join(shown, ", ") <> more
  end

  defp short({:ok, value}), do: short(value)
  defp short({:error, _, _} = error), do: error_line(error)

  defp short(value) do
    text = inspect(value, charlists: :as_lists, limit: 8, printable_limit: 60)
    if String.length(text) > 80, do: String.slice(text, 0, 80) <> "…", else: text
  end

  @doc """
  Which way a hidden row moved the answer, when every difference agrees:
  `:counts_hidden` (higher, more, or true where it was false) or
  `:took_slots` (nil, lower, fewer, or false). A hint, not a diagnosis.
  """
  def hint({:ok, before}, {:ok, value}) do
    directions = before |> leaves(value, []) |> Enum.map(fn {_, a, b} -> direction(a, b) end)

    cond do
      directions == [] -> nil
      Enum.all?(directions, &(&1 == :more)) -> :counts_hidden
      Enum.all?(directions, &(&1 == :fewer)) -> :took_slots
      true -> nil
    end
  end

  def hint(_before, _value), do: nil

  defp direction(a, b) when is_number(a) and is_number(b), do: if(b > a, do: :more, else: :fewer)
  defp direction(nil, _b), do: :more
  defp direction(_a, nil), do: :fewer
  defp direction(a, b) when is_list(a) and is_list(b), do: compare_size(length(a), length(b))
  defp direction(false, true), do: :more
  defp direction(true, false), do: :fewer
  defp direction(_a, _b), do: :other

  defp compare_size(a, b) when b > a, do: :more
  defp compare_size(a, b) when b < a, do: :fewer
  defp compare_size(_a, _b), do: :other

  # Rows: from a survey, or from a reviewed data layer's records

  defp task_of({_status, _signature, task}), do: task
  defp task_of(_record), do: nil

  defp surveyed(adapter, rows) do
    reviewed? = Adapter.reviewed?(adapter)
    variants = if reviewed?, do: adapter.variant_expectations(), else: %{}
    own = if reviewed?, do: adapter.expectations(), else: %{}

    for row <- rows do
      decoy = Map.get(row, :decoy) || %{status: :not_run, reason: "not surveyed"}

      Map.merge(decoy, %{
        id: row.scenario,
        task: task_of(Map.get(variants, {row.scenario, :decoy})),
        base_task: task_of(Map.get(own, row.scenario))
      })
    end
  end

  @doc """
  A reviewed data layer's decoy rows from its records alone: a decoy record
  whose scenario's own record is supported is an issue (a value) or needs
  triage (an error); any other difference is the scenario's own gap.
  """
  def declared_rows(adapter) do
    expectations = adapter.expectations()
    variants = adapter.variant_expectations()

    for scenario <- Catalog.for_adapter(adapter) do
      own = Map.get(expectations, scenario.id)
      decoy = Map.get(variants, {scenario.id, :decoy})

      row =
        case {Variant.applies?(scenario, :decoy), own, decoy} do
          {{false, reason}, _, _} -> %{status: :opted_out, reason: reason}
          {true, _, nil} -> %{status: :same}
          {true, :supported, :supported} -> %{status: :same}
          {true, :supported, {_, signature, task}} -> recorded(scenario, signature, task)
          {true, _, _} -> %{status: :base_failing}
        end

      Map.merge(%{id: scenario.id, base_task: task_of(own), task: nil}, row)
    end
  end

  defp recorded(scenario, {:value, value}, task) do
    expected = {:ok, scenario.expected}
    status = if Decoy.leaks(value) == [], do: :influenced, else: :leaked

    %{
      status: status,
      task: task,
      diff: diff(expected, {:ok, value}),
      hint: hint(expected, {:ok, value})
    }
  end

  defp recorded(_scenario, {:error, exception, pattern}, task),
    do: %{
      status: :decoy_error,
      task: task,
      error: "#{inspect(exception)}: ~r/#{Regex.source(pattern)}/"
    }

  defp recorded(scenario, {:order_dependent, _}, task),
    do: %{
      status: :influenced,
      task: task,
      diff: diff({:ok, scenario.expected}, {:order_dependent, %{}}),
      hint: nil
    }

  @doc "Issue and triage rows with no recorded gap."
  def unrecorded(rows),
    do: Enum.filter(rows, &(&1.status in [:decoy_error | @issues] and is_nil(&1.task)))

  # Rendering

  @doc "The one-line verdict for a data layer's rows."
  def verdict(rows, reviewed?) do
    counts = Enum.frequencies_by(rows, & &1.status)
    count = &Map.get(counts, &1, 0)
    issues = Enum.filter(rows, &(&1.status in @issues))
    triage = Enum.filter(rows, &(&1.status == :decoy_error))

    unrecorded = fn rows ->
      if reviewed?,
        do: "#{Enum.count(rows, &is_nil(&1.task))} unrecorded",
        else: "unreviewed"
    end

    issue_part =
      if issues == [],
        do: "**No issues**",
        else:
          "**#{plural(length(issues), "issue")}** (#{count.(:leaked)} leaked, " <>
            "#{count.(:influenced)} influenced; #{unrecorded.(issues)})"

    triage_part =
      if triage == [],
        do: "nothing to triage",
        else: "#{length(triage)} need triage (#{unrecorded.(triage)})"

    "#{issue_part} · #{triage_part} · the rest clean: #{count.(:same)} same, " <>
      "#{count.(:base_failing)} base failing, #{count.(:opted_out)} opted out, " <>
      "#{count.(:not_run)} not run."
  end

  defp plural(1, word), do: "1 #{word}"
  defp plural(n, word), do: "#{n} #{word}s"

  defp section(rows, reviewed?) do
    unrecorded_first = &Enum.sort_by(&1, fn row -> {not is_nil(row.task), row.id} end)
    issues = rows |> Enum.filter(&(&1.status in @issues)) |> unrecorded_first.()

    triage =
      rows
      |> Enum.filter(&(&1.status == :decoy_error))
      |> Enum.sort_by(&{not is_nil(&1.task), &1[:error], &1.id})

    issue_table =
      if issues == [] do
        ""
      else
        "| Scenario | Status | Hint | Diff | Gap |\n| --- | --- | --- | --- | --- |\n" <>
          Enum.map_join(issues, "\n", fn row ->
            "| `#{row.id}` | #{label(row.status)} | #{hint_label(row[:hint])} | " <>
              "#{cell(row[:diff])} | #{gap_cell(row.task, reviewed?)} |"
          end) <> "\n\n"
      end

    triage_table =
      if triage == [] do
        ""
      else
        "Need triage: the scenario's own run is right, and with decoys it raises. " <>
          "Scenarios with the same error and gap share a row.\n\n" <>
          "| Scenario | Error | Gap |\n| --- | --- | --- |\n" <>
          (triage
           |> Enum.chunk_by(&{&1[:error], &1.task})
           |> Enum.map_join("\n", fn [row | rest] ->
             more = if rest == [], do: "", else: " and #{length(rest)} more"

             "| `#{row.id}`#{more} | #{cell(row[:error])} | #{gap_cell(row.task, reviewed?)} |"
           end)) <> "\n\n"
      end

    "#{verdict(rows, reviewed?)}\n\n" <>
      issue_table <> triage_table <> base_failing_line(rows) <> not_run_line(rows)
  end

  defp base_failing_line(rows) do
    failing = Enum.filter(rows, &(&1.status == :base_failing))

    if failing == [] do
      ""
    else
      gaps =
        failing
        |> Enum.map(& &1.base_task)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.sort()
        |> Enum.map_join(", ", &gap_link/1)

      where = if gaps == "", do: "", else: "; their own gaps: #{gaps}"

      verb = if length(failing) == 1, do: "fails", else: "fail"

      "#{plural(length(failing), "scenario")} already #{verb} without decoys, so a " <>
        "difference isn't a decoy signal#{where}.\n\n"
    end
  end

  defp not_run_line(rows) do
    reasons =
      rows
      |> Enum.filter(&(&1.status == :not_run))
      |> Enum.frequencies_by(&Map.get(&1, :reason, "not run"))

    if reasons == %{},
      do: "",
      else:
        "Not run: " <>
          Enum.map_join(reasons, "; ", fn {reason, n} -> "#{n}, #{reason}" end) <> ".\n\n"
  end

  defp label(:decoy_error), do: "decoy error"
  defp label(status), do: to_string(status)

  defp hint_label(:counts_hidden), do: "counts hidden rows?"
  defp hint_label(:took_slots), do: "hidden rows took limit/offset slots?"
  defp hint_label(_hint), do: ""

  defp gap_cell(nil, true), do: "**unrecorded**"
  defp gap_cell(nil, false), do: "unreviewed"
  defp gap_cell(task, _reviewed?), do: gap_link(task)

  defp cell(nil), do: ""
  defp cell(text), do: "`#{text |> String.replace("|", "\\|") |> String.replace("`", "'")}`"

  defp gap_link(task) do
    id = Gaps.id(task)
    "[#{Gaps.fetch!(id).title}](GAPS.md##{id})"
  end

  @intro """
  Every scenario also runs with a hidden copy of each fixture row stored
  next to the real ones: in a mirror tenant, with colliding local ids, where
  the table is multitenant by attribute, and otherwise with a reserved id a
  read policy hides (`Ash.Conformance.Decoy`). An issue is a decoy in the
  answer (leaked), or an answer that was right and changes with decoys
  (influenced); a decoy error needs triage. Each needs a recorded gap. Hints
  are guesses from the direction of the change.
  """

  @doc "`ECOSYSTEM.md`'s decoy section: a verdict and the issues for each data layer."
  def markdown(results) do
    sections =
      results
      |> Enum.reject(& &1.unavailable)
      |> Enum.map_join("\n", fn %{adapter: adapter, rows: rows} ->
        "### #{adapter.label()}\n\n" <>
          section(surveyed(adapter, rows), Adapter.reviewed?(adapter))
      end)

    "## Decoy variant\n\n#{@intro}\n#{sections}"
  end

  @doc "A survey file's decoy section."
  def detail(adapter, rows),
    do:
      "## Decoy variant\n\n#{@intro}\n" <>
        section(surveyed(adapter, rows), Adapter.reviewed?(adapter))

  @doc "`FEATURES.md`'s decoy section, from the reviewed adapters' records."
  def declared(adapters) do
    sections =
      Enum.map_join(adapters, "\n", fn adapter ->
        "### #{adapter.label()}\n\n" <> section(declared_rows(adapter), true)
      end)

    "## Decoy variant\n\n#{@intro}\nFrom the recorded contracts: a diff compares a " <>
      "decoy record with the scenario's intended answer.\n\n#{sections}"
  end
end
