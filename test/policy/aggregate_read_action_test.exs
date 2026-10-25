# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Policy.AggregateReadActionTest do
  @moduledoc false
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

    actions do
      defaults [:read, create: :*]
    end

    policies do
      policy always() do
        authorize_if always()
      end
    end
  end

  # Only visible orders can be read, with any read action.
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
      belongs_to :event, Ash.Test.Policy.AggregateReadActionTest.Event,
        public?: true,
        attribute_writable?: true

      belongs_to :customer, Customer, public?: true, attribute_writable?: true
    end

    actions do
      defaults [:read, create: :*]
      read :all_orders
    end

    policies do
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
    end

    aggregates do
      list :order_customer_names, [:orders, :customer], :name, public?: true
      list :order_by_action_customer_names, [:orders_by_action, :customer], :name, public?: true
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

  # Only visible children can be read, with any read action, and only those with an id over 20
  # with the strict action.
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

    actions do
      defaults [:read, create: :*]
      read :all_children
      read :strict

      read :labelled do
        argument :label, :string, allow_nil?: false
        filter expr(label == ^arg(:label))
      end
    end

    policies do
      policy action_type(:read) do
        authorize_if expr(hidden == false)
      end

      policy action(:strict) do
        authorize_if expr(id > 20)
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
        read_action: :labelled,
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

  # Ann's order is visible and Cara's isn't.
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

  # Each parent has one visible child, and parent 1 has a hidden one too. Parent 1's children are
  # labelled "high", and parent 2's "low".
  defp parents_with_children do
    for id <- [1, 2], do: Ash.create!(Parent, %{id: id}, authorize?: false)

    for child <- [
          %{id: 11, parent_id: 1, label: "high"},
          %{id: 12, parent_id: 1, label: "high", hidden: true},
          %{id: 21, parent_id: 2, label: "low"}
        ],
        do: Ash.create!(Child, child, authorize?: false)

    :ok
  end

  defp parent_counts(load) do
    Parent
    |> Ash.Query.sort(:id)
    |> Ash.Query.load(load)
    |> Ash.read!(@actor)
    |> Enum.map(&{&1.id, Map.get(&1, load)})
  end

  test "an aggregate's path applies the read policies of the resources along it" do
    event = Ash.load!(event_with_orders(), :order_customer_names, @actor)
    assert event.order_customer_names == ["Ann"]
  end

  test "a relationship with its own read action along an aggregate's path applies its read policies" do
    event = Ash.load!(event_with_orders(), :order_by_action_customer_names, @actor)
    assert event.order_by_action_customer_names == ["Ann"]
  end

  test "an aggregate applies the read policies of the records it aggregates" do
    parents_with_children()
    assert parent_counts(:child_count) == [{1, 1}, {2, 1}]
  end

  test "a resource aggregate with its own read_action applies the read policies" do
    parents_with_children()
    assert parent_counts(:all_read_children_count) == [{1, 1}, {2, 1}]
  end

  test "an aggregate with a query for another action applies the read policies" do
    parents_with_children()
    query = Ash.Query.for_read(Child, :all_children)

    counts =
      Parent
      |> Ash.Query.aggregate(:all_count, :count, :read_children, query: query)
      |> Ash.Query.sort(:id)
      |> Ash.read!(@actor)
      |> Enum.map(&{&1.id, &1.aggregates[:all_count]})

    assert counts == [{1, 1}, {2, 1}]
  end

  test "an aggregate with a query for another action applies that action's read policies, as loading does" do
    parents_with_children()
    query = Ash.Query.for_read(Child, :strict)

    counts =
      Parent
      |> Ash.Query.aggregate(:strict_count, :count, :read_children, query: query)
      |> Ash.Query.load(read_children: query)
      |> Ash.Query.sort(:id)
      |> Ash.read!(@actor)
      |> Enum.map(&{&1.id, &1.aggregates[:strict_count], length(&1.read_children)})

    assert counts == [{1, 0, 0}, {2, 1, 1}]
  end

  test "an aggregate with a query for another action is read without its relationship's read_action_arguments" do
    parents_with_children()
    query = Ash.Query.for_read(Child, :all_children)

    counts =
      Parent
      |> Ash.Query.aggregate(:all_count, :count, :high_children, query: query)
      |> Ash.Query.load(high_children: query)
      |> Ash.Query.sort(:id)
      |> Ash.read!(@actor)
      |> Enum.map(&{&1.id, &1.aggregates[:all_count], length(&1.high_children)})

    assert counts == [{1, 1, 1}, {2, 1, 1}]
  end
end
