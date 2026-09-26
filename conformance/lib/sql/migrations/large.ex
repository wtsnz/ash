# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.Large do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:lg_rows, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:value, :bigint)
      add(:label, :text)
    end
  end
end
