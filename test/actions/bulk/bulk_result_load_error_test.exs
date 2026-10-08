# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Actions.BulkResultLoadErrorTest do
  @moduledoc false
  use ExUnit.Case, async: true

  require Ash.Query

  alias Ash.Test.Domain, as: Domain

  defmodule Notifier do
    @moduledoc false
    use Ash.Notifier

    def notify(notification) do
      send(self(), {:notification, notification})
      :ok
    end
  end

  defmodule Comment do
    @moduledoc false
    use Ash.Resource, domain: Domain, data_layer: Ash.DataLayer.Ets

    ets do
      private?(true)
    end

    actions do
      default_accept :*
      defaults [:read, create: :*]

      read :by_flag do
        argument :flag, :boolean, allow_nil?: false
      end
    end

    attributes do
      uuid_primary_key :id
    end

    relationships do
      belongs_to :post, Ash.Test.Actions.BulkResultLoadErrorTest.Post,
        public?: true,
        attribute_writable?: true
    end
  end

  defmodule Post do
    @moduledoc false
    use Ash.Resource,
      domain: Domain,
      data_layer: Ash.DataLayer.Ets,
      notifiers: [Notifier]

    ets do
      private?(true)
    end

    actions do
      default_accept :*
      defaults [:read, :destroy, create: :*, update: :*]
    end

    attributes do
      uuid_primary_key :id
      attribute :title, :string, public?: true
    end

    relationships do
      # Loading this fails, because `:by_flag` requires an argument.
      has_many :flagged_comments, Comment, public?: true, read_action: :by_flag
    end
  end

  @opts [
    return_records?: true,
    return_errors?: true,
    notify?: true,
    stop_on_error?: false,
    load: [:flagged_comments]
  ]

  test "bulk create returns an error when loading the created records fails" do
    assert %Ash.BulkResult{errors: [%Ash.Error.Invalid{}]} =
             Ash.bulk_create([%{title: "title"}], Post, :create, @opts)
  end

  test "bulk update returns an error when loading the updated records fails" do
    post = Ash.create!(Post, %{title: "title"})

    for strategy <- [:atomic, :stream] do
      assert %Ash.BulkResult{errors: [%Ash.Error.Invalid{}]} =
               Post
               |> Ash.Query.filter(id == ^post.id)
               |> Ash.bulk_update(:update, %{title: "new title"}, [strategy: strategy] ++ @opts)
    end
  end

  test "bulk destroy returns an error when loading the destroyed records fails" do
    for strategy <- [:atomic, :stream] do
      post = Ash.create!(Post, %{title: "title"})

      assert %Ash.BulkResult{errors: [%Ash.Error.Invalid{}]} =
               Post
               |> Ash.Query.filter(id == ^post.id)
               |> Ash.bulk_destroy(:destroy, %{}, [strategy: strategy] ++ @opts)
    end
  end
end
