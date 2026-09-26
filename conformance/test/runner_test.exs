# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.RunnerTest do
  use ExUnit.Case, async: true
  alias Ash.Conformance.{Runner, Scenario}
  require Scenario

  defp scenario, do: Scenario.new("example", :runner, 7, fn _ -> 7 end)

  test "supported scenarios must return the shared expected value" do
    assert Runner.assert_outcome!(scenario(), :supported, {:ok, 7})

    assert_raise ExUnit.AssertionError, ~r/expected 7, got 8/, fn ->
      Runner.assert_outcome!(scenario(), :supported, {:ok, 8})
    end
  end

  test "supported exceptions fail instead of becoming skips" do
    assert_raise ExUnit.AssertionError, ~r/raised ArgumentError/, fn ->
      Runner.assert_outcome!(scenario(), :supported, {:error, ArgumentError, "broken"})
    end
  end

  test "unsupported errors require both the exception class and message" do
    status = {:unsupported, {:error, ArgumentError, ~r/^feature unavailable$/}, "GAPS.md#example"}

    assert Runner.assert_outcome!(
             scenario(),
             status,
             {:error, ArgumentError, "feature unavailable"}
           )

    for outcome <- [
          {:error, RuntimeError, "feature unavailable"},
          {:error, ArgumentError, "database offline"}
        ] do
      assert_raise ExUnit.AssertionError, ~r/signature changed/, fn ->
        Runner.assert_outcome!(scenario(), status, outcome)
      end
    end
  end

  test "unexpected passes require promotion" do
    for status <- [:unsupported, :known_defect] do
      assert_raise ExUnit.AssertionError, ~r/unexpected pass/, fn ->
        Runner.assert_outcome!(scenario(), {status, {:value, 6}, "GAPS.md#example"}, {:ok, 7})
      end
    end
  end

  test "known wrong results cannot mask a different wrong result or exception" do
    status = {:known_defect, {:value, 6}, "GAPS.md#example"}
    assert Runner.assert_outcome!(scenario(), status, {:ok, 6})

    for outcome <- [{:ok, 5}, {:error, ArgumentError, "broken"}] do
      assert_raise ExUnit.AssertionError, ~r/signature changed/, fn ->
        Runner.assert_outcome!(scenario(), status, outcome)
      end
    end
  end

  test "unresolved semantics preserve a strict observation and a decision link" do
    status = {:unresolved, {:value, [1, 2]}, "GAPS.md#semantics"}
    assert Runner.assert_outcome!(%{scenario() | expected: :unresolved}, status, {:ok, [1, 2]})

    assert_raise ExUnit.AssertionError, ~r/signature changed/, fn ->
      Runner.assert_outcome!(%{scenario() | expected: :unresolved}, status, {:ok, [2, 1]})
    end
  end

  test "all nonconforming statuses require a task or decision" do
    assert_raise ExUnit.AssertionError, ~r/link/, fn ->
      Runner.assert_outcome!(scenario(), {:known_defect, {:value, 6}, ""}, {:ok, 6})
    end
  end

  test "operation errors are captured without catching exits" do
    assert {:error, ArgumentError, "bad input"} =
             Runner.capture(fn -> raise ArgumentError, "bad input" end)

    assert catch_exit(Runner.capture(fn -> exit(:database_down) end)) == :database_down
  end

  test "observed results are recorded before a failed assertion" do
    record = fn result -> send(self(), {:recorded, result}) end
    failing = %{scenario() | run: fn _ -> 8 end}

    assert_raise ExUnit.AssertionError, ~r/expected 7, got 8/, fn ->
      Runner.run!(failing, :supported, %{}, record)
    end

    assert_received {:recorded, {:ok, 8}}
  end

  test "reporting failures cannot become accepted operation errors" do
    record = fn _ -> raise ArgumentError, "report unavailable" end

    expectation =
      {:known_defect, {:error, ArgumentError, ~r/report unavailable/}, "GAPS.md#example"}

    assert_raise ArgumentError, "report unavailable", fn ->
      Runner.run!(scenario(), expectation, %{}, record)
    end
  end

  defmodule SetupAdapter do
    @moduledoc false
    def id, do: :setup_adapter
    def checkout!, do: :ok
    def checkin!, do: :ok
    def instrumentation, do: nil
    def resource(role), do: Ash.Conformance.Ets.resource(role)
    def persist!(_role, _rows, _opts), do: raise("cannot store this")
  end

  test "a not-run record needs the fixture to fail with its reason, and nothing else" do
    record = fn result -> send(self(), {:recorded, result}) end
    not_run = Ash.Conformance.Contracts.Records.not_run(~r/cannot store this/, "example")
    stores = %{scenario() | fixture: :empty}
    fails = %{scenario() | fixture: :records}

    assert Runner.execute_expectation!(fails, SetupAdapter, not_run, record, record)
    assert_received {:recorded, {:error, Ash.Conformance.Fixtures.SetupError, _message}}

    # A fixture that starts storing is a change to review, not a pass.
    assert_raise ExUnit.AssertionError, ~r/the fixture now stores/, fn ->
      Runner.execute_expectation!(stores, SetupAdapter, not_run, record, record)
    end

    other = Ash.Conformance.Contracts.Records.not_run(~r/another reason/, "example")

    assert_raise ExUnit.AssertionError, ~r/setup failure changed/, fn ->
      Runner.execute_expectation!(fails, SetupAdapter, other, record, record)
    end
  end

  defmodule CountingInstrumentation do
    def measure(_adapter, operation), do: {operation.(), %{query_count: 2}}
  end

  defmodule InstrumentedAdapter do
    def instrumentation, do: CountingInstrumentation
  end

  defmodule UninstrumentedAdapter do
    def instrumentation, do: nil
  end

  test "fallback evidence is recorded separately and never changes the verdict" do
    record = fn evidence -> send(self(), {:fallback, evidence}) end
    probed = %{scenario() | fallback: "Ash evaluates in memory"}

    observe = Runner.observer(probed, InstrumentedAdapter, record)
    assert Runner.run!(probed, :supported, %{}, fn _ -> :ok end, observe)

    assert_received {:fallback,
                     %{probe: "Ash evaluates in memory", query_count: 2, observed: false}}

    observe = Runner.observer(probed, UninstrumentedAdapter, record)
    assert Runner.run!(probed, :supported, %{}, fn _ -> :ok end, observe)
    assert_received {:fallback, %{observed: :unavailable}}
  end

  test "scenarios without a fallback probe are not instrumented" do
    observe = Runner.observer(scenario(), InstrumentedAdapter, fn _ -> flunk("recorded") end)
    assert Runner.run!(scenario(), :supported, %{}, fn _ -> :ok end, observe)
  end

  test "zero data-layer queries is the only positive fallback observation" do
    assert %{observed: true} = Runner.fallback_evidence("probe", 0)
    assert %{observed: false} = Runner.fallback_evidence("probe", 1)
  end

  describe "strict comparison" do
    alias Ash.Conformance.Compare

    test "integers and floats are different results" do
      refute Compare.equal?(2, 2.0)
      refute Compare.equal?(%{1 => 2}, %{1 => 2.0})
      refute Compare.equal?([2, 2, 7], [2.0, 2.0, 7.0])
      assert Compare.equal?(%{1 => [2, {3, "a"}]}, %{1 => [2, {3, "a"}]})
    end

    test "structs compare every field, including precision" do
      refute Compare.equal?(Decimal.new("0.3"), Decimal.new("0.30"))
      refute Compare.equal?(~U[2024-01-01 00:00:00Z], ~U[2024-01-01 00:00:00.000000Z])
      assert Compare.equal?(~D[2024-01-01], ~D[2024-01-01])
    end

    test "a supported scenario fails when only the numeric type changed" do
      assert_raise ExUnit.AssertionError, ~r/expected 7, got 7.0/, fn ->
        Runner.assert_outcome!(scenario(), :supported, {:ok, 7.0})
      end
    end
  end

  describe "seed order" do
    test "matching outcomes in every order combine to one outcome" do
      assert Runner.combine(forward: {:ok, 7}, reverse: {:ok, 7}, rotated: {:ok, 7}) == {:ok, 7}
    end

    test "an order-dependent outcome never passes, even when one order is right" do
      outcome = Runner.combine(forward: {:ok, 7}, reverse: {:ok, 7}, rotated: {:ok, 4})
      assert {:order_dependent, %{rotated: {:ok, 4}}} = outcome

      assert_raise ExUnit.AssertionError, ~r/depends on row order/, fn ->
        Runner.assert_outcome!(scenario(), :supported, outcome)
      end
    end

    test "an order-dependent defect must match every order" do
      signature =
        {:order_dependent, %{forward: {:value, 7}, reverse: {:value, 7}, rotated: {:value, 4}}}

      status = {:known_defect, signature, "GAPS.md#example"}
      outcome = {:order_dependent, %{forward: {:ok, 7}, reverse: {:ok, 7}, rotated: {:ok, 4}}}
      assert Runner.assert_outcome!(scenario(), status, outcome)

      changed = {:order_dependent, %{forward: {:ok, 7}, reverse: {:ok, 5}, rotated: {:ok, 4}}}

      assert_raise ExUnit.AssertionError, ~r/signature changed/, fn ->
        Runner.assert_outcome!(scenario(), status, changed)
      end

      assert_raise ExUnit.AssertionError, ~r/signature changed/, fn ->
        Runner.assert_outcome!(scenario(), status, {:ok, 5})
      end
    end

    test "rotation starts from the middle so it differs from both ends" do
      Process.put({Ash.Conformance.Fixtures, :order}, :rotated)
      assert Ash.Conformance.Fixtures.ordered([1, 2, 3, 4, 5]) == [3, 4, 5, 1, 2]
    after
      Process.delete({Ash.Conformance.Fixtures, :order})
    end
  end
end
