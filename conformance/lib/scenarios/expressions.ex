# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Expressions do
  @moduledoc """
  Expression functions and nil logic, on the expression fixture
  (`Ash.Conformance.Fixtures.Expressions`):

  | id | a | b | f | d | s | t | day | at |
  | --- | --- | --- | --- | --- | --- | --- | --- | --- |
  | 1 | 7 | 2 | 1.5 | 2.50 | "Hello" | "Ünïcode ✓" | 2024-02-28 | 2024-02-28 23:30 |
  | 2 | -7 | 3 | -2.5 | -1.25 | "  padded  " | "abc" | 2024-12-31 | 2024-12-31 12:00 |
  | 3 | nil | 4 | nil | nil | nil | "x" | nil | nil |
  | 4 | 0 | nil | 2.0 | 0.1 | "" | nil | 2023-01-31 | 2023-01-31 00:00 |

  Answers come from the expressions guide: operators behave as in Elixir
  except that nil behaves like SQL `NULL`, and each function as documented.
  Integer division is a float (`Ash.Query.Operator.Basic`). A unit test
  checks that Ash's in-memory evaluation, through ETS, gives the same
  answers, except where a decision is open.

  Each `expr.*` scenario reads the expression as a calculation on every row;
  `expr.filter.*` and `nil.*` scenarios filter by it and return the IDs.
  Floats are rounded to six places and datetimes compare by value, as the
  calculation's representation is tier 1's concern.
  """
  require Ash.Expr
  import Ash.Expr, only: [expr: 1]
  import Ash.Conformance.Scenario, only: [new: 5]
  import Ash.Conformance.Scenarios.ExpressionHelpers
  alias Ash.Conformance.Storage

  def all, do: arithmetic() ++ strings() ++ conditionals() ++ dates() ++ filters() ++ nil_logic()

  defp arithmetic do
    int = Storage.stored(:integer)

    [
      calc("expr.add", :integer, expr(a + b), [9, -4, nil, nil], int),
      calc("expr.subtract", :integer, expr(a - b), [5, -10, nil, nil], int),
      calc("expr.multiply", :integer, expr(a * b), [14, -21, nil, nil], int),
      # Integer division is a float, as in Elixir; SQL's integer division truncates.
      calc("expr.divide", :float, expr(a / b), [3.5, -2.333333, nil, nil], int),
      calc(
        "expr.divide_float",
        :float,
        expr(f / 2),
        [0.75, -1.25, nil, 1.0],
        Storage.stored(:float)
      ),
      calc(
        "expr.decimal_multiply",
        :decimal,
        expr(d * 2),
        [Decimal.new("5.00"), Decimal.new("-2.50"), nil, Decimal.new("0.2")],
        Storage.stored(:decimal)
      ),
      # `round/1` rounds half away from zero, as Elixir does.
      calc("expr.round", :float, expr(round(f)), [2.0, -3.0, nil, 2.0], Storage.stored(:float)),
      calc(
        "expr.round_decimal",
        :decimal,
        expr(round(d, 1)),
        [Decimal.new("2.5"), Decimal.new("-1.3"), nil, Decimal.new("0.1")],
        Storage.stored(:decimal)
      )
    ]
  end

  defp strings do
    text = Storage.stored(:string)

    [
      calc("expr.concat", :string, expr(s <> "!"), ["Hello!", "  padded  !", nil, "!"], text),
      # Graphemes, as `String.length/1` counts them.
      calc("expr.string_length", :integer, expr(string_length(t)), [9, 3, 1, nil], text),
      calc(
        "expr.string_downcase",
        :string,
        expr(string_downcase(t)),
        ["ünïcode ✓", "abc", "x", nil],
        text
      ),
      calc("expr.string_trim", :string, expr(string_trim(s)), ["Hello", "padded", nil, ""], text),
      # Zero-based, or nil when the substring is absent.
      calc(
        "expr.string_position",
        :integer,
        expr(string_position(s, "l")),
        [2, nil, nil, nil],
        text
      ),
      # Joins the non-nil values.
      calc(
        "expr.string_join",
        :string,
        expr(string_join([s, t], "-")),
        ["Hello-Ünïcode ✓", "  padded  -abc", "x", ""],
        text
      ),
      calc(
        "expr.contains_unicode",
        :boolean,
        expr(contains(t, "ï")),
        [true, false, false, nil],
        text
      ),
      calc(
        "expr.type_to_string",
        :string,
        expr(type(a, :string)),
        ["7", "-7", nil, "0"],
        Storage.stored(:integer)
      )
    ]
  end

  defp conditionals do
    int = Storage.stored(:integer)

    [
      # A nil condition takes the else branch, as in Elixir and SQL's CASE.
      calc(
        "expr.if",
        :string,
        expr(if a > 0, do: "pos", else: "other"),
        ["pos", "other", "other", "other"],
        int
      ),
      calc(
        "expr.cond",
        :string,
        expr(
          cond do
            a > 5 -> "big"
            a < 0 -> "negative"
            true -> "none"
          end
        ),
        ["big", "negative", "none", "none"],
        int
      ),
      # `||` is the left value unless it is nil or false: 0 is kept.
      calc("expr.or_else", :integer, expr(a || b), [7, -7, 4, 0], int),
      # `&&` is the right value when the left is not nil or false.
      calc("expr.and_then", :integer, expr(a && b), [2, 3, nil, nil], int)
    ]
  end

  defp dates do
    [
      calc(
        "expr.date_add_day",
        :date,
        expr(date_add(day, 1, :day)),
        [~D[2024-02-29], ~D[2025-01-01], nil, ~D[2023-02-01]],
        Storage.stored(:date)
      ),
      # A month past the 31st lands on the month's last day, as `Date.shift/2` does.
      calc(
        "expr.date_add_month",
        :date,
        expr(date_add(day, 1, :month)),
        [~D[2024-03-28], ~D[2025-01-31], nil, ~D[2023-02-28]],
        Storage.stored(:date)
      ),
      calc(
        "expr.datetime_add",
        :utc_datetime_usec,
        expr(datetime_add(at, 90, :minute)),
        [~U[2024-02-29 01:00:00Z], ~U[2024-12-31 13:30:00Z], nil, ~U[2023-01-31 01:30:00Z]],
        Storage.stored(:utc_datetime_usec)
      ),
      calc(
        "expr.start_of_day",
        :utc_datetime_usec,
        expr(start_of_day(at)),
        [~U[2024-02-28 00:00:00Z], ~U[2024-12-31 00:00:00Z], nil, ~U[2023-01-31 00:00:00Z]],
        Storage.stored(:utc_datetime_usec)
      )
    ]
  end

  # The same functions where a data layer translates them inside WHERE.
  defp filters do
    [
      filter("expr.filter.divide", expr(a / b > 3), [1], Storage.stored(:integer)),
      filter("expr.filter.round", expr(round(f) == -3.0), [2], Storage.stored(:float)),
      filter(
        "expr.filter.string_length",
        expr(string_length(t) == 9),
        [1],
        Storage.stored(:string)
      ),
      filter(
        "expr.filter.string_downcase",
        expr(string_downcase(t) == "ünïcode ✓"),
        [1],
        Storage.stored(:string)
      ),
      filter("expr.filter.concat", expr(s <> "!" == "!"), [4], Storage.stored(:string)),
      filter("expr.filter.or_else", expr((a || 100) > 50), [3], Storage.stored(:integer)),
      filter(
        "expr.filter.date_add_month",
        expr(date_add(day, 1, :month) == ^~D[2023-02-28]),
        [4],
        Storage.stored(:date)
      )
    ]
  end

  # A comparison with nil is nil, and a nil filter excludes the row, as in SQL.
  defp nil_logic do
    int = Storage.stored(:integer)

    [
      filter("nil.not_equal", expr(a != 7), [2, 4], int),
      filter("nil.not_equal_negated", expr(not (a == 7)), [2, 4], int),
      filter("nil.compare_columns", expr(a > b), [1], int),
      filter("nil.compare_columns_negated", expr(not (a > b)), [2], int),
      # Ash warns that comparing with nil is never true.
      filter("nil.pinned_nil", expr(a == ^nil), [], int),
      filter("nil.and", expr(a > 0 and b > 0), [1], int),
      filter("nil.not_and", expr(not (a > 0 and b > 3)), [1, 2, 4], int),
      # `a`, `not a` and `is_nil(a)` partition the rows.
      new(
        "nil.partition",
        :filters,
        {[1], [2, 4], [3]},
        fn ctx ->
          {ids(ctx, expr(a > 0)), ids(ctx, expr(not (a > 0))), ids(ctx, expr(is_nil(a)))}
        end,
        opts(int)
      ),
      # SQL says `-7 in [7, nil]` is NULL, so its negation excludes the row;
      # Ash's in-memory evaluation says it is false. Undecided: `in-list-nil`.
      filter("nil.not_in_with_nil", expr(a not in [7, nil]), :unresolved, int),
      # Ash documents `true or nil` as nil; SQL and Ash's evaluator return true
      # for row 3. Undecided: `true-or-nil`.
      filter("nil.or", expr(a > 0 or b > 3), :unresolved, int)
    ]
  end
end
