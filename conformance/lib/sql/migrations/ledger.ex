# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.Ledger do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:dc_ledger, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:amount, :bigint)
    end
  end
end
