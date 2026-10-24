# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.VariantTest do
  use ExUnit.Case, async: false
  alias Ash.Conformance.{Adapter, Catalog, Runner, Variant}

  for adapter <- Adapter.selected(),
      Variant.supported?(adapter),
      scenario <- Catalog.for_adapter(adapter),
      variant <- Variant.all(),
      Variant.applies?(scenario, variant) == true do
    @tag adapter: adapter.id(), scenario: scenario.id, area: scenario.area, variant: variant
    test "#{adapter.id()} #{scenario.id}@#{variant}" do
      adapter = unquote(adapter)
      scenario = Enum.find(Catalog.all(), &(&1.id == unquote(scenario.id)))
      Runner.execute_variant!(scenario, adapter, unquote(variant))
    end
  end

  describe "variants" do
    test "the base run keeps authorization off and the base resources" do
      assert Variant.current() == :base
      refute Variant.authorize?()
      assert Variant.resource(Ash.Conformance.Sqlite, :parent) == Ash.Conformance.Sqlite.Parent
    end

    test "every variant authorizes, and policy variants read from their own resource set" do
      for variant <- Variant.all() do
        Variant.run(variant, fn ->
          assert Variant.authorize?()
          resource = Variant.resource(Ash.Conformance.Sqlite, :parent)
          assert Code.ensure_loaded?(resource)

          assert Ash.Resource.Info.authorizers(resource) ==
                   if(variant == :authorize, do: [], else: [Ash.Policy.Authorizer])
        end)
      end

      assert Variant.current() == :base
    end

    test "a resource with its own authorizer keeps its own policies in every set" do
      base = Ash.Conformance.Sqlite.AuthorizedChild

      Variant.run(:filter_policy, fn ->
        variant = Variant.resource(Ash.Conformance.Sqlite, :authorized_child)
        assert variant != base

        assert Ash.Policy.Info.policies(variant) |> length() ==
                 Ash.Policy.Info.policies(base) |> length()
      end)
    end

    test "the filter policy adds a filter every stored row passes" do
      resource = Ash.Conformance.Sqlite.FilterPolicy.Parent
      filter = Ash.Conformance.Variant.EveryRow.filter(nil, %{}, resource: resource)
      assert inspect(filter) =~ "not is_nil({:_ref, [], :id})"
    end

    test "grids with their own authorization axis don't run variants" do
      scenario = Enum.find(Catalog.all(), &(&1.area == :policies))
      assert {false, _reason} = Variant.applies?(scenario, :authorize)
    end
  end
end
