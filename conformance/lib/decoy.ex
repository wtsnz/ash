# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Decoy do
  @moduledoc """
  The decoy variant's rows: a hidden copy of every fixture row, next to the
  rows the scenario reads, that no answer may contain.

  Under `Ash.Conformance.Variant`'s `:decoy` variant, `Ash.Conformance.Fixtures.seed!/4`
  stores a decoy for each row before the row itself, so a query that loses a
  filter tends to meet a decoy first. A decoy is the same row with:

  - its primary key moved into a reserved range, 880,000,000 to
    880,999,999 (`id/1`);
  - its tenant attribute set to that tenant's mirror, a reserved integer or
    the tenant marked with `"~decoy"`, wherever any role over the same table
    is multitenant by attribute, so local identities collide across tenants
    as the data layer allows;
  - other integer attributes moved into the same range (`value/1`), except
    foreign keys (`*_id`, `*_key`) and `local_id`, which keep pointing at
    real rows: a decoy child belongs to a real parent;
  - attributes of an identity that can't repeat (any identity, except a
    tenant-scoped one under attribute tenancy) moved too: strings marked
    with `"~decoy"`, integers into the reserved range.

  The decoy resource set hides them: tenancy hides the mirror tenant on
  resources multitenant by attribute, and a read policy hides the reserved
  range on every other resource (`Ash.Conformance.Variant.NotDecoy`). So
  the scenario's answer must not change, and no reserved id, reserved value
  or marked string may appear anywhere in its outcome, error messages
  included (`leaks/1`).

  Rows are not copied for a resource without an integer primary key, since
  no policy could hide them. A row stored with an explicit `tenant:` option,
  for schema-based tenancy, gets its decoy in the same tenant, hidden by the
  policy.
  """

  @base 880_000_000
  @span 1_000_000
  @marker "~decoy"

  @doc "The reserved range of decoy ids and values."
  def range, do: @base..(@base + @span - 1)

  @doc "A real id's decoy id."
  def id(id) when is_integer(id), do: @base + rem(abs(id), @span)

  @doc "A real integer value's decoy value."
  def value(value) when is_integer(value), do: @base + rem(abs(value), @span)

  @doc "Whether an integer is in the reserved range."
  def reserved?(value) when is_integer(value), do: value in range()
  def reserved?(_value), do: false

  @doc """
  Every decoy id, value or marked string in a term, in the order found.
  Strings are searched for reserved numbers too, so a leak in an error message
  counts.
  """
  def leaks(term), do: term |> scan([]) |> Enum.reverse() |> Enum.uniq()

  defp scan(value, acc) when is_integer(value),
    do: if(reserved?(value), do: [value | acc], else: acc)

  defp scan(value, acc) when is_binary(value) do
    numbers =
      ~r/(?<!\d)880\d{6}(?!\d)/
      |> Regex.scan(value)
      |> Enum.map(fn [match] -> String.to_integer(match) end)

    marked = if String.contains?(value, @marker), do: [value], else: []
    Enum.reverse(numbers ++ marked) ++ acc
  end

  defp scan(%Ash.ForbiddenField{}, acc), do: acc

  defp scan(%MapSet{} = set, acc), do: Enum.reduce(set, acc, &scan/2)

  defp scan(%_{} = struct, acc),
    do: struct |> Map.from_struct() |> Map.drop([:__meta__, :__metadata__]) |> scan(acc)

  defp scan(value, acc) when is_map(value),
    do: Enum.reduce(value, acc, fn {key, value}, acc -> scan(value, scan(key, acc)) end)

  defp scan(value, acc) when is_list(value), do: Enum.reduce(value, acc, &scan/2)
  defp scan(value, acc) when is_tuple(value), do: value |> Tuple.to_list() |> scan(acc)
  defp scan(_value, acc), do: acc

  @doc """
  The decoys for `rows` of `resource`, a role in the decoy resource set; see
  the module documentation for what is copied.
  """
  def rows(adapter, resource, rows) do
    case hidable_key(resource) do
      nil -> []
      key -> for row <- rows, is_integer(Map.get(row, key)), do: copy(adapter, resource, key, row)
    end
  end

  # The first primary key, when it is an integer the policy can hide by.
  defp hidable_key(resource) do
    with [key | _] <- Ash.Resource.Info.primary_key(resource),
         %{type: Ash.Type.Integer} <- Ash.Resource.Info.attribute(resource, key) do
      key
    else
      _ -> nil
    end
  end

  defp attribute_tenancy?(resource),
    do: Ash.Resource.Info.multitenancy_strategy(resource) == :attribute

  defp copy(adapter, resource, key, row) do
    tenant_attribute = tenant_attribute(adapter, resource)
    unscoped = unscoped_identity_fields(resource)

    Map.new(row, fn {field, value} ->
      attribute = Ash.Resource.Info.attribute(resource, field)

      cond do
        field == key -> {field, id(value)}
        field == tenant_attribute and not is_nil(value) -> {field, mirror(value)}
        is_nil(value) or is_nil(attribute) -> {field, value}
        field in unscoped and is_binary(value) -> {field, value <> @marker}
        field in unscoped and is_integer(value) -> {field, value(value)}
        reference?(field, resource) -> {field, value}
        attribute.type == Ash.Type.Integer and is_integer(value) -> {field, value(value)}
        true -> {field, value}
      end
    end)
  end

  @doc "A tenant's mirror tenant: one per real tenant, so local identities still collide."
  def mirror(value) when is_integer(value), do: value(value)
  def mirror(value) when is_binary(value), do: value <> @marker

  defp reference?(field, resource) do
    name = to_string(field)

    field == :local_id or String.ends_with?(name, ["_id", "_key"]) or
      field in Ash.Resource.Info.primary_key(resource)
  end

  # Identities whose values cannot repeat in a decoy: every identity, except
  # tenant-scoped ones under attribute tenancy, where the decoy is in its
  # mirror tenant. Under schema-based tenancy the decoy shares the tenant.
  defp unscoped_identity_fields(resource) do
    scoped? = attribute_tenancy?(resource)

    resource
    |> Ash.Resource.Info.identities()
    |> Enum.reject(&(scoped? and not Map.get(&1, :all_tenants?, false)))
    |> Enum.flat_map(& &1.keys)
  end

  @doc """
  The attribute an attribute-multitenant role over the same table uses, so a
  row seeded through a plain role over that table still lands in the mirror
  tenant.
  """
  def tenant_attribute(adapter, resource) do
    if attribute_tenancy?(resource) do
      Ash.Resource.Info.multitenancy_attribute(resource)
    else
      adapter |> tenant_attributes() |> Map.get(table(resource))
    end
  end

  defp tenant_attributes(adapter) do
    key = {__MODULE__, :tenant_attributes, adapter}

    case :persistent_term.get(key, nil) do
      nil ->
        attributes =
          for role <- Ash.Conformance.Adapter.roles(),
              resource = Module.concat(adapter, Macro.camelize("#{role}")),
              Code.ensure_loaded?(resource),
              attribute_tenancy?(resource),
              into: %{},
              do: {table(resource), Ash.Resource.Info.multitenancy_attribute(resource)}

        :persistent_term.put(key, attributes)
        attributes

      attributes ->
        attributes
    end
  end

  defp table(resource) do
    if function_exported?(resource, :__conformance_table__, 0),
      do: resource.__conformance_table__()
  end
end
