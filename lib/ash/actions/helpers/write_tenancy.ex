# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Actions.Helpers.WriteTenancy do
  @moduledoc false
  # Scopes writes to their tenant under attribute multitenancy: a write given a tenant only
  # changes, deletes or upserts over records in that tenant.
  #
  # `Ash.DataLayer.update/2`, `destroy/2`, `upsert/4`, `update_many/3` and `bulk_create/3` (for
  # upserts) call this for every changeset, so the scope doesn't depend on which action path
  # built it. The single actions also call `filter/1` earlier, before authorization, and bulk
  # creates before batching upserts by their filter. Adding the predicate again is harmless, so
  # nothing records that it was added (a record of it could be copied to another changeset along
  # with its context).
  #
  # Context multitenancy needs nothing here: the data layer applies `changeset.tenant` itself.

  require Ash.Expr

  @doc """
  Adds the tenant filter to a changeset, unless it has no tenant, the resource doesn't use
  attribute multitenancy, or the action bypasses multitenancy.

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

  defp predicate(changeset) do
    tenant = changeset.to_tenant

    if not is_nil(tenant) and
         Ash.Resource.Info.multitenancy_strategy(changeset.resource) == :attribute and
         not bypass?(changeset) do
      attribute = Ash.Resource.Info.multitenancy_attribute(changeset.resource)
      {m, f, a} = Ash.Resource.Info.multitenancy_parse_attribute(changeset.resource)
      value = apply(m, f, [tenant | a])

      Ash.Expr.expr(^Ash.Expr.ref(attribute) == ^value)
    end
  end

  defp bypass?(changeset) do
    action_multitenancy =
      case changeset.action do
        %{multitenancy: multitenancy} -> multitenancy
        _ -> nil
      end

    action_multitenancy in [:bypass, :bypass_all] or
      Ash.Actions.Helpers.get_multitenancy_from_context(changeset) in [:bypass, :bypass_all]
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
