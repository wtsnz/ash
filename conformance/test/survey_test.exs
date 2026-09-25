# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SurveyTest do
  use ExUnit.Case, async: true
  alias Ash.Conformance.{Scenario, Survey}
  require Scenario

  defp scenario(expected), do: Scenario.new("example", :survey, expected, fn _ -> nil end)

  test "the intended answer works, in every seed order" do
    assert Survey.classify(scenario(7), {:ok, 7}) == {:works, :supported}

    order_dependent =
      {:order_dependent, %{forward: {:ok, 7}, reverse: {:ok, 7}, rotated: {:ok, 4}}}

    assert Survey.classify(scenario(7), order_dependent) == {:wrong, :known_defect}
  end

  test "an Ash error saying the feature is unsupported is a rejection" do
    outcome = {:error, Ash.Error.Invalid, "Data layer does not support using query aggregates"}
    assert Survey.classify(scenario(7), outcome) == {:rejected, :unsupported}
  end

  test "an exception from inside the data layer is a crash, even if wrapped by Ash" do
    outcome =
      {:error, Ash.Error.Unknown, "* ** (KeyError) key :sort not found (does not support)"}

    assert Survey.classify(scenario(7), outcome) == {:crashed, :known_defect}

    assert Survey.classify(scenario(7), {:error, RuntimeError, "boom"}) ==
             {:crashed, :known_defect}
  end

  test "a different value is a wrong answer, including a changed numeric type" do
    assert Survey.classify(scenario(7), {:ok, 8}) == {:wrong, :known_defect}
    assert Survey.classify(scenario(7), {:ok, 7.0}) == {:wrong, :known_defect}
  end

  test "an intended rejection works; an unresolved scenario is an open question" do
    rejection = scenario({:error, Ash.Error.Invalid, ~r/not found/})

    assert Survey.classify(rejection, {:error, Ash.Error.Invalid, "record not found"}) ==
             {:works, :supported}

    assert Survey.classify(scenario(:unresolved), {:ok, 1}) == {:open_question, :unresolved}
  end

  test "the committed ETS survey report is current" do
    assert File.read!("surveys/features-ets.md") ==
             Survey.markdown(Ash.Conformance.Ets, Survey.run(Ash.Conformance.Ets)),
           "Run MIX_ENV=test mix conformance.survey ets --output surveys"
  end
end
