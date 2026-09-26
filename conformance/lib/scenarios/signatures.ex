# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Signatures do
  @moduledoc """
  One scenario for every argument signature Ash declares for its functions
  (`args/0`) and its arithmetic and concatenation operators (`types/0`), on
  the signature fixture (`Ash.Conformance.Fixtures.Signatures`):

  | id | s | c | i | j | f | d | day | dt, sec | at | naive | tm | tmu | strs | ints | m | flag |
  | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
  | 1 | "Hello World" | "HeLLo" | 7 | 3 | 2.5 | 2.345 | 2024-01-31 | 2024-01-31 10:30:00 | 10:30:00.123456 | 2024-01-31 10:30:00 | 10:30:00 | 10:30:00.123456 | ["a", "b", "c"] | [1, 2, 2, 3] | %{"k" => "v", "nested" => %{"x" => 1}} | true |
  | 2 | "" | "" | 0 | -2 | -1.5 | -0.5 | 2024-02-29 | 2024-02-29 23:59:59 | 23:59:59.999999 | 2024-02-29 23:59:59 | 23:59:59 | 23:59:59.999999 | [] | [] | %{} | false |
  | 3 | nil | nil | nil | nil | nil | nil | nil | nil | nil | nil | nil | nil | nil | nil | nil | nil |

  Each scenario reads its expression as a calculation on the three rows, so
  the data layer computes it. A literal argument (`^Duration.new!(...)`,
  `^ci("...")`) is always paired with a column. Answers are written by hand
  from the expressions guide and, for operators, `Ash.Query.Operator.Basic`:
  a date minus a date is whole days, other differences are whole seconds
  (`DateTime.diff/2`), durations shift as `DateTime.shift/2` does, and time
  wraps at midnight. Nil in gives nil out, unless a function says otherwise.
  A unit test checks the answers against Ash's in-memory evaluation, and
  another that every signature Ash declares has a scenario or an exclusion.
  """
  require Ash.Expr
  import Ash.Expr, only: [expr: 1]
  import Ash.Conformance.Scenario, only: [new: 5]
  alias Ash.Conformance.Storage

  @basis "../documentation/topics/reference/expressions.md"
  @operators "../lib/ash/query/operator/basic.ex"
  @text [trim?: false, allow_empty?: true]

  # Signatures without a scenario, and why.
  @excluded [
    {{:function, :fragment, :var_args},
     "Raw SQL; each data layer's own tests cover the fragments it accepts"},
    {{:function, :lazy, [:any]}, "Runs an Elixir function in memory; never reaches a data layer"},
    {{:function, :error, [:atom, :any]},
     "Raises by design; the error-expressions scenarios cover it"},
    {{:function, :composite_type, [:any, :any]},
     "Builds a value of a custom composite type; needs a composite-type fixture"},
    {{:function, :composite_type, [:any, :any, :any]},
     "Builds a value of a custom composite type; needs a composite-type fixture"},
    {{:function, :range_adjacent, [range: :any, range: :same]},
     "Needs a range column; ranges are AshPostgres-only"},
    {{:function, :range_contains, [range: :any, range: :same]},
     "Needs a range column; ranges are AshPostgres-only"},
    {{:function, :range_contains, [{:range, :any}, :same]},
     "Needs a range column; ranges are AshPostgres-only"},
    {{:function, :range_lower, [:any]}, "Needs a range column; ranges are AshPostgres-only"},
    {{:function, :range_overlaps, [range: :any, range: :same]},
     "Needs a range column; ranges are AshPostgres-only"},
    {{:function, :range_upper, [:any]}, "Needs a range column; ranges are AshPostgres-only"},
    {{:operator, :-, [:duration, :duration]},
     "Needs a stored duration: SQLite cannot store one (duration-storage), and a fixture row that fails would block every signature"},
    {{:operator, :+, [:duration, :duration]},
     "Needs a stored duration: SQLite cannot store one (duration-storage), and a fixture row that fails would block every signature"}
  ]

  def excluded, do: @excluded

  def all, do: Enum.map(entries(), &scenario/1)

  @doc "The scenario IDs of one group: `:dates`, `:collections`, `:strings`, `:numbers` or `:operators`."
  def ids(group), do: groups() |> Keyword.fetch!(group) |> Enum.map(&id/1)

  @doc "Every scenario's signature key, by scenario ID."
  def signatures, do: Map.new(entries(), &{id(&1), &1.key})

  defp id(%{key: {_, name, _}, suffix: suffix}), do: "sig.#{slug(name)}.#{suffix}"

  defp slug(:-), do: "minus"
  defp slug(:+), do: "plus"
  defp slug(:*), do: "times"
  defp slug(:/), do: "div"
  defp slug(:<>), do: "concat"
  defp slug(name), do: name

  defp scenario(%{key: {kind, name, _}, suffix: suffix} = entry) do
    expected = by_row(entry.expected)
    run = calculated(entry.type, entry.expression)
    basis = if kind == :operator, do: @operators, else: @basis
    opts = [fixture: :signatures, requires: requires(entry.expression), semantic_basis: basis]
    new("sig.#{slug(name)}.#{suffix}", :expressions, expected, run, opts)
  end

  @columns %{
    s: :string,
    c: :ci_string,
    i: :integer,
    j: :integer,
    f: :float,
    d: :decimal,
    day: :date,
    at: :utc_datetime_usec,
    sec: :utc_datetime,
    naive: :naive_datetime,
    tm: :time,
    tmu: :time_usec,
    strs: :strings,
    ints: :integers,
    m: :map,
    flag: :boolean
  }

  # The tier-1 cells of the columns the expression reads.
  defp requires(expression) do
    expression
    |> Ash.Filter.list_refs()
    |> Enum.map(& &1.attribute)
    |> Enum.uniq()
    |> Enum.flat_map(&List.wrap(Map.get(@columns, &1)))
    |> Storage.stored()
  end

  def by_row(values), do: Map.new(Enum.zip(1..3, Enum.map(values, &project/1)))

  def calculated(type, expression) do
    fn ctx ->
      ctx.adapter.resource(:sig_row)
      |> Ash.Query.calculate(:result, type, expression, %{}, constraints(type))
      |> Ash.Query.sort(:id)
      |> Ash.read!(authorize?: Ash.Conformance.Variant.authorize?())
      |> Map.new(&{&1.id, project(&1.calculations.result)})
    end
  end

  defp constraints(type) when type in [:string, :ci_string], do: @text
  defp constraints({:array, type}) when type in [:string, :ci_string], do: [items: @text]
  defp constraints(_type), do: []

  @doc """
  Values compared by what they mean: floats to six places, datetimes and
  times in microseconds, durations in seconds, case-insensitive strings as
  strings. Decimals compare by value (`Ash.Conformance.Compare`).
  """
  def project(value) when is_float(value), do: Float.round(value, 6)
  def project(%DateTime{} = value), do: {:datetime, DateTime.to_unix(value, :microsecond)}

  def project(%NaiveDateTime{} = value),
    do: {:naive_datetime, NaiveDateTime.diff(value, ~N[1970-01-01 00:00:00], :microsecond)}

  def project(%Time{} = value), do: {:time, Time.diff(value, ~T[00:00:00], :microsecond)}

  def project(%Duration{year: 0, month: 0} = value),
    do:
      {:duration,
       value.week * 604_800 + value.day * 86_400 + value.hour * 3600 + value.minute * 60 +
         value.second}

  def project(%Ash.CiString{} = value), do: to_string(value)
  def project(values) when is_list(values), do: Enum.map(values, &project/1)
  def project(value), do: value

  defp ci(value), do: Ash.CiString.new(value)
  defp hours(n), do: Duration.new!(hour: n)

  defp fun(name, args, suffix, type, expression, expected),
    do: %{
      key: {:function, name, args},
      suffix: suffix,
      type: type,
      expression: expression,
      expected: expected
    }

  defp op(name, args, suffix, type, expression, expected),
    do: %{
      key: {:operator, name, args},
      suffix: suffix,
      type: type,
      expression: expression,
      expected: expected
    }

  defp groups,
    do: [
      dates: time_functions(),
      collections: collections(),
      strings: strings(),
      numbers: numbers(),
      operators: operators()
    ]

  defp entries, do: groups() |> Keyword.values() |> Enum.concat()

  # Rows 1 and 2 are in 2024, so every "before now" comparison is true.
  defp time_functions do
    one_day = Duration.new!(day: 1)
    minutes = Duration.new!(minute: 90)
    zone = "Etc/GMT+5"

    [
      fun(:ago, [:integer, :duration_name], "integer", :boolean, expr(at < ago(1, :day)), [
        true,
        true,
        nil
      ]),
      fun(:ago, [:duration], "duration", :boolean, expr(at < ago(^one_day)), [true, true, nil]),
      fun(
        :from_now,
        [:integer, :duration_name],
        "integer",
        :boolean,
        expr(at < from_now(1, :day)),
        [true, true, nil]
      ),
      fun(:from_now, [:duration], "duration", :boolean, expr(at < from_now(^one_day)), [
        true,
        true,
        nil
      ]),
      fun(:now, [], "compare", :boolean, expr(at < now()), [true, true, nil]),
      fun(:today, [], "compare", :boolean, expr(day < today()), [true, true, nil]),
      fun(
        :date_add,
        [:date, :integer, :duration_name],
        "integer",
        :date,
        expr(date_add(day, 1, :day)),
        [~D[2024-02-01], ~D[2024-03-01], nil]
      ),
      fun(:date_add, [:date, :duration], "duration", :date, expr(date_add(day, ^one_day)), [
        ~D[2024-02-01],
        ~D[2024-03-01],
        nil
      ]),
      fun(
        :datetime_add,
        [:datetime, :integer, :duration_name],
        "integer",
        :datetime,
        expr(datetime_add(dt, 90, :minute)),
        [~U[2024-01-31 12:00:00Z], ~U[2024-03-01 01:29:59Z], nil]
      ),
      fun(
        :datetime_add,
        [:datetime, :duration],
        "duration",
        :datetime,
        expr(datetime_add(dt, ^minutes)),
        [~U[2024-01-31 12:00:00Z], ~U[2024-03-01 01:29:59Z], nil]
      ),
      fun(
        :datetime_add,
        [:naive_datetime, :integer, :duration_name],
        "naive_integer",
        :naive_datetime,
        expr(datetime_add(naive, 90, :minute)),
        [~N[2024-01-31 12:00:00], ~N[2024-03-01 01:29:59], nil]
      ),
      fun(
        :datetime_add,
        [:naive_datetime, :duration],
        "naive_duration",
        :naive_datetime,
        expr(datetime_add(naive, ^minutes)),
        [~N[2024-01-31 12:00:00], ~N[2024-03-01 01:29:59], nil]
      ),
      fun(:start_of_day, [:datetime], "datetime", :utc_datetime, expr(start_of_day(dt)), [
        ~U[2024-01-31 00:00:00Z],
        ~U[2024-02-29 00:00:00Z],
        nil
      ]),
      # UTC-5, with no daylight saving: local midnight is 05:00 UTC.
      fun(
        :start_of_day,
        [:datetime, :string],
        "datetime_zone",
        :utc_datetime,
        expr(start_of_day(dt, ^zone)),
        [~U[2024-01-31 05:00:00Z], ~U[2024-02-29 05:00:00Z], nil]
      ),
      fun(:start_of_day, [:date], "date", :utc_datetime, expr(start_of_day(day)), [
        ~U[2024-01-31 00:00:00Z],
        ~U[2024-02-29 00:00:00Z],
        nil
      ]),
      fun(
        :start_of_day,
        [:date, :string],
        "date_zone",
        :utc_datetime,
        expr(start_of_day(day, ^zone)),
        [~U[2024-01-31 05:00:00Z], ~U[2024-02-29 05:00:00Z], nil]
      )
    ]
  end

  defp collections do
    [
      # Zero-based; out of range is nil.
      fun(:at, [{:array, :any}, :integer], "index", :string, expr(at(strs, 1)), ["b", nil, nil]),
      # A list of columns is never nil itself, so row 3 counts three nils.
      fun(:count_nils, [array: :any], "list", :integer, expr(count_nils([s, i, f])), [0, 0, 3]),
      fun(:length, [array: :any], "array", :integer, expr(length(ints)), [4, 0, nil]),
      fun(:has, [{:array, :any}, :same], "array", :boolean, expr(has(ints, 2)), [
        true,
        false,
        nil
      ]),
      fun(
        :intersects,
        [array: :any, array: :same],
        "array",
        :boolean,
        expr(intersects(ints, [3, 9])),
        [true, false, nil]
      ),
      fun(
        :get_path,
        [:map, {:array, :any}],
        "path",
        :integer,
        expr(get_path(m, ["nested", "x"])),
        [1, nil, nil]
      ),
      fun(:get_path, [:map, :any], "key", :string, expr(get_path(m, "k")), ["v", nil, nil]),
      fun(:is_nil, [:any], "column", :boolean, expr(is_nil(s)), [false, false, true]),
      fun(
        :is_distinct_from,
        [:any, :same],
        "integer",
        :boolean,
        expr(is_distinct_from(i, 7)),
        [false, true, true]
      ),
      fun(
        :is_not_distinct_from,
        [:any, :same],
        "integer",
        :boolean,
        expr(is_not_distinct_from(i, 7)),
        [true, false, false]
      ),
      # A nil condition takes the else branch, or nil without one.
      fun(:if, [:boolean, :any], "no_else", :string, expr(if(flag, do: "y")), ["y", nil, nil]),
      fun(
        :if,
        [:boolean, :any, :same],
        "else",
        :string,
        expr(if(flag, do: "y", else: "n")),
        ["y", "n", "n"]
      ),
      fun(:type, [:any, :any], "string", :string, expr(type(i, :string)), ["7", "0", nil]),
      fun(
        :type,
        [:any, :any, :any],
        "constraints",
        :string,
        expr(type(i, :string, [])),
        ["7", "0", nil]
      )
    ]
  end

  defp strings do
    [
      fun(:contains, [:string, :string], "string", :boolean, expr(contains(s, "World")), [
        true,
        false,
        nil
      ]),
      fun(
        :contains,
        [:string, :ci_string],
        "string_ci",
        :boolean,
        expr(contains(s, ^ci("world"))),
        [true, false, nil]
      ),
      fun(:contains, [:ci_string, :string], "ci_string", :boolean, expr(contains(c, "hel")), [
        true,
        false,
        nil
      ]),
      fun(
        :contains,
        [:ci_string, :ci_string],
        "ci_ci",
        :boolean,
        expr(contains(c, ^ci("LLO"))),
        [true, false, nil]
      ),
      fun(:string_downcase, [:string], "string", :string, expr(string_downcase(s)), [
        "hello world",
        "",
        nil
      ]),
      fun(:string_downcase, [:ci_string], "ci", :ci_string, expr(string_downcase(c)), [
        "hello",
        "",
        nil
      ]),
      fun(
        :string_ends_with,
        [:string, :string],
        "string",
        :boolean,
        expr(string_ends_with(s, "World")),
        [true, false, nil]
      ),
      fun(
        :string_ends_with,
        [:string, :ci_string],
        "string_ci",
        :boolean,
        expr(string_ends_with(s, ^ci("WORLD"))),
        [true, false, nil]
      ),
      fun(
        :string_ends_with,
        [:ci_string, :string],
        "ci_string",
        :boolean,
        expr(string_ends_with(c, "llo")),
        [true, false, nil]
      ),
      fun(
        :string_ends_with,
        [:ci_string, :ci_string],
        "ci_ci",
        :boolean,
        expr(string_ends_with(c, ^ci("LLO"))),
        [true, false, nil]
      ),
      fun(
        :string_starts_with,
        [:string, :string],
        "string",
        :boolean,
        expr(string_starts_with(s, "Hello")),
        [true, false, nil]
      ),
      fun(
        :string_starts_with,
        [:string, :ci_string],
        "string_ci",
        :boolean,
        expr(string_starts_with(s, ^ci("hello"))),
        [true, false, nil]
      ),
      fun(
        :string_starts_with,
        [:ci_string, :string],
        "ci_string",
        :boolean,
        expr(string_starts_with(c, "hel")),
        [true, false, nil]
      ),
      fun(
        :string_starts_with,
        [:ci_string, :ci_string],
        "ci_ci",
        :boolean,
        expr(string_starts_with(c, ^ci("HEL"))),
        [true, false, nil]
      ),
      # Nil values are skipped, so a list of two nils joins to "".
      fun(:string_join, [array: :string], "array", :string, expr(string_join(strs)), [
        "abc",
        "",
        nil
      ]),
      fun(
        :string_join,
        [{:array, :string}, :string],
        "array_separator",
        :string,
        expr(string_join(strs, "-")),
        ["a-b-c", "", nil]
      ),
      fun(
        :string_join,
        [{:array, :string}, :ci_string],
        "array_ci_separator",
        :ci_string,
        expr(string_join(strs, ^ci("-"))),
        ["a-b-c", "", nil]
      ),
      fun(:string_join, [array: :ci_string], "ci_list", :ci_string, expr(string_join([c, c])), [
        "HeLLoHeLLo",
        "",
        ""
      ]),
      fun(
        :string_join,
        [{:array, :ci_string}, :ci_string],
        "ci_list_separator",
        :ci_string,
        expr(string_join([c, c], ^ci("-"))),
        ["HeLLo-HeLLo", "-", ""]
      ),
      fun(:string_length, [:string], "string", :integer, expr(string_length(s)), [11, 0, nil]),
      fun(:string_length, [:ci_string], "ci", :integer, expr(string_length(c)), [5, 0, nil]),
      fun(
        :string_length,
        [:string, :atom],
        "codepoints",
        :integer,
        expr(string_length(s, :codepoints)),
        [11, 0, nil]
      ),
      fun(
        :string_length,
        [:ci_string, :atom],
        "ci_bytes",
        :integer,
        expr(string_length(c, :bytes)),
        [5, 0, nil]
      ),
      # Zero-based, or nil when absent; a case-insensitive side matches either case.
      fun(
        :string_position,
        [:string, :string],
        "string",
        :integer,
        expr(string_position(s, "o")),
        [4, nil, nil]
      ),
      fun(
        :string_position,
        [:string, :ci_string],
        "string_ci",
        :integer,
        expr(string_position(s, ^ci("WORLD"))),
        [6, nil, nil]
      ),
      fun(
        :string_position,
        [:ci_string, :string],
        "ci_string",
        :integer,
        expr(string_position(c, "ll")),
        [2, nil, nil]
      ),
      fun(
        :string_position,
        [:ci_string, :ci_string],
        "ci_ci",
        :integer,
        expr(string_position(c, ^ci("LO"))),
        [3, nil, nil]
      ),
      # As `String.split/3`: the default separator is a space, and "" splits to [""].
      fun(:string_split, [:string], "default", {:array, :string}, expr(string_split(s)), [
        ["Hello", "World"],
        [""],
        nil
      ]),
      fun(
        :string_split,
        [:string, :string],
        "separator",
        {:array, :string},
        expr(string_split(s, "o")),
        [["Hell", " W", "rld"], [""], nil]
      ),
      fun(
        :string_split,
        [:string, :string, :keyword],
        "trim",
        {:array, :string},
        expr(string_split(s, "o", trim?: true)),
        [["Hell", " W", "rld"], [], nil]
      ),
      fun(
        :string_split,
        [:string, :ci_string, :keyword],
        "ci_separator_trim",
        {:array, :string},
        expr(string_split(s, ^ci("o"), trim?: true)),
        [["Hell", " W", "rld"], [], nil]
      ),
      fun(:string_split, [:ci_string], "ci", {:array, :ci_string}, expr(string_split(c)), [
        ["HeLLo"],
        [""],
        nil
      ]),
      fun(
        :string_split,
        [:ci_string, :string],
        "ci_separator",
        {:array, :ci_string},
        expr(string_split(c, "e")),
        [["H", "LLo"], [""], nil]
      ),
      fun(
        :string_split,
        [:ci_string, :ci_string],
        "ci_ci",
        {:array, :ci_string},
        expr(string_split(c, ^ci("e"))),
        [["H", "LLo"], [""], nil]
      ),
      fun(
        :string_split,
        [:ci_string, :string, :keyword],
        "ci_trim",
        {:array, :ci_string},
        expr(string_split(c, "e", trim?: true)),
        [["H", "LLo"], [], nil]
      ),
      fun(
        :string_split,
        [:ci_string, :ci_string, :keyword],
        "ci_ci_trim",
        {:array, :ci_string},
        expr(string_split(c, ^ci("e"), trim?: true)),
        [["H", "LLo"], [], nil]
      ),
      fun(:string_trim, [:string], "string", :string, expr(string_trim(s)), [
        "Hello World",
        "",
        nil
      ]),
      fun(:string_trim, [:ci_string], "ci", :ci_string, expr(string_trim(c)), ["HeLLo", "", nil])
    ]
  end

  # `round` rounds half away from zero, as Elixir and `Decimal.round/2` do.
  defp numbers do
    [
      fun(:-, [:any], "negate", :integer, expr(-i), [-7, 0, nil]),
      fun(:rem, [:integer, :integer], "integer", :integer, expr(rem(i, j)), [1, 0, nil]),
      fun(:round, [:float, :integer], "float_places", :float, expr(round(f / 3, 2)), [
        0.83,
        -0.5,
        nil
      ]),
      fun(:round, [:decimal, :integer], "decimal_places", :decimal, expr(round(d, 2)), [
        Decimal.new("2.35"),
        Decimal.new("-0.5"),
        nil
      ]),
      fun(:round, [:integer, :integer], "integer_places", :integer, expr(round(i, 1)), [
        7,
        0,
        nil
      ]),
      fun(:round, [:float], "float", :float, expr(round(f)), [3.0, -2.0, nil]),
      fun(:round, [:decimal], "decimal", :decimal, expr(round(d)), [
        Decimal.new("2"),
        Decimal.new("-1"),
        nil
      ]),
      fun(:round, [:integer], "integer", :integer, expr(round(i)), [7, 0, nil])
    ]
  end

  defp operators do
    half = Decimal.new("0.5")
    one_day = Duration.new!(day: 1)
    one_hour = hours(1)

    [
      op(:<>, [:string, :string], "string", :string, expr(s <> "!"), ["Hello World!", "!", nil]),
      op(:<>, [:ci_string, :ci_string], "ci_ci", :ci_string, expr(c <> c), [
        "HeLLoHeLLo",
        "",
        nil
      ]),
      op(:<>, [:string, :ci_string], "string_ci", :ci_string, expr(s <> c), [
        "Hello WorldHeLLo",
        "",
        nil
      ]),
      op(:<>, [:ci_string, :string], "ci_string", :ci_string, expr(c <> s), [
        "HeLLoHello World",
        "",
        nil
      ]),
      op(:/, [:float, :float], "float_float", :float, expr(f / 0.5), [5.0, -3.0, nil]),
      op(:/, [:decimal, :decimal], "decimal_decimal", :decimal, expr(d / ^half), [
        Decimal.new("4.69"),
        Decimal.new("-1"),
        nil
      ]),
      op(:/, [:float, :decimal], "float_decimal", :decimal, expr(f / ^half), [
        Decimal.new("5"),
        Decimal.new("-3"),
        nil
      ]),
      op(:/, [:decimal, :float], "decimal_float", :decimal, expr(d / 0.5), [
        Decimal.new("4.69"),
        Decimal.new("-1"),
        nil
      ]),
      op(:/, [:integer, :integer], "integer_integer", :float, expr(i / 2), [3.5, 0.0, nil]),
      op(:/, [:integer, :float], "integer_float", :float, expr(i / 0.5), [14.0, 0.0, nil]),
      op(:/, [:integer, :decimal], "integer_decimal", :decimal, expr(i / ^half), [
        Decimal.new("14"),
        Decimal.new("0"),
        nil
      ]),
      op(:/, [:float, :integer], "float_integer", :float, expr(f / 2), [1.25, -0.75, nil]),
      op(:/, [:decimal, :integer], "decimal_integer", :decimal, expr(d / 2), [
        Decimal.new("1.1725"),
        Decimal.new("-0.25"),
        nil
      ]),
      op(:*, [:same, :any], "integer", :integer, expr(i * j), [21, 0, nil]),
      op(:*, [:duration, :integer], "duration_integer", :duration, expr(^one_hour * i), [
        hours(7),
        hours(0),
        nil
      ]),
      op(:*, [:integer, :duration], "integer_duration", :duration, expr(i * ^one_hour), [
        hours(7),
        hours(0),
        nil
      ])
    ] ++ minus(one_day, one_hour) ++ plus(one_day, one_hour)
  end

  defp minus(one_day, one_hour) do
    [
      op(:-, [:same, :any], "integer", :integer, expr(i - j), [4, 2, nil]),
      op(:-, [:date, :duration], "date_duration", :date, expr(day - ^one_day), [
        ~D[2024-01-30],
        ~D[2024-02-28],
        nil
      ]),
      op(:-, [:date, :date], "date_date", :integer, expr(day - ^~D[2024-01-01]), [30, 59, nil]),
      op(:-, [:datetime, :duration], "datetime_duration", :datetime, expr(dt - ^one_hour), [
        ~U[2024-01-31 09:30:00Z],
        ~U[2024-02-29 22:59:59Z],
        nil
      ]),
      op(
        :-,
        [:datetime, :datetime],
        "datetime_datetime",
        :integer,
        expr(dt - ^~U[2024-01-31 10:00:00Z]),
        [1800, 2_555_999, nil]
      ),
      op(
        :-,
        [:utc_datetime, :duration],
        "utc_datetime_duration",
        :utc_datetime,
        expr(sec - ^one_hour),
        [~U[2024-01-31 09:30:00Z], ~U[2024-02-29 22:59:59Z], nil]
      ),
      op(
        :-,
        [:utc_datetime, :utc_datetime],
        "utc_datetime_utc_datetime",
        :integer,
        expr(sec - ^~U[2024-01-31 10:00:00Z]),
        [1800, 2_555_999, nil]
      ),
      op(
        :-,
        [:utc_datetime_usec, :duration],
        "usec_duration",
        :utc_datetime_usec,
        expr(at - ^one_hour),
        [~U[2024-01-31 09:30:00.123456Z], ~U[2024-02-29 22:59:59.999999Z], nil]
      ),
      # Whole seconds, truncated, as `DateTime.diff/2`.
      op(
        :-,
        [:utc_datetime_usec, :utc_datetime_usec],
        "usec_usec",
        :integer,
        expr(at - ^~U[2024-01-31 10:00:00.000000Z]),
        [1800, 2_555_999, nil]
      ),
      op(
        :-,
        [:naive_datetime, :duration],
        "naive_duration",
        :naive_datetime,
        expr(naive - ^one_hour),
        [~N[2024-01-31 09:30:00], ~N[2024-02-29 22:59:59], nil]
      ),
      op(
        :-,
        [:naive_datetime, :naive_datetime],
        "naive_naive",
        :integer,
        expr(naive - ^~N[2024-01-31 10:00:00]),
        [1800, 2_555_999, nil]
      ),
      op(:-, [:time, :duration], "time_duration", :time, expr(tm - ^one_hour), [
        ~T[09:30:00],
        ~T[22:59:59],
        nil
      ]),
      op(:-, [:time, :time], "time_time", :integer, expr(tm - ^~T[10:00:00]), [
        1800,
        50_399,
        nil
      ]),
      op(:-, [:time_usec, :duration], "time_usec_duration", :time_usec, expr(tmu - ^one_hour), [
        ~T[09:30:00.123456],
        ~T[22:59:59.999999],
        nil
      ]),
      op(
        :-,
        [:time_usec, :time_usec],
        "time_usec_time_usec",
        :integer,
        expr(tmu - ^~T[10:00:00.000000]),
        [1800, 50_399, nil]
      )
    ]
  end

  # Time wraps at midnight: 23:59:59 plus an hour is 00:59:59.
  defp plus(one_day, one_hour) do
    next_day = [~D[2024-02-01], ~D[2024-03-01], nil]
    datetime = [~U[2024-01-31 11:30:00Z], ~U[2024-03-01 00:59:59Z], nil]
    usec = [~U[2024-01-31 11:30:00.123456Z], ~U[2024-03-01 00:59:59.999999Z], nil]
    naive = [~N[2024-01-31 11:30:00], ~N[2024-03-01 00:59:59], nil]
    time = [~T[11:30:00], ~T[00:59:59], nil]
    time_usec = [~T[11:30:00.123456], ~T[00:59:59.999999], nil]

    [
      op(:+, [:same, :any], "integer", :integer, expr(i + j), [10, -2, nil]),
      op(:+, [:date, :duration], "date_duration", :date, expr(day + ^one_day), next_day),
      op(:+, [:duration, :date], "duration_date", :date, expr(^one_day + day), next_day),
      op(
        :+,
        [:datetime, :duration],
        "datetime_duration",
        :datetime,
        expr(dt + ^one_hour),
        datetime
      ),
      op(
        :+,
        [:duration, :datetime],
        "duration_datetime",
        :datetime,
        expr(^one_hour + dt),
        datetime
      ),
      op(
        :+,
        [:utc_datetime, :duration],
        "utc_datetime_duration",
        :utc_datetime,
        expr(sec + ^one_hour),
        datetime
      ),
      op(
        :+,
        [:duration, :utc_datetime],
        "duration_utc_datetime",
        :utc_datetime,
        expr(^one_hour + sec),
        datetime
      ),
      op(
        :+,
        [:utc_datetime_usec, :duration],
        "usec_duration",
        :utc_datetime_usec,
        expr(at + ^one_hour),
        usec
      ),
      op(
        :+,
        [:duration, :utc_datetime_usec],
        "duration_usec",
        :utc_datetime_usec,
        expr(^one_hour + at),
        usec
      ),
      op(
        :+,
        [:naive_datetime, :duration],
        "naive_duration",
        :naive_datetime,
        expr(naive + ^one_hour),
        naive
      ),
      op(
        :+,
        [:duration, :naive_datetime],
        "duration_naive",
        :naive_datetime,
        expr(^one_hour + naive),
        naive
      ),
      op(:+, [:time, :duration], "time_duration", :time, expr(tm + ^one_hour), time),
      op(:+, [:duration, :time], "duration_time", :time, expr(^one_hour + tm), time),
      op(
        :+,
        [:time_usec, :duration],
        "time_usec_duration",
        :time_usec,
        expr(tmu + ^one_hour),
        time_usec
      ),
      op(
        :+,
        [:duration, :time_usec],
        "duration_time_usec",
        :time_usec,
        expr(^one_hour + tmu),
        time_usec
      )
    ]
  end
end
