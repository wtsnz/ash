# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Actions.OutputPresentationTest do
  @moduledoc """
  Every action result hides the fields the actor can't see, as a read does.

  Reads evaluate field policies for embedded resources (alone, in arrays and in unions) and clean
  them recursively. Create, update and destroy results only had the top-level record's fields
  cleaned, so field-policied values in embedded resources came back from writes, bulk writes and
  generic actions. The "keeps working" tests cover the same results for actors who may see the
  values, and the placeholders that let a hidden embedded value be written back.
  """
  use ExUnit.Case, async: true

  require Ash.Query

  defmodule PubSub do
    @moduledoc false
    def broadcast(topic, event, notification) do
      send(self(), {:broadcast, topic, event, notification})
      :ok
    end
  end

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

  defmodule Note do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.OutputPresentationTest.Domain,
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
      field_policy :body do
        authorize_if actor_attribute_equals(:admin?, true)
      end

      field_policy :* do
        authorize_if always()
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :body, :string, public?: true, default: "note body"
    end

    relationships do
      belongs_to :user, Ash.Test.Actions.OutputPresentationTest.User,
        public?: true,
        attribute_writable?: true
    end

    actions do
      defaults [:read, create: :*]
    end
  end

  defmodule User do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.OutputPresentationTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer],
      notifiers: [Ash.Notifier.PubSub]

    ets do
      private? true
    end

    pub_sub do
      module Ash.Test.Actions.OutputPresentationTest.PubSub
      prefix "user"
      publish :update_with_publication, ["updated"], load: [:secret, :secret_calc, notes: [:body]]
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

      field_policy [:secret, :secret_calc, :note_count] do
        authorize_if actor_attribute_equals(:admin?, true)
      end

      field_policy :* do
        authorize_if always()
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
      attribute :secret, :string, public?: true
      attribute :profile, Ash.Test.Actions.OutputPresentationTest.Profile, public?: true

      attribute :profiles, {:array, Ash.Test.Actions.OutputPresentationTest.Profile},
        public?: true

      attribute :contact, :union,
        public?: true,
        constraints: [
          types: [
            profile: [type: Ash.Test.Actions.OutputPresentationTest.Profile],
            text: [type: :string]
          ]
        ]
    end

    relationships do
      has_many :notes, Ash.Test.Actions.OutputPresentationTest.Note, public?: true
    end

    calculations do
      calculate :secret_calc, :string, expr(secret), public?: true
    end

    aggregates do
      count :note_count, :notes, public?: true
    end

    actions do
      defaults [:read, :destroy, create: :*, update: [:name, :profile]]

      update :update_with_publication do
        accept [:name]
      end

      action :get_profile, Ash.Test.Actions.OutputPresentationTest.Profile do
        argument :id, :uuid, allow_nil?: false

        run fn input, _ ->
          {:ok, Ash.get!(__MODULE__, input.arguments.id, authorize?: false).profile}
        end
      end

      action :get_profiles, {:array, Ash.Test.Actions.OutputPresentationTest.Profile} do
        argument :id, :uuid, allow_nil?: false

        run fn input, _ ->
          {:ok, Ash.get!(__MODULE__, input.arguments.id, authorize?: false).profiles}
        end
      end

      action :get_user, :struct do
        constraints instance_of: __MODULE__
        argument :id, :uuid, allow_nil?: false

        run fn input, _ ->
          {:ok, Ash.get!(__MODULE__, input.arguments.id, authorize?: false)}
        end
      end
    end
  end

  defmodule HolderNote do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.OutputPresentationTest.Domain,
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
      field_policy :body do
        authorize_if actor_attribute_equals(:admin?, true)
      end

      field_policy :* do
        authorize_if always()
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :body, :string, public?: true, default: "note body"
    end

    relationships do
      belongs_to :holder, Ash.Test.Actions.OutputPresentationTest.Holder,
        public?: true,
        attribute_writable?: true
    end

    actions do
      defaults [:read, create: :*]
    end
  end

  defmodule Holder do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.OutputPresentationTest.Domain,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer]

    alias Ash.Test.Actions.OutputPresentationTest.Profile

    ets do
      private? true
    end

    policies do
      policy always() do
        authorize_if always()
      end
    end

    field_policies do
      field_policy :read_only do
        authorize_if action(:read)
      end

      field_policy :write_only do
        authorize_if action(:update)
      end

      field_policy :contextual do
        authorize_if context_equals(:allow_secret?, true)
      end

      field_policy :context_hidden do
        forbid_if context_equals(:hide_secret?, true)
        authorize_if always()
      end

      # Evaluating this filter fails.
      field_policy :runtime_checked do
        authorize_if expr(error(Ash.Error.Query.InvalidQuery, %{message: "can't decide"}))
      end

      field_policy :* do
        authorize_if always()
      end
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
      attribute :profile, Profile, public?: true

      attribute :payload, :map,
        public?: true,
        constraints: [fields: [profile: [type: Profile], label: [type: :string]]]

      attribute :nested_arrays, {:array, {:array, Profile}}, public?: true, default: []
    end

    calculations do
      calculate :profile_calc, Profile, expr(profile), public?: true
      calculate :read_only, :string, expr(name), public?: true
      calculate :write_only, :string, expr(name), public?: true
      calculate :contextual, :string, expr(name), public?: true
      calculate :context_hidden, :string, expr(name), public?: true
      calculate :runtime_checked, :string, expr(name), public?: true
    end

    relationships do
      has_many :notes, Ash.Test.Actions.OutputPresentationTest.HolderNote, public?: true
    end

    actions do
      defaults [:read, :destroy, create: :*, update: :*]

      action :map_result, :map do
        constraints fields: [profile: [type: Profile]]
        run fn _, _ -> {:ok, %{profile: struct(Profile, bio: "b", ssn: "secret")}} end
      end

      action :tuple_result, :tuple do
        constraints fields: [profile: [type: Profile]]
        run fn _, _ -> {:ok, {struct(Profile, bio: "b", ssn: "secret")}} end
      end

      action :profile_struct, :struct do
        constraints instance_of: Profile
        argument :id, :uuid, allow_nil?: false

        run fn input, _ ->
          {:ok, Ash.get!(__MODULE__, input.arguments.id, authorize?: false).profile}
        end
      end
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Ash.Test.Actions.OutputPresentationTest.Note
      resource Ash.Test.Actions.OutputPresentationTest.User
      resource Ash.Test.Actions.OutputPresentationTest.HolderNote
      resource Ash.Test.Actions.OutputPresentationTest.Holder
    end
  end

  @user [actor: %{admin?: false}, authorize?: true]
  @admin [actor: %{admin?: true}, authorize?: true]

  defp user! do
    user =
      Ash.create!(
        User,
        %{
          name: "u",
          secret: "s3cret",
          profile: %{bio: "b", ssn: "123-45"},
          profiles: [%{bio: "b1", ssn: "111-11"}, %{bio: "b2", ssn: "222-22"}],
          contact: %{bio: "c", ssn: "333-33"}
        },
        authorize?: false
      )

    Ash.create!(Note, %{user_id: user.id}, authorize?: false)
    Ash.create!(Note, %{user_id: user.id}, authorize?: false)
    user
  end

  defp by_id(user), do: Ash.Query.filter(User, id == ^user.id)

  defp stored(user), do: Ash.get!(User, user.id, authorize?: false)

  defp assert_embedded_hidden(record) do
    assert %Ash.ForbiddenField{} = record.profile.ssn
    assert Enum.all?(record.profiles, &match?(%Ash.ForbiddenField{}, &1.ssn))
    assert %Ash.ForbiddenField{} = record.contact.value.ssn
    assert record.profile.bio == "b"
    assert Enum.map(record.profiles, & &1.bio) == ["b1", "b2"]
  end

  describe "keeps working" do
    test "a read hides embedded fields from a non-admin" do
      user = user!()
      [read] = Ash.read!(by_id(user), @user)

      assert %Ash.ForbiddenField{} = read.secret
      assert_embedded_hidden(read)
    end

    test "an admin sees embedded fields in create, update and destroy results" do
      created =
        Ash.create!(User, %{name: "n", profile: %{bio: "b", ssn: "999-99"}}, @admin)

      assert created.profile.ssn == "999-99"

      user = user!()
      updated = user |> Ash.Changeset.for_update(:update, %{name: "v"}, @admin) |> Ash.update!()
      assert updated.secret == "s3cret"
      assert updated.profile.ssn == "123-45"
      assert Enum.map(updated.profiles, & &1.ssn) == ["111-11", "222-22"]
      assert updated.contact.value.ssn == "333-33"

      destroyed = Ash.destroy!(user!(), @admin ++ [return_destroyed?: true])
      assert destroyed.profile.ssn == "123-45"
    end

    test "an admin sees embedded fields in bulk results" do
      user = user!()

      %{records: [record]} =
        Ash.bulk_update!(
          by_id(user),
          :update,
          %{name: "w"},
          @admin ++ [strategy: :atomic, return_records?: true]
        )

      assert record.profile.ssn == "123-45"
    end

    test "authorize?: false returns every value" do
      user = user!()

      updated =
        user
        |> Ash.Changeset.for_update(:update, %{name: "v"})
        |> Ash.update!(authorize?: false)

      assert updated.secret == "s3cret"
      assert updated.profile.ssn == "123-45"
    end

    test "top-level fields are hidden in update results" do
      user = user!()
      updated = user |> Ash.Changeset.for_update(:update, %{name: "v"}, @user) |> Ash.update!()
      assert %Ash.ForbiddenField{} = updated.secret
    end

    test "a hidden embedded value read by a non-admin can be written back" do
      user = user!()
      [read] = Ash.read!(by_id(user), @user)

      read
      |> Ash.Changeset.for_update(:update, %{profile: read.profile}, @user)
      |> Ash.update!()

      assert stored(user).profile.ssn == "123-45"
    end

    test "loading through embedded attributes the actor can see" do
      user = user!()

      [read] =
        by_id(user)
        |> Ash.Query.load(profile: [:bio], contact: [profile: [:bio]])
        |> Ash.read!(@user)

      assert read.profile.bio == "b"
      assert %Ash.ForbiddenField{} = read.profile.ssn
    end

    test "publications still get their loads" do
      user = user!()

      user
      |> Ash.Changeset.for_update(:update_with_publication, %{name: "v"}, @user)
      |> Ash.update!()

      assert_received {:broadcast, "user:updated", "update_with_publication", notification}
      assert notification.data.name == "v"
    end
  end

  describe "write results" do
    test "a create result hides embedded fields" do
      created =
        Ash.create!(
          User,
          %{
            name: "n",
            profile: %{bio: "b", ssn: "999-99"},
            profiles: [%{bio: "b1", ssn: "1"}, %{bio: "b2", ssn: "2"}],
            contact: %{bio: "c", ssn: "3"}
          },
          @user
        )

      assert_embedded_hidden(created)
    end

    test "an update result hides embedded fields, alone, in arrays and in unions" do
      user = user!()
      updated = user |> Ash.Changeset.for_update(:update, %{name: "v"}, @user) |> Ash.update!()
      assert_embedded_hidden(updated)
    end

    test "a destroy result hides embedded fields" do
      destroyed = Ash.destroy!(user!(), @user ++ [return_destroyed?: true])
      assert_embedded_hidden(destroyed)
    end

    test "bulk update results hide embedded fields, with each strategy" do
      for strategy <- [:atomic, :stream] do
        user = user!()

        %{records: [record]} =
          Ash.bulk_update!(
            by_id(user),
            :update,
            %{name: "w"},
            @user ++ [strategy: strategy, return_records?: true, allow_stream_with: :full_read]
          )

        assert_embedded_hidden(record)
      end
    end

    test "bulk destroy results hide embedded fields, with each strategy" do
      for strategy <- [:atomic, :stream] do
        user = user!()

        %{records: [record]} =
          Ash.bulk_destroy!(
            by_id(user),
            :destroy,
            %{},
            @user ++ [strategy: strategy, return_records?: true, allow_stream_with: :full_read]
          )

        assert_embedded_hidden(record)
      end
    end

    test "an aggregate loaded on the query of an atomic bulk update is hidden" do
      user = user!()

      %{records: [record]} =
        Ash.bulk_update!(
          by_id(user) |> Ash.Query.load(:note_count),
          :update,
          %{name: "w"},
          @user ++ [strategy: :atomic, return_records?: true]
        )

      assert %Ash.ForbiddenField{} = record.note_count
    end

    test "a hidden embedded value in a write result keeps its original value, and can be written back" do
      user = user!()
      updated = user |> Ash.Changeset.for_update(:update, %{name: "v"}, @user) |> Ash.update!()

      assert %Ash.ForbiddenField{original_value: "123-45"} = updated.profile.ssn

      updated
      |> Ash.Changeset.for_update(:update, %{profile: updated.profile}, @user)
      |> Ash.update!()

      assert stored(user).profile.ssn == "123-45"
    end

    test "an aggregate loaded without authorization doesn't survive into an actor's update result" do
      user = user!()
      [loaded] = by_id(user) |> Ash.Query.load(:note_count) |> Ash.read!(authorize?: false)
      assert loaded.note_count == 2

      updated = loaded |> Ash.Changeset.for_update(:update, %{name: "v"}, @user) |> Ash.update!()
      assert %Ash.ForbiddenField{} = updated.note_count
    end
  end

  describe "generic action results" do
    test "an embedded return hides its fields" do
      user = user!()

      profile =
        User
        |> Ash.ActionInput.for_action(:get_profile, %{id: user.id}, @user)
        |> Ash.run_action!()

      assert %Ash.ForbiddenField{} = profile.ssn
      assert profile.bio == "b"
    end

    test "an array of embedded returns hides their fields" do
      user = user!()

      profiles =
        User
        |> Ash.ActionInput.for_action(:get_profiles, %{id: user.id}, @user)
        |> Ash.run_action!()

      assert Enum.all?(profiles, &match?(%Ash.ForbiddenField{}, &1.ssn))
    end

    test "a struct return hides top-level and embedded fields" do
      user = user!()

      returned =
        User
        |> Ash.ActionInput.for_action(:get_user, %{id: user.id}, @user)
        |> Ash.run_action!()

      assert %Ash.ForbiddenField{} = returned.secret
      assert_embedded_hidden(returned)
    end

    test "an admin sees the fields of an embedded return" do
      user = user!()

      profile =
        User
        |> Ash.ActionInput.for_action(:get_profile, %{id: user.id}, @admin)
        |> Ash.run_action!()

      assert profile.ssn == "123-45"
    end
  end

  describe "notifier dependencies" do
    test "the returned record doesn't carry the values loaded for notifiers" do
      user = user!()

      updated =
        user
        |> Ash.Changeset.for_update(:update_with_publication, %{name: "v"}, @user)
        |> Ash.update!()

      assert %Ash.ForbiddenField{} = updated.secret

      assert Enum.filter(updated.calculations, fn
               {{Ash.Notifier.NotifierDependencies, _}, _} -> true
               _ -> false
             end) == []
    end
  end

  describe "loading through forbidden composite attributes" do
    test "a nested load through a forbidden embedded or union attribute returns ForbiddenField" do
      user = user!()
      actor = %{admin?: false, hide_composites?: true}

      for load <- [[profile: [:bio]], [profiles: [:bio]], [contact: [profile: [:bio]]]] do
        [read] = by_id(user) |> Ash.Query.load(load) |> Ash.read!(actor: actor)

        assert %Ash.ForbiddenField{} = read.profile
        assert %Ash.ForbiddenField{} = read.profiles
        assert %Ash.ForbiddenField{} = read.contact
      end
    end
  end

  describe "cases from review" do
    defp holder!(attrs \\ %{}) do
      holder =
        Ash.create!(
          Holder,
          Map.merge(%{name: "secret", profile: %{bio: "b", ssn: "secret"}}, attrs),
          authorize?: false
        )

      Ash.create!(HolderNote, %{holder_id: holder.id}, authorize?: false)
      holder
    end

    defp stored_holder(holder), do: Ash.get!(Holder, holder.id, authorize?: false)

    test "nested arrays of embedded resources keep their shape" do
      created =
        Ash.create!(
          Holder,
          %{
            nested_arrays: [
              [%{bio: "a", ssn: "1"}, %{bio: "b", ssn: "2"}],
              [%{bio: "c", ssn: "3"}]
            ]
          },
          @user
        )

      assert [[%Profile{} = a, %Profile{} = b], [%Profile{} = c]] = created.nested_arrays
      assert %Ash.ForbiddenField{original_value: "1"} = a.ssn
      assert %Ash.ForbiddenField{original_value: "2"} = b.ssn
      assert %Ash.ForbiddenField{original_value: "3"} = c.ssn
      assert c.bio == "c"
    end

    test "a field policy that can't be evaluated hides the value instead of failing the committed write" do
      holder = holder!() |> Ash.load!(:runtime_checked, authorize?: false)

      assert {:ok, updated} =
               holder |> Ash.Changeset.for_update(:update, %{name: "v"}, @user) |> Ash.update()

      assert %Ash.ForbiddenField{} = updated.runtime_checked
      assert stored_holder(holder).name == "v"
    end

    test "fields of related records loaded before the action are hidden" do
      # Field policies only: which related records the actor may read isn't checked again.
      holder = holder!() |> Ash.load!(:notes, authorize?: false)

      updated = holder |> Ash.Changeset.for_update(:update, %{name: "v"}, @user) |> Ash.update!()
      assert [%HolderNote{body: %Ash.ForbiddenField{}}] = updated.notes

      updated = holder |> Ash.Changeset.for_update(:update, %{name: "v"}, @admin) |> Ash.update!()
      assert [%HolderNote{body: "note body"}] = updated.notes
    end

    test "fields of related records loaded by the action are hidden" do
      updated =
        holder!()
        |> Ash.Changeset.for_update(:update, %{name: "v"}, @user)
        |> Ash.update!(load: [:notes])

      assert [%HolderNote{body: %Ash.ForbiddenField{}}] = updated.notes
    end

    test "a typed calculation loaded before the action hides its embedded fields" do
      holder = holder!() |> Ash.load!(:profile_calc, authorize?: false)

      updated = holder |> Ash.Changeset.for_update(:update, %{name: "v"}, @user) |> Ash.update!()
      assert %Ash.ForbiddenField{} = updated.profile_calc.ssn
      assert updated.profile_calc.bio == "b"
    end

    test "embedded resources in a map's fields are hidden" do
      created =
        Ash.create!(Holder, %{payload: %{profile: %{bio: "b", ssn: "secret"}, label: "l"}}, @user)

      assert %Ash.ForbiddenField{} = created.payload.profile.ssn
      assert created.payload.label == "l"

      created =
        Ash.create!(
          Holder,
          %{payload: %{profile: %{bio: "b", ssn: "secret"}, label: "l"}},
          @admin
        )

      assert created.payload.profile.ssn == "secret"
    end

    test "generic map and tuple returns hide embedded fields" do
      map = Holder |> Ash.ActionInput.for_action(:map_result, %{}, @user) |> Ash.run_action!()
      assert %Ash.ForbiddenField{} = map.profile.ssn

      {profile} =
        Holder |> Ash.ActionInput.for_action(:tuple_result, %{}, @user) |> Ash.run_action!()

      assert %Ash.ForbiddenField{} = profile.ssn

      map = Holder |> Ash.ActionInput.for_action(:map_result, %{}, @admin) |> Ash.run_action!()
      assert map.profile.ssn == "secret"
    end

    test "an embedded struct returned by a generic action can be written back" do
      holder = holder!()

      profile =
        Holder
        |> Ash.ActionInput.for_action(:profile_struct, %{id: holder.id}, @user)
        |> Ash.run_action!()

      assert %Ash.ForbiddenField{original_value: "secret"} = profile.ssn

      holder |> Ash.Changeset.for_update(:update, %{profile: profile}, @user) |> Ash.update!()
      assert stored_holder(holder).profile.ssn == "secret"
    end

    test "fields loaded before the action are checked with the action's context" do
      holder = holder!() |> Ash.load!([:contextual, :context_hidden], authorize?: false)

      updated =
        holder
        |> Ash.Changeset.for_update(:update, %{name: "v"}, @user)
        |> Ash.Changeset.set_context(%{allow_secret?: true, hide_secret?: true})
        |> Ash.update!()

      assert updated.contextual == "secret"
      assert %Ash.ForbiddenField{} = updated.context_hidden
    end

    test "fields loaded before the action are checked like fields the action loads" do
      # Both are checked as the primary read action would, not as the update.
      carried =
        holder!()
        |> Ash.load!([:read_only, :write_only], authorize?: false)
        |> Ash.Changeset.for_update(:update, %{name: "v"}, @user)
        |> Ash.update!()

      loaded =
        holder!()
        |> Ash.Changeset.for_update(:update, %{name: "v"}, @user)
        |> Ash.Changeset.load([:read_only, :write_only])
        |> Ash.update!()

      assert carried.read_only == "secret"
      assert %Ash.ForbiddenField{} = carried.write_only
      assert loaded.read_only == "v"
      assert %Ash.ForbiddenField{} = loaded.write_only
    end

    test "returned notifications keep the notifier values, so they can be delivered later" do
      {updated, notifications} =
        user!()
        |> Ash.Changeset.for_update(:update_with_publication, %{name: "v"}, @user)
        |> Ash.update!(return_notifications?: true)

      refute Enum.any?(
               updated.calculations,
               &match?({{Ash.Notifier.NotifierDependencies, _}, _}, &1)
             )

      [notification] = Enum.filter(notifications, &(&1.resource == User))

      assert Enum.any?(
               notification.data.calculations,
               &match?({{Ash.Notifier.NotifierDependencies, _}, _}, &1)
             )

      Ash.Notifier.notify(notifications)
      assert_received {:broadcast, "user:updated", "update_with_publication", delivered}
      assert delivered.data.name == "v"
    end
  end
end
