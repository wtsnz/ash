# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Resource.Relationships.BelongsToTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Ash.Resource.Relationships.BelongsTo
  alias Ash.Test.Domain, as: Domain

  defmacrop defposts(do: body) do
    module = Module.concat(["rand#{System.unique_integer([:positive])}", Post])

    quote do
      defmodule unquote(module) do
        @moduledoc false
        use Ash.Resource, domain: Domain

        attributes do
          uuid_primary_key :id
        end

        unquote(body)
      end

      alias unquote(module), as: Post
    end
  end

  describe "representation" do
    test "it creates an attribute" do
      defposts do
        relationships do
          belongs_to :foobar, FooBar
        end
      end

      assert [
               _,
               %Ash.Resource.Attribute{
                 name: :foobar_id,
                 primary_key?: false,
                 type: Ash.Type.UUID,
                 public?: false
               }
             ] = Ash.Resource.Info.attributes(Post)
    end

    test "it creates an attribute that honors attribute_writable?" do
      defposts do
        relationships do
          belongs_to :foobar, FooBar, attribute_writable?: true, public?: true
        end
      end

      assert [
               _,
               %Ash.Resource.Attribute{
                 name: :foobar_id,
                 primary_key?: false,
                 type: Ash.Type.UUID,
                 public?: true,
                 writable?: true
               }
             ] = Ash.Resource.Info.attributes(Post)
    end

    test "it creates an attribute that honors attribute_always_select?" do
      defposts do
        relationships do
          belongs_to :foobar, FooBar, attribute_always_select?: true
        end
      end

      assert [
               _,
               %Ash.Resource.Attribute{
                 name: :foobar_id,
                 always_select?: true
               }
             ] = Ash.Resource.Info.attributes(Post)
    end

    test "it creates an attribute that honors attribute_constraints" do
      defposts do
        relationships do
          belongs_to :foobar, FooBar,
            attribute_type: :string,
            attribute_constraints: [min_length: 3, trim?: false]
        end
      end

      assert [
               _,
               %Ash.Resource.Attribute{
                 name: :foobar_id,
                 type: Ash.Type.String,
                 constraints: constraints
               }
             ] = Ash.Resource.Info.attributes(Post)

      assert constraints[:min_length] == 3
      assert constraints[:trim?] == false
    end

    test "enforces attribute_constraints on a parameterized custom type at runtime" do
      defmodule PrefixedId do
        use Ash.Type

        @impl true
        def storage_type(_), do: :string

        @impl true
        def constraints, do: [prefix: [type: :string, required: true]]

        @impl true
        def cast_input(nil, _), do: {:ok, nil}

        def cast_input(value, constraints) when is_binary(value) do
          prefix = Keyword.fetch!(constraints, :prefix)

          if String.starts_with?(value, prefix <> "_") do
            {:ok, value}
          else
            {:error, message: "must start with #{prefix}_"}
          end
        end

        def cast_input(_, _), do: :error

        @impl true
        def cast_stored(value, _), do: {:ok, value}

        @impl true
        def dump_to_native(value, _), do: {:ok, value}
      end

      defmodule ConstrainedParent do
        use Ash.Resource, domain: Domain, data_layer: Ash.DataLayer.Ets

        attributes do
          attribute :id, PrefixedId,
            primary_key?: true,
            allow_nil?: false,
            public?: true,
            writable?: true,
            constraints: [prefix: "par"]
        end

        actions do
          defaults [:read, create: [:id]]
        end
      end

      defmodule ConstrainedChild do
        use Ash.Resource, domain: Domain, data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key :id
        end

        relationships do
          belongs_to :parent, ConstrainedParent,
            attribute_type: PrefixedId,
            attribute_constraints: [prefix: "par"],
            attribute_writable?: true,
            public?: true
        end

        actions do
          defaults [:read, create: [:parent_id]]
        end
      end

      parent = Ash.create!(ConstrainedParent, %{id: "par_123"})

      child = Ash.create!(ConstrainedChild, %{parent_id: parent.id})
      assert child.parent_id == "par_123"
      assert Ash.load!(child, :parent).parent.id == "par_123"

      assert {:error, _} = Ash.create(ConstrainedChild, %{parent_id: "other_123"})
    end

    test "it creates a relationship" do
      defposts do
        relationships do
          belongs_to :foo, Foo, public?: true
          belongs_to :bar, Bar, source_attribute: :bazz
          belongs_to :sorted, Bazzinga, default_sort: [inserted_at: :desc]
        end
      end

      assert [
               %BelongsTo{
                 cardinality: :one,
                 define_attribute?: true,
                 destination: Foo,
                 destination_attribute: :id,
                 attribute_type: :uuid,
                 name: :foo,
                 primary_key?: false,
                 source_attribute: :foo_id,
                 type: :belongs_to,
                 public?: true
               },
               %BelongsTo{
                 cardinality: :one,
                 define_attribute?: true,
                 destination: Bar,
                 destination_attribute: :id,
                 attribute_type: :uuid,
                 name: :bar,
                 primary_key?: false,
                 source_attribute: :bazz,
                 type: :belongs_to,
                 public?: false
               },
               %BelongsTo{
                 cardinality: :one,
                 destination: Bazzinga,
                 destination_attribute: :id,
                 name: :sorted,
                 source_attribute: :sorted_id,
                 type: :belongs_to,
                 public?: false,
                 default_sort: [inserted_at: :desc]
               }
             ] = Ash.Resource.Info.relationships(Post)

      assert [%BelongsTo{name: :foo}] = Ash.Resource.Info.public_relationships(Post)

      assert %BelongsTo{name: :foo} = Ash.Resource.Info.public_relationship(Post, :foo)

      assert nil == Ash.Resource.Info.relationship(Post, :definitely_legit_relationship)

      assert nil == Ash.Resource.Info.public_relationship(Post, :bar)
    end
  end

  describe "validations" do
    test "fails if destination_attribute is not an atom" do
      assert_raise(
        Spark.Error.DslError,
        ~r/invalid value for :destination_attribute option: expected atom, got: \"foo\"/,
        fn ->
          defposts do
            relationships do
              belongs_to(:foobar, FooBar, destination_attribute: "foo", public?: true)
            end
          end
        end
      )
    end

    test "fails if source_attribute is not an atom" do
      assert_raise(
        Spark.Error.DslError,
        ~r/invalid value for :source_attribute option: expected atom, got: \"foo\"/,
        fn ->
          defposts do
            relationships do
              belongs_to(:foobar, FooBar, source_attribute: "foo", public?: true)
            end
          end
        end
      )
    end

    test "fails if the destination is not an atom" do
      assert_raise(
        Spark.Error.DslError,
        ~r/expected module in :destination option, got: \"foobar\"/,
        fn ->
          defposts do
            relationships do
              belongs_to(:foobar, "foobar", public?: true)
            end
          end
        end
      )
    end

    test "fails if the relationship name is not an atom" do
      assert_raise(
        Spark.Error.DslError,
        ~r/invalid value for :name option: expected atom, got: \"foobar\"/,
        fn ->
          defposts do
            relationships do
              belongs_to("foobar", Foobar, public?: true)
            end
          end
        end
      )
    end

    test "fails if `primary_key?` is not a boolean" do
      assert_raise(
        Spark.Error.DslError,
        ~r/invalid value for :primary_key\? option: expected boolean, got: \"blah\"/,
        fn ->
          defposts do
            relationships do
              belongs_to(:foobar, Foobar, primary_key?: "blah", public?: true)
            end
          end
        end
      )
    end

    test "fails if `attribute_constraints` is not a keyword list" do
      assert_raise(
        Spark.Error.DslError,
        ~r/invalid value for :attribute_constraints option: expected keyword list/,
        fn ->
          defposts do
            relationships do
              belongs_to(:foobar, FooBar, attribute_constraints: "blah")
            end
          end
        end
      )
    end

    test "fails if `public?` is not a boolean" do
      assert_raise(
        Spark.Error.DslError,
        ~r/invalid value for :public\? option: expected boolean, got: "blah"/,
        fn ->
          defposts do
            relationships do
              belongs_to(:foobar, Foobar, public?: "blah")
            end
          end
        end
      )
    end
  end

  test "fails if `define_attribute?` is not a boolean" do
    assert_raise(
      Spark.Error.DslError,
      ~r/invalid value for :define_attribute\? option: expected boolean, got: \"blah\"/,
      fn ->
        defposts do
          relationships do
            belongs_to(:foobar, Foobar, define_attribute?: "blah", public?: true)
          end
        end
      end
    )
  end

  test "fails in domain initialization if the destination resource doesn't have the correct field" do
    output =
      ExUnit.CaptureIO.capture_io(:stderr, fn ->
        defposts do
          relationships do
            belongs_to(:post, __MODULE__, define_attribute?: false, public?: true)
          end
        end

        defmodule Domain do
          use Ash.Domain

          resources do
            resource Post
          end
        end
      end)

    assert String.contains?(output, "Relationship") and
             String.contains?(output, "expects source attribute") and
             String.contains?(output, "post_id")
  end
end
