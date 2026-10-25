# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Invariants.World do
  @moduledoc """
  The one fixture every operation runs against, and what each view of it may
  see.

  Two organisations' orders join shared events to shared customers:

  | order | org | event | customer | visible |
  | ---: | ---: | ---: | --- | --- |
  | 11 | 1 | 1 | 1 Ann | yes |
  | 12 | 1 | 1 | 3 Cara | no |
  | 13 | 2 | 1 | 2 Bob | yes |
  | 14 | 1 | 2 | 4 Dan | yes |
  | 15 | 2 | 2 | 5 Zed | yes |
  | 16 | 2 | 1 | 4 Dan | yes |
  | 17 | 2 | 3 | 2 Bob | yes |

  Zed and Yan sort first by name descending, and Yan has no order, so a path
  that reads customers unfiltered returns one of them. Notes repeat local ids
  across organisations, and note 103 is hidden. People carry `SECRET` in
  every admin-only value.

  A view is `{shape, org}`: what an actor in organisation `org` may read
  through that shape's resources. Tenancy hides the other organisation's
  orders under `:tenant` and `:schema`; the read policy hides invisible orders
  under `:secure`. Notes and lists are always the organisation's own, and
  hidden notes are hidden under `:secure`.
  """
  alias Ash.Invariants.Layer

  @customers [{1, "Ann"}, {2, "Bob"}, {3, "Cara"}, {4, "Dan"}, {5, "Zed"}, {6, "Yan"}]

  # {id, org, event, customer, visible}
  @orders [
    {11, 1, 1, 1, true},
    {12, 1, 1, 3, false},
    {13, 2, 1, 2, true},
    {14, 1, 2, 4, true},
    {15, 2, 2, 5, true},
    {16, 2, 1, 4, true},
    {17, 2, 3, 2, true}
  ]

  # {id, org, local id, body, value, visible}
  @notes [
    {101, 1, 1, "a1", 1, true},
    {102, 1, 2, "a2", 2, true},
    {103, 1, 3, "a3", 3, false},
    {201, 2, 1, "b1", 10, true},
    {202, 2, 2, "b2", 20, true},
    {204, 2, 4, "b4", 40, true}
  ]

  @doc "The organisations' schemas, for the `:schema` shape."
  def schemas, do: ["org_1", "org_2"]

  @doc "The tenant to pass for an organisation under a shape."
  def tenant(:schema, org), do: "org_#{org}"
  def tenant(_shape, org), do: org

  @doc "Every row, by table. Rows with an organisation carry it as `org_id`."
  def rows do
    %{
      customers: for({id, name} <- @customers, do: %{id: id, name: name}),
      events: for(id <- 1..3, do: %{id: id, name: "e#{id}", recorded: nil}),
      orders:
        for {id, org, event, customer, visible} <- @orders do
          %{id: id, org_id: org, event_id: event, customer_id: customer, visible: visible}
        end,
      notes:
        for {id, org, local, body, value, visible} <- @notes do
          %{id: id, org_id: org, local_id: local, body: body, value: value, visible: visible}
        end,
      lists: [%{id: 1, org_id: 1, name: "l1"}, %{id: 2, org_id: 2, name: "l2"}],
      people: Enum.map(1..2, &person/1)
    }
  end

  @doc "A person whose every admin-only value says `SECRET`."
  def person(id) do
    %{
      id: id,
      name: "p#{id}",
      secret: "SECRET-#{id}",
      event_id: id,
      profile: %{bio: "bio-#{id}", ssn: "SECRET-ssn-#{id}"},
      cards: [%{label: "c#{id}", number: "SECRET-card-#{id}"}],
      payment: %Ash.Union{type: :card, value: %{label: "pay", number: "SECRET-pay-#{id}"}}
    }
  end

  @doc "The rows a view may see."
  def visible({shape, org}),
    do:
      Map.new(rows(), fn {table, rows} ->
        {table, Enum.filter(rows, &visible?({shape, org}, table, &1))}
      end)

  @doc "Whether a view may see a row of a table."
  def visible?({shape, org}, :orders, row) when shape in [:tenant, :schema], do: row.org_id == org
  def visible?({:secure, _org}, :orders, row), do: row.visible
  def visible?({:secure, org}, :notes, row), do: row.org_id == org and row.visible
  def visible?({_shape, org}, table, row) when table in [:notes, :lists], do: row.org_id == org
  def visible?({_shape, org}, :schema_orders, row), do: row.schema_org == org
  def visible?(_view, _table, _row), do: true

  @doc "The rows of a snapshot a view may not see."
  def hidden(view, snapshot),
    do:
      Map.new(snapshot, fn {table, rows} ->
        {table, Enum.reject(rows, &visible?(view, table, &1))}
      end)

  @doc """
  Stores `rows` under a layer: orders once by attribute and, where the layer
  has the `:schema` shape, again in each organisation's schema.
  """
  def seed!(layer, rows) do
    role = &Layer.resource(layer, &1)
    Ash.Seed.seed!(role.(Customer), rows.customers)
    Ash.Seed.seed!(role.(TenantEvent), rows.events)
    Ash.Seed.seed!(role.(Person), Enum.map(rows.people, &embed/1))

    for {org, orders} <- Enum.group_by(rows.orders, & &1.org_id) do
      Ash.Seed.seed!(role.(TenantOrder), orders, tenant: org)

      if :schema in layer.shapes() do
        orders = Enum.map(orders, &Map.delete(&1, :org_id))
        Ash.Seed.seed!(role.(SchemaOrder), orders, tenant: tenant(:schema, org))
      end
    end

    for {org, lists} <- Enum.group_by(rows.lists, & &1.org_id),
        do: Ash.Seed.seed!(role.(List), lists, tenant: org)

    for {org, notes} <- Enum.group_by(rows.notes, & &1.org_id),
        do: Ash.Seed.seed!(role.(Note), notes, tenant: org)

    :ok
  end

  defp embed(person) do
    %{
      person
      | profile: struct(Ash.Invariants.Profile, person.profile),
        cards: Enum.map(person.cards, &struct(Ash.Invariants.Card, &1)),
        payment: %{person.payment | value: struct(Ash.Invariants.Card, person.payment.value)}
    }
  end

  @doc "Everything stored, across tenants and without authorization, by table."
  def snapshot(layer) do
    role = &Layer.resource(layer, &1)
    all = fn resource, opts -> resource |> Ash.read!([authorize?: false] ++ opts) |> rows_of() end
    global = fn resource -> resource |> Ash.Query.for_read(:global) |> all.([]) end

    orders =
      if :schema in layer.shapes() do
        for org <- 1..2,
            row <- all.(role.(SchemaOrder), tenant: tenant(:schema, org)),
            do: Map.put(row, :schema_org, org)
      else
        []
      end

    %{
      customers: all.(role.(Customer), []),
      events: all.(role.(TenantEvent), []),
      orders: global.(role.(TenantOrder)),
      schema_orders: orders,
      notes: global.(role.(Note)),
      lists: Enum.flat_map(1..2, &all.(role.(List), tenant: &1)),
      people: all.(role.(Person), [])
    }
  end

  defp rows_of(records) do
    records
    |> Enum.map(fn %resource{} = record ->
      Map.take(record, Ash.Resource.Info.attribute_names(resource) |> Enum.to_list())
    end)
    |> Enum.sort_by(& &1.id)
  end

  @doc "Ids for rows a write creates, clear of the fixture's."
  def next_id, do: 700_000 + System.unique_integer([:positive, :monotonic])
end
