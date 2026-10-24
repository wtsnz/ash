# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Adversarial do
  @moduledoc """
  Resource roles for the adversarial scenarios (`Ash.Conformance.Adversarial`),
  over the `adv_*` tables.

  Events and customers are shared; orders join them. Three shapes read the
  same orders:

  - `adv_event`/`adv_order`: orders are multitenant by `org_id`, and unique
    on `[:event_id, :customer_id]` within a tenant, the usual join table, so
    Ash loads the `many_to_many` with a lateral join where it can;
  - `adv_secure_event`/`adv_secure_order`: orders have a read policy,
    `visible == true`, and no tenancy;
  - `adv_plain_event`/`adv_plain_order`: no tenancy and no policy.

  Each event has `has_many :orders` and `many_to_many :buyers`, with
  aggregates over both. The `through` relationships live in a resource over
  the same table that `Ash.Conformance.Adversarial.through/2` compiles at run
  time, as `load.through` does: Ash only warns when a data layer can't
  support them, and compiling them here would turn that warning into a build
  failure.

  Notes (`adv_note`) are multitenant by `org_id`, with a tenant-scoped
  `local_id` identity, an all-tenants `code` identity (tenant-scoped where
  identities must be pre-checked, as on ETS, since an all-tenants identity
  can't be), and actions that can and cannot run atomically. Lists (`adv_list`) relate notes with
  `manage_relationship`. `adv_secure_note`/`adv_secure_list` add a read
  policy on notes. People (`adv_person`) have admin-only field policies on a
  top-level attribute, an aggregate, an embedded resource, an array of
  embedded resources and a union.
  """

  defmacro __using__(opts) do
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)
    Code.ensure_compiled!(adapter)

    # Only integrations that run the adversarial fixture define these, so a
    # data layer that doesn't run them reports nothing new.
    if adapter.fixture?(:adversarial), do: define(opts, adapter, __CALLER__)
  end

  defp define(opts, adapter, caller) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(caller)
    identity_opts = Ash.Conformance.Resources.Base.identity_options(adapter)
    module = fn name -> Module.concat(namespace, name) end
    customer = module.(AdvCustomer)

    shapes =
      for {prefix, kind} <- [{"Adv", :tenant}, {"AdvSecure", :secure}, {"AdvPlain", :plain}],
          do: shape(namespace, adapter, prefix, kind)

    notes =
      for {prefix, secure?} <- [{"Adv", false}, {"AdvSecure", true}] do
        [
          note(
            module.(prefix <> "Note"),
            module.(prefix <> "List"),
            secure?,
            adapter,
            identity_opts
          ),
          list(module.(prefix <> "List"), module.(prefix <> "Note"), adapter)
        ]
      end

    quote context: Elixir do
      defmodule unquote(customer) do
        use Ash.Conformance.Resources.Base, adapter: unquote(adapter), table: "adv_customers"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:name, :string, public?: true)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])
        end
      end

      (unquote_splicing(List.flatten(shapes ++ notes)))
      unquote(person(module.(AdvPerson), module.(AdvPlainOrder), adapter))
    end
  end

  @doc """
  One shape's event and order resources, `<prefix>Event` and `<prefix>Order`
  under `namespace`. `kind` is `:tenant`, `:secure`, `:plain` or `:schema`,
  schema-based tenancy, which only Postgres provisions
  (`Ash.Conformance.Postgres.SchemaResources`).
  """
  def shape(namespace, adapter, prefix, kind) do
    identity_opts = Ash.Conformance.Resources.Base.identity_options(adapter)
    event = Module.concat(namespace, prefix <> "Event")
    order = Module.concat(namespace, prefix <> "Order")
    customer = Module.concat(namespace, AdvCustomer)

    [
      event(event, order, customer, kind, adapter),
      order(order, event, customer, kind, adapter, identity_opts)
    ]
  end

  @doc "The orders' tenancy for a shape: by attribute on `org_id`, by schema, or none."
  def tenancy(:tenant) do
    quote context: Elixir do
      multitenancy do
        strategy(:attribute)
        attribute(:org_id)
      end
    end
  end

  def tenancy(:schema) do
    quote context: Elixir do
      multitenancy do
        strategy(:context)
      end
    end
  end

  def tenancy(_kind), do: nil

  # Orders with their own authorizer and a read policy on `visible`.
  defp order_policies(:secure) do
    quote context: Elixir do
      policies do
        policy action_type(:read) do
          authorize_if(expr(visible == true))
        end

        policy action_type([:create, :update, :destroy]) do
          authorize_if(always())
        end
      end
    end
  end

  defp order_policies(_kind), do: nil

  # A read every shape has, which reads across tenants where there are any.
  defp global_read(:tenant) do
    quote context: Elixir do
      read :global do
        multitenancy(:allow_global)
      end
    end
  end

  defp global_read(_kind), do: quote(context: Elixir, do: read(:global))

  defp order(module, event, customer, kind, adapter, identity_opts) do
    authorizers = if kind == :secure, do: [Ash.Policy.Authorizer], else: []

    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "adv_orders",
          authorizers: unquote(authorizers)

        attributes do
          attribute(:id, :integer,
            primary_key?: true,
            allow_nil?: false,
            public?: true,
            default: &Ash.Conformance.Resources.Adversarial.next_id/0
          )

          if unquote(kind != :schema), do: attribute(:org_id, :integer, public?: true)
          attribute(:event_id, :integer, public?: true)
          attribute(:customer_id, :integer, public?: true)
          attribute(:visible, :boolean, public?: true, default: true)
        end

        unquote(Ash.Conformance.Resources.Adversarial.tenancy(kind))

        # One order per customer per event. With this identity, Ash loads a
        # many_to_many through orders with a lateral join where it can.
        identities do
          identity(:one_per_event, [:event_id, :customer_id], unquote(identity_opts))
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])
          unquote(global_read(kind))
        end

        relationships do
          belongs_to(:event, unquote(event), define_attribute?: false, public?: true)
          belongs_to(:customer, unquote(customer), define_attribute?: false, public?: true)
        end

        unquote(order_policies(kind))
      end
    end
  end

  defp event(module, order, customer, kind, adapter) do
    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base, adapter: unquote(adapter), table: "adv_events"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:name, :string, public?: true)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])

          update :set_buyers do
            argument(:customer_ids, {:array, :integer}, allow_nil?: false)
            require_atomic?(false)
            change(manage_relationship(:customer_ids, :buyers, type: :append_and_remove))
          end
        end

        relationships do
          has_many(:orders, unquote(order), destination_attribute: :event_id, public?: true)

          many_to_many :buyers, unquote(customer) do
            public?(true)
            through(unquote(order))
            join_relationship(:orders)
            source_attribute_on_join_resource(:event_id)
            destination_attribute_on_join_resource(:customer_id)
          end
        end

        aggregates do
          count(:order_count, :orders, public?: true)
          list(:order_customer_ids, [:orders, :customer], :id, sort: [id: :asc], public?: true)
          count(:buyer_count, :buyers, public?: true)
          list(:buyer_ids, :buyers, :id, sort: [id: :asc], public?: true)
          first(:top_buyer, :buyers, :id, sort: [name: :desc], public?: true)
        end

        @doc false
        def __adversarial_shape__, do: unquote(kind)
      end
    end
  end

  defp note(module, list, secure?, adapter, identity_opts) do
    policies =
      if secure? do
        quote context: Elixir do
          policies do
            policy action_type([:read, :update]) do
              authorize_if(expr(visible == true))
            end

            policy action_type([:create, :destroy]) do
              authorize_if(always())
            end
          end
        end
      end

    authorizers = if secure?, do: [Ash.Policy.Authorizer], else: []

    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "adv_notes",
          authorizers: unquote(authorizers)

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:org_id, :integer, public?: true)
          attribute(:local_id, :integer, allow_nil?: false, public?: true)
          attribute(:code, :string, allow_nil?: false, public?: true)
          attribute(:body, :string, public?: true)
          attribute(:value, :integer, public?: true)
          attribute(:list_id, :integer, public?: true)
          attribute(:visible, :boolean, public?: true, default: true)
        end

        multitenancy do
          strategy(:attribute)
          attribute(:org_id)
        end

        identities do
          identity(:local_id, [:local_id], unquote(identity_opts))
          identity(:code, [:code], unquote(code_identity_opts(identity_opts)))
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])

          read :global do
            multitenancy(:allow_global)
          end

          update :edit do
            accept([:body, :value])
            require_atomic?(false)
            change(Ash.Conformance.Resources.NonAtomic)
          end

          destroy :remove do
            require_atomic?(false)
            change(Ash.Conformance.Resources.NonAtomic)
          end
        end

        relationships do
          belongs_to(:list, unquote(list), define_attribute?: false, public?: true)
        end

        unquote(policies)
      end
    end
  end

  # An all-tenants identity can't be pre-checked, so a data layer that can't
  # enforce identities itself (ETS) gets a tenant-scoped `code` instead.
  defp code_identity_opts(identity_opts) do
    if identity_opts[:pre_check?], do: identity_opts, else: [all_tenants?: true]
  end

  defp list(module, note, adapter) do
    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "adv_lists",
          authorizers: [Ash.Policy.Authorizer]

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:org_id, :integer, public?: true)
          attribute(:name, :string, public?: true)
        end

        multitenancy do
          strategy(:attribute)
          attribute(:org_id)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])

          update :attach do
            argument(:note_ids, {:array, :integer}, allow_nil?: false)
            require_atomic?(false)
            change(manage_relationship(:note_ids, :notes, type: :append))
          end
        end

        relationships do
          has_many(:notes, unquote(note), destination_attribute: :list_id, public?: true)
        end

        policies do
          policy always() do
            authorize_if(always())
          end
        end
      end
    end
  end

  defp person(module, order, adapter) do
    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "adv_people",
          authorizers: [Ash.Policy.Authorizer]

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:name, :string, public?: true)
          attribute(:secret, :string, public?: true)
          attribute(:event_id, :integer, public?: true)
          attribute(:profile, Ash.Conformance.Resources.AdvProfile, public?: true)
          attribute(:cards, {:array, Ash.Conformance.Resources.AdvCard}, public?: true)

          attribute(:payment, :union,
            public?: true,
            constraints: [
              types: [
                card: [type: Ash.Conformance.Resources.AdvCard],
                note: [type: :string]
              ]
            ]
          )
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])

          update :edit do
            accept([:name])
            require_atomic?(false)
            change(Ash.Conformance.Resources.NonAtomic)
          end
        end

        relationships do
          has_many(:orders, unquote(order),
            source_attribute: :event_id,
            destination_attribute: :event_id
          )
        end

        aggregates do
          count(:order_count, :orders, public?: true)
        end

        policies do
          policy always() do
            authorize_if(always())
          end
        end

        field_policies do
          field_policy [:secret, :order_count] do
            authorize_if(actor_attribute_equals(:admin, true))
          end

          field_policy :* do
            authorize_if(always())
          end
        end
      end
    end
  end

  @doc "Ids for join rows `manage_relationship` creates, clear of every fixture's ids."
  def next_id, do: 700_000 + System.unique_integer([:positive, :monotonic])
end

defmodule Ash.Conformance.Resources.NonAtomic do
  @moduledoc "A change with no atomic form, so its action can't run atomically."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context), do: changeset
end
