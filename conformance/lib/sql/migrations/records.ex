# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.Records do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:dc_records, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:code, :text, null: false)
      add(:name, :text)
      add(:quantity, :bigint)
      add(:price, :decimal)
      add(:ratio, :float)
      add(:active, :boolean)
      add(:status, :text)
      add(:born_on, :date)
      add(:seen_at, :utc_datetime_usec)
      add(:opens_at, :time)
      add(:external_id, :uuid)
      add(:tags, {:array, :text})
      add(:metadata, :map)
      add(:address, :map)
    end

    create(unique_index(:dc_records, [:code], name: :dc_records_code_index))
  end
end
