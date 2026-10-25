# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Test.Actions.WriteTenantScopingTest do
  @moduledoc """
  Every write path given a tenant only writes records in that tenant.

  Each test that crosses tenants starts from a note that belongs to shop "b", held by code acting
  for shop "a" (for example a record kept between requests or jobs, or read without a tenant).
  `Ash.update(b_note, ..., tenant: "a")` is refused, so every other way of writing it should be
  too. The "within a tenant" tests cover the same paths for normal use.
  """
  use ExUnit.Case, async: true

  require Ash.Expr
  require Ash.Query

  defmodule Scope do
    @moduledoc false
    defstruct [:tenant]

    defimpl Ash.Scope.ToOpts do
      def get_actor(_), do: :error
      def get_tenant(%{tenant: tenant}), do: {:ok, tenant}
      def get_context(_), do: :error
      def get_tracer(_), do: :error
      def get_authorize?(_), do: :error
    end
  end

  defmodule ManualDestroy do
    @moduledoc false
    use Ash.Resource.ManualDestroy

    # A typical manual destroy: delete by primary key through the data layer.
    def destroy(changeset, _opts, _context) do
      case Ash.DataLayer.destroy(changeset.resource, changeset) do
        :ok -> {:ok, changeset.data}
        other -> other
      end
    end
  end

  defmodule Note do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.WriteTenantScopingTest.Domain,
      data_layer: Ash.DataLayer.Ets

    ets do
      private? true
    end

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
      defaults [:read, create: [:body]]

      read :global do
        multitenancy :allow_global
      end

      update :update do
        primary? true
        accept [:body]
      end

      update :update_nonatomic do
        accept [:body]
        require_atomic? false
        change fn changeset, _ -> changeset end
      end

      update :update_bypass do
        accept [:body]
        multitenancy :bypass
      end

      destroy :destroy do
        primary? true
      end

      destroy :destroy_nonatomic do
        require_atomic? false
        change fn changeset, _ -> changeset end
      end

      destroy :archive do
        soft? true
        change set_attribute(:body, "archived")
      end

      destroy :manual_destroy do
        manual ManualDestroy
      end

      destroy :destroy_bypass do
        multitenancy :bypass
      end
    end
  end

  # Client-generated primary keys (for example offline sync), upserted on the primary key.
  defmodule ClientNote do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.WriteTenantScopingTest.Domain,
      data_layer: Ash.DataLayer.Ets

    ets do
      private? true
    end

    multitenancy do
      strategy :attribute
      attribute :shop_id
      # Needed to check an `all_tenants?` identity on ETS.
      global? true
    end

    attributes do
      uuid_primary_key :id, writable?: true, public?: true
      attribute :shop_id, :string, allow_nil?: false, public?: true
      attribute :slug, :string, public?: true
      attribute :code, :string, public?: true
      attribute :body, :string, public?: true
      attribute :secret, :string, public?: true
    end

    identities do
      identity :slug, [:slug], pre_check?: true
      identity :global_code, [:code], all_tenants?: true, pre_check?: true
    end

    actions do
      defaults [:read, create: [:id, :slug, :code, :body, :secret]]

      create :save do
        accept [:id, :body]
        upsert? true
        upsert_fields [:body]
      end

      create :save_by_slug do
        accept [:slug, :body]
        upsert? true
        upsert_identity :slug
        upsert_fields [:body]
      end

      create :save_by_code do
        accept [:code, :body]
        upsert? true
        upsert_identity :global_code
        upsert_fields [:body]
      end
    end
  end

  defmodule CtxNote do
    @moduledoc false
    use Ash.Resource,
      domain: Ash.Test.Actions.WriteTenantScopingTest.Domain,
      data_layer: Ash.DataLayer.Ets

    ets do
      private? true
    end

    multitenancy do
      strategy :context
    end

    attributes do
      # Writable, so two tenants can hold records with the same primary key.
      uuid_primary_key :id, writable?: true, public?: true
      attribute :body, :string, public?: true
    end

    actions do
      defaults [:read, :destroy, create: [:id, :body], update: [:body]]

      # A change that depends on the tenant the changeset was built for.
      update :stamp_tenant do
        require_atomic? false
        accept []

        change fn changeset, _ ->
          Ash.Changeset.force_change_attribute(changeset, :body, "built for #{changeset.tenant}")
        end
      end
    end
  end

  defmodule Domain do
    @moduledoc false
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource Note do
        define :update_note, action: :update
        define :update_note_nonatomic, action: :update_nonatomic
        define :destroy_note, action: :destroy
      end

      resource ClientNote

      resource CtxNote do
        define :destroy_ctx_note, action: :destroy
      end
    end
  end

  defp note!(tenant, body \\ "original") do
    Ash.create!(Note, %{body: body}, tenant: tenant)
  end

  # The note's body as stored in its own tenant, or `:gone`.
  defp stored(%Note{id: id, shop_id: shop_id}) do
    case Ash.get(Note, id, tenant: shop_id) do
      {:ok, note} -> note.body
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} -> :gone
    end
  end

  defp stored(%CtxNote{id: id}, tenant) do
    case Ash.get(CtxNote, id, tenant: tenant) do
      {:ok, note} -> note.body
      {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} -> :gone
    end
  end

  defp stored_client_note(id) do
    ClientNote
    |> Ash.read!(context: %{shared: %{private: %{multitenancy: :bypass_all}}})
    |> Enum.filter(&(&1.id == id))
    |> Enum.map(&{&1.shop_id, &1.body})
  end

  # A note as read through an `:allow_global` read with no tenant, so its metadata has no tenant.
  defp read_globally(%Note{id: id}) do
    Note
    |> Ash.Query.for_read(:global)
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one!()
  end

  describe "within a tenant" do
    test "single updates and destroys" do
      note = note!("a")
      assert {:ok, _} = Ash.update(note, %{body: "changed"}, tenant: "a")
      assert {:ok, _} = Domain.update_note(note, %{body: "via interface"}, tenant: "a")
      assert stored(note) == "via interface"

      assert {:ok, _} =
               note
               |> Ash.Changeset.for_update(:update_nonatomic, %{body: "nonatomic"}, tenant: "a")
               |> Ash.update()

      assert stored(note) == "nonatomic"

      assert :ok = Ash.destroy(note, action: :archive, tenant: "a")
      assert stored(note) == "archived"

      assert :ok = Domain.destroy_note(note, tenant: "a")
      assert stored(note) == :gone

      note = note!("a")
      assert :ok = note |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: "a") |> Ash.destroy()
      assert stored(note) == :gone

      note = note!("a")

      assert :ok =
               note
               |> Ash.Changeset.for_destroy(:manual_destroy, %{}, tenant: "a")
               |> Ash.destroy()

      assert stored(note) == :gone
    end

    test "the tenant comes from the record when none is given" do
      note = note!("a")
      assert {:ok, _} = Ash.update(note, %{body: "changed"})
      assert stored(note) == "changed"
      assert :ok = Ash.destroy(note)
      assert stored(note) == :gone
    end

    test "with a scope" do
      note = note!("a")
      scope = %Scope{tenant: "a"}
      assert {:ok, _} = Ash.update(note, %{body: "changed"}, scope: scope)
      assert stored(note) == "changed"
      assert :ok = Ash.destroy(note, scope: scope)
      assert stored(note) == :gone
    end

    for strategy <- [:atomic, :atomic_batches, :stream] do
      test "bulk update and destroy of records, #{strategy}" do
        note = note!("a")

        assert %{status: :success} =
                 Ash.bulk_update([note], :update_nonatomic, %{body: "changed"},
                   tenant: "a",
                   strategy: [unquote(strategy), :stream],
                   return_errors?: true
                 )

        assert stored(note) == "changed"

        assert %{status: :success} =
                 Ash.bulk_update([note], :update, %{body: "atomic"},
                   tenant: "a",
                   strategy: unquote(strategy),
                   return_errors?: true
                 )

        assert stored(note) == "atomic"

        assert %{status: :success} =
                 Ash.bulk_destroy([note], :archive, %{},
                   tenant: "a",
                   strategy: unquote(strategy),
                   return_errors?: true
                 )

        assert stored(note) == "archived"

        assert %{status: :success} =
                 Ash.bulk_destroy([note], :destroy, %{},
                   tenant: "a",
                   strategy: unquote(strategy),
                   return_errors?: true
                 )

        assert stored(note) == :gone
      end

      test "update_many, #{strategy}" do
        note = note!("a")

        assert %{status: :success} =
                 Ash.update_many([{note, %{body: "changed"}}], Note, :update,
                   tenant: "a",
                   strategy: unquote(strategy),
                   return_errors?: true
                 )

        assert stored(note) == "changed"
      end
    end

    test "a bulk update over a query only changes the tenant's records" do
      a_note = note!("a")
      b_note = note!("b")

      Note
      |> Ash.Query.set_tenant("a")
      |> Ash.bulk_update!(:update_nonatomic, %{body: "changed"}, strategy: :stream)

      assert stored(a_note) == "changed"
      assert stored(b_note) == "original"
    end

    test "list code interfaces" do
      note = note!("a")

      assert %{status: :success} =
               Domain.update_note_nonatomic([note], %{body: "changed"}, tenant: "a")

      assert stored(note) == "changed"
      assert %{status: :success} = Domain.destroy_note([note], tenant: "a")
      assert stored(note) == :gone
    end

    test "a record read without a tenant can be written with its own tenant" do
      note = "a" |> note!() |> read_globally()
      assert is_nil(note.__metadata__[:tenant])

      assert %{status: :success} =
               Ash.bulk_update([note], :update_nonatomic, %{body: "changed"},
                 tenant: "a",
                 strategy: :stream
               )

      assert stored(note) == "changed"
    end

    test "upserts on the primary key and on an identity" do
      id = Ash.UUID.generate()

      assert {:ok, _} =
               Ash.create(ClientNote, %{id: id, body: "first"}, action: :save, tenant: "a")

      assert {:ok, _} =
               Ash.create(ClientNote, %{id: id, body: "second"}, action: :save, tenant: "a")

      assert stored_client_note(id) == [{"a", "second"}]

      assert %{status: :success} =
               Ash.bulk_create([%{id: id, body: "bulk"}], ClientNote, :save,
                 tenant: "a",
                 return_errors?: true
               )

      assert stored_client_note(id) == [{"a", "bulk"}]

      {:ok, by_slug} =
        Ash.create(ClientNote, %{slug: "s", body: "first"}, action: :save_by_slug, tenant: "a")

      assert {:ok, _} =
               Ash.create(ClientNote, %{slug: "s", body: "second"},
                 action: :save_by_slug,
                 tenant: "a"
               )

      assert stored_client_note(by_slug.id) == [{"a", "second"}]
    end

    test "an identity upsert in another tenant creates that tenant's own record" do
      {:ok, b_note} =
        Ash.create(ClientNote, %{slug: "s", body: "b's"}, action: :save_by_slug, tenant: "b")

      assert {:ok, a_note} =
               Ash.create(ClientNote, %{slug: "s", body: "a's"},
                 action: :save_by_slug,
                 tenant: "a"
               )

      assert a_note.id != b_note.id
      assert stored_client_note(b_note.id) == [{"b", "b's"}]
    end

    test "a changeset whose tenant was cleared falls back to the record's" do
      note = note!("a")

      assert {:ok, _} =
               note
               |> Ash.Changeset.for_update(:update_nonatomic, %{body: "changed"})
               |> Ash.Changeset.set_tenant(nil)
               |> Ash.update()

      assert stored(note) == "changed"
    end

    test "context multitenancy" do
      {:ok, note} = Ash.create(CtxNote, %{body: "original"}, tenant: "a")
      assert {:ok, _} = Ash.update(note, %{body: "changed"}, tenant: "a")
      assert stored(note, "a") == "changed"
      assert :ok = Domain.destroy_ctx_note(note, tenant: "a")
      assert stored(note, "a") == :gone
    end

    test "a :bypass action writes in any tenant" do
      b_note = note!("b")

      assert {:ok, _} =
               b_note
               |> Ash.Changeset.for_update(:update_bypass, %{body: "bypassed"}, tenant: "a")
               |> Ash.update()

      assert stored(b_note) == "bypassed"

      assert %{status: :success} =
               Ash.bulk_update([b_note], :update_bypass, %{body: "bulk bypassed"},
                 tenant: "a",
                 strategy: :stream,
                 return_errors?: true
               )

      assert stored(b_note) == "bulk bypassed"

      assert :ok =
               b_note
               |> Ash.Changeset.for_destroy(:destroy_bypass, %{}, tenant: "a")
               |> Ash.destroy()

      assert stored(b_note) == :gone
    end
  end

  describe "a changeset built for one tenant" do
    setup do
      id = Ash.UUID.generate()
      {:ok, a_note} = Ash.create(CtxNote, %{id: id, body: "a's"}, tenant: "a")
      {:ok, b_note} = Ash.create(CtxNote, %{id: id, body: "b's"}, tenant: "b")
      %{a_note: a_note, b_note: b_note}
    end

    test "runs again in the same tenant", %{a_note: a_note} do
      changeset = Ash.Changeset.for_update(a_note, :stamp_tenant, %{}, tenant: "a")
      assert {:ok, _} = Ash.update(changeset, tenant: "a")
      assert stored(a_note, "a") == "built for a"
    end

    test "isn't updated in another tenant", %{a_note: a_note, b_note: b_note} do
      changeset = Ash.Changeset.for_update(a_note, :stamp_tenant, %{}, tenant: "a")

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.update(changeset, tenant: "b")

      assert stored(a_note, "a") == "a's"
      assert stored(b_note, "b") == "b's"
    end

    test "isn't destroyed in another tenant", %{a_note: a_note, b_note: b_note} do
      changeset = Ash.Changeset.for_destroy(a_note, :destroy, %{}, tenant: "a")

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.destroy(changeset, tenant: "b")

      assert stored(a_note, "a") == "a's"
      assert stored(b_note, "b") == "b's"
    end

    test "isn't run in another tenant given by a scope", %{a_note: a_note, b_note: b_note} do
      changeset = Ash.Changeset.for_update(a_note, :stamp_tenant, %{}, tenant: "a")
      assert {:error, _} = Ash.update(changeset, scope: %Scope{tenant: "b"})
      assert stored(b_note, "b") == "b's"
    end
  end

  describe "another tenant's record, single actions" do
    test "an update is refused" do
      b_note = note!("b")
      assert {:error, _} = Ash.update(b_note, %{body: "changed by a"}, tenant: "a")
      assert {:error, _} = Domain.update_note(b_note, %{body: "changed by a"}, tenant: "a")

      assert {:error, _} =
               b_note
               |> Ash.Changeset.for_update(:update_nonatomic, %{body: "changed by a"},
                 tenant: "a"
               )
               |> Ash.update()

      assert stored(b_note) == "original"
    end

    test "a destroy given the tenant as an option is refused" do
      b_note = note!("b")
      assert {:error, _} = Ash.destroy(b_note, tenant: "a")
      assert {:error, _} = Ash.destroy(b_note, action: :archive, tenant: "a")
      assert stored(b_note) == "original"
    end

    test "a destroy code interface is refused" do
      b_note = note!("b")
      assert {:error, _} = Domain.destroy_note(b_note, tenant: "a")
      assert stored(b_note) == "original"
    end

    test "a destroy changeset built for the tenant is refused" do
      b_note = note!("b")

      assert {:error, _} =
               b_note |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: "a") |> Ash.destroy()

      assert {:error, _} =
               b_note
               |> Ash.Changeset.for_destroy(:destroy_nonatomic, %{}, tenant: "a")
               |> Ash.destroy()

      assert stored(b_note) == "original"
    end

    test "a manual destroy gets the tenant it was given" do
      b_note = note!("b")

      assert {:error, _} =
               b_note
               |> Ash.Changeset.for_destroy(:manual_destroy, %{}, tenant: "a")
               |> Ash.destroy()

      assert stored(b_note) == "original"
    end

    test "an update or destroy with a scope is refused" do
      b_note = note!("b")
      scope = %Scope{tenant: "a"}
      assert {:error, _} = Ash.update(b_note, %{body: "changed by a"}, scope: scope)
      assert stored(b_note) == "original"
      assert {:error, _} = Ash.destroy(b_note, scope: scope)
      assert stored(b_note) == "original"
    end

    for action <- [:update, :update_nonatomic] do
      test "a tenant given when running a changeset built without one, #{action}" do
        b_note = note!("b")
        changeset = Ash.Changeset.for_update(b_note, unquote(action), %{body: "changed by a"})
        assert {:error, _} = Ash.update(changeset, tenant: "a")
        assert stored(b_note) == "original"
      end
    end

    test "a changeset that copies another changeset's context" do
      a_note = note!("a")
      b_note = note!("b")
      test_pid = self()

      a_note
      |> Ash.Changeset.for_update(:update_nonatomic, %{body: "changed"}, tenant: "a")
      |> Ash.Changeset.after_action(fn changeset, record ->
        result =
          b_note
          |> Ash.Changeset.for_update(:update_nonatomic, %{body: "changed by a"},
            tenant: "a",
            context: changeset.context
          )
          |> Ash.update()

        send(test_pid, {:copied_context_result, result})
        {:ok, record}
      end)
      |> Ash.update!()

      assert_received {:copied_context_result, {:error, _}}
      assert stored(b_note) == "original"
    end

    test "a changeset without an action, written through the data layer" do
      b_note = note!("b")

      changeset =
        b_note
        |> Ash.Changeset.new()
        |> Ash.Changeset.set_tenant("a")
        |> Ash.Changeset.force_change_attribute(:body, "changed by a")

      assert {:error, %Ash.Error.Changes.StaleRecord{}} = Ash.DataLayer.update(Note, changeset)
      assert stored(b_note) == "original"
    end

    test "a context-multitenancy destroy runs in the tenant it was given" do
      {:ok, b_note} = Ash.create(CtxNote, %{body: "original"}, tenant: "b")
      # Tenant a has no such row. ETS treats deleting a missing row as `:ok`, so only the
      # outcome for tenant b is checked.
      Domain.destroy_ctx_note(b_note, tenant: "a")
      assert stored(b_note, "b") == "original"
    end
  end

  describe "another tenant's record, bulk actions" do
    for strategy <- [:atomic, :atomic_batches, :stream] do
      test "bulk update, #{strategy}" do
        b_note = note!("b")

        Ash.bulk_update([b_note], :update, %{body: "changed by a"},
          tenant: "a",
          strategy: unquote(strategy)
        )

        assert stored(b_note) == "original"
      end

      test "bulk destroy, #{strategy}" do
        b_note = note!("b")
        Ash.bulk_destroy([b_note], :destroy, %{}, tenant: "a", strategy: unquote(strategy))
        assert stored(b_note) == "original"
      end

      test "bulk soft destroy, #{strategy}" do
        b_note = note!("b")
        Ash.bulk_destroy([b_note], :archive, %{}, tenant: "a", strategy: unquote(strategy))
        assert stored(b_note) == "original"
      end

      test "update_many, #{strategy}" do
        b_note = note!("b")

        Ash.update_many([{b_note, %{body: "changed by a"}}], Note, :update,
          tenant: "a",
          strategy: unquote(strategy)
        )

        assert stored(b_note) == "original"
      end
    end

    test "a non-atomic action falling back to :stream" do
      b_note = note!("b")

      Ash.bulk_update([b_note], :update_nonatomic, %{body: "changed by a"},
        tenant: "a",
        strategy: [:atomic, :stream]
      )

      Ash.bulk_destroy([b_note], :destroy_nonatomic, %{},
        tenant: "a",
        strategy: [:atomic, :stream]
      )

      assert stored(b_note) == "original"
    end

    test "list code interfaces" do
      b_note = note!("b")
      Domain.update_note_nonatomic([b_note], %{body: "changed by a"}, tenant: "a")
      Domain.destroy_note([b_note], tenant: "a")
      assert stored(b_note) == "original"
    end

    test "a record read without a tenant" do
      b_note = "b" |> note!() |> read_globally()

      Ash.bulk_update([b_note], :update_nonatomic, %{body: "changed by a"},
        tenant: "a",
        strategy: :stream
      )

      Ash.bulk_destroy([b_note], :destroy, %{}, tenant: "a", strategy: :stream)
      assert stored(b_note) == "original"
    end

    test "update_many with a record read without a tenant" do
      for strategy <- [:atomic, :atomic_batches, :stream] do
        b_note = "b" |> note!() |> read_globally()

        Ash.update_many([{b_note, %{body: "changed by a"}}], Note, :update,
          tenant: "a",
          strategy: strategy
        )

        assert stored(b_note) == "original"
      end
    end

    test "a refused record is not returned" do
      b_note = note!("b")

      result =
        Ash.bulk_update([b_note], :update_nonatomic, %{body: "changed by a"},
          tenant: "a",
          strategy: :stream,
          return_records?: true
        )

      assert result.records in [nil, []]
    end
  end

  describe "another tenant's record, upserts" do
    setup do
      {:ok, b_note} =
        Ash.create(ClientNote, %{body: "b's", secret: "b's secret", slug: "s", code: "c"},
          tenant: "b"
        )

      %{b_note: b_note}
    end

    test "an upsert on the primary key is refused", %{b_note: b_note} do
      result =
        Ash.create(ClientNote, %{id: b_note.id, body: "from a"}, action: :save, tenant: "a")

      assert {:error, _} = result
      assert stored_client_note(b_note.id) == [{"b", "b's"}]
    end

    test "a bulk upsert on the primary key is refused", %{b_note: b_note} do
      result =
        Ash.bulk_create([%{id: b_note.id, body: "from a"}], ClientNote, :save,
          tenant: "a",
          return_records?: true
        )

      refute Enum.any?(result.records || [], &(&1.secret == "b's secret"))
      assert stored_client_note(b_note.id) == [{"b", "b's"}]
    end

    test "an upsert with its own upsert_condition is refused", %{b_note: b_note} do
      condition = Ash.Expr.expr(body == "b's")

      assert {:error, _} =
               Ash.create(ClientNote, %{id: b_note.id, body: "from a"},
                 action: :save,
                 tenant: "a",
                 upsert_condition: condition
               )

      # A refused bulk upsert is skipped like any upsert whose condition is false: no error, and
      # no record returned.
      result =
        Ash.bulk_create([%{id: b_note.id, body: "from a"}], ClientNote, :save,
          tenant: "a",
          upsert_condition: condition,
          return_records?: true
        )

      assert result.records == []
      assert stored_client_note(b_note.id) == [{"b", "b's"}]
    end

    test "an upsert on an all_tenants? identity is refused", %{b_note: b_note} do
      # The identity is unique across tenants, but only tenant b may update b's record.
      Ash.create(ClientNote, %{code: "c", body: "from a"}, action: :save_by_code, tenant: "a")

      assert stored_client_note(b_note.id) == [{"b", "b's"}]
    end
  end
end
