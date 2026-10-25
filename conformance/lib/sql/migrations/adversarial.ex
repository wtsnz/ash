# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Migrations.Adversarial do
  @moduledoc """
  The adversarial scenarios' tables, with the unique indexes AshPostgres's
  migration generator writes for their identities: tenant-scoped ones
  include `org_id`, the all-tenants `code` doesn't. Only adapters that run
  the adversarial fixture add it to their migrations.
  """
  use Ecto.Migration

  def change do
    create table(:adv_events, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:name, :text)
    end

    create table(:adv_customers, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:name, :text)
    end

    create table(:adv_orders, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:org_id, :bigint)
      add(:event_id, :bigint)
      add(:customer_id, :bigint)
      add(:visible, :boolean)
    end

    create(
      unique_index(:adv_orders, [:org_id, :event_id, :customer_id],
        name: :adv_orders_one_per_event_index
      )
    )

    create table(:adv_notes, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:org_id, :bigint, null: false)
      add(:local_id, :bigint, null: false)
      add(:code, :text, null: false)
      add(:body, :text)
      add(:value, :bigint)
      add(:list_id, :bigint)
      add(:visible, :boolean)
    end

    create(unique_index(:adv_notes, [:org_id, :local_id], name: :adv_notes_local_id_index))
    create(unique_index(:adv_notes, [:code], name: :adv_notes_code_index))

    create table(:adv_lists, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:org_id, :bigint, null: false)
      add(:name, :text)
    end

    create table(:adv_people, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:name, :text)
      add(:secret, :text)
      add(:event_id, :bigint)
      add(:profile, :map)
      add(:cards, {:array, :map})
      add(:payment, :map)
    end
  end
end

defmodule Ash.Conformance.SQL.Migrations.AdversarialContext do
  @moduledoc "Orders in each tenant's schema, for the schema-based adversarial scenarios."
  use Ecto.Migration

  def change do
    for schema <- ["dc_tenant_a", "dc_tenant_b"] do
      create table(:adv_orders, primary_key: false, prefix: schema) do
        add(:id, :bigint, primary_key: true)
        add(:event_id, :bigint)
        add(:customer_id, :bigint)
        add(:visible, :boolean)
      end

      create(
        unique_index(:adv_orders, [:event_id, :customer_id],
          prefix: schema,
          name: :adv_orders_one_per_event_index
        )
      )
    end
  end
end
