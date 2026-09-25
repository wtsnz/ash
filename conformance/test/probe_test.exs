# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.ProbeTest do
  use ExUnit.Case, async: true
  alias Ash.Conformance.{Probe, Scenario}
  require Scenario

  test "correct, incorrect and rejected probes remain unreviewed observations" do
    scenario = Scenario.new("candidate", :probe, 7, fn _ -> 7 end)

    for outcome <- [{:ok, 7}, {:ok, 8}, {:error, ArgumentError, "not implemented"}] do
      report = Probe.observation(scenario, outcome)
      assert report.classification == :unreviewed
      refute report.semantic_pass
      assert report.fallback == :unobserved
      refute Map.has_key?(report, :accepted)
      assert is_binary(report.observation.actual)
    end
  end
end
