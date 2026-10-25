# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

for layer <- Ash.Invariants.Layer.all(), do: layer.setup!()
Ash.Invariants.start_cache()
ExUnit.start(timeout: :infinity)

defmodule Ash.Invariants.Test do
  @moduledoc false
  import ExUnit.Assertions

  @doc "Runs a check, and fails it unless its outcome is the one `Known` records."
  def verify!(layer, check, fun) do
    case {fun.(), Ash.Invariants.Known.reason(layer.id(), check)} do
      {:ok, nil} -> :ok
      {{:error, message}, nil} -> flunk(message)
      {{:error, _message}, _reason} -> :ok
      {:ok, reason} -> flunk("passes now; remove it from Ash.Invariants.Known (#{reason})")
    end
  end
end
