# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Policy.FieldPolicy.LoadThroughForbiddenAttributeTest do
  @moduledoc false
  use ExUnit.Case, async: true

  require Ash.Query

  defmodule Profile do
    @moduledoc false
    use Ash.Resource, data_layer: :embedded, authorizers: [Ash.Policy.Authorizer]

    policies do
      policy always() do
        authorize_if always()
      end
    end

    field_policies do
      field_policy :ssn do
        authorize_if actor_attribute_equals(:admin?, true)
      end

      field_policy :* do
        authorize_if always()
      end
    end

    attributes do
      attribute :bio, :string, public?: true
      attribute :ssn, :string, public?: true
    end
  end

  defmodule User do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Policy.FieldPolicy.LoadThroughForbiddenAttributeTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    alias Ash.Test.Policy.FieldPolicy.LoadThroughForbiddenAttributeTest.Profile

    ets do
      private? true
    end

    policies do
      policy always() do
        authorize_if always()
      end
    end

    field_policies do
      field_policy [:profile, :profiles, :contact] do
        forbid_if actor_attribute_equals(:hide_composites?, true)
        authorize_if always()
      end

      field_policy :* do
        authorize_if always()
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
      attribute :profile, Profile, public?: true
      attribute :profiles, {:array, Profile}, public?: true

      attribute :contact, :union,
        public?: true,
        constraints: [
          types: [
            profile: [type: Profile],
            text: [type: :string]
          ]
        ]
    end

    actions do
      defaults [:read, create: :*]
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Ash.Test.Policy.FieldPolicy.LoadThroughForbiddenAttributeTest.User
    end
  end

  setup do
    user =
      Ash.create!(
        User,
        %{
          name: "u",
          profile: %{bio: "b", ssn: "123-45"},
          profiles: [%{bio: "b1", ssn: "111-11"}, %{bio: "b2", ssn: "222-22"}],
          contact: %{bio: "c", ssn: "333-33"}
        },
        authorize?: false
      )

    %{user: user}
  end

  defp by_id(user), do: Ash.Query.filter(User, id == ^user.id)

  test "loading through embedded and union attributes the actor can see", %{user: user} do
    [read] =
      by_id(user)
      |> Ash.Query.load(profile: [:bio], profiles: [:bio], contact: [profile: [:bio]])
      |> Ash.read!(actor: %{admin?: false}, authorize?: true)

    assert read.profile.bio == "b"
    assert %Ash.ForbiddenField{} = read.profile.ssn
    assert Enum.map(read.profiles, & &1.bio) == ["b1", "b2"]
    assert read.contact.value.bio == "c"
  end

  test "loading through an embedded or union attribute the actor can't see returns ForbiddenField",
       %{user: user} do
    actor = %{admin?: false, hide_composites?: true}

    for load <- [[profile: [:bio]], [profiles: [:bio]], [contact: [profile: [:bio]]]] do
      [read] = by_id(user) |> Ash.Query.load(load) |> Ash.read!(actor: actor, authorize?: true)

      assert %Ash.ForbiddenField{} = read.profile, inspect(load)
      assert %Ash.ForbiddenField{} = read.profiles, inspect(load)
      assert %Ash.ForbiddenField{} = read.contact, inspect(load)
    end
  end
end
