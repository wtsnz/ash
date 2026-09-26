# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Shapes do
  @moduledoc """
  The shapes grid's resources (`Ash.Conformance.Shapes`): integer-keyed roots,
  and mids, leaves and tips keyed by integers or UUIDs. Roots define one
  aggregate per key type, depth, condition and kind; mids read their root's
  label in a calculation.
  """
  alias Ash.Conformance.Shapes

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)
    module = fn role -> Module.concat(namespace, Macro.camelize(to_string(role))) end
    root = module.(:shape_root)

    chains =
      for key <- [:integer, :uuid] do
        mid = module.(:"shape_#{key}_mid")
        leaf = module.(:"shape_#{key}_leaf")
        tip = module.(:"shape_#{key}_tip")
        type = if key == :integer, do: :integer, else: :uuid

        quote context: Elixir do
          defmodule unquote(mid) do
            use Ash.Conformance.Resources.Base,
              adapter: unquote(adapter),
              table: unquote("shape_#{key}_mids")

            attributes do
              attribute(:id, unquote(type), primary_key?: true, allow_nil?: false, public?: true)
              attribute(:value, :integer, public?: true)
            end

            actions do
              defaults([:read, :destroy, create: :*, update: :*])
            end

            relationships do
              belongs_to(:root, unquote(root),
                attribute_type: :integer,
                allow_nil?: true,
                public?: true,
                attribute_public?: true
              )

              has_many(:leaves, unquote(leaf), destination_attribute: :mid_id, public?: true)
            end

            calculations do
              calculate(:root_label, :string, expr(root.label), public?: true)

              calculate(
                :root_label_module,
                :string,
                {Ash.Conformance.Resources.RefCalculation, relationship: :root, field: :label},
                public?: true
              )
            end

            aggregates do
              count(:leaf_count, :leaves, public?: true)
            end
          end

          defmodule unquote(leaf) do
            use Ash.Conformance.Resources.Base,
              adapter: unquote(adapter),
              table: unquote("shape_#{key}_leaves")

            attributes do
              attribute(:id, unquote(type), primary_key?: true, allow_nil?: false, public?: true)
              attribute(:mid_id, unquote(type), public?: true)
              attribute(:value, :integer, public?: true)
            end

            actions do
              defaults([:read, :destroy, create: :*, update: :*])
            end

            relationships do
              has_many(:tips, unquote(tip), destination_attribute: :leaf_id, public?: true)
            end
          end

          defmodule unquote(tip) do
            use Ash.Conformance.Resources.Base,
              adapter: unquote(adapter),
              table: unquote("shape_#{key}_tips")

            attributes do
              attribute(:id, unquote(type), primary_key?: true, allow_nil?: false, public?: true)
              attribute(:leaf_id, unquote(type), public?: true)
              attribute(:value, :integer, public?: true)
            end

            actions do
              defaults([:read, :destroy, create: :*, update: :*])
            end
          end
        end
      end

    aggregates = Enum.map(Shapes.aggregates(), &aggregate/1)
    integer_mid = module.(:shape_integer_mid)
    uuid_mid = module.(:shape_uuid_mid)

    quote context: Elixir do
      defmodule unquote(root) do
        use Ash.Conformance.Resources.Base, adapter: unquote(adapter), table: "shape_roots"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:label, :string, public?: true)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])
        end

        relationships do
          has_many(:integer_mids, unquote(integer_mid),
            destination_attribute: :root_id,
            public?: true
          )

          has_many(:uuid_mids, unquote(uuid_mid), destination_attribute: :root_id, public?: true)

          # Sorted by the destination's own aggregate, so the sort runs inside
          # the relationship's subquery.
          has_many(:integer_mids_by_leaves, unquote(integer_mid),
            destination_attribute: :root_id,
            sort: [leaf_count: :desc, value: :asc],
            public?: true
          )

          has_many(:uuid_mids_by_leaves, unquote(uuid_mid),
            destination_attribute: :root_id,
            sort: [leaf_count: :desc, value: :asc],
            public?: true
          )
        end

        aggregates do
          (unquote_splicing(aggregates))

          first(:first_by_leaves_integer, :integer_mids, :value,
            sort: [leaf_count: :desc, value: :asc],
            public?: true
          )

          first(:first_by_leaves_uuid, :uuid_mids, :value,
            sort: [leaf_count: :desc, value: :asc],
            public?: true
          )
        end
      end

      unquote_splicing(chains)
    end
  end

  defp aggregate(%{key: key, depth: depth, predicate: predicate, kind: kind} = definition) do
    name = Shapes.aggregate_name(definition)
    path = Shapes.path(key, depth)

    opts =
      [public?: true] ++
        case predicate do
          :none -> []
          :constant -> [filter: true]
          :field -> [filter: quote(context: Elixir, do: expr(value > 2))]
        end

    case kind do
      :count -> quote(context: Elixir, do: count(unquote(name), unquote(path), unquote(opts)))
      :exists -> quote(context: Elixir, do: exists(unquote(name), unquote(path), unquote(opts)))
      :sum -> quote(context: Elixir, do: sum(unquote(name), unquote(path), :value, unquote(opts)))
    end
  end
end
