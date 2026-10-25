# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.Shapes do
  @moduledoc "The shapes grid's tables: roots, and integer- and UUID-keyed mids, leaves and tips."
  use Ecto.Migration

  def change do
    create table(:shape_roots, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:label, :text)
    end

    for {key, type} <- [integer: :bigint, uuid: :uuid] do
      create table(:"shape_#{key}_mids", primary_key: false) do
        add(:id, type, primary_key: true)
        add(:root_id, :bigint)
        add(:value, :bigint)
      end

      create table(:"shape_#{key}_leaves", primary_key: false) do
        add(:id, type, primary_key: true)
        add(:mid_id, type)
        add(:value, :bigint)
      end

      create table(:"shape_#{key}_tips", primary_key: false) do
        add(:id, type, primary_key: true)
        add(:leaf_id, type)
        add(:value, :bigint)
      end
    end
  end
end
