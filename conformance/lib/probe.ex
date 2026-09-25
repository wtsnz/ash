# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Probe do
  @moduledoc "Observe one case during adapter bring-up; never assign or accept an expectation."
  alias Ash.Conformance.{Capabilities, Fixtures, Report, Runner}

  def run(scenario, adapter) do
    :ok = adapter.checkout!()

    try do
      context = Fixtures.build!(adapter, scenario.fixture)
      Fixtures.prepare!(context, scenario.id)
      parent = self()
      observe = Runner.observer(scenario, adapter, &send(parent, {:fallback, &1}))
      outcome = observe.(fn -> Runner.capture(fn -> scenario.run.(context) end) end)

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
    after
      adapter.checkin!()
    end
  end

  def observation(scenario, outcome) do
    %{
      scenario: scenario.id,
      semantic_basis: scenario.semantic_basis,
      fixture: scenario.fixture,
      profile: scenario.profile,
      classification: :unreviewed,
      semantic_pass: false,
      intended: inspect(scenario.expected, limit: :infinity),
      observation: Report.observation(outcome),
      fallback: :unobserved,
      next_step:
        "Investigate against the semantic source; add an explicit expectation or decision after review. No expectation was written."
    }
  end
end
