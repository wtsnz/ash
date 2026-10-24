# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.Values do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:ac_readings, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:parent_id, :bigint)
      add(:amount, :decimal)
      add(:taken_on, :date)
      add(:taken_at, :utc_datetime_usec)
      add(:taken_time, :time)
    end
  end
end
