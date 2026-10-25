# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Actions.RelationshipPathsTest do
  @moduledoc """
  Aggregates and filters over a relationship path authorize every resource on it, the way
  loading the path does.

  An event's orders link it to customers, and an actor can only read visible orders. Ann's order
  is visible and Cara's isn't, so through the orders an actor can only reach Ann: by the plain
  path `[:orders, :customer]`, the `many_to_many :buyers` (through `Order`), and the
  `has_many :customers, through: [:orders, :customer]`. Customers named "Hidden" can't be read.
  """
  use ExUnit.Case, async: true

  require Ash.Query

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      allow_unregistered? true
    end
  end

  defmodule Customer do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private? true
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    relationships do
      has_many :tags, Ash.Test.Actions.RelationshipPathsTest.Tag, public?: true
    end

    actions do
      defaults [:read, create: :*]
      read :forbid_all
    end

    policies do
      policy action(:forbid_all) do
        forbid_if always()
      end

      policy action_type(:read) do
        authorize_if expr(name != "Hidden")
      end

      policy action_type(:create) do
        authorize_if always()
      end
    end
  end

  defmodule Tag do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private? true
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    relationships do
      belongs_to :customer, Customer, public?: true, attribute_writable?: true
    end

    actions do
      defaults [:read, create: :*]
    end

    policies do
      policy always() do
        authorize_if always()
      end
    end
  end

  defmodule Order do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private? true
    end

    attributes do
      uuid_primary_key :id
      attribute :visible, :boolean, allow_nil?: false, default: true, public?: true
    end

    relationships do
      belongs_to :event, Ash.Test.Actions.RelationshipPathsTest.Event,
        public?: true,
        attribute_writable?: true

      belongs_to :customer, Customer, public?: true, attribute_writable?: true
    end

    actions do
      defaults [:read, create: :*]
      read :all_orders
    end

    field_policies do
      field_policy :visible do
        forbid_if always()
      end

      field_policy :* do
        authorize_if always()
      end
    end

    policies do
      # An actor with `deny_orders: true` can't read any orders.
      policy action_type(:read) do
        forbid_if actor_attribute_equals(:deny_orders, true)
        authorize_if always()
      end

      policy action_type(:read) do
        authorize_if expr(visible == true)
      end

      policy action_type(:create) do
        authorize_if always()
      end
    end
  end

  defmodule Event do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private? true
    end

    attributes do
      uuid_primary_key :id
    end

    relationships do
      has_many :orders, Order, public?: true
      has_many :orders_by_action, Order, public?: true, read_action: :all_orders

      many_to_many :buyers, Customer do
        public? true
        through Order
        join_relationship :orders
        source_attribute_on_join_resource :event_id
        destination_attribute_on_join_resource :customer_id
      end

      has_many :customers, Customer, through: [:orders, :customer], public?: true
      has_many :buyers_via, Customer, through: [:buyers], public?: true
      has_many :nested_customers, Customer, through: [:customers], public?: true

      has_many :forbidden_customers, Customer,
        through: [:orders, :customer],
        read_action: :forbid_all,
        public?: true
    end

    aggregates do
      list :order_customer_names, [:orders, :customer], :name, public?: true
      list :order_by_action_customer_names, [:orders_by_action, :customer], :name, public?: true
      count :buyer_count, :buyers, public?: true
      list :buyer_names, :buyers, :name, public?: true
      list :customer_names, :customers, :name, public?: true
      count :customer_count, :customers, public?: true
      list :customer_tags, [:customers, :tags], :name, public?: true
      list :buyer_tags, [:buyers, :tags], :name, public?: true
    end

    actions do
      defaults [:read, create: :*]
    end

    policies do
      policy always() do
        authorize_if always()
      end
    end
  end

  # Ratings and children with `hidden: true` can't be read.
  defmodule Rating do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private? true
    end

    attributes do
      attribute :id, :integer, primary_key?: true, allow_nil?: false, public?: true
      attribute :child_id, :integer, public?: true
      attribute :hidden, :boolean, public?: true, default: false
    end

    actions do
      defaults [:read, create: :*]
    end

    policies do
      policy action_type(:read) do
        authorize_if expr(hidden == false)
      end

      policy action_type(:create) do
        authorize_if always()
      end
    end
  end

  defmodule Child do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private? true
    end

    attributes do
      attribute :id, :integer, primary_key?: true, allow_nil?: false, public?: true
      attribute :parent_id, :integer, public?: true
      attribute :label, :string, public?: true
      attribute :hidden, :boolean, public?: true, default: false
    end

    relationships do
      has_many :ratings, Rating, destination_attribute: :child_id
    end

    aggregates do
      count :rating_count, :ratings
    end

    calculations do
      calculate :well_rated, :boolean, expr(rating_count > 1)
    end

    actions do
      defaults [:read, create: :*]
      read :all_children

      read :policy_label do
        argument :label, :string, allow_nil?: false
      end

      read :by_label do
        argument :label, :string, allow_nil?: false
        filter expr(label == ^arg(:label))
      end
    end

    policies do
      policy action(:policy_label) do
        authorize_if expr(label == ^arg(:label))
      end

      policy action_type(:read) do
        authorize_if expr(hidden == false)
      end

      policy action_type(:create) do
        authorize_if always()
      end
    end
  end

  defmodule Parent do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private? true
    end

    attributes do
      attribute :id, :integer, primary_key?: true, allow_nil?: false, public?: true
    end

    relationships do
      has_many :children, Child, destination_attribute: :parent_id
      has_many :read_children, Child, destination_attribute: :parent_id, read_action: :read

      has_many :high_children, Child,
        destination_attribute: :parent_id,
        read_action: :policy_label,
        read_action_arguments: %{label: "high"}
    end

    aggregates do
      count :child_count, :children
      count :all_read_children_count, :read_children, read_action: :all_children
    end

    actions do
      defaults [:read, create: :*]
    end

    policies do
      policy always() do
        authorize_if always()
      end
    end
  end

  @actor [authorize?: true, actor: %{id: 1}]

  defp event_with_orders do
    event = Ash.create!(Event, %{}, authorize?: false)
    ann = Ash.create!(Customer, %{name: "Ann"}, authorize?: false)
    cara = Ash.create!(Customer, %{name: "Cara"}, authorize?: false)
    Ash.create!(Order, %{event_id: event.id, customer_id: ann.id}, authorize?: false)

    Ash.create!(Order, %{event_id: event.id, customer_id: cara.id, visible: false},
      authorize?: false
    )

    event
  end

  defp events_matching(input, opts \\ @actor) do
    Event |> Ash.Query.filter_input(input) |> Ash.read!(opts) |> length()
  end

  # Parent 1 has a visible child labelled "high" with one visible and two hidden ratings, and a
  # hidden child labelled "high". Parent 2 has a visible child labelled "low".
  defp parents_with_children do
    for id <- [1, 2], do: Ash.create!(Parent, %{id: id}, authorize?: false)

    for child <- [
          %{id: 11, parent_id: 1, label: "high"},
          %{id: 12, parent_id: 1, label: "high", hidden: true},
          %{id: 21, parent_id: 2, label: "low"}
        ],
        do: Ash.create!(Child, child, authorize?: false)

    for rating <- [
          %{id: 1, child_id: 11},
          %{id: 2, child_id: 11, hidden: true},
          %{id: 3, child_id: 11, hidden: true}
        ],
        do: Ash.create!(Rating, rating, authorize?: false)

    :ok
  end

  defp parent_aggregate(name, kind, relationship, query) do
    Parent
    |> Ash.Query.aggregate(name, kind, relationship, query: query)
    |> Ash.Query.sort(:id)
    |> Ash.read!(@actor)
    |> Enum.map(&{&1.id, &1.aggregates[name]})
  end

  describe "normal use" do
    test "loading a many_to_many or through relationship authorizes the join resource" do
      event = Ash.load!(event_with_orders(), [:buyers, :customers], @actor)

      assert Enum.map(event.buyers, & &1.name) == ["Ann"]
      assert Enum.map(event.customers, & &1.name) == ["Ann"]
    end

    test "an aggregate over a plain path authorizes the resources along it" do
      assert Ash.load!(event_with_orders(), :order_customer_names, @actor).order_customer_names ==
               ["Ann"]
    end

    test "filter_input over a plain path or a through relationship authorizes each step" do
      event_with_orders()

      assert events_matching(%{orders: %{customer: %{name: %{eq: "Cara"}}}}) == 0
      assert events_matching(%{customers: %{name: %{eq: "Cara"}}}) == 0
      assert events_matching(%{customers: %{name: %{eq: "Ann"}}}) == 1
    end

    test "an aggregate continuing past a many_to_many or through relationship authorizes it" do
      event = Ash.create!(Event, %{}, authorize?: false)

      for name <- ["Ann", "Hidden"] do
        customer = Ash.create!(Customer, %{name: name}, authorize?: false)
        Ash.create!(Tag, %{name: name, customer_id: customer.id}, authorize?: false)
        Ash.create!(Order, %{event_id: event.id, customer_id: customer.id}, authorize?: false)
      end

      event = Ash.load!(event, [:customer_tags, :buyer_tags], @actor)

      assert event.customer_tags == ["Ann"]
      assert event.buyer_tags == ["Ann"]
    end

    test "unauthorized aggregates over a many_to_many or through relationship count every row" do
      event =
        Ash.load!(event_with_orders(), [:buyer_count, :buyer_names, :customer_names],
          authorize?: false
        )

      assert event.buyer_count == 2
      assert Enum.sort(event.buyer_names) == ["Ann", "Cara"]
      assert Enum.sort(event.customer_names) == ["Ann", "Cara"]
    end

    test "loading and filtering by an aggregate authorizes the related records" do
      parents_with_children()

      counts =
        Parent |> Ash.Query.sort(:id) |> Ash.Query.load(:child_count) |> Ash.read!(@actor)

      assert Enum.map(counts, &{&1.id, &1.child_count}) == [{1, 1}, {2, 1}]
      assert Parent |> Ash.Query.filter(child_count > 1) |> Ash.read!(@actor) == []
    end

    test "an unauthorized aggregate keeps its query's action arguments" do
      parents_with_children()
      query = Ash.Query.for_read(Child, :by_label, %{label: "high"})

      assert Parent
             |> Ash.Query.aggregate(:high_count, :count, :children, query: query)
             |> Ash.Query.sort(:id)
             |> Ash.read!(authorize?: false)
             |> Enum.map(&{&1.id, &1.aggregates.high_count}) == [{1, 2}, {2, 0}]
    end
  end

  describe "S-07: aggregates through a join resource" do
    test "count over a many_to_many" do
      assert Ash.load!(event_with_orders(), :buyer_count, @actor).buyer_count == 1
    end

    test "list over a many_to_many" do
      assert Ash.load!(event_with_orders(), :buyer_names, @actor).buyer_names == ["Ann"]
    end

    test "list over a through relationship" do
      assert Ash.load!(event_with_orders(), :customer_names, @actor).customer_names == ["Ann"]
    end

    test "filter_input on an aggregate over a through relationship" do
      event_with_orders()
      assert events_matching(%{customer_count: %{gt: 1}}) == 0
    end
  end

  describe "N1: a relationship along an aggregate's path with its own read action" do
    test "its read policies apply" do
      event = Ash.load!(event_with_orders(), :order_by_action_customer_names, @actor)
      assert event.order_by_action_customer_names == ["Ann"]
    end
  end

  describe "N2: an aggregate read with another action than its relationship's read action" do
    test "a resource aggregate with its own read_action applies the read policies" do
      parents_with_children()

      counts =
        Parent
        |> Ash.Query.sort(:id)
        |> Ash.Query.load(:all_read_children_count)
        |> Ash.read!(@actor)

      assert Enum.map(counts, &{&1.id, &1.all_read_children_count}) == [{1, 1}, {2, 1}]
    end

    test "an aggregate with a query for another action applies the read policies" do
      parents_with_children()
      query = Ash.Query.for_read(Child, :all_children)

      assert parent_aggregate(:all_count, :count, :read_children, query) == [{1, 1}, {2, 1}]
    end
  end

  describe "B-065" do
    test "an authorized aggregate keeps its query's action arguments" do
      parents_with_children()
      query = Ash.Query.for_read(Child, :by_label, %{label: "high"})

      assert parent_aggregate(:high_count, :count, :children, query) == [{1, 1}, {2, 0}]
    end
  end

  describe "S-19" do
    test "an aggregate in another aggregate's query filter applies the read policies" do
      parents_with_children()
      query = Ash.Query.filter(Child, rating_count > 1)

      assert parent_aggregate(:well_rated, :count, :children, query) == [{1, 0}, {2, 0}]
    end
  end

  describe "aggregate arguments (review)" do
    # Policy filters were cached by relationship and action, so the second aggregate got the
    # first one's.
    test "aggregates with queries for the same action with different arguments each apply their own read policies" do
      parents_with_children()
      high = Ash.Query.for_read(Child, :policy_label, %{label: "high"})
      low = Ash.Query.for_read(Child, :policy_label, %{label: "low"})
      assert parent_aggregate(:one_high, :count, :children, high) == [{1, 1}, {2, 0}]
      assert parent_aggregate(:one_low, :count, :children, low) == [{1, 0}, {2, 1}]

      actual =
        Parent
        |> Ash.Query.aggregate(:high, :count, :children, query: high)
        |> Ash.Query.aggregate(:low, :count, :children, query: low)
        |> Ash.Query.sort(:id)
        |> Ash.read!(@actor)
        |> Enum.map(&{&1.id, &1.aggregates.high, &1.aggregates.low})

      assert actual == [{1, 1, 0}, {2, 0, 1}]
    end

    test "a query's arguments override the relationship's read_action_arguments, as when loading" do
      parents_with_children()
      low = Ash.Query.for_read(Child, :policy_label, %{label: "low"})

      loaded =
        Parent
        |> Ash.Query.sort(:id)
        |> Ash.Query.load(high_children: low)
        |> Ash.read!(@actor)

      assert Enum.map(loaded, &{&1.id, Enum.map(&1.high_children, fn child -> child.label end)}) ==
               [{1, []}, {2, ["low"]}]

      assert parent_aggregate(:low, :count, :high_children, low) == [{1, 0}, {2, 1}]
    end
  end

  describe "through relationships (review)" do
    test "a many_to_many inside a through relationship, or a nested through relationship" do
      event = event_with_orders()

      for relationship <- [:buyers_via, :nested_customers] do
        loaded = Ash.load!(event, [relationship], @actor)
        assert Enum.map(Map.fetch!(loaded, relationship), & &1.name) == ["Ann"]

        result =
          Event
          |> Ash.Query.aggregate(:names, :list, [relationship], field: :name)
          |> Ash.read_one!(@actor)

        assert result.aggregates.names == ["Ann"]
      end
    end

    test "a through relationship along the path keeps its own read action, as when loading" do
      event = event_with_orders()
      customer = Customer |> Ash.Query.filter(name == "Ann") |> Ash.read_one!(authorize?: false)
      Ash.create!(Tag, %{name: "secret", customer_id: customer.id}, authorize?: false)
      assert Ash.load!(event, :forbidden_customers, @actor).forbidden_customers == []

      result =
        Event
        |> Ash.Query.aggregate(:names, :list, [:forbidden_customers, :tags], field: :name)
        |> Ash.read_one!(@actor)

      assert result.aggregates.names == []
    end
  end

  describe "other aggregates (review)" do
    test "first and exists aggregates, and an aggregate with authorize? false" do
      event_with_orders()

      for relationship <- [:buyers, :customers] do
        result =
          Event
          |> Ash.Query.aggregate(:first, :first, relationship,
            field: :name,
            query: [sort: [name: :desc]]
          )
          |> Ash.Query.aggregate(:any, :exists, relationship, query: [filter: [name: "Cara"]])
          |> Ash.Query.aggregate(:all, :count, relationship, authorize?: false)
          |> Ash.read_one!(@actor)

        assert result.aggregates == %{first: "Ann", any: false, all: 2}
      end
    end

    test "a calculation in an aggregate's query authorizes the aggregate it uses" do
      parents_with_children()

      assert parent_aggregate(:well_rated, :count, :children, Ash.Query.filter(Child, well_rated)) ==
               [{1, 0}, {2, 0}]
    end

    test "sum aggregates and sorts on aggregates" do
      parents_with_children()

      result =
        Parent
        |> Ash.Query.aggregate(:sum_ids, :sum, :children, field: :id)
        |> Ash.Query.sort(:id)
        |> Ash.read!(@actor)

      assert Enum.map(result, &{&1.id, &1.aggregates.sum_ids}) == [{1, 11}, {2, 21}]
      assert Parent |> Ash.Query.sort(child_count: :desc) |> Ash.read!(@actor) |> length() == 2
    end

    test "a forbidden read of the join resource gives the aggregates' defaults" do
      event = event_with_orders()

      loaded =
        Ash.load!(event, [:buyer_count, :buyer_names, :customer_count],
          authorize?: true,
          actor: %{deny_orders: true}
        )

      assert loaded.buyer_count == 0
      assert loaded.buyer_names == []
      assert loaded.customer_count == 0
    end

    test "a field policy on the join resource applies to filter_input" do
      event_with_orders()
      assert events_matching(%{orders: %{visible: %{eq: true}}}) == 0
    end

    test "an aggregate's own join filter applies with the read policies" do
      event_with_orders()

      result =
        Event
        |> Ash.Query.aggregate(:names, :list, [:orders, :customer],
          field: :name,
          join_filters: %{[:orders] => [visible: false]}
        )
        |> Ash.read_one!(@actor)

      assert result.aggregates.names == []
    end
  end
end
