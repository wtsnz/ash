# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Blockers do
  @moduledoc """
  What stops a scenario from working: a prerequisite that demonstrably
  fails.

  A scenario that ran has the prerequisites it declares with `requires:`. A
  scenario that could not run, because a fixture row could not be stored,
  has the tier-1 storage cells of that row's types
  (`Ash.Conformance.Fixtures.SetupError`). A scenario that does not work is
  blocked by each failing prerequisite; where that prerequisite is itself
  blocked, by its blockers instead, so reports name the root cause.

  A label is an explanation, not a verdict: the scenario keeps its
  classification, and a scenario that works is never labelled. Only a
  demonstrated failure blocks:

  - A declared storage cell blocks when storing or reading its value back
    loses or rejects it. A failure only when updating or clearing it does
    not, since scenarios read what their fixtures stored. A different
    representation (≈) does not block. Neither does a table that could not
    be created: that shows the migration generator's gap, not whether the
    fixture's own table stores the type.
  - A storage cell explains a setup failure only when storing or reading
    its type raised. A setup failure is an exception, which a lost value
    does not cause. Where the row went into the tier-1 table itself (tier
    2), a table tier 1 could not create explains it too.
  - Any other prerequisite blocks when it ran and does not work. One that
    could not run blocks only through its own blockers, and an open
    question never blocks.
  """

  @doc """
  Adds `blocked_by` to each of one data layer's rows: the sorted root
  blockers, or `[]`. `requires` maps scenario IDs to their declared
  prerequisites.
  """
  def label(rows, requires) do
    by_id = Map.new(rows, &{&1.scenario, &1})

    Enum.map(rows, fn row ->
      blocked =
        if working?(row),
          do: [],
          else: row |> prerequisites(requires) |> roots(by_id, requires, [])

      Map.put(row, :blocked_by, blocked)
    end)
  end

  # Prerequisites are `{id, why}`: `:setup` for a stored row's cells,
  # `:own_table` when that row went into the tier-1 table, `:declared` for
  # `requires:`.
  defp roots(prerequisites, by_id, requires, seen) do
    prerequisites
    |> Enum.flat_map(fn {id, why} ->
      row = Map.get(by_id, id)

      cond do
        # Not hosted on this data layer, or already visited on this path.
        is_nil(row) or id in seen -> []
        storage?(row) -> if storage_blocks?(row, why), do: [id], else: []
        working?(row) -> []
        true -> deeper(row, id, by_id, requires, seen)
      end
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp deeper(row, id, by_id, requires, seen) do
    case {roots(prerequisites(row, requires), by_id, requires, [id | seen]), row.classification} do
      {[], :setup_failed} -> []
      {[], _classification} -> [id]
      {roots, _classification} -> roots
    end
  end

  defp prerequisites(%{classification: :setup_failed} = row, _requires) do
    case Map.get(row, :setup) do
      %{cells: cells, own_table: true} -> Enum.map(cells, &{&1, :own_table})
      %{cells: cells} -> Enum.map(cells, &{&1, :setup})
      _ -> []
    end
  end

  defp prerequisites(row, requires),
    do: requires |> Map.get(row.scenario, []) |> Enum.map(&{&1, :declared})

  defp working?(row), do: row.classification in [:works, :open_question]
  defp storage?(row), do: String.starts_with?(row.scenario, "storage.")

  defp storage_blocks?(row, why) do
    case {Map.get(row, :detail), why} do
      {%{result: "error", step: step}, why} when why in [:setup, :own_table] ->
        step in ["create", "read", "run"]

      {%{result: "no_table"}, :own_table} ->
        true

      {%{result: result, step: step}, :declared} ->
        result in ["lost", "error"] and step in ["create", "read", "run"]

      _ ->
        false
    end
  end

  @doc """
  Each root blocker, most first, with how many scenarios it stops from
  running, how many failures it may explain, and how many of those it is the
  only blocker of: fixing it alone would let them run or pass, as far as
  the suite knows. A scenario with several blockers counts under each.
  """
  def ranking(rows) do
    rows
    |> Enum.flat_map(fn row ->
      blockers = Map.get(row, :blocked_by, [])

      for blocker <- blockers,
          do: {blocker, {row.classification == :setup_failed, blockers == [blocker]}}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {blocker, flags} ->
      %{
        blocker: blocker,
        not_run: Enum.count(flags, &elem(&1, 0)),
        failing: Enum.count(flags, &(!elem(&1, 0))),
        only: Enum.count(flags, &elem(&1, 1))
      }
    end)
    |> Enum.sort_by(&{-(&1.not_run + &1.failing), -&1.only, &1.blocker})
  end

  @doc "Setup failures no storage cell explains, grouped by role and reason."
  def unexplained(rows) do
    for %{classification: :setup_failed} = row <- rows, Map.get(row, :blocked_by, []) == [] do
      setup = Map.get(row, :setup) || %{role: nil, reason: row.actual}
      {setup.role, setup.reason}
    end
    |> Enum.frequencies()
    |> Enum.sort_by(fn {key, count} -> {-count, key} end)
  end

  @doc "One data layer's blockers, as a markdown section body."
  def markdown(rows) do
    by_id = Map.new(rows, &{&1.scenario, &1})

    ranked =
      case ranking(rows) do
        [] ->
          "No failure has a failing prerequisite."

        ranking ->
          body =
            Enum.map_join(ranking, "\n", fn entry ->
              "| `#{entry.blocker}` | #{result(Map.fetch!(by_id, entry.blocker))} | #{entry.not_run} | #{entry.failing} | #{entry.only} |"
            end)

          "| Blocker | Its result | Not run | Failing | Only blocker of |\n| --- | --- | ---: | ---: | ---: |\n" <>
            body
      end

    unexplained =
      case unexplained(rows) do
        [] ->
          ""

        groups ->
          body =
            Enum.map_join(groups, "\n", fn {{role, reason}, count} ->
              role = if role, do: "`#{role}`", else: "—"
              "| #{count} | #{role} | #{escape(reason)} |"
            end)

          """

          Setup failures that no storage cell explains: no type in the row
          raised when stored on its own, or tier 1 could not test it.

          | Scenarios | Role | Reason |
          | ---: | --- | --- |
          #{body}
          """
      end

    ranked <> "\n" <> unexplained
  end

  defp result(%{scenario: "storage." <> _, detail: %{result: result} = detail}),
    do: "#{result}#{if detail.step, do: " at #{detail.step}"}: #{escape(detail.note)}"

  defp result(%{classification: classification}),
    do: classification |> to_string() |> String.replace("_", " ")

  defp escape(nil), do: ""

  defp escape(text),
    do: text |> String.replace("|", "\\|") |> String.replace("\n", " ") |> String.slice(0, 160)
end
