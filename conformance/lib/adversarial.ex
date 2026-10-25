# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Adversarial do
  @moduledoc """
  The adversarial scenarios' fixture and reference model: shapes and paths a
  leak needs that the rest of the suite doesn't have.

  Three organisations' worth of orders join shared events to shared
  customers. Orders are tenant-scoped (`org_id`) in one shape, guarded by a
  read policy (`visible == true`) in another, and plain in a third
  (`Ash.Conformance.Resources.Adversarial`):

  | order | org | event | customer | visible |
  | ---: | ---: | ---: | --- | --- |
  | 11 | 1 | 1 | 1 Ann | yes |
  | 12 | 1 | 1 | 3 Cara | no |
  | 13 | 2 | 1 | 2 Bob | yes |
  | 14 | 1 | 2 | 4 Dan | yes |
  | 15 | 2 | 2 | 5 Zed | yes |
  | 16 | 2 | 1 | 4 Dan | yes |
  | 17 | 2 | 3 | 2 Bob | yes |

  Zed and Yan (6) sort first by name descending, and Yan has no order, so a
  path that reads the destination unfiltered returns one of them. Event 3
  has no order in organisation 1.

  Notes belong to an organisation, with local ids that repeat across them,
  an all-tenants `code`, and a list (`@notes`). People carry admin-only
  fields at every depth (`@people`).

  Every answer below comes from these rows, never from a data layer.
  """

  # {id, name}
  @events [{1, "e1"}, {2, "e2"}, {3, "e3"}]
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

  # {id, org, local id, code, body, value, visible}
  @notes [
    {101, 1, 1, "n1-1", "a1", 1, true},
    {102, 1, 2, "n1-2", "a2", 2, true},
    {103, 1, 3, "n1-3", "a3", 3, false},
    {201, 2, 1, "n2-1", "b1", 10, true},
    {202, 2, 2, "n2-2", "b2", 20, true},
    {204, 2, 4, "n2-4", "b4", 40, true}
  ]

  @lists [{1, 1, "l1"}, {2, 2, "l2"}]

  @people [
    %{
      id: 1,
      name: "p1",
      secret: "secret-1",
      event_id: 1,
      profile: %{bio: "bio-1", ssn: "ssn-1"},
      cards: [%{label: "c1a", number: "card-1a"}, %{label: "c1b", number: "card-1b"}],
      payment: %{label: "pay-1", number: "pay-card-1"}
    },
    %{
      id: 2,
      name: "p2",
      secret: "secret-2",
      event_id: 2,
      profile: %{bio: "bio-2", ssn: "ssn-2"},
      cards: [%{label: "c2a", number: "card-2a"}],
      payment: %{label: "pay-2", number: "pay-card-2"}
    }
  ]

  @doc "The tenants of the schema-based shape, by organisation."
  def schemas, do: %{1 => "dc_tenant_a", 2 => "dc_tenant_b"}

  # Fixture rows

  def event_rows, do: for({id, name} <- @events, do: %{id: id, name: name})
  def customer_rows, do: for({id, name} <- @customers, do: %{id: id, name: name})

  def order_rows do
    for {id, org, event, customer, visible} <- @orders,
        do: %{id: id, org_id: org, event_id: event, customer_id: customer, visible: visible}
  end

  def note_rows do
    for {id, org, local, code, body, value, visible} <- @notes do
      %{
        id: id,
        org_id: org,
        local_id: local,
        code: code,
        body: body,
        value: value,
        visible: visible
      }
    end
  end

  def list_rows, do: for({id, org, name} <- @lists, do: %{id: id, org_id: org, name: name})
  def person_rows, do: @people

  # The reference model for paths through orders

  @doc "Event id to the sorted, distinct customer ids its `orders` reach."
  def related(orders) do
    Map.new(@events, fn {event, _} ->
      {event,
       orders
       |> Enum.filter(&(&1.event_id == event))
       |> Enum.map(& &1.customer_id)
       |> Enum.uniq()
       |> Enum.sort()}
    end)
  end

  @doc "The orders one organisation can read, or every order."
  def orders(:all), do: order_rows()
  def orders({:org, org}), do: Enum.filter(order_rows(), &(&1.org_id == org))
  def orders(:visible), do: Enum.filter(order_rows(), & &1.visible)

  @doc "Customers ids sorted by name descending, as `sort: [name: :desc]` orders them."
  def by_name_desc(ids) do
    names = Map.new(@customers)
    Enum.sort_by(ids, &Map.fetch!(names, &1), :desc)
  end

  @doc "A path's loads for each event."
  def loads(scope), do: related(orders(scope))

  @doc "The first `limit` customers of one event after `offset`, by name descending."
  def page(scope, event, limit, offset) do
    scope
    |> loads()
    |> Map.fetch!(event)
    |> by_name_desc()
    |> Enum.drop(offset)
    |> Enum.take(limit)
  end

  @doc "The first customer by name descending for each event, or nil."
  def first(scope), do: Map.new(loads(scope), fn {event, ids} -> {event, top(ids)} end)

  @doc "Whether each event's unsorted has_one is one of its own customers, or nil."
  def member(scope),
    do: Map.new(loads(scope), fn {event, ids} -> {event, if(ids != [], do: true)} end)

  @doc "`{count, ids, first by name}` for each event: the shape's three aggregates."
  def aggregates(scope),
    do: Map.new(loads(scope), fn {event, ids} -> {event, {length(ids), ids, top(ids)}} end)

  @doc "`{count, ids}` of the plain `orders` path, the control for `aggregates/1`."
  def path_aggregates(scope) do
    orders = orders(scope)

    Map.new(@events, fn {event, _} ->
      mine = Enum.filter(orders, &(&1.event_id == event))
      {event, {length(mine), mine |> Enum.map(& &1.customer_id) |> Enum.sort()}}
    end)
  end

  @doc "The events with an order from `customer`."
  def with_customer(scope, customer),
    do: for({event, ids} <- loads(scope), customer in ids, do: event) |> Enum.sort()

  @doc "The events whose count of distinct customers is `count`."
  def with_count(scope, count),
    do: for({event, ids} <- loads(scope), length(ids) == count, do: event) |> Enum.sort()

  defp top([]), do: nil
  defp top(ids), do: ids |> by_name_desc() |> hd()

  # Through relationships

  @doc """
  The event resource with `through` relationships for a shape's event role,
  in the current variant's resource set: `<event>.Through`, over the same
  table. It is compiled when first used, as `load.through`'s is, because Ash
  only warns when a data layer can't support `through` relationships
  (AshSqlite), and a warning at build time would fail the build. The second
  element says whether Ash warned.
  """
  def through(adapter, event_role) do
    event = adapter.resource(event_role)
    module = Module.concat(event, Through)
    key = {__MODULE__, module}

    case :persistent_term.get(key, nil) do
      nil ->
        # Capturing needs ExUnit's capture server, which mix tasks do not start.
        {:ok, _} = Application.ensure_all_started(:ex_unit)

        {_, output} =
          ExUnit.CaptureIO.with_io(:stderr, fn ->
            Code.compile_quoted(through_definition(module, event, adapter))
          end)

        warned? = output =~ "does not support `through` relationships"
        :persistent_term.put(key, warned?)
        {module, warned?}

      warned? ->
        {module, warned?}
    end
  end

  defp through_definition(module, event, adapter) do
    order = Ash.Resource.Info.related(event, :orders)
    customer = Ash.Resource.Info.related(event, :buyers)

    quote do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base, adapter: unquote(adapter), table: "adv_events"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:name, :string, public?: true)
        end

        relationships do
          has_many(:orders, unquote(order), destination_attribute: :event_id, public?: true)

          has_many(:customers, unquote(customer), through: [:orders, :customer], public?: true)

          has_many(:customers_via_event, unquote(customer),
            through: [:orders, :event, :orders, :customer],
            public?: true
          )

          # A many_to_many inside the path.
          has_many(:buyers_via_event, unquote(customer),
            through: [:orders, :event, :buyers],
            public?: true
          )

          has_one(:first_customer, unquote(customer),
            through: [:orders, :customer],
            sort: [name: :desc],
            public?: true
          )

          has_one(:a_customer, unquote(customer), through: [:orders, :customer], public?: true)
        end

        aggregates do
          count(:customer_count, :customers, public?: true)
          list(:customer_ids, :customers, :id, sort: [id: :asc], public?: true)
          first(:top_customer, :customers, :id, sort: [name: :desc], public?: true)
        end
      end
    end
  end

  # The reference model for writes

  @doc "Every stored note as `{id, org, local id, body, list id}`, before any write."
  def notes,
    do: for(note <- note_rows(), do: {note.id, note.org_id, note.local_id, note.body, nil})

  @doc "The stored notes after `fun` changes each `{id, org, local, body, list}` row, or drops it with nil."
  def notes_after(fun), do: notes() |> Enum.map(fun) |> Enum.reject(&is_nil/1)

  @doc """
  The stored notes after `ids` were changed: `:update` sets their body to
  `"x"`, `:destroy` drops them, and `{:body, body}` sets that body. For
  pinning what a data layer did instead of the intended write.
  """
  def notes_after(ids, change) do
    notes_after(fn {id, org, local, body, list} = row ->
      cond do
        id not in ids -> row
        change == :update -> {id, org, local, "x", list}
        change == :destroy -> nil
        match?({:body, _}, change) -> {id, org, local, elem(change, 1), list}
        true -> {id, org, local, body, list}
      end
    end)
  end

  @doc "Person 1's admin-only values as a write result shows them, the top-level secret hidden."
  def leaked_fields,
    do: %{secret: :forbidden, ssn: "ssn-1", cards: ["card-1a", "card-1b"], payment: "pay-card-1"}

  @doc """
  The join-policy aggregates with every customer reached twice: once through
  a real order and once through its hidden decoy.
  """
  def doubled_join,
    do: %{
      1 => {8, [1, 1, 2, 2, 3, 3, 4, 4], 4},
      2 => {4, [4, 4, 5, 5], 5},
      3 => {2, [2, 2], 2}
    }

  @doc "Every stored order as `{org, event, customer}`."
  def order_links,
    do:
      for(order <- order_rows(), do: {order.org_id, order.event_id, order.customer_id})
      |> Enum.sort()
end
