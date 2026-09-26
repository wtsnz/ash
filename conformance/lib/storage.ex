# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Storage do
  @moduledoc """
  Tier 1: can the data layer store each Ash type and give it back unchanged?

  Every type has its own resource (`id` plus `value`) and its own table, so a
  type the data layer cannot store fails only its own cells, never a shared
  fixture. Each cell is one type with one class of values:

  - `ordinary`: values any application stores, which later tiers rely on;
  - `edge`: extremes such as int64 bounds, microseconds, unicode, empty values;
  - `null`: nil.

  A cell goes through the resource's own actions: create, a fresh read,
  update, and update to nil. The observation records each step as `:ok`,
  `{:changed, value}` (equal by the type's own `equal?/2`, but a different
  representation, such as `1.5` read back as `1.5000000000`), `{:lost, value}`,
  `{:error, message}` or `:skipped` after an earlier failure.

  Tables are created one at a time by the adapter (`provision/2`), using the
  column type the data layer's own migration generator would choose. A table
  that cannot be created fails its cells with the reason.
  """
  alias Ash.Conformance.Compare

  @address Ash.Conformance.Resources.Address
  @text [trim?: false, allow_empty?: true]

  @types [
    %{
      name: :integer,
      label: "Integers",
      type: :integer,
      ordinary: [1, -7, 0],
      edge: [9_223_372_036_854_775_807, -9_223_372_036_854_775_808]
    },
    %{
      name: :float,
      label: "Floats",
      type: :float,
      ordinary: [1.5, -0.25],
      edge: [1.0e300, -1.0e-300, 0.30000000000000004]
    },
    %{
      name: :decimal,
      label: "Decimals",
      type: :decimal,
      ordinary: [Decimal.new("1.5"), Decimal.new("-20.25")],
      edge: [Decimal.new("12345678901234567.89"), Decimal.new("0.000001"), Decimal.new("100")]
    },
    %{
      name: :string,
      label: "Strings",
      type: :string,
      constraints: @text,
      ordinary: ["apple", "Banana"],
      edge: [
        "",
        "  padded  ",
        "Ünïcode ✓ 日本",
        "it's \"quoted\"\nnew line\ttab",
        String.duplicate("x", 1000),
        "nul\0byte"
      ]
    },
    %{
      name: :ci_string,
      label: "Case-insensitive strings",
      type: :ci_string,
      constraints: @text,
      ordinary: ["Hello", "world"],
      edge: ["ÜNÏCODE ✓", ""]
    },
    %{
      name: :binary,
      label: "Binaries",
      type: :binary,
      ordinary: [<<1, 2, 3>>, "text"],
      edge: [<<0, 255, 0, 128>>, ""]
    },
    %{name: :boolean, label: "Booleans", type: :boolean, ordinary: [true, false], edge: []},
    %{
      name: :atom,
      label: "Atoms with one_of",
      type: :atom,
      constraints: [one_of: [:red, :green, :blue]],
      ordinary: [:red, :green],
      edge: []
    },
    %{
      name: :date,
      label: "Dates",
      type: :date,
      ordinary: [~D[2024-02-29], ~D[1999-12-31]],
      edge: [~D[0001-01-01], ~D[9999-12-31]]
    },
    %{
      name: :time,
      label: "Times",
      type: :time,
      ordinary: [~T[12:34:56], ~T[08:00:00]],
      edge: [~T[00:00:00], ~T[23:59:59]]
    },
    %{
      name: :time_usec,
      label: "Microsecond times",
      type: :time_usec,
      ordinary: [~T[12:34:56.123456], ~T[08:00:00.000000]],
      edge: [~T[23:59:59.999999], ~T[00:00:00.000001]]
    },
    %{
      name: :utc_datetime,
      label: "UTC datetimes",
      type: :utc_datetime,
      ordinary: [~U[2024-02-29 12:34:56Z], ~U[1999-12-31 23:59:59Z]],
      edge: [~U[1970-01-01 00:00:00Z], ~U[2999-12-31 23:59:59Z]]
    },
    %{
      name: :utc_datetime_usec,
      label: "Microsecond UTC datetimes",
      type: :utc_datetime_usec,
      ordinary: [~U[2024-02-29 12:34:56.123456Z], ~U[1999-12-31 23:59:59.000000Z]],
      edge: [~U[1999-12-31 23:59:59.999999Z], ~U[1970-01-01 00:00:00.000001Z]]
    },
    %{
      name: :naive_datetime,
      label: "Naive datetimes",
      type: :naive_datetime,
      ordinary: [~N[2024-02-29 12:34:56], ~N[1999-12-31 23:59:59]],
      edge: [~N[0001-01-01 00:00:00], ~N[9999-12-31 23:59:59]]
    },
    %{
      name: :duration,
      label: "Durations",
      type: :duration,
      ordinary: [Duration.new!(hour: 1, minute: 30), Duration.new!(day: 2)],
      edge: [Duration.new!(year: 1, month: 2, day: 3, hour: 4), Duration.new!(second: -5)]
    },
    %{
      name: :uuid,
      label: "UUIDs",
      type: :uuid,
      ordinary: ["5f3c2a1e-8b7d-4c6e-9a0b-1c2d3e4f5a6b", "0b9e1d4c-2f3a-4b5c-8d6e-7f8091a2b3c4"],
      edge: ["00000000-0000-0000-0000-000000000000", "ffffffff-ffff-ffff-ffff-ffffffffffff"]
    },
    %{
      name: :uuid_v7,
      label: "UUIDv7s",
      type: :uuid_v7,
      ordinary: ["01920d4e-6b1a-7c2d-8e3f-4a5b6c7d8e9f", "01920d4e-6b1b-7000-8000-000000000001"],
      edge: []
    },
    %{
      name: :map,
      label: "Maps",
      type: :map,
      ordinary: [%{"a" => 1, "b" => "x"}, %{"c" => [1, 2]}],
      edge: [%{}, %{"nested" => %{"list" => [1, "two", nil], "flag" => true}, "unicode" => "✓"}]
    },
    %{
      name: :strings,
      label: "Arrays of strings",
      type: {:array, :string},
      constraints: [items: @text],
      ordinary: [["b", "a", "b"], ["c"]],
      edge: [[], ["", " x ", "✓"]]
    },
    %{
      name: :integers,
      label: "Arrays of integers",
      type: {:array, :integer},
      ordinary: [[3, 1, 2], [4]],
      edge: [[], [9_223_372_036_854_775_807]]
    },
    %{
      name: :embedded,
      label: "Embedded resources",
      type: @address,
      ordinary: [%{city: "Auckland", zip: "1010"}, %{city: "Wellington", zip: nil}],
      edge: [%{city: "Ōtautahi ✓", zip: ""}]
    },
    %{
      name: :embeddeds,
      label: "Arrays of embedded resources",
      type: {:array, @address},
      ordinary: [
        [%{city: "Auckland", zip: "1010"}, %{city: "Wellington", zip: nil}],
        [%{city: "Dunedin", zip: "9016"}]
      ],
      edge: [[]]
    },
    %{
      name: :union,
      label: "Unions",
      type: :union,
      constraints: [
        types: [int: [type: :integer], text: [type: :string]],
        storage: :type_and_value
      ],
      ordinary: [%Ash.Union{type: :int, value: 5}, %Ash.Union{type: :text, value: "five"}],
      edge: []
    }
  ]

  @classes [:ordinary, :edge, :null]

  def types, do: Enum.map(@types, &Map.put_new(&1, :constraints, []))
  def classes, do: @classes
  def fetch!(name), do: Enum.find(types(), &(&1.name == name)) || raise("Unknown type #{name}")

  @doc "The resource role and table for a type."
  def role(name), do: :"storage_#{name}"
  def table(name), do: "st_#{name}"
  def roles, do: Enum.map(types(), &role(&1.name))

  @doc "The cells a type has: every class that has values."
  def cells(type), do: Enum.filter(@classes, &(&1 == :null or values(type, &1) != []))

  def values(_type, :null), do: [nil]
  def values(type, class), do: Map.fetch!(type, class)

  def scenario_id(name, class), do: "storage.#{name}.#{class}"

  @doc "The storage cells a scenario requires: each named type's cell of `class`."
  def stored(names, class \\ :ordinary),
    do: Enum.map(List.wrap(names), &scenario_id(fetch!(&1).name, class))

  @doc """
  The cell a stored value depends on: the ordinary cell of its attribute's
  type, or the null cell for nil. Nil when tier 1 has no such type. Edge
  cells are never used: a fixture's values are ordinary unless a scenario
  says otherwise, and an edge failure such as a NUL byte would blame the
  wrong cause.
  """
  def cell(attribute, value) do
    type = resolve(attribute.type)

    case Enum.find(types(), &(resolve(&1.type) == type)) do
      nil -> nil
      %{name: name} -> scenario_id(name, if(is_nil(value), do: :null, else: :ordinary))
    end
  end

  # Any embedded resource is stored as the embedded cell's `Address` is.
  defp resolve({:array, type}), do: {:array, resolve(type)}

  defp resolve(type) do
    type = Ash.Type.get_type(type)

    cond do
      Ash.Type.embedded_type?(type) -> :embedded
      Ash.Type.NewType.new_type?(type) -> resolve(Ash.Type.NewType.subtype_of(type))
      true -> type
    end
  end

  @doc "The intended observation: every step returns the value unchanged."
  def expected(:null), do: [create: :ok, read: :ok]
  def expected(_class), do: [create: :ok, read: :ok, update: :ok, clear: :ok]

  @doc """
  Creates each type's table with `create`, one at a time, and records the
  column type or the reason it failed. `create` returns `{:ok, column}`.
  """
  def provision(adapter, create) do
    results =
      Map.new(types(), fn type ->
        result =
          try do
            create.(type)
          rescue
            exception -> {:error, Ash.Conformance.Fixtures.reason(exception)}
          end

        {type.name, result}
      end)

    :persistent_term.put({__MODULE__, adapter}, results)
  end

  @doc """
  `{:ok, column}`, `{:error, reason}` or `{:error, reason, column}` (the column
  that could not be created), or nil if the adapter provisions nothing.
  """
  def provisioned(adapter, name),
    do: :persistent_term.get({__MODULE__, adapter}, %{}) |> Map.get(name)

  @doc "Runs one cell and returns its observation."
  def round_trip(adapter, name, class) do
    type = fetch!(name)

    case provisioned(adapter, name) do
      {:error, reason} -> [table: {:error, reason}]
      {:error, reason, _column} -> [table: {:error, reason}]
      _ -> steps(adapter.resource(role(name)), values(type, class), class)
    end
  end

  defp steps(resource, values, class) do
    attribute = Ash.Resource.Info.attribute(resource, :value)
    ids = Enum.to_list(1..length(values))
    # Update moves each value to the next row, so updates use the same class.
    rotated = tl(values) ++ [hd(values)]

    plan = [
      create: fn ->
        Enum.each(Enum.zip(ids, values), fn {id, value} ->
          Ash.create!(resource, %{id: id, value: value}, authorize?: false)
        end)
      end,
      read: fn -> check(resource, attribute, values) end,
      update: fn ->
        update_all(resource, rotated)
        check(resource, attribute, rotated)
      end,
      clear: fn ->
        update_all(resource, [nil | tl(rotated)])
        check(resource, attribute, [nil | tl(rotated)])
      end
    ]

    plan
    |> Enum.take(if class == :null, do: 2, else: 4)
    |> Enum.map_reduce(:ok, fn
      {step, _run}, :failed ->
        {{step, :skipped}, :failed}

      {step, run}, :ok ->
        result =
          try do
            case run.() do
              :ok -> :ok
              {tag, _} = result when tag in [:changed, :lost] -> result
            end
          rescue
            exception -> {:error, Ash.Conformance.Fixtures.reason(exception)}
          end

        {{step, result}, if(result == :ok, do: :ok, else: :failed)}
    end)
    |> elem(0)
  end

  defp update_all(resource, values) do
    resource
    |> read!()
    |> Enum.zip(values)
    |> Enum.each(fn {record, value} ->
      Ash.update!(record, %{value: value}, authorize?: false)
    end)
  end

  defp read!(resource) do
    resource |> Ash.Query.sort(:id) |> Ash.read!(authorize?: false)
  end

  # A fresh read of every row, compared value by value with what was written.
  defp check(resource, attribute, values) do
    got = resource |> read!() |> Enum.map(& &1.value)

    if length(got) != length(values) do
      {:lost, got}
    else
      values
      |> Enum.zip(got)
      |> Enum.map(fn {value, read} -> compare(attribute, value, read) end)
      |> Enum.find(:ok, &(&1 != :ok))
    end
  end

  @doc """
  Whether `got` is `want` for an attribute by the type's own equality, in any
  representation. Tier 1 reports representation; later tiers only need the
  value.
  """
  def same?(attribute, want, got), do: compare(attribute, want, got) != {:lost, got}

  defp compare(_attribute, nil, nil), do: :ok
  defp compare(_attribute, nil, got), do: {:lost, got}

  defp compare(attribute, value, got) do
    {:ok, want} = Ash.Type.cast_input(attribute.type, value, attribute.constraints)

    cond do
      Compare.equal?(normalize(want), normalize(got)) -> :ok
      got != nil and same_value?(attribute.type, want, got) -> {:changed, got}
      true -> {:lost, got}
    end
  end

  # The same value in another representation: more fractional digits, or a
  # CiString read back as a plain string. A different type, such as a string
  # for a date, is not the same value.
  defp same_value?(type, want, got) do
    Ash.Type.equal?(type, want, got) or equivalent?(want, got)
  end

  defp equivalent?(%DateTime{} = a, %DateTime{} = b), do: DateTime.compare(a, b) == :eq

  defp equivalent?(%NaiveDateTime{} = a, %NaiveDateTime{} = b),
    do: NaiveDateTime.compare(a, b) == :eq

  defp equivalent?(%Time{} = a, %Time{} = b), do: Time.compare(a, b) == :eq
  defp equivalent?(%Decimal{} = a, %Decimal{} = b), do: Decimal.equal?(a, b)

  defp equivalent?(%Duration{} = a, %Duration{} = b),
    do: without_precision(a) == without_precision(b)

  defp equivalent?(a, b) when is_list(a) and is_list(b),
    do:
      length(a) == length(b) and
        Enum.all?(Enum.zip(a, b), fn {x, y} -> x == y or equivalent?(x, y) end)

  defp equivalent?(_a, _b), do: false

  defp without_precision(%Duration{microsecond: {microseconds, _precision}} = duration),
    do: %{duration | microsecond: microseconds}

  # Embedded records carry metadata; only their attribute values are stored.
  defp normalize(%Ash.Union{type: type, value: value}), do: {:union, type, normalize(value)}
  defp normalize(list) when is_list(list), do: Enum.map(list, &normalize/1)

  defp normalize(%module{} = struct) do
    if Ash.Resource.Info.resource?(module) do
      names = module |> Ash.Resource.Info.attributes() |> Enum.map(& &1.name)
      struct |> Map.take(names) |> Map.new(fn {key, value} -> {key, normalize(value)} end)
    else
      struct
    end
  end

  defp normalize(value), do: value

  @doc """
  A JSON-friendly summary of a cell's observation, for reports: the result,
  the first step that did not return the value unchanged, a short note, and
  the column type the table was created with.
  """
  def detail(adapter, name, outcome) do
    column =
      case provisioned(adapter, name) do
        {:ok, column} -> column
        {:error, _reason, column} -> column
        _ -> nil
      end

    Map.put(summarize(outcome), :column, column)
  end

  defp summarize({:ok, [table: {:error, reason}]}),
    do: %{result: "no_table", step: "table", note: reason}

  defp summarize({:ok, observed}) do
    case Enum.find(observed, fn {_step, result} -> result not in [:ok, :skipped] end) do
      nil -> %{result: "ok", step: nil, note: nil}
      {step, {:changed, got}} -> %{result: "changed", step: to_string(step), note: short(got)}
      {step, {:lost, got}} -> %{result: "lost", step: to_string(step), note: short(got)}
      {step, {:error, message}} -> %{result: "error", step: to_string(step), note: message}
    end
  end

  defp summarize({:error, _exception, message}),
    do: %{result: "error", step: "run", note: message |> String.split("\n") |> hd()}

  defp summarize({:order_dependent, _}),
    do: %{result: "order_dependent", step: nil, note: "differs between seed orders"}

  defp short(value), do: value |> inspect(limit: 5, printable_limit: 60) |> String.slice(0, 120)
end
