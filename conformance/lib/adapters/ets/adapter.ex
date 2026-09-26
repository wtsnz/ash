# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Ets do
  @moduledoc """
  Ash's ETS data layer: the smallest complete adapter, and the worked example.

  It has no expectation records, so it runs only through probes and surveys,
  whose results are always unreviewed. Everything not defined here comes from
  `use Ash.Conformance.Adapter`.
  """
  use Ash.Conformance.Adapter, id: :ets, label: "Ash.DataLayer.Ets", package: :ash

  # Private tables belong to the calling process, which isolates each case.
  # Roles that share a SQL table share an ETS table, as views do in SQL.
  def resource_config(table) do
    {Ash.DataLayer.Ets,
     quote do
       ets do
         private?(true)
         table(unquote(String.to_atom(table)))
       end
     end}
  end

  # ETS cannot enforce uniqueness itself, so Ash checks identities first.
  def identity_options, do: [pre_check?: true]

  def setup!, do: :ok
  def checkout!, do: checkin!()

  # Drop this process's tables so the next case starts empty.
  def checkin! do
    for role <- Ash.Conformance.Adapter.roles(), resource = resource(role) do
      Ash.DataLayer.Ets.stop(resource)
      Process.delete({:ash_ets_table, Ash.DataLayer.Ets.Info.table(resource), nil})
    end

    :ok
  end
end

defmodule Ash.Conformance.Ets.Resources do
  @moduledoc "Every shared resource role, instantiated for Ash's ETS data layer."
  use Ash.Conformance.Resources, namespace: Ash.Conformance.Ets, adapter: Ash.Conformance.Ets
end
