# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenario do
  @moduledoc "A public Ash operation with an adapter-independent expected result."
  @enforce_keys [:id, :area, :expected, :run]
  defstruct [
    :id,
    :area,
    :expected,
    :run,
    :source,
    :description,
    fixture: :aggregate,
    profile: :shared,
    capabilities: [],
    benchmark: false,
    fallback: nil,
    semantic_basis: "../documentation/topics/resources/aggregates.md"
  ]

  defmacro new(id, area, expected, run, opts \\ []) do
    source = %{
      file: Path.relative_to(__CALLER__.file, Path.expand("..", __DIR__)),
      line: __CALLER__.line
    }

    quote do
      %Ash.Conformance.Scenario{
        id: unquote(id),
        area: unquote(area),
        expected: unquote(expected),
        run: unquote(run),
        source: unquote(Macro.escape(source)),
        description: Keyword.get(unquote(opts), :description, unquote(id)),
        fixture: Keyword.get(unquote(opts), :fixture, :aggregate),
        profile: Keyword.get(unquote(opts), :profile, :shared),
        capabilities: Keyword.get(unquote(opts), :capabilities, []),
        benchmark: Keyword.get(unquote(opts), :benchmark, false),
        fallback: Keyword.get(unquote(opts), :fallback),
        semantic_basis:
          Keyword.get(
            unquote(opts),
            :semantic_basis,
            "../documentation/topics/resources/aggregates.md"
          )
      }
    end
  end
end

defmodule Ash.Conformance.Runner do
  @moduledoc """
  Checks conformance or an explicitly recorded gap.

  Only the operation is captured. Database setup and fixture construction happen
  outside this boundary. Rejections require an exception class and message
  pattern; wrong-result defects require the exact observed value. An unexpected
  pass is a failure until the adapter's expectation is promoted.
  """
  import ExUnit.Assertions

  def execute!(
        scenario,
        adapter,
        record_result \\ fn _ -> :ok end,
        record_fallback \\ fn _ -> :ok end
      ) do
    expectation = Ash.Conformance.Expectations.for(scenario.id, adapter.id())
    :ok = adapter.checkout!()

    try do
      run_with_setup!(
        scenario,
        expectation,
        fn ->
          context = Ash.Conformance.Fixtures.build!(adapter, scenario.fixture)
          Ash.Conformance.Fixtures.prepare!(context, scenario.id)
          context
        end,
        record_result,
        observer(scenario, adapter, record_fallback)
      )
    after
      adapter.checkin!()
    end
  end

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

      instrumentation ->
        fn operation ->
          {outcome, measurements} = instrumentation.measure(adapter, operation)
          record.(fallback_evidence(fallback, measurements.query_count))
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

  def assert_outcome!(scenario, :supported, {:ok, actual}) do
    assert actual == scenario.expected,
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

    if status != :unresolved and outcome == {:ok, scenario.expected} do
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

  defp matches?({:value, expected}, {:ok, actual}), do: expected == actual

  defp matches?({:error, exception, pattern}, {:error, exception, message}),
    do: Regex.match?(pattern, message)

  defp matches?(_, _), do: false
  defp format(value), do: inspect(value, charlists: :as_lists)
end
