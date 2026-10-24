# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.DecoyReportTest do
  use ExUnit.Case, async: true
  alias Ash.Conformance.{Adapter, Contracts.Gaps, Report.DecoyReport, Scenario}

  defp scenario(expected), do: %Scenario{id: "x", area: :x, expected: expected, run: & &1}

  describe "classification" do
    test "a decoy in the outcome leaks, whatever the scenario's own run did" do
      assert %{status: :leaked} =
               DecoyReport.classify(scenario([1]), {:ok, [1]}, {:ok, [1, 880_000_011]})

      assert %{status: :leaked} =
               DecoyReport.classify(
                 scenario([1]),
                 {:ok, [2]},
                 {:error, RuntimeError, "row 880000011"}
               )
    end

    test "a right answer that changes with decoys is influenced, with a hint" do
      assert %{status: :influenced, hint: :counts_hidden, diff: "1: 4 → 8, 2: 1 → 2"} =
               DecoyReport.classify(
                 scenario(%{1 => 4, 2 => 1, 3 => 0}),
                 {:ok, %{1 => 4, 2 => 1, 3 => 0}},
                 {:ok, %{1 => 8, 2 => 2, 3 => 0}}
               )

      assert %{status: :influenced, hint: :took_slots, diff: "1: 9 → nil"} =
               DecoyReport.classify(
                 scenario(%{1 => 9, 2 => 4}),
                 {:ok, %{1 => 9, 2 => 4}},
                 {:ok, %{1 => nil, 2 => 4}}
               )

      assert %{status: :influenced, hint: nil} =
               DecoyReport.classify(scenario({1, 2}), {:ok, {1, 2}}, {:ok, {2, 1}})
    end

    test "a right answer that raises with decoys needs triage" do
      assert %{status: :decoy_error, error: "RuntimeError: no such relationship X.ys"} =
               DecoyReport.classify(
                 scenario([1]),
                 {:ok, [1]},
                 {:error, RuntimeError,
                  "\nUnknown Error\n\n* no such relationship X.ys\n  query: ..."}
               )
    end

    test "a failing scenario's difference is not a decoy signal" do
      assert %{status: :base_failing} =
               DecoyReport.classify(scenario([1]), {:ok, [2]}, {:ok, [3]})

      assert %{status: :base_failing} =
               DecoyReport.classify(scenario([1]), {:error, KeyError, "a"}, {:ok, [1]})
    end

    test "the same error with different SQL, parameters or ids is the same" do
      base = {:error, Ash.Error.Unknown, "\nBread Crumbs:\n  > in A\n\n* ERROR 1 bad\n SELECT $1"}

      decoy =
        {:error, Ash.Error.Unknown, "\nBread Crumbs:\n  > in B\n\n* ERROR 2 bad\n SELECT $9"}

      assert %{status: :same} = DecoyReport.classify(scenario([1]), base, decoy)

      other = {:error, ArgumentError, "\n* ERROR 2 bad"}
      assert %{status: :base_failing} = DecoyReport.classify(scenario([1]), base, other)
    end

    test "the same error in every seed order is that error, whatever follows its first line" do
      error = fn trace -> {:error, ArgumentError, "\n* bad input\n  #{trace}"} end
      decoy = {:order_dependent, %{forward: error.("a.ex:1"), reverse: error.("b.ex:2")}}

      assert %{status: :same} =
               DecoyReport.classify(
                 scenario({:error, ArgumentError, ~r/bad input/}),
                 error.("c.ex:3"),
                 decoy
               )
    end

    test "a diff shows only what differs, by map key and tuple position" do
      assert DecoyReport.diff({:ok, {%{1 => [1, 3]}, 5}}, {:ok, {%{1 => [1, 2, 3]}, 5}}) ==
               "#0 1: [1, 3] → [1, 2, 3]"
    end
  end

  describe "the verdict" do
    test "counts issues, unrecorded ones and triage, and calls the rest clean" do
      rows = [
        %{id: "a", status: :influenced, task: "GAPS.md#authorization-bounds"},
        %{id: "b", status: :leaked, task: nil},
        %{id: "c", status: :decoy_error, task: nil},
        %{id: "d", status: :same, task: nil},
        %{id: "e", status: :base_failing, task: nil}
      ]

      assert DecoyReport.verdict(rows, true) ==
               "**2 issues** (1 leaked, 1 influenced; 1 unrecorded) · 1 need triage " <>
                 "(1 unrecorded) · the rest clean: 1 same, 1 base failing, 0 opted out, 0 not run."

      assert length(DecoyReport.unrecorded(rows)) == 2
    end
  end

  # Every leaked, influenced or decoy-error row of a reviewed data layer has
  # a recorded gap. The variant tests make this hold for what actually runs:
  # a decoy run that differs from the scenario's own record without a decoy
  # record fails (`Runner.execute_variant!/3`). This checks the records
  # themselves: none is left unrecorded, and each links a known gap.
  for adapter <- Adapter.all() do
    test "#{adapter.id()} leaves no decoy issue unrecorded" do
      rows = DecoyReport.declared_rows(unquote(adapter))
      assert DecoyReport.unrecorded(rows) == []

      for %{status: status, task: task} <- rows, status in [:leaked, :influenced, :decoy_error] do
        assert Gaps.id(task) in Gaps.ids()
      end
    end
  end
end
