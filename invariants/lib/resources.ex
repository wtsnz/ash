# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Invariants.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    allow_unregistered?(true)
  end
end

defmodule Ash.Invariants.Resources do
  @moduledoc """
  The resources each layer runs, as `<layer>.<role>`: `Ash.Invariants.Ets.Note`.

  Events and customers are shared. Orders join them, and each shape reads the
  same orders a different way:

  - `:tenant` (`TenantEvent`, `TenantOrder`): orders are multitenant by `org_id`;
  - `:secure` (`SecureEvent`, `SecureOrder`): orders have a read policy,
    `visible == true`, and no tenancy;
  - `:schema` (`SchemaEvent`, `SchemaOrder`): orders live in each
    organisation's schema.

  Each event reaches its customers six ways: `many_to_many :buyers`,
  `has_many through:` over two hops, four hops and a `many_to_many` step, the
  plain `orders.customer` path, and a sorted `has_one through:`, with
  aggregates over each.

  Notes are multitenant by `org_id`, with a tenant-scoped `local_id`
  identity and actions that can't run atomically. `SecureNote` adds a read
  policy over the same rows. Lists attach notes with `manage_relationship`.
  People have admin-only field policies on an attribute, an aggregate, an
  embedded resource, an array of them and a union, and a public calculation
  that returns its argument, which may be an expression. Notes and people
  have a `:paged` read with keyset and offset pagination.
  """

  defmacro define(layer) do
    layer = Macro.expand(layer, __CALLER__)
    module = &Ash.Invariants.Layer.resource(layer, &1)

    shapes =
      for shape <- layer.shapes() do
        name = shape |> to_string() |> Macro.camelize()
        event = module.(name <> "Event")
        order = module.(name <> "Order")

        [
          event(layer, shape, event, order, module.(Customer)),
          order(layer, shape, order, event, module.(Customer))
        ]
      end

    notes =
      for {prefix, secure?} <- [{"", false}, {"Secure", true}] do
        note = module.(prefix <> "Note")
        list = module.(prefix <> "List")
        [note(layer, secure?, note, list), list(layer, list, note)]
      end

    quote context: Elixir do
      unquote(customer(layer, module.(Customer)))
      unquote_splicing(List.flatten(shapes ++ notes))
      unquote(person(layer, module.(Person), module.(SecureOrder)))
    end
  end

  defp resource(layer, module, table, authorizers, body) do
    {data_layer, config} = layer.data_layer(table)

    quote context: Elixir do
      defmodule unquote(module) do
        @moduledoc false
        use Ash.Resource,
          domain: Ash.Invariants.Domain,
          data_layer: unquote(data_layer),
          authorizers: unquote(authorizers)

        unquote(config)
        unquote(body)
      end
    end
  end

  # An identity ETS can't enforce must be checked before writing.
  defp identity_opts(layer), do: if(layer == Ash.Invariants.Ets, do: [pre_check?: true], else: [])

  defp customer(layer, module) do
    resource(
      layer,
      module,
      "customers",
      [],
      quote context: Elixir do
        attributes do
          attribute :id, :integer, primary_key?: true, allow_nil?: false, public?: true
          attribute :name, :string, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]
        end
      end
    )
  end

  defp event(layer, shape, module, order, customer) do
    resource(
      layer,
      module,
      "events",
      [],
      quote context: Elixir do
        attributes do
          attribute :id, :integer, primary_key?: true, allow_nil?: false, public?: true
          attribute :name, :string, public?: true
          attribute :recorded, :integer, public?: true
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]

          update :record_count do
            change atomic_update(:recorded, expr(order_count))
          end

          update :set_buyers do
            argument :customer_ids, {:array, :integer}, allow_nil?: false
            require_atomic? false
            change manage_relationship(:customer_ids, :buyers, type: :append_and_remove)
          end
        end

        relationships do
          has_many :orders, unquote(order), destination_attribute: :event_id, public?: true

          many_to_many :buyers, unquote(customer) do
            public? true
            through unquote(order)
            join_relationship :orders
            source_attribute_on_join_resource :event_id
            destination_attribute_on_join_resource :customer_id
          end

          if unquote(layer.through?()) do
            has_many :customers, unquote(customer), through: [:orders, :customer], public?: true

            has_many :customers_via_event, unquote(customer),
              through: [:orders, :event, :orders, :customer],
              public?: true

            has_many :customers_via_buyers, unquote(customer),
              through: [:orders, :event, :buyers],
              public?: true

            has_one :first_customer, unquote(customer),
              through: [:orders, :customer],
              sort: [name: :desc],
              public?: true
          end
        end

        aggregates do
          count :order_count, :orders, public?: true
          count :buyer_count, :buyers, public?: true
          count :path_count, [:orders, :customer], field: :id, uniq?: true, public?: true
          list :buyer_ids, :buyers, :id, sort: [id: :asc], uniq?: true, public?: true
          list :path_ids, [:orders, :customer], :id, sort: [id: :asc], uniq?: true, public?: true
          first :top_buyer, :buyers, :id, sort: [name: :desc], public?: true
          first :top_path, [:orders, :customer], :id, sort: [name: :desc], public?: true

          if unquote(layer.through?()) do
            count :customer_count, :customers, public?: true
            list :customer_ids, :customers, :id, sort: [id: :asc], uniq?: true, public?: true
            first :top_customer, :customers, :id, sort: [name: :desc], public?: true
          end
        end

        # Aggregates referenced in a calculation still authorize.
        calculations do
          calculate :order_total, :integer, expr(order_count), public?: true
          calculate :inline_count, :integer, expr(count(orders)), public?: true
        end

        @doc false
        def shape, do: unquote(shape)
      end
    )
  end

  defp order(layer, shape, module, event, customer) do
    tenancy =
      case shape do
        :tenant ->
          quote context: Elixir do
            multitenancy do
              strategy :attribute
              attribute :org_id
            end
          end

        :schema ->
          quote context: Elixir do
            multitenancy do
              strategy :context
            end
          end

        :secure ->
          quote context: Elixir do
            policies do
              policy action_type(:read) do
                authorize_if expr(visible == true)
              end

              policy action_type([:create, :update, :destroy]) do
                authorize_if always()
              end
            end
          end
      end

    authorizers = if shape == :secure, do: [Ash.Policy.Authorizer], else: []

    resource(
      layer,
      module,
      "orders",
      authorizers,
      quote context: Elixir do
        attributes do
          attribute :id, :integer,
            primary_key?: true,
            allow_nil?: false,
            public?: true,
            default: &Ash.Invariants.World.next_id/0

          if unquote(shape != :schema), do: attribute(:org_id, :integer, public?: true)
          attribute :event_id, :integer, public?: true
          attribute :customer_id, :integer, public?: true
          attribute :visible, :boolean, public?: true, default: true
        end

        unquote(tenancy)

        # One order per customer per event: with it, Ash loads `buyers` with a
        # lateral join where the data layer can.
        identities do
          identity :one_per_event, [:event_id, :customer_id], unquote(identity_opts(layer))
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]

          read :global do
            if unquote(shape == :tenant), do: multitenancy(:allow_global)
          end
        end

        relationships do
          belongs_to :event, unquote(event), define_attribute?: false, public?: true
          belongs_to :customer, unquote(customer), define_attribute?: false, public?: true
        end
      end
    )
  end

  defp note(layer, secure?, module, list) do
    policies =
      if secure? do
        quote context: Elixir do
          policies do
            policy action_type([:read, :update]) do
              authorize_if expr(visible == true)
            end

            policy action_type([:create, :destroy]) do
              authorize_if always()
            end
          end
        end
      end

    authorizers = if secure?, do: [Ash.Policy.Authorizer], else: []

    resource(
      layer,
      module,
      "notes",
      authorizers,
      quote context: Elixir do
        attributes do
          attribute :id, :integer, primary_key?: true, allow_nil?: false, public?: true
          attribute :org_id, :integer, public?: true
          attribute :local_id, :integer, allow_nil?: false, public?: true
          attribute :body, :string, public?: true
          attribute :value, :integer, public?: true
          attribute :list_id, :integer, public?: true
          attribute :visible, :boolean, public?: true, default: true
        end

        multitenancy do
          strategy :attribute
          attribute :org_id
        end

        identities do
          identity :local_id, [:local_id], unquote(identity_opts(layer))
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]

          read :global do
            multitenancy :allow_global
          end

          read :paged do
            pagination keyset?: true, offset?: true, required?: false
          end

          update :edit do
            accept [:body, :value]
            require_atomic? false
            change Ash.Invariants.NonAtomic
          end

          destroy :remove do
            require_atomic? false
            change Ash.Invariants.NonAtomic
          end
        end

        relationships do
          belongs_to :list, unquote(list), define_attribute?: false, public?: true
        end

        unquote(policies)
      end
    )
  end

  defp list(layer, module, note) do
    resource(
      layer,
      module,
      "lists",
      [],
      quote context: Elixir do
        attributes do
          attribute :id, :integer, primary_key?: true, allow_nil?: false, public?: true
          attribute :org_id, :integer, public?: true
          attribute :name, :string, public?: true
        end

        multitenancy do
          strategy :attribute
          attribute :org_id
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]

          update :attach do
            argument :note_ids, {:array, :integer}, allow_nil?: false
            require_atomic? false
            change manage_relationship(:note_ids, :notes, type: :append)
          end
        end

        relationships do
          has_many :notes, unquote(note), destination_attribute: :list_id, public?: true
        end
      end
    )
  end

  defp person(layer, module, order) do
    resource(
      layer,
      module,
      "people",
      [Ash.Policy.Authorizer],
      quote context: Elixir do
        attributes do
          attribute :id, :integer, primary_key?: true, allow_nil?: false, public?: true
          attribute :name, :string, public?: true
          attribute :secret, :string, public?: true
          attribute :event_id, :integer, public?: true
          attribute :profile, Ash.Invariants.Profile, public?: true
          attribute :cards, {:array, Ash.Invariants.Card}, public?: true

          attribute :payment, :union,
            public?: true,
            constraints: [
              types: [card: [type: Ash.Invariants.Card], note: [type: :string]]
            ]
        end

        actions do
          defaults [:read, :destroy, create: :*, update: :*]

          read :paged do
            pagination keyset?: true, offset?: true, required?: false
          end
        end

        relationships do
          has_many :orders, unquote(order),
            source_attribute: :event_id,
            destination_attribute: :event_id,
            public?: true
        end

        aggregates do
          count :order_count, :orders, public?: true
        end

        # Returns its argument, which may be an expression.
        calculations do
          calculate :echo, :string, expr(^arg(:value)) do
            public? true
            argument :value, :string, allow_expr?: true
          end
        end

        policies do
          policy always() do
            authorize_if always()
          end
        end

        field_policies do
          field_policy [:secret, :order_count] do
            authorize_if actor_attribute_equals(:admin, true)
          end

          field_policy :* do
            authorize_if always()
          end
        end
      end
    )
  end
end

defmodule Ash.Invariants.Profile do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded, authorizers: [Ash.Policy.Authorizer]

  attributes do
    attribute :bio, :string, public?: true
    attribute :ssn, :string, public?: true
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  field_policies do
    field_policy :ssn do
      authorize_if actor_attribute_equals(:admin, true)
    end

    field_policy :* do
      authorize_if always()
    end
  end
end

defmodule Ash.Invariants.Card do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded, authorizers: [Ash.Policy.Authorizer]

  attributes do
    attribute :label, :string, public?: true
    attribute :number, :string, public?: true
  end

  policies do
    policy always() do
      authorize_if always()
    end
  end

  field_policies do
    field_policy :number do
      authorize_if actor_attribute_equals(:admin, true)
    end

    field_policy :* do
      authorize_if always()
    end
  end
end

defmodule Ash.Invariants.NonAtomic do
  @moduledoc "A change with no atomic form, so its action can't run atomically."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context), do: changeset
end
