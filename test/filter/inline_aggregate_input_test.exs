# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Filter.InlineAggregateInputTest do
  @moduledoc false
  use ExUnit.Case, async: true

  require Ash.Query
  import Ash.Expr

  defmodule Comment do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Filter.InlineAggregateInputTest.Domain,
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
      belongs_to :post, Ash.Test.Filter.InlineAggregateInputTest.Post,
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
      domain: Ash.Test.Filter.InlineAggregateInputTest.Domain,
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
      has_many :comments, Ash.Test.Filter.InlineAggregateInputTest.Comment, public?: true
      has_many :hidden_comments, Ash.Test.Filter.InlineAggregateInputTest.Comment
    end

    actions do
      defaults [:read, create: :*]
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Ash.Test.Filter.InlineAggregateInputTest.Comment
      resource Ash.Test.Filter.InlineAggregateInputTest.Post
    end
  end

  @user [actor: %{admin?: false}, authorize?: true]
  @admin [actor: %{admin?: true}, authorize?: true]

  setup do
    p1 = Ash.create!(Post, %{name: "p1", internal: "zz"}, authorize?: false)
    Ash.create!(Post, %{name: "p2", internal: "aa"}, authorize?: false)

    for {body, visible} <- [{"secret", false}, {"public", true}, {"public2", true}] do
      Ash.create!(Comment, %{post_id: p1.id, body: body, visible: visible}, authorize?: false)
    end

    :ok
  end

  defp names(query, opts) do
    query |> Ash.read!(opts) |> Enum.map(& &1.name) |> Enum.sort()
  end

  test "an inline aggregate in client input only counts related records the actor can read" do
    # One hidden and two visible comments on p1.
    assert names(Ash.Query.filter_input(Post, expr(count(comments) == 3)), @user) == []
    assert names(Ash.Query.filter_input(Post, expr(count(comments) == 2)), @user) == ["p1"]
  end

  test "an inline aggregate's filter on visible fields works in client input" do
    assert names(
             Ash.Query.filter_input(
               Post,
               expr(count(comments, filter: expr(body == "public")) == 1)
             ),
             @user
           ) == ["p1"]
  end

  test "an inline aggregate's filter is client input" do
    # Back through the comment to its post, to test the post's hidden field.
    for filter <- [
          expr(count(comments, filter: expr(post.internal == "zz")) == 2),
          expr(count(comments, query: [filter: expr(post.internal == "zz")]) == 2)
        ] do
      assert names(Ash.Query.filter_input(Post, filter), @user) == []
      assert names(Ash.Query.filter_input(Post, filter), @admin) == ["p1"]
    end
  end

  test "an inline aggregate in client input can't turn off authorization" do
    query = Ash.Query.filter_input(Post, expr(count(comments, authorize?: false) == 3))
    assert {:error, %Ash.Error.Invalid{}} = Ash.read(query, @user)
  end

  test "an inline aggregate in client input can't use a relationship that isn't public" do
    query = Ash.Query.filter_input(Post, expr(count(hidden_comments) == 2))
    assert {:error, %Ash.Error.Invalid{}} = Ash.read(query, @user)
  end

  test "an inline aggregate in client input can't aggregate over another resource" do
    query = Ash.Query.filter_input(Post, expr(count(Comment, filter: expr(visible == true)) > 0))
    assert {:error, %Ash.Error.Invalid{}} = Ash.read(query, @user)
  end

  test "trusted filters can aggregate over a relationship that isn't public" do
    # The aggregate still only counts comments the actor can read.
    assert names(Ash.Query.filter(Post, count(hidden_comments) == 2), @user) == ["p1"]
  end

  test "an inline aggregate over a path that doesn't exist returns an error" do
    refute Ash.Query.filter_input(Post, expr(count(nope) > 0)).valid?
    refute Ash.Query.filter(Post, count(nope) > 0).valid?
  end
end
