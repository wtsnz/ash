# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Runner do
  @moduledoc """
  Checks conformance or an explicitly recorded gap.

  Only the operation is captured. Database setup and fixture construction happen
  outside this boundary. Rejections require an exception class and message
  pattern; wrong-result defects require the exact observed value. An unexpected
  pass is a failure until the adapter's expectation is promoted.
  """
  import ExUnit.Assertions

  @orders [:forward, :reverse, :rotated]

  @doc """
  Runs a scenario three times, with its fixtures seeded forward, in reverse and
  rotated to start from the middle, and asserts the combined outcome against
  the adapter's expectation.

  Seeding order changes the physical row order on some data layers. A result
  that relies on unspecified order therefore differs between the runs and is
  recorded as `{:order_dependent, %{forward: ..., reverse: ..., rotated: ...}}`,
  which can never pass. Two orders are not enough: a query that takes the first
  rows unsorted can return the intended answer from both ends of the data.
  """
  def execute!(
        scenario,
        adapter,
        record_result \\ fn _ -> :ok end,
        record_fallback \\ fn _ -> :ok end
      ) do
    expectation = Ash.Conformance.Contracts.Expectations.for(scenario.id, adapter.id())
    outcome = observe_both_orders(scenario, adapter, record_fallback)
    record_result.(outcome)
    assert_outcome!(scenario, expectation, outcome)
  end

  def orders, do: @orders

  def observe_both_orders(scenario, adapter, record_fallback \\ fn _ -> :ok end) do
    @orders
    |> Enum.map(fn order ->
      observe =
        if order == :forward, do: observer(scenario, adapter, record_fallback), else: & &1.()

      {order, observe_once(scenario, adapter, order, observe)}
    end)
    |> combine()
  end

  defp observe_once(scenario, adapter, order, observe) do
    :ok = adapter.checkout!()

    try do
      context = Ash.Conformance.Fixtures.build!(adapter, scenario.fixture, order)
      Ash.Conformance.Fixtures.prepare!(context, scenario.id)
      observe.(fn -> capture(fn -> scenario.run.(context) end) end)
    after
      adapter.checkin!()
    end
  end

  def combine([{_, first} | rest] = outcomes) do
    if Enum.all?(rest, fn {_, outcome} -> same_outcome?(first, outcome) end),
      do: first,
      else: {:order_dependent, Map.new(outcomes)}
  end

  defp same_outcome?({:ok, left}, {:ok, right}), do: Ash.Conformance.Compare.equal?(left, right)

  defp same_outcome?({:error, exception, left}, {:error, exception, right}),
    do:
      Ash.Conformance.Report.outcome({:error, exception, left}) ==
        Ash.Conformance.Report.outcome({:error, exception, right})

  defp same_outcome?(_, _), do: false

  def run_with_setup!(
        scenario,
        expectation,
        setup,
        record_result \\ fn _ -> :ok end,
        observe \\ & &1.()
      ) do
    context = setup.()
    run!(scenario, expectation, context, record_result, observe)
  end

  def run!(scenario, expectation, context, record_result \\ fn _ -> :ok end, observe \\ & &1.()) do
    outcome = observe.(fn -> capture(fn -> scenario.run.(context) end) end)
    record_result.(outcome)
    assert_outcome!(scenario, expectation, outcome)
  end

  @doc """
  Wraps only the operation when a scenario names an Ash fallback to observe.

  The evidence is the number of data-layer queries the operation issued. It is
  recorded beside the result and never changes whether the scenario passes.
  """
  def observer(%{fallback: nil}, _adapter, _record), do: & &1.()

  def observer(%{fallback: fallback}, adapter, record) do
    case adapter.instrumentation() do
      nil ->
        fn operation ->
          record.(%{probe: fallback, observed: :unavailable})
          operation.()
        end

      # Evidence is only meaningful when the operation succeeded.
      instrumentation ->
        fn operation ->
          {outcome, measurements} = instrumentation.measure(adapter, operation)

          if match?({:ok, _}, outcome),
            do: record.(fallback_evidence(fallback, measurements.query_count))

          outcome
        end
    end
  end

  def fallback_evidence(probe, query_count),
    do: %{
      probe: probe,
      query_count: query_count,
      observed: query_count == 0,
      rule: "Ash handled the operation without any data-layer query"
    }

  def assert_outcome!(
        %{expected: {:error, exception, pattern}} = scenario,
        :supported,
        {:error, exception, message}
      ) do
    assert Regex.match?(pattern, message),
           "#{scenario.id}: rejection signature changed: #{message}"
  end

  def assert_outcome!(scenario, :supported, {:order_dependent, _} = outcome) do
    flunk("#{scenario.id}: result depends on row order: #{format(outcome)}")
  end

  def assert_outcome!(scenario, :supported, {:ok, actual}) do
    assert Ash.Conformance.Compare.equal?(actual, scenario.expected),
           "#{scenario.id}: expected #{format(scenario.expected)}, got #{format(actual)}"
  end

  def assert_outcome!(scenario, :supported, {:error, exception, message}) do
    flunk(
      "#{scenario.id}: expected #{format(scenario.expected)}, raised #{inspect(exception)}: #{message}"
    )
  end

  def assert_outcome!(scenario, {status, signature, task}, outcome)
      when status in [:unsupported, :known_defect, :unresolved] do
    assert is_binary(task) and byte_size(task) > 0,
           "A gap must link to an implementation task or decision"

    if status != :unresolved and passes?(scenario, outcome) do
      flunk(
        "#{scenario.id}: unexpected pass; promote this #{status} expectation to :supported (#{task})"
      )
    end

    assert matches?(signature, outcome),
           "#{scenario.id}: #{status} signature changed (#{task})\n" <>
             "Expected: #{format(signature)}\nObserved: #{format(outcome)}"
  end

  def capture(fun) do
    {:ok, fun.()}
  rescue
    exception -> {:error, exception.__struct__, Exception.message(exception)}
  end

  defp passes?(scenario, outcome), do: semantic_pass?(scenario, outcome)

  @doc """
  Whether an outcome is the scenario's intended answer, including an intended
  rejection. Used by the strict runner and by unreviewed surveys.
  """
  def semantic_pass?(%{expected: :unresolved}, _outcome), do: false

  def semantic_pass?(%{expected: {:error, exception, pattern}}, {:error, exception, message}),
    do: Regex.match?(pattern, message)

  def semantic_pass?(scenario, {:ok, actual}),
    do: Ash.Conformance.Compare.equal?(actual, scenario.expected)

  def semantic_pass?(_scenario, _outcome), do: false

  defp matches?({:value, expected}, {:ok, actual}),
    do: Ash.Conformance.Compare.equal?(expected, actual)

  defp matches?({:order_dependent, signatures}, {:order_dependent, outcomes}),
    do:
      Enum.sort(Map.keys(signatures)) == Enum.sort(Map.keys(outcomes)) and
        Enum.all?(signatures, fn {order, signature} ->
          matches?(signature, Map.fetch!(outcomes, order))
        end)

  defp matches?({:error, exception, pattern}, {:error, exception, message}),
    do: Regex.match?(pattern, message)

  defp matches?(_, _), do: false
  defp format(value), do: inspect(value, charlists: :as_lists, custom_options: [sort_maps: true])
end
