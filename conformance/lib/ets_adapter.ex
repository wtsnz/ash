# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Ets do
  @moduledoc """
  A non-SQL integration using Ash's ETS data layer.

  It is deliberately not in `Adapter.all/0`: it has no expectation records, so
  it runs only through probes and `mix conformance.survey`, whose results are
  always unreviewed. It shows the runner, fixtures and shared resource roles
  working without Ecto, a repository or SQL.
  """
  @behaviour Ash.Conformance.Adapter

  def id, do: :ets
  def fixture?(fixture), do: fixture in [:aggregate, :records, :isolation, :empty]
  def profiles, do: [:shared]
  def instrumentation, do: nil

  def resource(role), do: Module.concat(Ash.Conformance.Ets, Macro.camelize(to_string(role)))

  def custom_aggregate, do: Ash.Conformance.EtsSum
  def setup!, do: :ok

  @roles ~w(parent child rating tag link child_tag event reading tenant_child tenant_link
            authorized_child ledger record tenant_parent tenant_item secure_parent secure_item
            context_parent context_item)a

  def checkout!, do: checkin!()

  # Private tables live in this process; drop them so the next case starts empty.
  def checkin! do
    for role <- @roles, resource = resource(role) do
      Ash.DataLayer.Ets.stop(resource)
      Process.delete({:ash_ets_table, Ash.DataLayer.Ets.Info.table(resource), nil})
    end

    :ok
  end

  def benchmark_persist!(role, rows), do: persist!(role, rows, [])
  def persist!(role, rows, opts), do: Ash.Seed.seed!(resource(role), rows, opts)
end

defmodule Ash.Conformance.EtsSum do
  @moduledoc false
  use Ash.Resource.Aggregate.CustomAggregate
end

defmodule Ash.Conformance.Ets.Manual do
  @moduledoc false
  use Ash.Resource.ManualRelationship

  def load(parents, _opts, %{query: query, actor: actor, authorize?: authorize?}) do
    ids = Enum.map(parents, & &1.id)

    rows =
      query
      |> Ash.Query.do_filter(parent_id: [in: ids])
      |> Ash.read!(actor: actor, authorize?: authorize?)

    {:ok, Enum.group_by(rows, & &1.parent_id)}
  end
end

defmodule Ash.Conformance.EtsResources do
  @moduledoc false
  use Ash.Conformance.Resources, namespace: Ash.Conformance.Ets, adapter: :ets
end

defmodule Ash.Conformance.EtsWriteResources do
  @moduledoc false
  use Ash.Conformance.WriteResources, namespace: Ash.Conformance.Ets, adapter: :ets
end
