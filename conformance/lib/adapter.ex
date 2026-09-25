# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Adapter do
  @moduledoc """
  How a data layer joins the suite: its resources, storage lifecycle and records.

  Scenarios receive an adapter and ask it for a resource by role. They never
  branch on the adapter ID. `use Ash.Conformance.Adapter` supplies defaults for
  everything except storage and resource configuration; see `AUTHORING.md`.
  """

  @callback id() :: atom()
  @doc "Display name for reports, such as `AshSqlite`."
  @callback label() :: String.t()
  @doc "The OTP application providing the data layer, for its version in reports."
  @callback package() :: atom()
  @callback resource(atom()) :: module()
  @callback custom_aggregate() :: module()
  @doc "The manual relationship implementation for the `manual_children` relationship."
  @callback manual_relationship() :: module()
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
  The data layer and its configuration block for one of the shared tables,
  e.g. `{MyDataLayer, quote(do: my_dl do table(...) end)}`.
  """
  @callback resource_config(table :: String.t()) :: {module(), Macro.t()}
  @doc "Options added to every shared identity, such as `pre_check?: true`."
  @callback identity_options() :: keyword()

  @doc """
  Reviewed adapters, from config. The suite names no adapter itself, so the
  shipped ones and one from another repository join the same way:

      config :ash_conformance, adapters: [MyApp.Conformance.Adapter]
  """
  def all, do: Application.get_env(:ash_conformance, :adapters, [])

  @doc "Adapters with no expectation records, from config; they run only as unreviewed surveys."
  def unreviewed, do: Application.get_env(:ash_conformance, :unreviewed_adapters, [])

  @doc "Every registered adapter, reviewed first, as the ecosystem report lists them."
  def every, do: all() ++ unreviewed()

  def reviewed?(adapter), do: adapter in all()

  @doc """
  The shared resource roles, and for each shared table the role that has every
  column. Adapters use these to provision and clear storage.
  """
  def roles,
    do: ~w(parent child rating tag link child_tag event reading tenant_child tenant_link
          authorized_child ledger record tenant_parent tenant_item secure_parent secure_item
          context_parent context_item)a

  def table_roles,
    do: ~w(parent child rating tag link child_tag event reading ledger record tenant_parent
          tenant_item)a

  def find!(name) do
    Enum.find(every(), &(to_string(&1.id()) == name)) ||
      raise ArgumentError, "Unknown adapter: #{inspect(name)}"
  end

  @doc """
  Adapters to run, from `from` (the reviewed ones by default): all of them, or
  those named in `CONFORMANCE_ADAPTERS`.
  """
  def selected(from \\ all()) do
    case System.get_env("CONFORMANCE_ADAPTERS") do
      nil ->
        from

      requested ->
        known = Map.new(from, &{to_string(&1.id()), &1})

        requested
        |> String.split(",")
        |> Enum.map(fn name ->
          Map.get(known, String.trim(name)) ||
            raise ArgumentError, "Unknown adapter: #{inspect(name)}"
        end)
        |> Enum.uniq()
    end
  end

  @doc """
  Defaults for a new adapter. Only storage and resource configuration are left:

      defmodule MyDataLayer.Conformance do
        use Ash.Conformance.Adapter, id: :my_data_layer, label: "MyDataLayer", package: :my_data_layer

        def resource_config(table), do: {MyDataLayer.DataLayer, quote(do: my_dl(do: table(unquote(table))))}
        def setup!, do: Ash.Conformance.Resources.compile!(__MODULE__)
      end
  """
  defmacro __using__(opts) do
    id = Keyword.fetch!(opts, :id)
    label = Keyword.fetch!(opts, :label)
    package = Keyword.fetch!(opts, :package)

    quote do
      @behaviour Ash.Conformance.Adapter

      def id, do: unquote(id)
      def label, do: unquote(label)
      def package, do: unquote(package)
      def profiles, do: [:shared]
      def resource(role), do: Module.concat(__MODULE__, Macro.camelize(to_string(role)))
      def persist!(role, rows, opts), do: Ash.Seed.seed!(resource(role), rows, opts)
      def benchmark_persist!(role, rows), do: persist!(role, rows, [])
      def instrumentation, do: nil
      def expectations, do: %{}
      def fixture?(fixture), do: fixture != :context_tenancy
      def custom_aggregate, do: Ash.Conformance.Resources.NoCustomAggregate
      def manual_relationship, do: Ash.Conformance.Resources.PlainManual
      def checkout!, do: :ok
      def checkin!, do: :ok
      def identity_options, do: []

      defoverridable profiles: 0,
                     resource: 1,
                     persist!: 3,
                     benchmark_persist!: 2,
                     instrumentation: 0,
                     expectations: 0,
                     fixture?: 1,
                     custom_aggregate: 0,
                     manual_relationship: 0,
                     checkout!: 0,
                     checkin!: 0,
                     identity_options: 0
    end
  end
end
