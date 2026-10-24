# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.Policy do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:pc_docs, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:team_id, :bigint)
      add(:owner_id, :bigint)
      add(:status, :text)
      add(:title, :text)
    end

    create table(:pc_notes, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:doc_id, :bigint)
      add(:owner_id, :bigint)
      add(:team_id, :bigint)
      add(:status, :text)
      add(:score, :bigint)
      add(:secret, :text)
    end

    create table(:pc_members, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:doc_id, :bigint)
      add(:user_id, :bigint)
    end
  end
end
