# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Columns do
  @moduledoc """
  The column type each SQL data layer's own migration generator gives an
  attribute, so tier-1 tables look like an application's would.

  `ash_sql/1` follows `migration_type/2` in AshPostgres's and AshSqlite's
  migration generators, which agree for every tier-1 type: strings are `text`,
  case-insensitive strings `citext`, integers `bigint`, UUIDs `uuid`, and
  anything else is Ash's storage type.
  """

  def ash_sql(%{type: type, constraints: constraints}), do: ash_sql(type, constraints)

  defp ash_sql({:array, type}, constraints),
    do: {:array, ash_sql(type, Keyword.get(constraints, :items, []))}

  defp ash_sql(Ash.Type.CiString, _), do: :citext
  defp ash_sql(type, _) when type in [Ash.Type.UUID, Ash.Type.UUIDv7], do: :uuid
  defp ash_sql(Ash.Type.Integer, _), do: :bigint

  defp ash_sql(type, constraints) do
    case Ash.Type.storage_type(type, constraints) do
      :string -> :text
      :ci_string -> :citext
      storage_type -> storage_type
    end
  end
end
