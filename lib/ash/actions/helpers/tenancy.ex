# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Actions.Helpers.Tenancy do
  @moduledoc false
  # Scopes reads and writes to their tenant under attribute multitenancy: a query or changeset
  # given a tenant only reads, changes, deletes or upserts over records in that tenant.
  #
  # Reads: the read action calls `filter_query/1`, and so do `Ash.Query.data_layer_query/2` and
  # `Ash.Query.apply_to/3`, so a query lowered for the data layer or evaluated in memory without
  # running the read action (by `Ash.can?`, or a data layer's joins and lookups) is scoped too.
  #
  # Writes: `Ash.DataLayer.update/2`, `destroy/2`, `upsert/4`, `update_many/3` and `bulk_create/3`
  # (for upserts) call this for every changeset. The single actions also call `filter/1` earlier,
  # before authorization, and bulk creates before batching upserts by their filter.
  #
  # Adding the predicate again is harmless, so nothing records that it was added (a record of it
  # could be copied to another query or changeset along with its context).
  #
  # Context multitenancy needs nothing here: the data layer applies the tenant itself.

  require Ash.Expr

  @doc """
  Adds the tenant filter to a query, unless it has no tenant, the resource doesn't use attribute
  multitenancy, or the action or context bypasses multitenancy.
  """
  @spec filter_query(Ash.Query.t()) :: Ash.Query.t()
  def filter_query(%Ash.Query{} = query) do
    case predicate(query) do
      nil -> query
      predicate -> Ash.Query.do_filter(query, predicate)
    end
  end

  @doc """
  Adds the tenant filter to a changeset, unless it has no tenant, the resource doesn't use
  attribute multitenancy, or the action or context bypasses multitenancy.

  On an update or destroy the filter must match the stored record. On an upsert it's the
  condition for updating a conflicting record.
  """
  @spec filter(Ash.Changeset.t()) :: Ash.Changeset.t()
  def filter(changeset) do
    case predicate(changeset) do
      nil ->
        changeset

      predicate ->
        if Ash.DataLayer.data_layer_can?(changeset.resource, :changeset_filter) do
          Ash.Changeset.filter(changeset, predicate)
        else
          changeset
        end
    end
  end

  @doc """
  Scopes a changeset that writes an existing record, just before it reaches the data layer.

  A data layer that can't filter a changeset gets the stored record checked against the tenant
  instead, and `{:error, StaleRecord}` if it's in another one.
  """
  @spec scope_write(Ash.Changeset.t()) :: {:ok, Ash.Changeset.t()} | {:error, term()}
  def scope_write(changeset) do
    case predicate(changeset) do
      nil ->
        {:ok, changeset}

      predicate ->
        if Ash.DataLayer.data_layer_can?(changeset.resource, :changeset_filter) do
          {:ok, Ash.Changeset.filter(changeset, predicate)}
        else
          check_stored_tenant(changeset, predicate)
        end
    end
  end

  @doc """
  Whether a record belongs to the tenant a query or changeset is scoped to. Always `true` when the
  query or changeset doesn't need the tenant filter.
  """
  @spec in_tenant?(Ash.Query.t() | Ash.Changeset.t(), Ash.Resource.Record.t()) :: boolean()
  def in_tenant?(subject, record) do
    case scope(subject) do
      nil -> true
      {attribute, value} -> Map.get(record, attribute) == value
    end
  end

  # The filter a query or changeset in `subject.to_tenant` needs, or `nil` if it needs none.
  defp predicate(subject) do
    case scope(subject) do
      nil -> nil
      {attribute, value} -> Ash.Expr.expr(^Ash.Expr.ref(attribute) == ^value)
    end
  end

  defp scope(subject) do
    tenant = subject.to_tenant

    if not is_nil(tenant) and
         Ash.Resource.Info.multitenancy_strategy(subject.resource) == :attribute and
         not bypass?(subject) do
      attribute = Ash.Resource.Info.multitenancy_attribute(subject.resource)
      {m, f, a} = Ash.Resource.Info.multitenancy_parse_attribute(subject.resource)

      {attribute, apply(m, f, [tenant | a])}
    end
  end

  # The action's `multitenancy`, or a mode set in the context (by an aggregate or calculation with
  # `multitenancy: :bypass`, or an action bypassing it for everything it runs).
  defp bypass?(subject) do
    action_multitenancy =
      case subject.action do
        %{multitenancy: multitenancy} -> multitenancy
        _ -> nil
      end

    context = subject.context || %{}

    [
      action_multitenancy,
      context[:multitenancy],
      context[:private][:multitenancy],
      context[:shared][:multitenancy],
      context[:shared][:private][:multitenancy]
    ]
    |> Enum.any?(&(&1 in [:bypass, :bypass_all]))
  end

  # Reads the record by primary key and tenant only, without the resource's read filters. Not
  # atomic with the write; within a transaction (as single actions and bulk batches run) it's as
  # good as the data layer's isolation.
  defp check_stored_tenant(changeset, predicate) do
    with {:ok, pkey_filter} <- Ash.Filter.get_filter(changeset.resource, changeset.data),
         {:ok, query} <-
           changeset.resource
           |> Ash.Query.new(base_filter?: false)
           |> Ash.Query.do_filter(pkey_filter)
           |> Ash.Query.do_filter(predicate)
           |> Ash.Query.data_layer_query(),
         {:ok, records} <- Ash.DataLayer.run_query(query, changeset.resource) do
      case records do
        [_] ->
          {:ok, changeset}

        _ ->
          {:error,
           Ash.Error.Changes.StaleRecord.exception(
             resource: changeset.resource,
             filter: predicate
           )}
      end
    end
  end
end
