# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.Combination do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:cb_owners, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:label, :text)
    end

    create table(:cb_items, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:owner_id, :bigint)
      add(:tenant, :text)
      add(:value, :bigint)
      add(:status, :text)
      add(:seen_by, :bigint)
    end

    create table(:cb_links, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:owner_id, :bigint)
      add(:item_id, :bigint)
    end
  end
end
