# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.Expressions do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:ex_rows, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:a, :bigint)
      add(:b, :bigint)
      add(:f, :float)
      add(:d, :decimal)
      add(:s, :text)
      add(:t, :text)
      add(:day, :date)
      add(:at, :utc_datetime_usec)
    end
  end
end
