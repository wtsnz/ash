# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Policy do
  @moduledoc """
  The policy grid's resources: documents (`pc_docs`), notes (`pc_notes`) and
  document members (`pc_members`), using only integer and string columns.

  The base roles (`policy_doc`, `policy_note`, `policy_member`) allow
  everything and are used to seed. Each policy shape adds a document and a
  note over the same tables; the note carries the shape's policy on reads,
  updates and destroys. See `Ash.Conformance.Policy` for each shape's rule.
  """
  alias Ash.Conformance.Policy

  defmacro __using__(opts) do
    namespace = opts |> Keyword.fetch!(:namespace) |> Macro.expand(__CALLER__)
    adapter = opts |> Keyword.fetch!(:adapter) |> Macro.expand(__CALLER__)
    module = fn role -> Module.concat(namespace, Macro.camelize(to_string(role))) end
    member = module.(:policy_member)

    pairs =
      [{module.(:policy_doc), module.(:policy_note), :base}] ++
        for shape <- Policy.shapes(),
            do: {module.(Policy.role(shape, :doc)), module.(Policy.role(shape, :note)), shape}

    definitions =
      Enum.flat_map(pairs, fn {doc, note, shape} ->
        [doc(doc, note, member, shape, adapter), note(note, doc, shape, adapter)]
      end)

    quote context: Elixir do
      unquote(member(member, adapter))
      (unquote_splicing(definitions))
    end
  end

  defp member(module, adapter) do
    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "pc_members",
          authorizers: [Ash.Policy.Authorizer]

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:doc_id, :integer, public?: true)
          attribute(:user_id, :integer, public?: true)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])
        end

        policies do
          policy always() do
            authorize_if(always())
          end
        end
      end
    end
  end

  defp doc(module, note, member, shape, adapter) do
    policies =
      if shape == :can_read do
        quote context: Elixir do
          policy action_type(:read) do
            authorize_if(expr(team_id == ^actor(:team)))
          end

          policy action_type([:create, :update, :destroy]) do
            authorize_if(always())
          end
        end
      else
        quote context: Elixir do
          policy always() do
            authorize_if(always())
          end
        end
      end

    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "pc_docs",
          authorizers: [Ash.Policy.Authorizer]

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:team_id, :integer, public?: true)
          attribute(:owner_id, :integer, public?: true)
          attribute(:status, :string, public?: true)
          attribute(:title, :string, public?: true)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])
        end

        relationships do
          has_many(:notes, unquote(note), destination_attribute: :doc_id, public?: true)
          has_many(:members, unquote(member), destination_attribute: :doc_id, public?: true)
        end

        aggregates do
          count(:note_count, :notes, public?: true)
          sum(:note_score, :notes, :score, default: 0, public?: true)
          count(:secret_count, :notes, field: :secret, public?: true)
        end

        policies do
          unquote(policies)
        end
      end
    end
  end

  defp note(module, doc, shape, adapter) do
    quote context: Elixir do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base,
          adapter: unquote(adapter),
          table: "pc_notes",
          authorizers: [Ash.Policy.Authorizer]

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
          attribute(:doc_id, :integer, public?: true)
          attribute(:owner_id, :integer, public?: true)
          attribute(:team_id, :integer, public?: true)
          attribute(:status, :string, public?: true)
          attribute(:score, :integer, public?: true)
          attribute(:secret, :string, public?: true)
        end

        actions do
          defaults([:read, :destroy, create: :*, update: :*])

          read :offset_page do
            pagination(offset?: true, countable: true, required?: false)
          end

          read :keyset_page do
            pagination(keyset?: true, countable: true, required?: false)
          end
        end

        relationships do
          belongs_to(:doc, unquote(doc),
            source_attribute: :doc_id,
            define_attribute?: false,
            public?: true
          )
        end

        policies do
          unquote(Ash.Conformance.Resources.Policy.note_policies(shape))
        end

        unquote(Ash.Conformance.Resources.Policy.field_policies(shape))
      end
    end
  end

  @doc false
  # Each shape's note policy, applied to reads, updates and destroys. Creates
  # are allowed, except in the owner shape, whose create policy is a filter
  # check that Ash evaluates after the insert.
  def note_policies(:owner) do
    quote context: Elixir do
      policy action_type([:read, :update, :destroy]) do
        authorize_if(expr(owner_id == ^actor(:id)))
      end

      policy action_type(:create) do
        authorize_if(expr(owner_id == ^actor(:id)))
      end
    end
  end

  def note_policies(:forbid) do
    guarded(
      quote context: Elixir do
        forbid_if(expr(status == "draft"))
        authorize_if(always())
      end
    )
  end

  def note_policies(:bypass) do
    quote context: Elixir do
      bypass actor_attribute_equals(:admin, true) do
        authorize_if(always())
      end

      policy action_type([:read, :update, :destroy]) do
        authorize_if(expr(owner_id == ^actor(:id)))
      end

      policy action_type(:create) do
        authorize_if(always())
      end
    end
  end

  def note_policies(:all_of) do
    quote context: Elixir do
      policy action_type([:read, :update, :destroy]) do
        authorize_if(expr(owner_id == ^actor(:id)))
      end

      policy action_type([:read, :update, :destroy]) do
        authorize_if(expr(team_id == ^actor(:team)))
      end

      policy action_type(:create) do
        authorize_if(always())
      end
    end
  end

  def note_policies(:any_of) do
    guarded(
      quote context: Elixir do
        authorize_if(expr(owner_id == ^actor(:id)))
        authorize_if(expr(status == "published"))
      end
    )
  end

  def note_policies(:related),
    do: guarded(quote(context: Elixir, do: authorize_if(expr(doc.team_id == ^actor(:team)))))

  def note_policies(:member),
    do:
      guarded(
        quote(
          context: Elixir,
          do: authorize_if(expr(exists(doc.members, user_id == ^actor(:id))))
        )
      )

  def note_policies(:can_read),
    do: guarded(quote(context: Elixir, do: authorize_if(can_read(:doc))))

  def note_policies(:strict) do
    quote context: Elixir do
      policy action_type([:read, :update, :destroy]) do
        access_type(:strict)
        authorize_if(actor_attribute_equals(:admin, true))
      end

      policy action_type(:create) do
        authorize_if(always())
      end
    end
  end

  def note_policies(shape) when shape in [:base, :field] do
    quote context: Elixir do
      policy always() do
        authorize_if(always())
      end
    end
  end

  defp guarded(checks) do
    quote context: Elixir do
      policy action_type([:read, :update, :destroy]) do
        unquote(checks)
      end

      policy action_type(:create) do
        authorize_if(always())
      end
    end
  end

  @doc false
  def field_policies(:field) do
    quote context: Elixir do
      field_policies do
        field_policy :secret do
          authorize_if(expr(owner_id == ^actor(:id)))
        end

        field_policy :* do
          authorize_if(always())
        end
      end
    end
  end

  def field_policies(_shape), do: nil
end
