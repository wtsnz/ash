# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Gaps do
  @moduledoc """
  The project that owns each `GAPS.md` entry.

  The first owner is where the fix starts. Later owners also need changes, such
  as an adapter capability gate or context passed in by Ash. Decisions are
  semantic questions for Ash to settle before any adapter can implement them.
  Postgres defects are listed under AshSQL when its lateral strategy produces
  them.
  """

  @names %{ash: "Ash", ash_sql: "AshSQL", ash_postgres: "AshPostgres", ash_sqlite: "AshSQLite"}

  @gaps %{
    "root-kinds" => {:implementation, [:ash_sql, :ash_sqlite]},
    "root-relationship" => {:implementation, [:ash_sql]},
    "root-first" => {:implementation, [:ash_sql]},
    "many-to-many-paths" => {:implementation, [:ash_sql]},
    "parent-correlation" => {:implementation, [:ash_sql, :ash_sqlite]},
    "parent-through-load" => {:implementation, [:ash_sql, :ash]},
    "nested-parent" => {:implementation, [:ash_sql, :ash]},
    "manual" => {:implementation, [:ash_sql, :ash_sqlite]},
    "no-attributes" => {:implementation, [:ash_sql, :ash_sqlite]},
    "filter-dependencies" => {:implementation, [:ash_sql]},
    "filter-fanout" => {:implementation, [:ash_sql]},
    "record-identity" => {:implementation, [:ash_sql]},
    "sorted-distinct-reads" => {:implementation, [:ash_sqlite, :ash_sql]},
    "decimal-precision" => {:implementation, [:ash_sqlite]},
    "from-many" => {:implementation, [:ash_sql]},
    "default-sort" => {:implementation, [:ash_sql]},
    "unsorted-bounds" => {:implementation, [:ash_sql]},
    "root-bounds" => {:implementation, [:ash_sql]},
    "relationship-context" => {:implementation, [:ash]},
    "authorization-bounds" => {:implementation, [:ash, :ash_sql]},
    "prepared-query" => {:implementation, [:ash_sql]},
    "tenant-bypass" => {:implementation, [:ash_sql]},
    "path-multiplicity" => {:decision, [:ash]},
    "keyless-identity" => {:decision, [:ash]},
    "many-to-many-bounds-api" => {:decision, [:ash]},
    "unique-list-order" => {:decision, [:ash]}
  }

  def all, do: @gaps
  def ids, do: Map.keys(@gaps)
  def kind(id), do: @gaps |> Map.fetch!(id) |> elem(0)
  def owners(id), do: @gaps |> Map.fetch!(id) |> elem(1)
  def names(id), do: Enum.map(owners(id), &Map.fetch!(@names, &1))

  def id("GAPS.md#" <> id), do: id

  @doc "The owner line each `GAPS.md` section must contain."
  def owner_line(id) do
    label = if kind(id) == :decision, do: "Decision owner", else: "Owner"
    "#{label}: #{Enum.join(names(id), ", then ")}."
  end
end
