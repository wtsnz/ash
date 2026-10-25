# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

for layer <- Ash.Invariants.Layer.all() do
  name = layer.id() |> to_string() |> Macro.camelize()

  defmodule Module.concat(Ash.Invariants.Test, name) do
    use ExUnit.Case, async: true
    @layer layer
    @moduletag layer.id()

    for {id, _op, _shape} = c <- Ash.Invariants.cases(layer),
        relation <- Ash.Invariants.relations(c) do
      @check "#{id} #{relation}"
      test @check do
        Ash.Invariants.Test.verify!(@layer, @check, fn ->
          Ash.Invariants.check(@layer, unquote(id), unquote(relation))
        end)
      end
    end

    for {shape, group} <- Ash.Invariants.groups(layer) do
      @check "#{shape}/#{group} agrees"
      test @check do
        Ash.Invariants.Test.verify!(@layer, @check, fn ->
          Ash.Invariants.check_group(@layer, unquote(shape), unquote(group))
        end)
      end
    end
  end
end

defmodule Ash.Invariants.Test.Known do
  use ExUnit.Case, async: true

  test "every known failure has a kind" do
    kinds = Keyword.keys(Ash.Invariants.Known.kinds())

    for {kind, _layers, _patterns, reason} <- Ash.Invariants.Known.all(),
        do: assert(kind in kinds, reason)
  end
end
