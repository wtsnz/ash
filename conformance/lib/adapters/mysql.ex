# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Mysql do
  @moduledoc """
  AshMysql over MySQL, through the shared SQL migrations and Ecto's sandbox.

  MySQL has no array column type, cannot index a `TEXT` column without a key
  length, and reads a bare `DECIMAL` as `DECIMAL(10,0)`. So the records table
  stores `tags` as JSON and `code` as a `VARCHAR`, and decimals are
  `DECIMAL(30,10)`: wide enough for the fixtures, while `AVG`, which adds
  four places, stays within the 34 digits Decimal parses by default. Every
  other table uses the shared migrations.
  """
  use Ash.Conformance.Adapter, id: :mysql, label: "AshMysql", package: :ash_mysql

  def repo, do: Ash.Conformance.MysqlRepo
  def manual_relationship, do: Ash.Conformance.Mysql.Manual

  def resource_config(table) do
    {AshMysql.DataLayer,
     quote do
       mysql do
         table(unquote(table))
         repo(Ash.Conformance.MysqlRepo)
       end
     end}
  end

  def setup! do
    Ash.Conformance.SQL.Database.setup!(repo(),
      replace: %{4 => Ash.Conformance.Mysql.Values, 6 => Ash.Conformance.Mysql.Records}
    )

    Ash.Conformance.Resources.compile!(__MODULE__)
  end

  def checkout!, do: Ecto.Adapters.SQL.Sandbox.checkout(repo())
  def checkin!, do: Ecto.Adapters.SQL.Sandbox.checkin(repo())
end

defmodule Ash.Conformance.MysqlRepo do
  @moduledoc false
  use AshMysql.Repo, otp_app: :ash_conformance
end

defmodule Ash.Conformance.Mysql.Manual do
  @moduledoc false
  use AshMysql.ManualRelationship
  use Ash.Conformance.SQL.Manual, prefix: :ash_mysql
end

defmodule Ash.Conformance.Mysql.Records do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:dc_records, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:code, :string, null: false)
      add(:name, :text)
      add(:quantity, :bigint)
      add(:price, :decimal, precision: 30, scale: 10)
      add(:ratio, :float)
      add(:active, :boolean)
      add(:status, :text)
      add(:born_on, :date)
      add(:seen_at, :utc_datetime_usec)
      add(:opens_at, :time)
      add(:external_id, :uuid)
      add(:tags, :json)
      add(:metadata, :map)
      add(:address, :map)
    end

    create(unique_index(:dc_records, [:code], name: :dc_records_code_index))
  end
end

defmodule Ash.Conformance.Mysql.Values do
  @moduledoc false
  use Ecto.Migration

  def change do
    create table(:ac_readings, primary_key: false) do
      add(:id, :bigint, primary_key: true)
      add(:parent_id, :bigint)
      add(:amount, :decimal, precision: 30, scale: 10)
      add(:taken_on, :date)
      add(:taken_at, :utc_datetime_usec)
      add(:taken_time, :time)
    end
  end
end
