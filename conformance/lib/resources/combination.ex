# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Combination do
  @moduledoc """
  The combination grid's resources, over integer and string columns only:
  owners (`cb_owners`), items (`cb_items`) and the links between them
  (`cb_links`). See `Ash.Conformance.Combinations`.

  Items are multitenant by their `tenant` attribute, with global reads
  allowed, and readable only by the user in `seen_by`. Owners define one
  aggregate per kind, relationship and aggregate filter.
  """
  alias Ash.Conformance.Combinations

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)
    module = fn role -> Module.concat(namespace, Macro.camelize(to_string(role))) end
    owner = module.(:combo_owner)
    item = module.(:combo_item)
    link = module.(:combo_link)

    quote context: Elixir do
      unquote(item(item, owner, adapter))
      unquote(link(link, adapter))
      unquote(owner(owner, item, link, adapter))
    end
  end

  defp owner(module, item, link, adapter) do
    aggregates = Enum.map(Combinations.aggregates(), &aggregate/1)

    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "cb_owners",
          authorizers: [Ash.Policy.Authorizer]

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:label, :string, public?: true)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])

          read :paged do
            pagination(offset?: true, keyset?: true, countable: true, required?: false)
          end

          create :create_with_items do
            accept([:id, :label])
            argument(:items, {:array, :map})
            change(manage_relationship(:items, type: :create))
          end

          update :replace_items do
            require_atomic?(false)
            argument(:items, {:array, :map})
            change(manage_relationship(:items, type: :direct_control))
          end
        end

        relationships do
          has_many(:items, unquote(item), destination_attribute: :owner_id, public?: true)

          has_many(:top_items, unquote(item),
            destination_attribute: :owner_id,
            sort: [value: :desc_nils_last, id: :asc],
            limit: 2,
            public?: true
          )

          many_to_many :linked_items, unquote(item) do
            through(unquote(link))
            source_attribute_on_join_resource(:owner_id)
            destination_attribute_on_join_resource(:item_id)
            public?(true)
          end
        end

        aggregates do
          (unquote_splicing(aggregates))
          sum(:double_sum, :items, :double_value, public?: true)
        end

        calculations do
          calculate(:count_doubled, :integer, expr(count_items_none * 2), public?: true)
        end

        policies do
          policy always() do
            authorize_if(always())
          end
        end
      end
    end
  end

  defp aggregate(%{kind: kind, relationship: relationship, filter: filter} = definition) do
    name = Combinations.aggregate_name(definition)

    opts =
      [public?: true] ++
        case filter do
          :none -> []
          :value_gt -> [filter: quote(context: Elixir, do: expr(value > 2))]
          :open -> [filter: quote(context: Elixir, do: expr(status == "open"))]
        end

    case kind do
      :count ->
        quote(context: Elixir, do: count(unquote(name), unquote(relationship), unquote(opts)))

      :exists ->
        quote(context: Elixir, do: exists(unquote(name), unquote(relationship), unquote(opts)))

      :sum ->
        quote(
          context: Elixir,
          do: sum(unquote(name), unquote(relationship), :value, unquote(opts))
        )

      :max ->
        quote(
          context: Elixir,
          do: max(unquote(name), unquote(relationship), :value, unquote(opts))
        )

      :list ->
        opts = opts ++ [sort: [id: :asc]]

        quote(
          context: Elixir,
          do: list(unquote(name), unquote(relationship), :value, unquote(opts))
        )
    end
  end

  defp item(module, owner, adapter) do
    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "cb_items",
          authorizers: [Ash.Policy.Authorizer]

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:owner_id, :integer, public?: true)
          attribute(:tenant, :string, public?: true)
          attribute(:value, :integer, public?: true)
          attribute(:status, :string, public?: true)
          attribute(:seen_by, :integer, public?: true)
        end

        multitenancy do
          strategy(:attribute)
          attribute(:tenant)
          global?(true)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])
        end

        relationships do
          belongs_to(:owner, unquote(owner),
            source_attribute: :owner_id,
            define_attribute?: false,
            public?: true
          )
        end

        calculations do
          calculate(:double_value, :integer, expr(value * 2), public?: true)

          calculate :value_plus, :integer, expr(value + ^arg(:amount)) do
            argument(:amount, :integer, allow_nil?: false)
            public?(true)
          end
        end

        policies do
          policy action_type(:read) do
            authorize_if(expr(seen_by == ^actor(:id)))
          end

          policy action_type([:create, :update, :destroy]) do
            authorize_if(always())
          end
        end
      end
    end
  end

  defp link(module, adapter) do
    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "cb_links"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:owner_id, :integer, public?: true)
          attribute(:item_id, :integer, public?: true)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])
        end
      end
    end
  end
end
