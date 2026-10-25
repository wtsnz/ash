# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Actions.Helpers.Tenancy do
  @moduledoc false
  # Scopes reads and writes to their tenant under attribute multitenancy: a query or changeset
  # given a tenant only reads, changes, deletes or upserts over records in that tenant.
  #
  # The read action, update, destroy and `update_many` each built this filter themselves. They
  # now share it here.
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
  """
  @spec filter(Ash.Changeset.t()) :: Ash.Changeset.t()
  def filter(changeset) do
    case predicate(changeset) do
      nil -> changeset
      predicate -> Ash.Changeset.filter(changeset, predicate)
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
end
