# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Contracts.Records do
  @moduledoc """
  Builders for expectation records, imported by each adapter's expectations.

  A record is `:supported`, or `{status, signature, "GAPS.md#gap"}` where the
  signature pins exactly what the adapter does instead: an error class and
  message pattern, a wrong value, or a value per seed order.

  An adapter's expectations are rules, resolved against the scenarios it runs:

      def rules do
        [
          supported("*"),
          expect("policy.*.get_error", unsupported(~r/no error expressions/, "error-expressions")),
          expect(~w(query.distinct query.union), unsupported(~r/does not support/, "query-distinct"))
        ]
      end

  Patterns are scenario IDs, where `*` matches anything. A scenario takes the
  record of the one `expect` rule that matches it, or `:supported` if a
  `supported` pattern matches. Two matching `expect` rules, or a rule that
  matches no scenario, raise. `supported` is a claim, not an acceptance: a
  scenario it covers that fails still fails the run.
  """

  def task(gap), do: "GAPS.md##{gap}"

  @doc "Scenarios expected to return the intended answer."
  def supported(patterns), do: {:supported, List.wrap(patterns)}

  @doc "Scenarios expected to behave as `record` instead."
  def expect(patterns, record), do: {:expect, List.wrap(patterns), record}

  @doc "An adapter's records by scenario ID, from its rules."
  def resolve(adapter, rules) do
    # Regexes hold references on OTP 28+, so the rules are keyed by their
    # printed form, which is stable, not by their terms.
    key = {__MODULE__, adapter, :erlang.phash2(inspect(rules, limit: :infinity))}

    case :persistent_term.get(key, nil) do
      nil ->
        records = do_resolve(adapter, rules)
        :persistent_term.put(key, records)
        records

      records ->
        records
    end
  end

  defp do_resolve(adapter, rules) do
    ids = adapter |> Ash.Conformance.Catalog.for_adapter() |> Enum.map(& &1.id)
    rules = Enum.map(rules, fn rule -> {rule, rule |> patterns() |> Enum.map(&glob/1)} end)

    for {rule, regexes} <- rules, not Enum.any?(ids, &matches?(regexes, &1)) do
      raise ArgumentError,
            "#{inspect(adapter)}: expectation rule #{inspect(patterns(rule))} matches no scenario"
    end

    Enum.reduce(ids, %{}, fn id, acc ->
      matching = for {rule, regexes} <- rules, matches?(regexes, id), do: rule

      case Enum.filter(matching, &match?({:expect, _, _}, &1)) do
        [{:expect, _, record}] ->
          Map.put(acc, id, record)

        [] ->
          if Enum.any?(matching, &match?({:supported, _}, &1)),
            do: Map.put(acc, id, :supported),
            else: acc

        several ->
          raise ArgumentError,
                "#{inspect(adapter)}: #{id} matches several expectation rules: " <>
                  inspect(Enum.map(several, &patterns/1))
      end
    end)
  end

  defp patterns({:supported, patterns}), do: patterns
  defp patterns({:expect, patterns, _record}), do: patterns

  defp matches?(regexes, id), do: Enum.any?(regexes, &Regex.match?(&1, id))

  defp glob(pattern) do
    ~r/\*/
    |> Regex.split(pattern)
    |> Enum.map_join(".*", &Regex.escape/1)
    |> then(&Regex.compile!("^" <> &1 <> "$"))
  end

  @doc "A documented rejection."
  def unsupported(pattern, gap, exception \\ Ash.Error.Unknown),
    do: {:unsupported, {:error, exception, pattern}, task(gap)}

  @doc "A defect that raises."
  def defect_error(pattern, gap, exception \\ Ash.Error.Unknown),
    do: {:known_defect, {:error, exception, pattern}, task(gap)}

  @doc "A defect that returns a wrong value."
  def defect_value(value, gap), do: {:known_defect, {:value, value}, task(gap)}

  @doc "A wrong answer that changes with the order rows were stored in."
  def defect_orders(values, gap),
    do:
      {:known_defect,
       {:order_dependent, Map.new(values, fn {order, value} -> {order, {:value, value}} end)},
       task(gap)}

  @doc "The observation for a scenario whose intended answer awaits a decision."
  def unresolved_value(value, gap), do: {:unresolved, {:value, value}, task(gap)}

  def unresolved_error(pattern, gap, exception \\ Ash.Error.Unknown),
    do: {:unresolved, {:error, exception, pattern}, task(gap)}
end
