# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fuzz do
  @moduledoc """
  Generated filters, checked without hand-written answers.

  StreamData generates filter trees over the expression fixture
  (`Ash.Conformance.Fixtures.Expressions`): comparisons, `in`, `is_nil`,
  `and`, `or`, `not` and a few expressions keyword filters cannot write,
  such as `a > b` or `string_length(t) > 2`. Each filter `p` runs on the
  data layer, and so does `not p`, and both are checked against an oracle:

  - `:sql` (the default): SQL's three-valued logic, which the expressions
    guide specifies ("nil values behave the way `NULL` values behave in
    SQL"), evaluated here over the rows read without a filter. Comparisons
    with nil are nil, `nil and false` is false, `nil or true` is true, and a
    row is kept only when the filter is true.
  - `:runtime`: Ash's own in-memory evaluation (`Ash.Filter.Runtime`) over
    the same rows. Run on a data layer, it finds where Ash's evaluator and
    the database differ; `runtime/1` checks Ash's evaluator against `:sql`
    with no data layer at all.

  `p` and `not p` must also never keep the same row.

  A failing filter is shrunk to a minimal one. Nothing here is an
  expectation: a disagreement is a lead for a person to triage into a
  written scenario (`CONFORMANCE_PLAN_v4.md`, part B). The generator leaves
  out what Ash has not decided, so it does not report those again: nil
  inside `in` lists (`in-list-nil`) and ordering comparisons on strings,
  whose collation Ash does not define.
  """
  require Ash.Expr
  import Ash.Expr, only: [expr: 1]

  @domain Ash.Conformance.Resources.Domain
  @comparisons [
    :eq,
    :not_eq,
    :greater_than,
    :less_than,
    :greater_than_or_equal,
    :less_than_or_equal
  ]
  @strings ["Hello", "abc", "x", "", "  padded  ", "Ünïcode ✓"]
  @dates [~D[2023-01-31], ~D[2024-02-28], ~D[2024-12-31], ~D[2024-06-01]]

  @doc "Expressions keyword filters cannot write, by name."
  def expressions do
    %{
      a_above_b: expr(a > b),
      sum_above_3: expr(a + b > 3),
      product_negative: expr(a * b < 0),
      t_longer_than_2: expr(string_length(t) > 2),
      s_equals_t: expr(s == t),
      double_f_above_a: expr(f * 2 > a),
      a_or_b_above_1: expr((a || b) > 1)
    }
  end

  @doc "The StreamData generator of filter trees."
  def filters do
    StreamData.tree(leaf(), fn child ->
      StreamData.one_of([
        StreamData.map(StreamData.list_of(child, length: 2), &{:and, &1}),
        StreamData.map(StreamData.list_of(child, length: 2), &{:or, &1}),
        StreamData.map(child, &{:not, &1})
      ])
    end)
  end

  defp leaf do
    ints = StreamData.integer(-8..8)

    StreamData.one_of([
      compare(:a, @comparisons, ints),
      compare(:b, @comparisons, ints),
      compare(:f, @comparisons, StreamData.member_of([-2.5, 0.0, 1.5, 2.0, 3.0])),
      compare(:s, [:eq, :not_eq], StreamData.member_of(@strings)),
      compare(:t, [:eq, :not_eq], StreamData.member_of(@strings)),
      compare(:day, @comparisons, StreamData.member_of(@dates)),
      StreamData.map(StreamData.member_of(~w(a b f s t day)a), &{:is_nil, &1}),
      StreamData.map(StreamData.list_of(ints, min_length: 1, max_length: 3), &{:in, :a, &1}),
      StreamData.map(
        StreamData.list_of(StreamData.member_of(@strings), min_length: 1, max_length: 3),
        &{:in, :s, &1}
      ),
      StreamData.map(StreamData.member_of(Map.keys(expressions()) |> Enum.sort()), &{:expr, &1})
    ])
  end

  defp compare(column, operators, values) do
    StreamData.map(StreamData.tuple({StreamData.member_of(operators), values}), fn {op, value} ->
      {:compare, column, op, value}
    end)
  end

  @doc "A filter tree as an Ash filter statement."
  def statement({:compare, column, op, value}), do: [{column, [{op, value}]}]
  def statement({:is_nil, column}), do: [{column, [is_nil: true]}]
  def statement({:in, column, values}), do: [{column, [in: values]}]
  def statement({:expr, name}), do: Map.fetch!(expressions(), name)
  def statement({:and, children}), do: [and: Enum.map(children, &statement/1)]
  def statement({:or, children}), do: [or: Enum.map(children, &statement/1)]
  def statement({:not, child}), do: [not: statement(child)]

  @doc "A filter tree written as an Ash expression, for reports."
  def describe({:compare, column, op, value}), do: "#{column} #{symbol(op)} #{inspect(value)}"
  def describe({:is_nil, column}), do: "is_nil(#{column})"
  def describe({:in, column, values}), do: "#{column} in #{inspect(values)}"
  def describe({:expr, name}), do: inspect(Map.fetch!(expressions(), name))
  def describe({:and, [l, r]}), do: "(#{describe(l)} and #{describe(r)})"
  def describe({:or, [l, r]}), do: "(#{describe(l)} or #{describe(r)})"
  def describe({:not, child}), do: "not #{describe(child)}"

  defp symbol(:eq), do: "=="
  defp symbol(:not_eq), do: "!="
  defp symbol(:greater_than), do: ">"
  defp symbol(:less_than), do: "<"
  defp symbol(:greater_than_or_equal), do: ">="
  defp symbol(:less_than_or_equal), do: "<="

  @doc """
  Runs `runs` generated filters per round against an adapter, from `seed`,
  and returns each distinct disagreement, shrunk. Each round starts from the
  next seed, so rounds find different failures. `setup?: false` skips the
  adapter's setup, where it already ran.
  """
  def run(adapter, opts \\ []) do
    runs = Keyword.get(opts, :runs, 200)
    rounds = Keyword.get(opts, :rounds, 3)
    seed = Keyword.get(opts, :seed, 2026)

    # Tests set up the reviewed adapters once, before any test runs.
    if Keyword.get(opts, :setup?, true), do: adapter.setup!()
    :ok = adapter.checkout!()

    try do
      Ash.Conformance.Fixtures.build!(adapter, :expressions)
      resource = adapter.resource(:expr_row)
      rows = Ash.read!(resource, authorize?: false)

      oracle = Keyword.get(opts, :oracle, :sql)
      rounds(&check(resource, rows, &1, oracle), seed, rounds, runs)
    after
      adapter.checkin!()
    end
  end

  defp round(check, seed, runs) do
    options = [initial_seed: {seed, 0, 0}, max_runs: runs, max_shrinking_steps: 200]

    case StreamData.check_all(filters(), options, check) do
      {:ok, _} -> nil
      {:error, %{shrunk_failure: failure}} -> failure
    end
  end

  @doc """
  Checks Ash's own evaluation against SQL's three-valued logic over the
  fixture rows, with no data layer: a failure here is Ash's evaluator.
  `adapter:` names any set-up adapter; only its resource definition is used.
  """
  def runtime(opts) do
    runs = Keyword.get(opts, :runs, 200)
    rounds = Keyword.get(opts, :rounds, 3)
    seed = Keyword.get(opts, :seed, 2026)
    resource = Keyword.fetch!(opts, :adapter).resource(:expr_row)
    rows = Enum.map(Ash.Conformance.Fixtures.Expressions.rows(), &struct(resource, &1))

    check = fn tree ->
      with {:ok, kept} <- evaluate(resource, rows, statement(tree)),
           {:ok, dropped} <- evaluate(resource, rows, not: statement(tree)) do
        compare(
          tree,
          kept,
          dropped,
          sql_keep(resource, rows, tree),
          sql_keep(resource, rows, {:not, tree})
        )
      else
        {:error, reason} -> {:error, %{filter: describe(tree), problems: [{:error, reason}]}}
      end
    end

    rounds(check, seed, rounds, runs)
  end

  defp rounds(check, seed, rounds, runs) do
    for round <- 0..(rounds - 1),
        failure = round(check, seed + round, runs),
        failure != nil,
        uniq: true,
        do: failure
  end

  @doc "Checks one filter tree, and its negation, on the data layer against an oracle."
  def check(resource, rows, tree, oracle \\ :sql) do
    statement = statement(tree)

    with {:ok, kept} <- read(resource, statement),
         {:ok, dropped} <- read(resource, not: statement),
         {:ok, expected_kept} <- expected(oracle, resource, rows, tree),
         {:ok, expected_dropped} <- expected(oracle, resource, rows, {:not, tree}) do
      compare(tree, kept, dropped, expected_kept, expected_dropped)
    else
      {:error, reason} -> {:error, %{filter: describe(tree), problems: [{:error, reason}]}}
    end
  end

  defp expected(:sql, resource, rows, tree), do: {:ok, sql_keep(resource, rows, tree)}
  defp expected(:runtime, resource, rows, tree), do: evaluate(resource, rows, statement(tree))

  defp compare(tree, kept, dropped, expected_kept, expected_dropped) do
    problems =
      [
        kept != expected_kept && {:filter, kept, expected_kept},
        dropped != expected_dropped && {:negation, dropped, expected_dropped},
        (overlap = kept -- (kept -- dropped)) != [] && {:overlap, overlap}
      ]
      |> Enum.filter(& &1)

    if problems == [],
      do: {:ok, nil},
      else: {:error, %{filter: describe(tree), problems: problems}}
  end

  @doc "The IDs of the rows SQL's three-valued logic keeps: those where the filter is true."
  def sql_keep(resource, rows, tree) do
    rows |> Enum.filter(&(sql(resource, &1, tree) == true)) |> Enum.map(& &1.id) |> Enum.sort()
  end

  defp sql(_resource, row, {:compare, column, op, value}),
    do: compare_values(op, Map.fetch!(row, column), value)

  defp sql(_resource, row, {:is_nil, column}), do: is_nil(Map.fetch!(row, column))

  defp sql(_resource, row, {:in, column, values}) do
    case Map.fetch!(row, column) do
      nil -> nil
      value -> Enum.any?(values, &(compare_values(:eq, value, &1) == true))
    end
  end

  # The named expressions hold no `and` or `or`, so Ash's evaluation is exact.
  defp sql(resource, row, {:expr, name}) do
    {:ok, value} = Ash.Expr.eval(Map.fetch!(expressions(), name), record: row, resource: resource)
    value
  end

  defp sql(resource, row, {:and, [l, r]}) do
    case {sql(resource, row, l), sql(resource, row, r)} do
      {false, _} -> false
      {_, false} -> false
      {true, true} -> true
      _ -> nil
    end
  end

  defp sql(resource, row, {:or, [l, r]}) do
    case {sql(resource, row, l), sql(resource, row, r)} do
      {true, _} -> true
      {_, true} -> true
      {false, false} -> false
      _ -> nil
    end
  end

  defp sql(resource, row, {:not, child}) do
    case sql(resource, row, child) do
      nil -> nil
      value -> not value
    end
  end

  defp compare_values(_op, nil, _value), do: nil

  defp compare_values(op, left, right) do
    order =
      case {left, right} do
        {%Date{}, %Date{}} -> Date.compare(left, right)
        _ when left < right -> :lt
        _ when left > right -> :gt
        _ -> :eq
      end

    case op do
      :eq -> order == :eq
      :not_eq -> order != :eq
      :greater_than -> order == :gt
      :less_than -> order == :lt
      :greater_than_or_equal -> order != :lt
      :less_than_or_equal -> order != :gt
    end
  end

  defp read(resource, statement) do
    resource
    |> Ash.Query.do_filter(statement)
    |> Ash.read(authorize?: false)
    |> case do
      {:ok, records} -> {:ok, records |> Enum.map(& &1.id) |> Enum.sort()}
      {:error, error} -> {:error, Ash.Conformance.Fixtures.reason(error)}
    end
  end

  defp evaluate(resource, rows, statement) do
    with {:ok, filter} <- Ash.Filter.parse(resource, statement),
         {:ok, kept} <- Ash.Filter.Runtime.filter_matches(@domain, rows, filter) do
      {:ok, kept |> Enum.map(& &1.id) |> Enum.sort()}
    else
      {:error, error} ->
        {:error, "Ash could not evaluate it: " <> Ash.Conformance.Fixtures.reason(error)}
    end
  end

  @doc "A markdown report of the disagreements found on what was checked."
  def markdown(label, failures, opts) do
    body =
      case failures do
        [] ->
          "No disagreement found."

        failures ->
          Enum.map_join(failures, "\n", fn %{filter: filter, problems: problems} ->
            "- `#{filter}`: " <> Enum.map_join(problems, "; ", &problem/1)
          end)
      end

    """
    # Generated filters on #{label}

    #{Keyword.get(opts, :rounds, 3)} rounds of #{Keyword.get(opts, :runs, 200)} filters from seed #{Keyword.get(opts, :seed, 2026)}, checked against #{oracle(Keyword.get(opts, :oracle, :sql))}, each shrunk to a minimal failing filter. These are leads to triage, not results: see `lib/fuzz.ex`.

    #{body}
    """
  end

  defp oracle(:sql), do: "SQL's three-valued logic"
  defp oracle(:runtime), do: "Ash's in-memory evaluation"

  defp problem({:filter, got, want}),
    do: "keeps #{inspect(got)}, the oracle keeps #{inspect(want)}"

  defp problem({:negation, got, want}),
    do: "its negation keeps #{inspect(got)}, the oracle keeps #{inspect(want)}"

  defp problem({:overlap, ids}), do: "the filter and its negation both keep #{inspect(ids)}"
  defp problem({:error, reason}), do: "raises: #{reason}"
end
