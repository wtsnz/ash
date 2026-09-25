# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Probe do
  @moduledoc "Observe one case during adapter bring-up; never assign or accept an expectation."
  alias Ash.Conformance.{Contracts.Capabilities, Report, Runner}

  def run(scenario, adapter) do
    parent = self()
    outcome = Runner.observe_both_orders(scenario, adapter, &send(parent, {:fallback, &1}))

    fallback =
      receive do
        {:fallback, evidence} -> evidence
      after
        0 -> :unobserved
      end

    observation(scenario, outcome)
    |> Map.put(:fallback, fallback)
    |> Map.put(:adapter, adapter.id())
    |> Map.put(:capabilities, Capabilities.for_scenario(adapter, scenario))
  end

  def observation(scenario, outcome) do
    %{
      scenario: scenario.id,
      semantic_basis: scenario.semantic_basis,
      fixture: scenario.fixture,
      profile: scenario.profile,
      classification: :unreviewed,
      semantic_pass: false,
      intended: Report.value(scenario.expected),
      observation: Report.observation(outcome),
      fallback: :unobserved,
      next_step:
        "Investigate against the semantic source; add an explicit expectation or decision after review. No expectation was written."
    }
  end
end
