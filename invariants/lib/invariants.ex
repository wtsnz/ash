# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Invariants do
  @moduledoc """
  Runs each operation (`Ash.Invariants.Ops`) under each layer and shape, and
  checks what must hold whatever the data layer:

  - `isolation`: the answer with every row stored is the answer with only the
    rows the actor may see. Reads run as organisation 1 then 2, and 2 then 1,
    so a statement cached for one tenant shows up in the other's answer.
  - `untouched`: after a write, every row the actor may not see is unchanged.
  - `expected`: with only the rows the actor may see, the answer is the
    group's intended answer from the fixture.
  - `noninterference`: changing only values the actor may not see (the
    `:altered` fixture) doesn't change the answer.
  - `secrets`: no answer contains a value marked `SECRET`.
  - `agrees`: the operations in a group give the same answer.

  Observations are cached, so each relation of a case reuses one run.
  """
  alias Ash.Invariants.{Layer, Ops, World}

  @doc "Every case for a layer, as `{id, op, shape}`, with ids like `tenant/load.m2m`."
  def cases(layer) do
    for op <- Ops.all(),
        shape <- op.shapes,
        shape in layer.shapes(),
        :through not in op.needs or layer.through?(),
        do: {"#{shape}/#{op.id}", op, shape}
  end

  @doc "The relations a case checks."
  def relations({_id, op, shape}) do
    [
      if(op.isolation?, do: :isolation),
      if(op.kind == :write, do: :untouched),
      if(Ops.expected(op.group, {shape, 1}) != nil, do: :expected),
      :noninterference,
      :secrets
    ]
    |> Enum.reject(&is_nil/1)
  end

  @doc "Every group a layer runs, as `{shape, group}`, with more than one operation."
  def groups(layer) do
    layer
    |> cases()
    |> Enum.group_by(fn {_id, op, shape} -> {shape, op.group} end)
    |> Enum.filter(fn {_key, cases} -> length(cases) > 1 end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  @doc "Checks one relation of a case: `:ok`, or `{:error, message}`."
  def check(layer, id, relation) do
    {^id, op, shape} = Enum.find(cases(layer), &(elem(&1, 0) == id))
    observation = observe(layer, op, shape)
    verdict(relation, op, shape, observation)
  end

  @doc "Checks that a group's operations agree in the full database."
  def check_group(layer, shape, group) do
    # Reads compare each organisation's answer from the first full run.
    answers =
      for {id, op, ^shape} <- cases(layer), op.group == group do
        observation = observe(layer, op, shape)

        case op.kind do
          :read -> {id, op, Enum.map([1, 2], &Map.fetch!(hd(observation.full), &1))}
          :write -> {id, op, [observation.full]}
        end
      end
      # Client input that is refused outright answers no question.
      |> Enum.reject(fn {_id, op, answer} -> op.refusable? and Enum.all?(answer, &refused?/1) end)
      |> Enum.map(fn {id, _op, answer} -> {id, answer} end)

    case Enum.uniq_by(answers, fn {_id, answer} -> Enum.map(answer, &comparable/1) end) do
      [_] -> :ok
      _ -> {:error, "the operations disagree:\n" <> Enum.map_join(answers, "\n", &line/1)}
    end
  end

  defp verdict(:isolation, %{kind: :read}, _shape, observation) do
    failures =
      for {full, run} <- Enum.zip(observation.full, ["1 then 2", "2 then 1"]),
          org <- [1, 2],
          not same?(full[org], observation.clean[org]) do
        "organisation #{org} (run #{run}): with every row #{show(full[org])}, " <>
          "with only its own #{show(observation.clean[org])}"
      end

    result(failures)
  end

  defp verdict(:isolation, _op, _shape, observation) do
    if same?(observation.full, observation.clean),
      do: :ok,
      else:
        {:error,
         "with every row #{show(observation.full)}, with only the actor's #{show(observation.clean)}"}
  end

  defp verdict(:untouched, _op, _shape, %{hidden_before: same, hidden_after: same}), do: :ok

  defp verdict(:untouched, _op, _shape, observation) do
    changed =
      for {table, before} <- observation.hidden_before,
          now = Map.fetch!(observation.hidden_after, table),
          before != now,
          do: "#{table}: before #{show(before)}, after #{show(now)}"

    {:error, "rows the actor can't see changed:\n" <> Enum.join(changed, "\n")}
  end

  defp verdict(:expected, %{kind: :read} = op, shape, observation) do
    failures =
      for org <- [1, 2],
          expected = Ops.expected(op.group, {shape, org}),
          not intended?(op, observation.clean[org], expected) do
        "organisation #{org}: expected #{show(expected)}, got #{show(observation.clean[org])}"
      end

    result(failures)
  end

  defp verdict(:expected, op, shape, observation) do
    expected = Ops.expected(op.group, {shape, 1})
    answer = observation.clean || observation.full

    if intended?(op, answer, expected),
      do: :ok,
      else: {:error, "expected #{show(expected)}, got #{show(answer)}"}
  end

  defp verdict(:noninterference, %{kind: :read}, _shape, observation) do
    failures =
      for org <- [1, 2],
          not same?(hd(observation.full)[org], observation.altered[org]) do
        "organisation #{org}: #{show(hd(observation.full)[org])}, " <>
          "and with other hidden values #{show(observation.altered[org])}"
      end

    result(failures)
  end

  defp verdict(:noninterference, _op, _shape, observation) do
    if same?(observation.full, observation.altered),
      do: :ok,
      else:
        {:error,
         "#{show(observation.full)}, and with other hidden values #{show(observation.altered)}"}
  end

  defp verdict(:secrets, _op, _shape, observation) do
    answers = [observation.full, observation.clean, observation.altered]
    shown = inspect(answers, limit: :infinity, printable_limit: :infinity)

    if String.contains?(shown, "SECRET"),
      do: {:error, "the answer shows an admin-only value: #{show(observation.full)}"},
      else: :ok
  end

  # The intended answer, or for client input also a refusal.
  defp intended?(op, answer, expected),
    do: same?(answer, {:ok, expected}) or (op.refusable? and refused?(answer))

  defp refused?(answer), do: match?({:raised, Ash.Error.Invalid, _}, answer)

  defp result([]), do: :ok
  defp result(failures), do: {:error, Enum.join(failures, "\n")}

  # Observations

  @doc """
  Runs a case, cached for the test run: reads as each organisation with only
  its own rows, then with every row in both orders; writes as organisation 1
  with only its rows (unless `isolation?` is false) and with every row,
  snapshotting the rest around the write. Both also run once more with every
  row and the `:altered` hidden values.
  """
  def observe(layer, op, shape) do
    key = {layer, op.id, shape}

    case :ets.lookup(__MODULE__, key) do
      [{^key, observation}] ->
        observation

      [] ->
        observation = run(layer, op, shape)
        :ets.insert(__MODULE__, {key, observation})
        observation
    end
  end

  @doc "Creates the observation cache; the calling process owns it."
  def start_cache, do: :ets.new(__MODULE__, [:named_table, :public, :set])

  defp run(layer, %{kind: :read} = op, shape) do
    clean =
      Map.new([1, 2], fn org ->
        {org,
         in_world(layer, World.visible({shape, org}), fn -> capture(layer, op, shape, org) end)}
      end)

    full =
      for orgs <- [[1, 2], [2, 1]] do
        in_world(layer, World.rows(), fn ->
          Map.new(orgs, &{&1, capture(layer, op, shape, &1)})
        end)
      end

    altered =
      in_world(layer, World.rows(:altered), fn ->
        Map.new([1, 2], &{&1, capture(layer, op, shape, &1)})
      end)

    %{clean: clean, full: full, altered: altered}
  end

  defp run(layer, op, shape) do
    view = {shape, 1}

    clean =
      if op.isolation?,
        do: in_world(layer, World.visible(view), fn -> capture(layer, op, shape, 1) end)

    {full, before, now} =
      in_world(layer, World.rows(), fn ->
        before = World.hidden(view, World.snapshot(layer))
        answer = capture(layer, op, shape, 1)
        {answer, before, World.hidden(view, World.snapshot(layer))}
      end)

    altered = in_world(layer, World.rows(:altered), fn -> capture(layer, op, shape, 1) end)

    %{clean: clean, full: full, altered: altered, hidden_before: before, hidden_after: now}
  end

  defp in_world(layer, rows, fun) do
    layer.isolated(fn ->
      World.seed!(layer, rows)
      fun.()
    end)
  end

  defp capture(layer, op, shape, org) do
    context = %{
      layer: layer,
      shape: shape,
      org: org,
      tenant: World.tenant(shape, org),
      view: {shape, org},
      role: &Layer.resource(layer, &1)
    }

    {:ok, op.run.(context)}
  rescue
    exception ->
      {:raised, exception.__struct__, exception |> Exception.message() |> first_line()}
  end

  defp first_line(message), do: message |> String.split("\n", parts: 2) |> hd()

  # Two answers are the same when equal, or when both raised the same exception.
  defp same?(left, right), do: comparable(left) == comparable(right)

  defp comparable({:raised, module, _message}), do: {:raised, module}
  defp comparable(answer), do: answer

  # An answer as captured, or any other value.
  defp show({:ok, value}), do: inspect(value, charlists: :as_lists, limit: 50)
  defp show({:raised, module, message}), do: "raised #{inspect(module)}: #{message}"
  defp show(value), do: inspect(value, charlists: :as_lists, limit: 50)

  defp line({id, answers}), do: "  #{id}: " <> Enum.map_join(answers, " | ", &show/1)
end
