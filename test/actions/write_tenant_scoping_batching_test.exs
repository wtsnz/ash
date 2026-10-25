# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Actions.WriteTenantScopingBatchingTest do
  @moduledoc """
  A bulk upsert's changesets are batched by their filter, which some data layers use as the
  upsert condition for the whole batch (AshPostgres takes the first changeset's). Changesets for
  different tenants must not share a batch. See `Ash.Test.Actions.WriteTenantScopingTest`.
  """
  use ExUnit.Case, async: false
  use Mimic

  defmodule ClientNote do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.WriteTenantScopingBatchingTest.Domain,
      data_layer: Ash.DataLayer.Ets

    ets do
      private? true
    end

    multitenancy do
      strategy :attribute
      attribute :shop_id
    end

    attributes do
      uuid_primary_key :id, writable?: true, public?: true
      attribute :shop_id, :string, allow_nil?: false, public?: true
      attribute :body, :string, public?: true
    end

    actions do
      defaults [:read]

      create :save do
        accept [:id, :body]
        upsert? true
        upsert_fields [:body]
      end
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource ClientNote
    end
  end

  test "a bulk upsert sends each tenant's changesets to the data layer separately" do
    test_pid = self()

    stub(Ash.DataLayer, :bulk_create, fn resource, changesets, options ->
      changesets = Enum.to_list(changesets)
      send(test_pid, {:batch, Enum.map(changesets, & &1.to_tenant)})
      call_original(Ash.DataLayer, :bulk_create, [resource, changesets, options])
    end)

    a_id = Ash.UUID.generate()
    b_id = Ash.UUID.generate()

    # Each record's tenant comes from its input.
    Ash.bulk_create(
      [%{id: a_id, body: "a's"}, %{id: b_id, body: "b's"}],
      ClientNote,
      :save,
      tenant: "a",
      transform_changeset: fn changeset ->
        if Ash.Changeset.get_attribute(changeset, :id) == b_id do
          changeset
          |> Ash.Changeset.set_tenant("b")
          |> Ash.Changeset.force_change_attribute(:shop_id, "b")
        else
          changeset
        end
      end
    )

    batches = collect_batches([])
    assert Enum.all?(batches, &(length(Enum.uniq(&1)) == 1)), inspect(batches)
  end

  defp collect_batches(acc) do
    receive do
      {:batch, tenants} -> collect_batches([tenants | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end
end
