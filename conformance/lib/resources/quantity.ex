# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Quantity do
  @moduledoc false
  use Ash.Type
  defstruct [:value, :unit]
  def constraints, do: [unit: [type: :atom, default: :units]]
  def storage_type(_), do: :integer
  def cast_input(value, constraints), do: cast_stored(value, constraints)
  def cast_stored(nil, _), do: {:ok, nil}
  def cast_stored(%__MODULE__{} = value, _), do: {:ok, value}

  def cast_stored(value, constraints) when is_integer(value),
    do: {:ok, %__MODULE__{value: value, unit: constraints[:unit]}}

  def cast_stored(_, _), do: :error
  def dump_to_native(%__MODULE__{value: value}, _), do: {:ok, value}
  def dump_to_native(value, _) when is_integer(value) or is_nil(value), do: {:ok, value}
end
