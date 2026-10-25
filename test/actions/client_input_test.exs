# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Actions.ClientInputTest do
  @moduledoc """
  Filters, sorts, pages and loads given by a client apply field policies and the read policies of
  related resources.

  `Ash.Query.filter_input/3` and `Ash.Query.sort_input/3` mark what they're given as client
  input, so the authorizer hides fields the actor can't see and related records it can't read.
  `Ash.Query.filter/2`, `Ash.Query.do_filter/3`, `Ash.Query.sort/3` and a page's `:filter` are
  trusted. The "keeps working" tests cover both; the others cover client input that raised, and
  `Ash.Query.apply_client_input/3`, which applies a client's whole query.
  """
  use ExUnit.Case, async: true

  require Ash.Query
  require Ash.Sort
  import Ash.Expr

  defmodule Comment do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.ClientInputTest.Domain,
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
      belongs_to :post, Ash.Test.Actions.ClientInputTest.Post,
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
      domain: Ash.Test.Actions.ClientInputTest.Domain,
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
      field_policy [:internal, :comment_count] do
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
      has_many :comments, Ash.Test.Actions.ClientInputTest.Comment, public?: true
      has_many :hidden_comments, Ash.Test.Actions.ClientInputTest.Comment
    end

    aggregates do
      count :comment_count, :comments, public?: true
    end

    actions do
      defaults [:read, create: :*]

      read :paged do
        pagination offset?: true, keyset?: true, required?: false
      end
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Ash.Test.Actions.ClientInputTest.Comment
      resource Ash.Test.Actions.ClientInputTest.Post
    end
  end

  @user [actor: %{admin?: false}, authorize?: true]
  @admin [actor: %{admin?: true}, authorize?: true]

  setup do
    p1 = Ash.create!(Post, %{name: "p1", internal: "zz"}, authorize?: false)
    p2 = Ash.create!(Post, %{name: "p2", internal: "aa"}, authorize?: false)
    p3 = Ash.create!(Post, %{name: "p3", internal: "mm"}, authorize?: false)

    for {body, visible} <- [{"secret", false}, {"public", true}, {"public2", true}] do
      Ash.create!(Comment, %{post_id: p1.id, body: body, visible: visible}, authorize?: false)
    end

    %{p1: p1, p2: p2, p3: p3}
  end

  defp names(query, opts) do
    query |> Ash.read!(opts) |> Enum.map(& &1.name) |> Enum.sort()
  end

  defp ordered(query, opts) do
    query |> Ash.read!(opts) |> Enum.map(& &1.name)
  end

  describe "keeps working" do
    test "filter_input hides field-policied values and related records the actor can't read" do
      assert names(Ash.Query.filter_input(Post, %{internal: %{eq: "zz"}}), @user) == []

      assert names(Ash.Query.filter_input(Post, %{comments: %{body: %{eq: "secret"}}}), @user) ==
               []

      assert names(Ash.Query.filter_input(Post, %{internal: %{eq: "zz"}}), @admin) == ["p1"]

      assert names(Ash.Query.filter_input(Post, %{comments: %{body: %{eq: "public"}}}), @user) ==
               ["p1"]
    end

    test "filter_input given an expression treats every reference in it as client input" do
      # What AshPhoenix.FilterForm builds: refs that aren't marked as input.
      hidden_field = expr(^Ash.Expr.ref(:internal) == "zz")
      hidden_related = expr(^Ash.Expr.ref([:comments], :body) == "secret")

      assert names(Ash.Query.filter_input(Post, hidden_field), @user) == []
      assert names(Ash.Query.filter_input(Post, hidden_related), @user) == []
      assert names(Ash.Query.filter_input(Post, hidden_field), @admin) == ["p1"]

      assert names(Ash.Query.filter_input(Post, expr(exists(comments, body == "secret"))), @user) ==
               []

      # One hidden and two visible comments on p1: a client can only count the visible ones.
      assert names(Ash.Query.filter_input(Post, expr(count(comments) == 3)), @user) == []
      assert names(Ash.Query.filter_input(Post, expr(count(comments) == 2)), @user) == ["p1"]
    end

    test "the same expression applied with do_filter/2 is trusted" do
      # Documents the trusted path, which AshPhoenix.FilterForm.filter/2 uses: it sees
      # the hidden field and the comment the actor can't read.
      assert names(Ash.Query.do_filter(Post, expr(^Ash.Expr.ref(:internal) == "zz")), @user) ==
               ["p1"]

      assert names(
               Ash.Query.do_filter(Post, expr(^Ash.Expr.ref([:comments], :body) == "secret")),
               @user
             ) == ["p1"]
    end

    test "sort_input on a hidden attribute doesn't order by it" do
      asc = ordered(Ash.Query.sort_input(Post, internal: :asc), @user)
      desc = ordered(Ash.Query.sort_input(Post, internal: :desc), @user)
      assert asc == desc

      assert ordered(Ash.Query.sort_input(Post, internal: :asc), @admin) == ["p2", "p3", "p1"]
    end

    test "sort_input on an aggregate the actor can see" do
      assert ordered(Ash.Query.sort_input(Post, comment_count: :desc, name: :asc), @admin) ==
               ["p1", "p2", "p3"]
    end

    test "trusted sorts on expressions" do
      assert ordered(
               Ash.Query.sort(Post, [{Ash.Sort.expr_sort(internal, :string), :asc}]),
               @admin
             ) ==
               ["p2", "p3", "p1"]
    end

    test "a page's filter is trusted, as the LiveView paginator uses it to refetch a page", %{
      p1: p1,
      p3: p3
    } do
      page =
        Post
        |> Ash.Query.for_read(:paged, %{}, @user)
        |> Ash.read!(page: [limit: 10, filter: [id: [in: [p1.id, p3.id]]]])

      assert page.results |> Enum.map(& &1.name) |> Enum.sort() == ["p1", "p3"]
    end
  end

  describe "sort_input" do
    test "on an aggregate the actor can't see doesn't order by it" do
      assert {:ok, desc} = Post |> Ash.Query.sort_input(comment_count: :desc) |> Ash.read(@user)
      assert {:ok, asc} = Post |> Ash.Query.sort_input(comment_count: :asc) |> Ash.read(@user)
      assert Enum.map(desc, & &1.name) == Enum.map(asc, & &1.name)
    end

    test "with an expression sort returns an error instead of raising" do
      query = Ash.Query.sort_input(Post, [{Ash.Sort.expr_sort(internal, :string), :asc}])

      refute query.valid?
      assert {:error, %Ash.Error.Invalid{}} = Ash.read(query, @user)
    end
  end

  describe "apply_client_input/3" do
    test "applies the filter and sort as client input" do
      assert Post
             |> Ash.Query.apply_client_input(%{filter: %{internal: %{eq: "zz"}}})
             |> names(@user) == []

      assert Post
             |> Ash.Query.apply_client_input(%{filter: %{internal: %{eq: "zz"}}})
             |> names(@admin) == ["p1"]

      asc = Post |> Ash.Query.apply_client_input(%{sort: "internal"}) |> ordered(@user)
      desc = Post |> Ash.Query.apply_client_input(%{sort: "-internal"}) |> ordered(@user)
      assert asc == desc
    end

    test "accepts string keys, as decoded from a request" do
      assert Post
             |> Ash.Query.apply_client_input(%{
               "filter" => %{"comments" => %{"body" => %{"eq" => "secret"}}},
               "sort" => "name"
             })
             |> names(@user) == []
    end

    test "applies the allowed page options" do
      page =
        Post
        |> Ash.Query.for_read(:paged, %{}, @user)
        |> Ash.Query.apply_client_input(%{sort: "name", page: %{"limit" => 1, "offset" => 1}})
        |> Ash.read!()

      assert Enum.map(page.results, & &1.name) == ["p2"]
    end

    test "refuses a page filter" do
      assert {:error, %Ash.Error.Invalid{}} =
               Post
               |> Ash.Query.for_read(:paged, %{}, @user)
               |> Ash.Query.apply_client_input(%{page: [limit: 10, filter: [internal: "zz"]]})
               |> Ash.read()
    end

    test "refuses unknown page options" do
      assert {:error, %Ash.Error.Invalid{}} =
               Post
               |> Ash.Query.for_read(:paged, %{}, @user)
               |> Ash.Query.apply_client_input(%{page: [limit: 10, before_all: true]})
               |> Ash.read()
    end

    test "applies nested load inputs as client input" do
      [p1] =
        Post
        |> Ash.Query.filter(name == "p1")
        |> Ash.Query.apply_client_input(%{
          load: %{comments: %{filter: %{body: %{in: ["secret", "public"]}}, sort: "body"}}
        })
        |> Ash.read!(@user)

      assert Enum.map(p1.comments, & &1.body) == ["public"]

      # A nested filter through the relationship back to the post hides the post's field too.
      [p1] =
        Post
        |> Ash.Query.filter(name == "p1")
        |> Ash.Query.apply_client_input(%{
          "load" => %{"comments" => %{"filter" => %{"post" => %{"internal" => %{"eq" => "zz"}}}}}
        })
        |> Ash.read!(@user)

      assert p1.comments == []
    end

    test "refuses loading a relationship that isn't public" do
      assert {:error, %Ash.Error.Invalid{}} =
               Post
               |> Ash.Query.apply_client_input(%{load: %{hidden_comments: %{}}})
               |> Ash.read(@user)
    end

    test "refuses unknown keys" do
      assert {:error, %Ash.Error.Invalid{}} =
               Post
               |> Ash.Query.apply_client_input(%{filter: %{name: "p1"}, select: [:internal]})
               |> Ash.read(@user)
    end
  end
end
