# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Filter.ExistsInputTest do
  @moduledoc false
  use ExUnit.Case, async: true

  require Ash.Query
  import Ash.Expr

  defmodule Comment do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Filter.ExistsInputTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private? true
    end

    policies do
      policy always() do
        authorize_if expr(visible == true)
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :body, :string, public?: true
      attribute :visible, :boolean, public?: true
    end

    relationships do
      belongs_to :post, Ash.Test.Filter.ExistsInputTest.Post,
        public?: true,
        attribute_writable?: true
    end

    actions do
      defaults [:read, create: :*]
    end
  end

  defmodule Post do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Filter.ExistsInputTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private? true
    end

    policies do
      policy always() do
        authorize_if always()
      end
    end

    field_policies do
      field_policy :internal do
        authorize_if actor_attribute_equals(:admin?, true)
      end

      field_policy :* do
        authorize_if always()
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
      attribute :internal, :string, public?: true
    end

    relationships do
      has_many :comments, Ash.Test.Filter.ExistsInputTest.Comment, public?: true
      has_many :hidden_comments, Ash.Test.Filter.ExistsInputTest.Comment
    end

    actions do
      defaults [:read, create: :*]
    end
  end

  defmodule SimplePost do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Filter.ExistsInputTest.Domain,
      data_layer: Ash.DataLayer.Simple

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Ash.Test.Filter.ExistsInputTest.Comment
      resource Ash.Test.Filter.ExistsInputTest.Post
      resource Ash.Test.Filter.ExistsInputTest.SimplePost
    end
  end

  @user [actor: %{admin?: false}, authorize?: true]
  @admin [actor: %{admin?: true}, authorize?: true]

  setup do
    p1 = Ash.create!(Post, %{name: "p1", internal: "zz"}, authorize?: false)
    Ash.create!(Post, %{name: "p2", internal: "aa"}, authorize?: false)

    for {body, visible} <- [{"secret", false}, {"public", true}] do
      Ash.create!(Comment, %{post_id: p1.id, body: body, visible: visible}, authorize?: false)
    end

    :ok
  end

  defp names(query, opts) do
    query |> Ash.read!(opts) |> Enum.map(& &1.name) |> Enum.sort()
  end

  test "exists in client input only sees related records the actor can read" do
    assert names(Ash.Query.filter_input(Post, expr(exists(comments, body == "secret"))), @user) ==
             []

    assert names(Ash.Query.filter_input(Post, expr(exists(comments, body == "public"))), @user) ==
             ["p1"]
  end

  test "exists with parent in client input hides the parent's hidden fields" do
    filter = expr(exists(comments, parent(internal) == "zz"))
    assert names(Ash.Query.filter_input(Post, filter), @user) == []
    assert names(Ash.Query.filter_input(Post, filter), @admin) == ["p1"]
  end

  test "exists in client input can't use a relationship that isn't public" do
    query = Ash.Query.filter_input(Post, expr(exists(hidden_comments, body == "public")))
    assert {:error, %Ash.Error.Invalid{}} = Ash.read(query, @user)

    query = Ash.Query.filter_input(Post, %{exists: %{hidden_comments: %{body: "public"}}})
    assert {:error, %Ash.Error.Invalid{}} = Ash.read(query, @user)
  end

  test "exists nested in an operator in client input can't use a relationship that isn't public" do
    # Nested in an operator, exists is hydrated rather than parsed.
    query = Ash.Query.filter_input(Post, expr(exists(hidden_comments, body == "public") == true))
    assert {:error, %Ash.Error.Invalid{}} = Ash.read(query, @user)
  end

  test "trusted filters can use exists over a relationship that isn't public" do
    assert names(Ash.Query.filter(Post, exists(hidden_comments, body == "public")), @user) ==
             ["p1"]
  end

  test "exists over a path that doesn't exist adds an Invalid error" do
    query = Ash.Query.filter_input(Post, expr(exists(nope, true)))
    refute query.valid?
    assert {:error, %Ash.Error.Invalid{}} = Ash.read(query, @user)

    query = Ash.Query.filter(Post, exists(nope, true))
    refute query.valid?
    assert {:error, %Ash.Error.Invalid{}} = Ash.read(query, @user)
  end

  test "unrelated exists on a data layer that doesn't support it adds an error" do
    refute Ash.Query.filter(SimplePost, exists(Comment, visible == true)).valid?
  end
end
