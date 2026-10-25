# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Actions.ReadTenantScopingTest do
  @moduledoc """
  Every read given a tenant only returns records in that tenant.

  The read action adds the attribute tenant filter itself. Queries that are lowered for the data
  layer or evaluated in memory without running the read action (by `Ash.can?`, data layers'
  joins and lookups, or `Ash.Query.data_layer_query/2` and `Ash.Query.apply_to/3` directly)
  carry the tenant but, without the filter, read every tenant's records. The "within a tenant"
  tests cover the same reads in normal use.
  """
  use ExUnit.Case, async: true

  require Ash.Expr
  require Ash.Query

  defmodule Note do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.ReadTenantScopingTest.Domain,
      data_layer: Ash.DataLayer.Ets

    ets do
      private? true
    end

    multitenancy do
      strategy :attribute
      attribute :shop_id
    end

    attributes do
      uuid_primary_key :id
      attribute :shop_id, :string, allow_nil?: false, public?: true
      attribute :body, :string, public?: true
    end

    actions do
      defaults [:read, create: [:body]]

      read :global do
        multitenancy :allow_global
      end

      read :bypass do
        multitenancy :bypass
      end
    end
  end

  # A policy that has to read the record to decide.
  defmodule PolicyNote do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.ReadTenantScopingTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    ets do
      private? true
    end

    multitenancy do
      strategy :attribute
      attribute :shop_id
    end

    attributes do
      uuid_primary_key :id
      attribute :shop_id, :string, allow_nil?: false, public?: true
      attribute :body, :string, public?: true
    end

    policies do
      policy always() do
        authorize_if expr(not is_nil(body))
      end
    end

    actions do
      defaults [:read, :destroy, create: [:body], update: [:body]]
    end
  end

  # Shared across tenants; its comments belong to tenants.
  defmodule Post do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.ReadTenantScopingTest.Domain,
      data_layer: Ash.DataLayer.Ets

    ets do
      private? true
    end

    attributes do
      uuid_primary_key :id
      attribute :title, :string, public?: true
    end

    relationships do
      has_many :comments, Ash.Test.Actions.ReadTenantScopingTest.Comment, public?: true
    end

    aggregates do
      count :comment_count, :comments, public?: true
    end

    calculations do
      calculate :has_comments?, :boolean, expr(exists(comments, true)), public?: true
    end

    actions do
      defaults [:read, create: [:title]]
    end
  end

  defmodule Comment do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.ReadTenantScopingTest.Domain,
      data_layer: Ash.DataLayer.Ets

    ets do
      private? true
    end

    multitenancy do
      strategy :attribute
      attribute :shop_id
    end

    attributes do
      uuid_primary_key :id
      attribute :shop_id, :string, allow_nil?: false, public?: true
      attribute :body, :string, public?: true
    end

    relationships do
      belongs_to :post, Ash.Test.Actions.ReadTenantScopingTest.Post,
        public?: true,
        attribute_writable?: true
    end

    actions do
      defaults [:read, create: [:body, :post_id]]
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Note
      resource PolicyNote
      resource Post
      resource Comment
    end
  end

  setup do
    a_note = Ash.create!(Note, %{body: "a's"}, tenant: "a")
    b_note = Ash.create!(Note, %{body: "b's"}, tenant: "b")
    %{a_note: a_note, b_note: b_note}
  end

  defp bodies(records), do: records |> Enum.map(& &1.body) |> Enum.sort()

  defp run_lowered(query) do
    {:ok, data_layer_query} = Ash.Query.data_layer_query(query)
    {:ok, records} = Ash.DataLayer.run_query(data_layer_query, query.resource)
    records
  end

  describe "within a tenant" do
    test "reads through the read action" do
      assert bodies(Ash.read!(Note, tenant: "a")) == ["a's"]
      assert Ash.count!(Note, tenant: "a") == 1
      assert Ash.list!(Note, :body, tenant: "a") == ["a's"]

      {:ok, %{query: query, run: run}} =
        Note |> Ash.Query.set_tenant("a") |> Ash.data_layer_query()

      {:ok, records} = run.(query)
      assert bodies(records) == ["a's"]
    end

    test "combination queries" do
      assert Note
             |> Ash.Query.set_tenant("a")
             |> Ash.Query.combination_of([
               Ash.Query.Combination.base(filter: Ash.Expr.expr(true))
             ])
             |> Ash.read!()
             |> bodies() == ["a's"]
    end

    test "loads, aggregates, exists and sorts over another resource's records" do
      post = Ash.create!(Post, %{title: "post"})
      Ash.create!(Comment, %{body: "a's", post_id: post.id}, tenant: "a")
      Ash.create!(Comment, %{body: "b's", post_id: post.id}, tenant: "b")

      loaded = Ash.load!(post, [:comments, :comment_count, :has_comments?], tenant: "a")
      assert bodies(loaded.comments) == ["a's"]
      assert loaded.comment_count == 1

      assert Post
             |> Ash.Query.filter(exists(comments, body == "b's"))
             |> Ash.read!(tenant: "a") == []

      assert [%{comment_count: 1}] =
               Post
               |> Ash.Query.sort(comment_count: :desc)
               |> Ash.Query.load(:comment_count)
               |> Ash.read!(tenant: "a")
    end

    test "a :bypass read action reads every tenant, read or lowered" do
      query = Ash.Query.for_read(Note, :bypass, %{}, tenant: "a")
      assert bodies(Ash.read!(query)) == ["a's", "b's"]
      assert bodies(run_lowered(query)) == ["a's", "b's"]
    end

    test "an :allow_global read action without a tenant reads every tenant" do
      assert bodies(Ash.read!(Note, action: :global)) == ["a's", "b's"]
      assert bodies(Ash.read!(Note, action: :global, tenant: "a")) == ["a's"]
    end

    test "a query applied to records in memory", %{a_note: a_note} do
      assert {:ok, [%{id: id}]} =
               Note |> Ash.Query.set_tenant("a") |> Ash.Query.apply_to([a_note])

      assert id == a_note.id
    end

    test "Ash.can? on the tenant's own record" do
      note = Ash.create!(PolicyNote, %{body: "a's"}, tenant: "a", authorize?: false)
      assert Ash.can?({note, :update}, nil, tenant: "a")
      assert Ash.can?({note, :destroy}, nil, tenant: "a")
      assert Ash.can?({PolicyNote, :read}, nil, tenant: "a", data: note)
    end
  end

  describe "another tenant's records" do
    test "a query lowered for the data layer" do
      assert bodies(Note |> Ash.Query.set_tenant("a") |> run_lowered()) == ["a's"]
    end

    test "a query built for a read action, lowered without running it" do
      query = Ash.Query.for_read(Note, :read, %{}, tenant: "a")
      assert bodies(run_lowered(query)) == ["a's"]
    end

    test "a query applied to records in memory", %{a_note: a_note, b_note: b_note} do
      assert {:ok, records} =
               Note |> Ash.Query.set_tenant("a") |> Ash.Query.apply_to([a_note, b_note])

      assert bodies(records) == ["a's"]
    end

    test "Ash.can? with a policy that reads the record" do
      b_note = Ash.create!(PolicyNote, %{body: "b's"}, tenant: "b", authorize?: false)
      refute Ash.can?({b_note, :update}, nil, tenant: "a")
      refute Ash.can?({b_note, :destroy}, nil, tenant: "a")
      refute Ash.can?({PolicyNote, :read}, nil, tenant: "a", data: b_note)
    end
  end
end
