# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.Signatures do
  @moduledoc "The signature fixture's table, with the columns AshPostgres's and AshSqlite's generators choose."
  use Ecto.Migration

  def change do
    create table(:sig_rows, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:s, :text)
      add(:c, :citext)
      add(:i, :bigint)
      add(:j, :bigint)
      add(:f, :float)
      add(:d, :decimal)
      add(:day, :date)
      add(:at, :utc_datetime_usec)
      add(:sec, :utc_datetime)
      add(:dt, :utc_datetime)
      add(:naive, :naive_datetime)
      add(:tm, :time)
      add(:tmu, :time_usec)
      add(:strs, {:array, :text})
      add(:ints, {:array, :bigint})
      add(:m, :map)
      add(:flag, :boolean)
    end
  end
end

defmodule Ash.Conformance.SQL.Migrations.SignaturesPlain do
  @moduledoc """
  The signature table for databases without `citext` or arrays, such as
  MySQL. Only the reviewed data layers run the signature fixture, so this
  only has to exist.
  """
  use Ecto.Migration

  def change do
    create table(:sig_rows, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:s, :text)
      add(:c, :text)
      add(:i, :bigint)
      add(:j, :bigint)
      add(:f, :float)
      add(:d, :decimal)
      add(:day, :date)
      add(:at, :utc_datetime_usec)
      add(:sec, :utc_datetime)
      add(:dt, :utc_datetime)
      add(:naive, :naive_datetime)
      add(:tm, :time)
      add(:tmu, :time_usec)
      add(:strs, :map)
      add(:ints, :map)
      add(:m, :map)
      add(:flag, :boolean)
    end
  end
end
