# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Policy.FieldPolicy.StructReturnOriginalValueTest do
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

  defmodule Holder do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Policy.FieldPolicy.StructReturnOriginalValueTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    alias Ash.Test.Policy.FieldPolicy.StructReturnOriginalValueTest.Profile

    ets do
      private? true
    end

    policies do
      policy always() do
        authorize_if always()
      end
    end

    field_policies do
      field_policy :secret do
        authorize_if actor_attribute_equals(:admin?, true)
      end

      field_policy :* do
        authorize_if always()
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :secret, :string, public?: true
      attribute :profile, Profile, public?: true
    end

    actions do
      defaults [:read, create: :*, update: :*]

      action :profile_struct, :struct do
        constraints instance_of: Profile
        argument :id, :uuid, allow_nil?: false

        run fn input, _ ->
          {:ok, Ash.get!(__MODULE__, input.arguments.id, authorize?: false).profile}
        end
      end

      action :holder_struct, :struct do
        constraints instance_of: __MODULE__
        argument :id, :uuid, allow_nil?: false

        run fn input, _ ->
          {:ok, Ash.get!(__MODULE__, input.arguments.id, authorize?: false)}
        end
      end
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Ash.Test.Policy.FieldPolicy.StructReturnOriginalValueTest.Holder
    end
  end

  @user [actor: %{admin?: false}, authorize?: true]

  setup do
    holder =
      Ash.create!(Holder, %{secret: "s3cret", profile: %{bio: "b", ssn: "123-45"}},
        authorize?: false
      )

    %{holder: holder}
  end

  defp stored(holder), do: Ash.get!(Holder, holder.id, authorize?: false)

  test "a hidden embedded value read by the actor can be written back", %{holder: holder} do
    [read] = Holder |> Ash.Query.filter(id == ^holder.id) |> Ash.read!(@user)
    assert %Ash.ForbiddenField{} = read.profile.ssn

    read |> Ash.Changeset.for_update(:update, %{profile: read.profile}, @user) |> Ash.update!()
    assert stored(holder).profile.ssn == "123-45"
  end

  test "an embedded struct returned by a generic action keeps its hidden values", %{
    holder: holder
  } do
    profile =
      Holder
      |> Ash.ActionInput.for_action(:profile_struct, %{id: holder.id}, @user)
      |> Ash.run_action!()

    assert profile.bio == "b"
    assert %Ash.ForbiddenField{original_value: "123-45"} = profile.ssn
  end

  test "an embedded struct returned by a generic action can be written back", %{holder: holder} do
    profile =
      Holder
      |> Ash.ActionInput.for_action(:profile_struct, %{id: holder.id}, @user)
      |> Ash.run_action!()

    holder |> Ash.Changeset.for_update(:update, %{profile: profile}, @user) |> Ash.update!()
    assert stored(holder).profile.ssn == "123-45"
  end

  test "applying field policies in memory to an embedded record keeps hidden values" do
    profile = struct(Profile, bio: "b", ssn: "123-45")

    assert {:ok, scrubbed} =
             Ash.Authorizer.apply_field_level_auth(Profile, profile, actor: %{admin?: false})

    assert scrubbed.bio == "b"
    assert %Ash.ForbiddenField{original_value: "123-45"} = scrubbed.ssn
  end

  test "applying field policies in memory to a hidden field keeps its placeholder", %{
    holder: holder
  } do
    [read] = Holder |> Ash.Query.filter(id == ^holder.id) |> Ash.read!(@user)
    assert %Ash.ForbiddenField{original_value: "123-45"} = read.profile.ssn

    assert {:ok, scrubbed} =
             Ash.Authorizer.apply_field_level_auth(Profile, read.profile, actor: %{admin?: false})

    assert scrubbed.ssn == read.profile.ssn
  end

  test "hidden top-level fields of a struct returned by a generic action have no original value",
       %{holder: holder} do
    returned =
      Holder
      |> Ash.ActionInput.for_action(:holder_struct, %{id: holder.id}, @user)
      |> Ash.run_action!()

    assert %Ash.ForbiddenField{original_value: nil} = returned.secret
  end
end
