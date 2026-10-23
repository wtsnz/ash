# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Actions.BulkReadErrorTest do
  use ExUnit.Case, async: false
  use Mimic

  defmodule Notifier do
    use Ash.Notifier

    def notify(notification) do
      send(self(), {:read_error_notification, notification})
      :ok
    end
  end

  defmodule ReadHook do
    use Ash.Resource.Preparation

    def prepare(query, _, _) do
      if query.context[:fail_after] do
        Ash.Query.before_action(query, fn query ->
          key = {__MODULE__, query.context[:read_key]}
          count = Process.get(key, 0) + 1
          Process.put(key, count)

          if count > query.context.fail_after do
            Ash.Query.add_error(query, "read failure")
          else
            query
          end
        end)
      else
        query
      end
    end
  end

  defmodule Record do
    use Ash.Resource,
      domain: Ash.Test.Domain,
      primary_read_warning?: false,
      data_layer: Ash.DataLayer.Ets,
      authorizers: [Ash.Policy.Authorizer],
      notifiers: [Notifier]

    ets do
      private? true
    end

    multitenancy do
      strategy :attribute
      attribute :tenant_id
      global? true
    end

    attributes do
      uuid_primary_key :id
      attribute :tenant_id, :string, public?: true, allow_nil?: false
      attribute :position, :integer, public?: true
      attribute :updated, :boolean, public?: true, default: false
    end

    identities do
      identity :unique_position, [:position], pre_check_with: Ash.Test.Domain
    end

    actions do
      defaults create: [:tenant_id, :position]

      read :read do
        primary? true
        pagination keyset?: true, offset?: true, required?: false
        prepare ReadHook
      end

      read :capped do
        pagination keyset?: true, required?: false, max_page_size: 2
        prepare ReadHook
      end

      read :offset do
        pagination offset?: true, required?: false
        prepare ReadHook
      end

      read :unpaginated do
        prepare ReadHook
      end

      update :non_atomic do
        require_atomic? false
        change fn changeset, _ -> Ash.Changeset.change_attribute(changeset, :updated, true) end
      end

      update :atomic do
        change set_attribute(:updated, true)
      end

      update :forbidden do
        require_atomic? false
        argument :note, :term
        validate fn _, _ -> :ok end, before_action?: true
      end

      destroy :non_atomic_destroy do
        require_atomic? false
        change fn changeset, _ -> changeset end
      end

      destroy :atomic_destroy
    end

    policies do
      policy action_type(:read) do
        access_type :strict
        authorize_if actor_attribute_equals(:can_read, true)
      end

      policy action(:forbidden) do
        forbid_if always()
      end

      policy action([:create, :non_atomic, :atomic, :non_atomic_destroy, :atomic_destroy]) do
        authorize_if always()
      end
    end

    code_interface do
      define :by_id, action: :forbidden, get_by: [:id]
      define :by_position, action: :forbidden, get_by_identity: :unique_position
      define :by_non_unique, action: :non_atomic, get_by: [:updated]
      define :with_note, action: :forbidden, get_by: [:id], args: [{:optional, :note}]
    end
  end

  setup do
    tenant = Ash.UUID.generate()

    records =
      for position <- 1..5 do
        Record
        |> Ash.Changeset.for_create(:create, %{tenant_id: tenant, position: position})
        |> Ash.create!(authorize?: false, tenant: tenant)
      end

    %{tenant: tenant, records: records}
  end

  defp bulk(operation, query, options) do
    {function, action} =
      case operation do
        :update -> {:bulk_update, :non_atomic}
        :destroy -> {:bulk_destroy, :non_atomic_destroy}
        :atomic_batches -> {:bulk_update, :atomic}
        :destroy_atomic_batches -> {:bulk_destroy, :atomic_destroy}
      end

    apply(Ash, function, [
      query,
      action,
      %{},
      Keyword.merge(
        [
          strategy:
            if(operation in [:atomic_batches, :destroy_atomic_batches],
              do: [:atomic_batches],
              else: [:stream]
            ),
          authorize?: true,
          return_records?: true,
          return_errors?: true,
          stop_on_error?: false,
          batch_size: 2,
          stream_batch_size: 2,
          allow_stream_with: :full_read
        ],
        options
      )
    ])
  end

  defp query(action, fail_after \\ nil) do
    Record
    |> Ash.Query.for_read(action, %{}, context: %{fail_after: fail_after, read_key: make_ref()})
    |> Ash.Query.sort(:position)
  end

  for operation <- [:update, :destroy, :atomic_batches, :destroy_atomic_batches],
      read_action <- [:read, :offset, :unpaginated] do
    test "#{operation} returns a forbidden #{read_action} read", %{tenant: tenant} do
      result = bulk(unquote(operation), query(unquote(read_action)), tenant: tenant)

      assert %Ash.BulkResult{status: :error, error_count: 1, errors: [%Ash.Error.Forbidden{}]} =
               result
    end

    test "#{operation} retains successful batches on a later #{read_action} read error", %{
      tenant: tenant
    } do
      result =
        bulk(unquote(operation), query(unquote(read_action), 1),
          tenant: tenant,
          actor: %{can_read: true},
          notify?: true,
          return_notifications?: true
        )

      assert %Ash.BulkResult{
               status: :partial_success,
               error_count: 1,
               records: records,
               notifications: notifications
             } = result

      assert Enum.map(records, & &1.position) == [1, 2]
      assert length(notifications) == 2
      assert Exception.message(hd(result.errors)) =~ "read failure"
    end
  end

  for operation <- [:update, :destroy, :atomic_batches, :destroy_atomic_batches] do
    test "#{operation} returns a terminal read error in a lazy result stream", %{tenant: tenant} do
      result =
        bulk(unquote(operation), query(:read, 1),
          tenant: tenant,
          actor: %{can_read: true},
          return_stream?: true,
          notify?: true,
          return_notifications?: true
        )
        |> Enum.to_list()

      assert Enum.count(result, &match?({:ok, _}, &1)) == 2
      assert Enum.count(result, &match?({:error, _}, &1)) == 1
      assert Enum.count(result, &match?({:notification, _}, &1)) == 2
    end
  end

  for transaction <- [false, :batch, :all],
      stop <- [false, true],
      return_errors <- [false, true] do
    test "read failure with transaction #{transaction}, stop #{stop}, errors #{return_errors}", %{
      tenant: tenant
    } do
      result =
        bulk(:update, query(:read, 1),
          tenant: tenant,
          actor: %{can_read: true},
          transaction: unquote(transaction),
          stop_on_error?: unquote(stop),
          return_errors?: unquote(return_errors),
          return_records?: false
        )

      assert result.status == :partial_success
      assert result.error_count == 1

      if unquote(return_errors),
        do: assert(length(result.errors) == 1),
        else: assert(result.errors in [nil, []])
    end
  end

  test "get_by on primary key returns a forbidden error", %{records: [record | _], tenant: tenant} do
    assert {:error, %Ash.Error.Forbidden{}} =
             Record.by_id(record.id, tenant: tenant, authorize?: true)
  end

  test "get_by on identity returns a forbidden error", %{records: [record | _], tenant: tenant} do
    assert {:error, %Ash.Error.Forbidden{}} =
             Record.by_position(record.position, tenant: tenant, authorize?: true)
  end

  test "non-unique get_by preserves the MultipleResults check", %{tenant: tenant} do
    assert {:error, %Ash.Error.Invalid.MultipleResults{count: 5}} =
             Record.by_non_unique(false, tenant: tenant, actor: %{can_read: true})
  end

  test "non-bang stream error is suppressed when return_errors? is false", %{tenant: tenant} do
    result = bulk(:update, query(:read), tenant: tenant, return_errors?: false)
    assert result.status == :error
    assert result.error_count == 1
    assert result.errors in [nil, []]
  end

  test "bang bulk update raises read error", %{tenant: tenant} do
    assert_raise Ash.Error.Forbidden, fn ->
      Ash.bulk_update!(query(:read), :non_atomic, %{},
        tenant: tenant,
        authorize?: true,
        strategy: [:stream],
        return_errors?: true,
        allow_stream_with: :full_read
      )
    end
  end

  test "read error flushes a partial write batch", %{tenant: tenant} do
    result =
      bulk(:update, query(:capped, 1),
        tenant: tenant,
        actor: %{can_read: true},
        batch_size: 3,
        stream_batch_size: 2
      )

    assert result.status == :partial_success
    assert Enum.map(result.records, & &1.position) == [1, 2]
    assert result.error_count == 1
  end

  test "successful notifications are sent once after a later read error", %{tenant: tenant} do
    result =
      bulk(:update, query(:read, 1), tenant: tenant, actor: %{can_read: true}, notify?: true)

    assert result.status == :partial_success
    assert_receive {:read_error_notification, %{action: %{name: :non_atomic}}}
    assert_receive {:read_error_notification, %{action: %{name: :non_atomic}}}
    refute_receive {:read_error_notification, %{action: %{name: :non_atomic}}}
  end

  test "data layer read errors become bulk errors", %{tenant: tenant} do
    expect(Ash.DataLayer, :run_query, fn _, _ -> {:error, "data layer failure"} end)
    result = bulk(:update, query(:read), tenant: tenant, actor: %{can_read: true})
    assert result.status == :error
    assert result.error_count == 1
    assert Exception.message(hd(result.errors)) =~ "data layer failure"
  end

  test "invalid read queries become bulk errors", %{tenant: tenant} do
    result =
      bulk(:update, Ash.Query.add_error(query(:read), "invalid query"),
        tenant: tenant,
        actor: %{can_read: true}
      )

    assert result.status == :error
    assert result.error_count == 1
  end

  test "public Ash.stream! still raises", %{tenant: tenant} do
    assert_raise Ash.Error.Forbidden, fn ->
      Record |> Ash.stream!(tenant: tenant, authorize?: true) |> Enum.to_list()
    end
  end

  for operation <- [:update, :destroy] do
    test "#{operation} captures a full_read failure", %{tenant: tenant} do
      result =
        bulk(unquote(operation), query(:unpaginated), tenant: tenant, stream_with: :full_read)

      assert %Ash.BulkResult{status: :error, error_count: 1, errors: [%Ash.Error.Forbidden{}]} =
               result
    end
  end

  test "a later data layer read error preserves the completed batch", %{tenant: tenant} do
    stub(Ash.DataLayer, :run_query, fn query, resource ->
      count = Process.get(:data_layer_reads, 0) + 1
      Process.put(:data_layer_reads, count)

      if count == 2 do
        {:error, "later data layer failure"}
      else
        Mimic.call_original(Ash.DataLayer, :run_query, [query, resource])
      end
    end)

    result = bulk(:update, query(:read), tenant: tenant, actor: %{can_read: true})
    assert result.status == :partial_success
    assert length(result.records) == 2
    assert result.error_count == 1
  end

  test "lazy read errors respect return_errors?: false", %{tenant: tenant} do
    assert [] ==
             bulk(:update, query(:read),
               tenant: tenant,
               return_stream?: true,
               return_errors?: false
             )
             |> Enum.to_list()
  end

  test "read failures do not rescue arbitrary exceptions in preparations", %{tenant: tenant} do
    q = query(:read) |> Ash.Query.before_action(fn _ -> raise "programmer error" end)

    assert_raise Ash.Error.Unknown, ~r/programmer error/, fn ->
      bulk(:update, q, tenant: tenant, actor: %{can_read: true})
    end
  end

  test "lazy and all transaction combination remains invalid", %{tenant: tenant} do
    assert_raise Ash.Error.Unknown, ~r/Cannot specify/, fn ->
      bulk(:update, query(:read), tenant: tenant, transaction: :all, return_stream?: true)
    end
  end
end
