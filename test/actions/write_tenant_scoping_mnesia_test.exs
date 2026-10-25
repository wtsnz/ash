# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Actions.WriteTenantScopingMnesiaTest do
  @moduledoc """
  Attribute multitenancy on a data layer that can't filter a changeset (`:changeset_filter`).
  See `Ash.Test.Actions.WriteTenantScopingTest`.
  """
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import ExUnit.CaptureIO

  defmodule Note do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.WriteTenantScopingMnesiaTest.Domain,
      data_layer: Ash.DataLayer.Mnesia

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
      defaults [:read, :destroy, create: [:body], update: [:body]]
    end
  end

  defmodule HiddenNote do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.WriteTenantScopingMnesiaTest.Domain,
      data_layer: Ash.DataLayer.Mnesia

    resource do
      base_filter visible: true
    end

    multitenancy do
      strategy :attribute
      attribute :shop_id
    end

    attributes do
      uuid_primary_key :id
      attribute :shop_id, :string, allow_nil?: false, public?: true
      attribute :visible, :boolean, default: true, public?: true
      attribute :body, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Note
      resource HiddenNote
    end
  end

  setup do
    capture_log(fn -> Ash.DataLayer.Mnesia.start(Domain, [Note, HiddenNote]) end)

    on_exit(fn ->
      capture_log(fn ->
        :mnesia.stop()
        :mnesia.delete_schema([node()])
      end)
    end)
  end

  defp stored(%Note{id: id, shop_id: shop_id}) do
    case Ash.get(Note, id, tenant: shop_id) do
      {:ok, note} -> note.body
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} -> :gone
    end
  end

  # The data layer warns that it can't apply the filter; keep the test output clean.
  defp quietly(fun) do
    capture_io(:stderr, fn -> send(self(), {:result, fun.()}) end)
    assert_received {:result, result}
    result
  end

  test "writes within a tenant" do
    note = Ash.create!(Note, %{body: "original"}, tenant: "a")
    assert {:ok, _} = quietly(fn -> Ash.update(note, %{body: "changed"}, tenant: "a") end)
    assert stored(note) == "changed"
    assert :ok = quietly(fn -> Ash.destroy(note, tenant: "a") end)
    assert stored(note) == :gone
  end

  test "another tenant's record is not updated" do
    b_note = Ash.create!(Note, %{body: "original"}, tenant: "b")

    assert {:error, _} =
             quietly(fn -> Ash.update(b_note, %{body: "changed by a"}, tenant: "a") end)

    assert stored(b_note) == "original"
  end

  test "another tenant's record is not destroyed" do
    b_note = Ash.create!(Note, %{body: "original"}, tenant: "b")
    assert {:error, _} = quietly(fn -> Ash.destroy(b_note, tenant: "a") end)
    assert stored(b_note) == "original"
  end

  test "the tenant check doesn't apply the resource's read filters" do
    note = Ash.Seed.seed!(HiddenNote, %{body: "original", visible: false}, tenant: "a")

    changeset =
      note
      |> Ash.Changeset.new()
      |> Ash.Changeset.set_tenant("a")
      |> Ash.Changeset.force_change_attribute(:body, "changed")

    assert {:ok, %{body: "changed"}} = Ash.DataLayer.update(HiddenNote, changeset)
  end
end
