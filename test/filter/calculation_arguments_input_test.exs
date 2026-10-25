# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Filter.CalculationArgumentsInputTest do
  @moduledoc false
  use ExUnit.Case, async: true

  require Ash.Query
  import Ash.Expr

  defmodule Post do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Filter.CalculationArgumentsInputTest.Domain,
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

    calculations do
      calculate :echo, :string, expr(^arg(:value)) do
        public? true
        argument :value, :string, allow_expr?: true
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
      resource Ash.Test.Filter.CalculationArgumentsInputTest.Post
    end
  end

  @user [actor: %{admin?: false}, authorize?: true]

  setup do
    for {name, internal} <- [{"p1", "zz"}, {"p2", "aa"}, {"p3", "mm"}] do
      Ash.create!(Post, %{name: name, internal: internal}, authorize?: false)
    end

    :ok
  end

  defp names(query, opts) do
    query |> Ash.read!(opts) |> Enum.map(& &1.name) |> Enum.sort()
  end

  defp ordered(query, opts) do
    query |> Ash.read!(opts) |> Enum.map(& &1.name)
  end

  test "a calculation argument given as an expression is refused in filter_input" do
    query = Ash.Query.filter_input(Post, expr(echo(value: internal) == "zz"))
    assert {:error, %Ash.Error.Invalid{}} = Ash.read(query, @user)
  end

  test "a calculation argument given as an expression is refused in sort_input" do
    query = Ash.Query.sort_input(Post, echo: {%{value: expr(internal)}, :asc})
    assert {:error, %Ash.Error.Invalid{}} = Ash.read(query, @user)
  end

  test "calculation arguments given as values still work in client input" do
    assert names(Ash.Query.filter_input(Post, expr(echo(value: "x") == "x")), @user) ==
             ["p1", "p2", "p3"]

    assert ordered(Ash.Query.sort_input(Post, echo: {%{value: "x"}, :asc}, name: :asc), @user) ==
             ["p1", "p2", "p3"]
  end

  test "trusted filters and sorts can still give a calculation an expression argument" do
    assert names(Ash.Query.filter(Post, echo(value: internal) == "zz"), @user) == ["p1"]

    assert ordered(Ash.Query.sort(Post, echo: {%{value: expr(internal)}, :asc}), @user) ==
             ["p2", "p3", "p1"]
  end
end
