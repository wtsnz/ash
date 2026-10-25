# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Policy.FieldPolicy.SortInputAggregateTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule Comment do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Policy.FieldPolicy.SortInputAggregateTest.Domain,
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

    attributes do
      uuid_primary_key :id
      attribute :body, :string, public?: true
    end

    relationships do
      belongs_to :post, Ash.Test.Policy.FieldPolicy.SortInputAggregateTest.Post,
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
      domain: Ash.Test.Policy.FieldPolicy.SortInputAggregateTest.Domain,
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
      field_policy [:comment_count, :first_comment_body] do
        authorize_if actor_attribute_equals(:admin?, true)
      end

      field_policy :* do
        authorize_if always()
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    relationships do
      has_many :comments, Ash.Test.Policy.FieldPolicy.SortInputAggregateTest.Comment,
        public?: true
    end

    aggregates do
      count :comment_count, :comments, public?: true

      first :first_comment_body, :comments, :body do
        public? true
        sort body: :asc
      end
    end

    actions do
      defaults [:read, create: :*]
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Ash.Test.Policy.FieldPolicy.SortInputAggregateTest.Comment
      resource Ash.Test.Policy.FieldPolicy.SortInputAggregateTest.Post
    end
  end

  @user [actor: %{admin?: false}, authorize?: true]
  @admin [actor: %{admin?: true}, authorize?: true]

  setup do
    p1 = Ash.create!(Post, %{name: "p1"}, authorize?: false)
    p2 = Ash.create!(Post, %{name: "p2"}, authorize?: false)
    _p3 = Ash.create!(Post, %{name: "p3"}, authorize?: false)

    for {post, body} <- [{p1, "c"}, {p1, "d"}, {p2, "a"}] do
      Ash.create!(Comment, %{post_id: post.id, body: body}, authorize?: false)
    end

    :ok
  end

  defp ordered(sort, opts) do
    Post |> Ash.Query.sort_input(sort) |> Ash.read!(opts) |> Enum.map(& &1.name)
  end

  test "sort_input on an aggregate the actor can see orders by it" do
    assert ordered([comment_count: :desc, name: :asc], @admin) == ["p1", "p2", "p3"]
    assert ordered([first_comment_body: :asc_nils_last, name: :asc], @admin) == ["p2", "p1", "p3"]
  end

  test "sort_input on a count the actor can't see doesn't order by it" do
    assert {:ok, desc} = Post |> Ash.Query.sort_input(comment_count: :desc) |> Ash.read(@user)
    assert {:ok, asc} = Post |> Ash.Query.sort_input(comment_count: :asc) |> Ash.read(@user)
    assert Enum.map(desc, & &1.name) == Enum.map(asc, & &1.name)
  end

  test "sort_input on an aggregate of a field the actor can't see doesn't order by it" do
    assert {:ok, desc} =
             Post |> Ash.Query.sort_input(first_comment_body: :desc) |> Ash.read(@user)

    assert {:ok, asc} = Post |> Ash.Query.sort_input(first_comment_body: :asc) |> Ash.read(@user)
    assert Enum.map(desc, & &1.name) == Enum.map(asc, & &1.name)
  end
end
