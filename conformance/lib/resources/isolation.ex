# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Isolation do
  @moduledoc "Shared resource roles for attribute tenancy and policy interactions."

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)
    identity_opts = Ash.Conformance.Resources.Base.identity_options(adapter)

    definitions =
      for {prefix, secured?, contextual?} <- [
            {"Tenant", false, false},
            {"Secure", true, false},
            {"Context", true, true}
          ] do
        parent = Module.concat(namespace, prefix <> "Parent")
        item = Module.concat(namespace, prefix <> "Item")

        quote context: Elixir do
          defmodule unquote(parent) do
            use Ash.Conformance.Resources.Base,
              adapter: unquote(adapter),
              table: "dc_parents",
              authorizers: [Ash.Policy.Authorizer]

            attributes do
              attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
              attribute(:tenant_id, :integer, public?: true)
              attribute(:local_id, :integer, allow_nil?: false, public?: true)
              attribute(:owner_id, :integer, allow_nil?: false, public?: true)
              attribute(:name, :string, public?: true)
            end

            multitenancy do
              strategy(:attribute)
              attribute(:tenant_id)
            end

            identities do
              identity(:local_id, [:local_id], unquote(identity_opts))
            end

            actions do
              defaults([:read, :destroy, create: :*, update: :*])

              read :global do
                multitenancy(:allow_global)
              end

              read :offset_page do
                pagination(offset?: true, countable: true, required?: false)
              end

              read :keyset_page do
                pagination(keyset?: true, countable: true, required?: false)
              end
            end

            relationships do
              has_many(:items, unquote(item),
                source_attribute: :local_id,
                destination_attribute: :parent_key,
                sort: [id: :asc],
                public?: true
              )

              has_many(:top_items, unquote(item),
                source_attribute: :local_id,
                destination_attribute: :parent_key,
                sort: [value: :desc_nils_last, id: :asc],
                limit: 1
              )

              has_many(:middle_items, unquote(item),
                source_attribute: :local_id,
                destination_attribute: :parent_key,
                sort: [value: :desc_nils_last, id: :asc],
                limit: 1,
                offset: 1
              )

              has_one(:best_item, unquote(item),
                source_attribute: :local_id,
                destination_attribute: :parent_key,
                from_many?: true,
                sort: [value: :desc_nils_last, id: :asc]
              )
            end

            aggregates do
              count(:item_count, :items, public?: true)
              sum(:item_sum, :items, :value, default: 0, public?: true)
              first(:top_value, :top_items, :value, public?: true)
            end

            calculations do
              calculate(:double_local_id, :integer, expr(local_id * 2), public?: true)
            end

            if unquote(secured?) do
              policies do
                policy action_type(:read) do
                  authorize_if(expr(owner_id == ^actor(:id)))
                end
              end
            else
              policies do
                policy always() do
                  authorize_if(always())
                end
              end
            end
          end

          defmodule unquote(item) do
            use Ash.Conformance.Resources.Base,
              adapter: unquote(adapter),
              table: "dc_items",
              authorizers: [Ash.Policy.Authorizer]

            attributes do
              attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
              attribute(:tenant_id, :integer, public?: true)
              attribute(:local_id, :integer, allow_nil?: false, public?: true)
              attribute(:parent_key, :integer, allow_nil?: false, public?: true)
              attribute(:owner_id, :integer, allow_nil?: false, public?: true)
              attribute(:department, :integer, allow_nil?: false, public?: true)
              attribute(:value, :integer, public?: true)
            end

            multitenancy do
              strategy(:attribute)
              attribute(:tenant_id)
            end

            identities do
              identity(:local_id, [:local_id], unquote(identity_opts))
            end

            actions do
              defaults([:read, :destroy, create: :*, update: :*])
            end

            if unquote(secured?) do
              policies do
                policy action_type(:read) do
                  authorize_if(expr(owner_id == ^actor(:id)))
                end

                policy action_type([:update, :destroy]) do
                  authorize_if(expr(owner_id == ^actor(:id)))
                end

                if unquote(contextual?) do
                  policy action_type(:read) do
                    authorize_if(expr(department == ^context([:shared, :department])))
                  end
                end
              end
            else
              policies do
                policy always() do
                  authorize_if(always())
                end
              end
            end
          end
        end
      end

    quote do
      (unquote_splicing(definitions))
    end
  end
end
