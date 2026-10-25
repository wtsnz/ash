# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Csv do
  @moduledoc """
  AshCsv, which keeps each resource in a CSV file.

  AshCsv reads columns by position, so each resource lists its own attributes
  as its columns (`Ash.Conformance.Csv.Columns`). Roles with the same columns
  share their table's file. A view role with other columns, such as
  `tenant_child` over `ac_children`, gets its own file, and `persist!/3`
  copies seeded rows into it; writes through one role do not reach the other.
  """
  use Ash.Conformance.Adapter, id: :csv, label: "AshCsv", package: :ash_csv

  @dir Path.expand("../../tmp/csv", __DIR__)

  def resource_config(table) do
    {AshCsv.DataLayer,
     quote do
       csv do
         file(unquote(Path.join(@dir, table)))
         create?(true)
         header?(true)
       end
     end}
  end

  def resource_options, do: [extensions: [Ash.Conformance.Csv.Extension]]

  def notes,
    do: [
      "Each resource's `columns` are set to its own attributes. A role over a shared table with " <>
        "other columns gets its own file, and seeded rows are copied into it."
    ]

  # AshCsv does not enforce uniqueness in storage.
  def identity_options, do: [pre_check?: true]

  def setup! do
    File.mkdir_p!(@dir)
    Ash.Conformance.Resources.compile!(__MODULE__)
  end

  def checkout!, do: checkin!()

  def checkin! do
    File.rm_rf!(@dir)
    File.mkdir_p!(@dir)
    :ok
  end

  def persist!(role, rows, opts) do
    result = Ash.Seed.seed!(resource(role), rows, opts)

    for view <- views(role) do
      columns = AshCsv.DataLayer.Info.columns(resource(view))
      Ash.Seed.seed!(resource(view), Enum.map(rows, &Map.take(&1, columns)), opts)
    end

    result
  end

  # Roles over the same table whose columns, and so file, differ.
  defp views(role) do
    file = file(role)

    for view <- Ash.Conformance.Adapter.roles(),
        view != role,
        Code.ensure_loaded?(resource(view)),
        other = file(view),
        other != file and table(other) == table(file),
        do: view
  end

  defp file(role), do: AshCsv.DataLayer.Info.file(resource(role))
  defp table(file), do: file |> Path.basename() |> String.split("--") |> hd()
end

defmodule Ash.Conformance.Csv.Columns do
  @moduledoc false
  # Sets each resource's columns to its attributes, and names its file after
  # the table and those columns, before AshCsv builds its row parser.
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def after?(Ash.Resource.Transformers.BelongsToAttribute), do: true
  def after?(_), do: false

  def transform(dsl) do
    columns = dsl |> Ash.Resource.Info.attributes() |> Enum.map(& &1.name)
    file = "#{AshCsv.DataLayer.Info.file(dsl)}--#{:erlang.phash2(columns)}.csv"

    {:ok,
     dsl
     |> Transformer.set_option([:csv], :columns, columns)
     |> Transformer.set_option([:csv], :file, file)}
  end
end

defmodule Ash.Conformance.Csv.Extension do
  @moduledoc false
  use Spark.Dsl.Extension, transformers: [Ash.Conformance.Csv.Columns]
end
