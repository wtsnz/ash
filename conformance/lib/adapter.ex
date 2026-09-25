# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Adapter do
  @moduledoc """
  Database and resource configuration for the shared aggregate scenarios.

  Scenarios receive an adapter and ask it for a resource by role. They never
  branch on the adapter ID. Other data layers can implement this contract and
  provide the same fixture domain without depending on Ecto in the runner.
  """

  @callback id() :: atom()
  @callback resource(atom()) :: module()
  @callback custom_aggregate() :: module()
  @callback setup!() :: term()
  @callback checkout!() :: term()
  @callback checkin!() :: term()
  @callback profiles() :: [atom()]
  @callback persist!(atom(), [map()], keyword()) :: term()
  @callback instrumentation() :: module() | nil
  @callback benchmark_persist!(atom(), [map()]) :: term()
  @doc "Whether this integration provides the resources for a fixture."
  @callback fixture?(atom()) :: boolean()
  @doc "Expectation records by scenario ID, for every scenario in the adapter's profiles."
  @callback expectations() :: %{String.t() => term()}
  @doc """
  For an adapter from another repository: the data layer and its configuration
  block for one of the shared tables, e.g. `{MyDataLayer, quote(do: my_dl do table(...) end)}`.
  """
  @callback resource_config(table :: String.t()) :: {module(), Macro.t()}
  @doc "Options added to every shared identity, such as `pre_check?: true`."
  @callback identity_options() :: keyword()
  @optional_callbacks resource_config: 1, identity_options: 0

  @doc """
  Reviewed adapters: the built-in ones, plus any listed in config, so an
  adapter from another repository can join without editing this file:

      config :ash_conformance, adapters: [MyApp.Conformance.Adapter]
  """
  def all,
    do:
      [Ash.Conformance.Sqlite, Ash.Conformance.Postgres] ++
        Application.get_env(:ash_conformance, :adapters, [])

  @doc "Integrations with no expectation records; they run only as unreviewed surveys."
  def unreviewed,
    do: [Ash.Conformance.Ets] ++ Application.get_env(:ash_conformance, :unreviewed_adapters, [])

  def find!(name) do
    Enum.find(all() ++ unreviewed(), &(to_string(&1.id()) == name)) ||
      raise ArgumentError, "Unknown adapter: #{inspect(name)}"
  end

  def selected do
    requested = System.get_env("CONFORMANCE_ADAPTERS", "sqlite,postgres") |> String.split(",")
    known = Map.new(all(), &{to_string(&1.id()), &1})

    Enum.map(requested, fn name ->
      Map.get(known, String.trim(name)) ||
        raise ArgumentError, "Unknown adapter: #{inspect(name)}"
    end)
    |> Enum.uniq()
  end
end
