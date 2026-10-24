# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Adversarial do
  @moduledoc """
  Shapes and paths where a missing tenant or policy filter shows up as
  another tenant's or a hidden row in the answer. The fixture and every
  intended answer are in `Ash.Conformance.Adversarial`.

  - `adv.tenant.*`, `adv.schema.*`: `many_to_many` and `has_many through:`
    (two hops, four hops, and a `many_to_many` inside the path) under
    attribute and schema-based tenancy: loads, bounded loads of one record,
    `has_one through` with and without a sort, aggregates, `exists` and
    relationship filters. Each reads organisation 1, then 2.
  - `adv.plain.*`: the bounded `through` loads without tenancy or policies.
  - `adv.join_policy.*`: the join resource's read policy on loads,
    aggregates, `exists` aggregates and `filter_input`. The policies guide
    says aggregates always authorize the related data they reference, and
    input filters apply each related resource's read policy.
  - `adv.foreign.*`: updates and destroys given another tenant's records,
    one at a time and in bulk with every strategy. Each bulk write gets one
    record of each tenant, so the answer shows both what changed and what
    must not.
  - `adv.upsert.*`: upserts whose identity values also exist in another
    tenant, with and without `return_skipped_upsert?`.
  - `adv.field_write.*`: write results under field policies, at the top
    level, in an embedded resource, an array of them and a union, from
    single and bulk actions, with loads on the bulk query.
  - `adv.manage.*`: `manage_relationship` with another tenant's record, a
    record the actor can't read, and a `many_to_many` replaced in one tenant.
  """
  import Ash.Conformance.Scenario, only: [new: 5]
  alias Ash.Conformance.Adversarial, as: Model
  require Ash.Query
  require Ash.Expr

  @multitenancy "../documentation/topics/advanced/multitenancy.md"
  @relationships "../documentation/topics/resources/relationships.md"
  @policies "../documentation/topics/security/policies.md"
  @load_tests "../test/actions/load_test.exs"
  @bulk "../documentation/topics/actions/update-actions.md"
  @upserts "../documentation/topics/actions/create-actions.md"
  @manage "../documentation/topics/resources/relationships.md"

  @actor %{id: 1, admin: false}

  def all,
    do:
      tenancy() ++
        schema() ++
        plain() ++
        join_policy() ++
        foreign() ++
        upserts() ++
        field_writes() ++ manage()

  defp opts(basis, extra \\ []), do: [fixture: :adversarial, semantic_basis: basis] ++ extra

  # Attribute tenancy: each scenario reads organisation 1, then 2.

  defp tenancy do
    t = fn fun -> {fun.(1), fun.(2)} end
    both = fn scope_fun -> {scope_fun.({:org, 1}), scope_fun.({:org, 2})} end

    [
      new(
        "adv.tenant.m2m_load",
        :adversarial,
        both.(&Model.loads/1),
        fn ctx -> t.(&loads(event(ctx, :adv_event), :buyers, tenant: &1)) end,
        opts(@multitenancy)
      ),
      new(
        "adv.tenant.through_load",
        :adversarial,
        both.(&Model.loads/1),
        fn ctx -> t.(&loads(through(ctx, :adv_event), :customers, tenant: &1)) end,
        opts(@multitenancy)
      ),
      new(
        "adv.tenant.through_long_load",
        :adversarial,
        both.(&Model.loads/1),
        fn ctx -> t.(&loads(through(ctx, :adv_event), :customers_via_event, tenant: &1)) end,
        opts(@multitenancy)
      ),
      new(
        "adv.tenant.through_many_to_many_load",
        :adversarial,
        both.(&Model.loads/1),
        fn ctx -> t.(&loads(through(ctx, :adv_event), :buyers_via_event, tenant: &1)) end,
        opts(@multitenancy)
      ),
      new(
        "adv.tenant.has_one_sorted",
        :adversarial,
        both.(&Model.first/1),
        fn ctx -> t.(&one(through(ctx, :adv_event), :first_customer, tenant: &1)) end,
        opts(@multitenancy)
      ),
      new(
        "adv.tenant.has_one_unsorted",
        :adversarial,
        both.(&Model.member/1),
        fn ctx -> t.(&member(through(ctx, :adv_event), {:org, &1}, tenant: &1)) end,
        opts(@multitenancy)
      ),
      new(
        "adv.tenant.has_one_limit",
        :adversarial,
        both.(&Model.first/1),
        fn ctx ->
          t.(&one(through(ctx, :adv_event), {:a_customer, by_name(ctx, 1)}, tenant: &1))
        end,
        opts(@load_tests)
      ),
      new(
        "adv.tenant.through_limit_one",
        :adversarial,
        both.(&Model.page(&1, 1, 1, 0)),
        fn ctx -> t.(&page(ctx, through(ctx, :adv_event), :customers, 1, 0, tenant: &1)) end,
        opts(@load_tests)
      ),
      new(
        "adv.tenant.through_offset",
        :adversarial,
        both.(&Model.page(&1, 1, 1, 1)),
        fn ctx -> t.(&page(ctx, through(ctx, :adv_event), :customers, 1, 1, tenant: &1)) end,
        opts(@load_tests)
      ),
      new(
        "adv.tenant.m2m_limit_one",
        :adversarial,
        both.(&Model.page(&1, 1, 1, 0)),
        fn ctx -> t.(&page(ctx, event(ctx, :adv_event), :buyers, 1, 0, tenant: &1)) end,
        opts(@load_tests)
      ),
      new(
        "adv.tenant.m2m_aggregates",
        :adversarial,
        both.(&Model.aggregates/1),
        fn ctx ->
          t.(
            &aggregates(event(ctx, :adv_event), [:buyer_count, :buyer_ids, :top_buyer],
              tenant: &1
            )
          )
        end,
        opts(@multitenancy)
      ),
      new(
        "adv.tenant.through_aggregates",
        :adversarial,
        both.(&Model.aggregates/1),
        fn ctx ->
          t.(
            &aggregates(
              through(ctx, :adv_event),
              [:customer_count, :customer_ids, :top_customer],
              tenant: &1
            )
          )
        end,
        opts(@multitenancy)
      ),
      new(
        "adv.tenant.path_aggregates",
        :adversarial,
        both.(&Model.path_aggregates/1),
        fn ctx ->
          t.(&aggregates(event(ctx, :adv_event), [:order_count, :order_customer_ids], tenant: &1))
        end,
        opts(@multitenancy)
      ),
      new(
        "adv.tenant.m2m_exists",
        :adversarial,
        both.(&Model.with_customer(&1, 2)),
        fn ctx ->
          t.(&events(event(ctx, :adv_event), Ash.Expr.expr(exists(buyers, id == 2)), tenant: &1))
        end,
        opts(@multitenancy)
      ),
      new(
        "adv.tenant.through_exists",
        :adversarial,
        both.(&Model.with_customer(&1, 2)),
        fn ctx ->
          t.(
            &events(through(ctx, :adv_event), Ash.Expr.expr(exists(customers, id == 2)),
              tenant: &1
            )
          )
        end,
        opts(@multitenancy)
      ),
      new(
        "adv.tenant.m2m_path_filter",
        :adversarial,
        both.(&Model.with_customer(&1, 4)),
        fn ctx ->
          t.(&events(event(ctx, :adv_event), Ash.Expr.expr(buyers.id == 4), tenant: &1))
        end,
        opts(@multitenancy)
      ),
      new(
        "adv.tenant.aggregate_filter",
        :adversarial,
        both.(&Model.with_count(&1, 1)),
        fn ctx ->
          t.(&events(event(ctx, :adv_event), Ash.Expr.expr(buyer_count == 1), tenant: &1))
        end,
        opts(@multitenancy)
      )
    ]
  end

  # Schema-based tenancy: organisation 1's orders are in one schema, 2's in
  # another. Only Postgres provisions it.

  defp schema do
    t = fn fun -> {fun.(Model.schemas()[1]), fun.(Model.schemas()[2])} end
    both = fn scope_fun -> {scope_fun.({:org, 1}), scope_fun.({:org, 2})} end

    opts = [
      profile: :context_tenancy,
      fixture: :adversarial_context,
      semantic_basis: @multitenancy
    ]

    [
      new(
        "adv.schema.m2m_load",
        :adversarial,
        both.(&Model.loads/1),
        fn ctx -> t.(&loads(event(ctx, :adv_schema_event), :buyers, tenant: &1)) end,
        opts
      ),
      new(
        "adv.schema.through_load",
        :adversarial,
        both.(&Model.loads/1),
        fn ctx -> t.(&loads(through(ctx, :adv_schema_event), :customers, tenant: &1)) end,
        opts
      ),
      new(
        "adv.schema.m2m_aggregates",
        :adversarial,
        both.(&Model.aggregates/1),
        fn ctx ->
          t.(
            &aggregates(event(ctx, :adv_schema_event), [:buyer_count, :buyer_ids, :top_buyer],
              tenant: &1
            )
          )
        end,
        opts
      ),
      new(
        "adv.schema.through_aggregates",
        :adversarial,
        both.(&Model.aggregates/1),
        fn ctx ->
          t.(
            &aggregates(
              through(ctx, :adv_schema_event),
              [:customer_count, :customer_ids, :top_customer],
              tenant: &1
            )
          )
        end,
        opts
      ),
      new(
        "adv.schema.m2m_exists",
        :adversarial,
        both.(&Model.with_customer(&1, 2)),
        fn ctx ->
          t.(
            &events(event(ctx, :adv_schema_event), Ash.Expr.expr(exists(buyers, id == 2)),
              tenant: &1
            )
          )
        end,
        opts
      ),
      new(
        "adv.schema.through_limit_one",
        :adversarial,
        both.(&Model.page(&1, 1, 1, 0)),
        fn ctx ->
          t.(&page(ctx, through(ctx, :adv_schema_event), :customers, 1, 0, tenant: &1))
        end,
        opts
      )
    ]
  end

  # Bounded `through` loads with nothing else in the way.

  defp plain do
    [
      new(
        "adv.plain.through_load",
        :adversarial,
        Model.loads(:all),
        fn ctx -> loads(through(ctx, :adv_plain_event), :customers, []) end,
        opts(@relationships)
      ),
      new(
        "adv.plain.through_limit_one",
        :adversarial,
        Model.page(:all, 1, 1, 0),
        fn ctx -> page(ctx, through(ctx, :adv_plain_event), :customers, 1, 0, []) end,
        opts(@load_tests)
      ),
      new(
        "adv.plain.through_offset",
        :adversarial,
        Model.page(:all, 1, 1, 1),
        fn ctx -> page(ctx, through(ctx, :adv_plain_event), :customers, 1, 1, []) end,
        opts(@load_tests)
      ),
      # Two records take the lateral join; the control for the two above.
      new(
        "adv.plain.through_limit_one_each",
        :adversarial,
        Map.new([1, 2], &{&1, Model.page(:all, &1, 1, 0)}),
        fn ctx ->
          through(ctx, :adv_plain_event)
          |> Ash.Query.filter(id in [1, 2])
          |> loads({:customers, by_name(ctx, 1)}, [])
        end,
        opts(@load_tests)
      ),
      new(
        "adv.plain.has_one_sorted",
        :adversarial,
        Model.first(:all),
        fn ctx -> one(through(ctx, :adv_plain_event), :first_customer, []) end,
        opts(@relationships)
      ),
      new(
        "adv.plain.has_one_unsorted",
        :adversarial,
        Model.member(:all),
        fn ctx -> member(through(ctx, :adv_plain_event), :all, []) end,
        opts(@relationships)
      ),
      new(
        "adv.plain.has_one_limit",
        :adversarial,
        Model.first(:all),
        fn ctx -> one(through(ctx, :adv_plain_event), {:a_customer, by_name(ctx, 1)}, []) end,
        opts(@load_tests)
      ),
      new(
        "adv.plain.m2m_limit_one",
        :adversarial,
        Model.page(:all, 1, 1, 0),
        fn ctx -> page(ctx, event(ctx, :adv_plain_event), :buyers, 1, 0, []) end,
        opts(@load_tests)
      )
    ]
  end

  # The join resource's read policy: order 12 (event 1 to Cara) is hidden.

  defp join_policy do
    actor = [actor: @actor, authorize?: true]

    [
      new(
        "adv.join_policy.m2m_load",
        :adversarial,
        Model.loads(:visible),
        fn ctx -> loads(event(ctx, :adv_secure_event), :buyers, actor) end,
        opts(@policies)
      ),
      new(
        "adv.join_policy.through_load",
        :adversarial,
        Model.loads(:visible),
        fn ctx -> loads(through(ctx, :adv_secure_event), :customers, actor) end,
        opts(@policies)
      ),
      new(
        "adv.join_policy.m2m_aggregates",
        :adversarial,
        Model.aggregates(:visible),
        fn ctx ->
          aggregates(event(ctx, :adv_secure_event), [:buyer_count, :buyer_ids, :top_buyer], actor)
        end,
        opts(@policies)
      ),
      new(
        "adv.join_policy.through_aggregates",
        :adversarial,
        Model.aggregates(:visible),
        fn ctx ->
          aggregates(
            through(ctx, :adv_secure_event),
            [:customer_count, :customer_ids, :top_customer],
            actor
          )
        end,
        opts(@policies)
      ),
      # The same rows through the plain `orders` path, which applies the policy.
      new(
        "adv.join_policy.path_aggregates",
        :adversarial,
        Model.path_aggregates(:visible),
        fn ctx ->
          aggregates(event(ctx, :adv_secure_event), [:order_count, :order_customer_ids], actor)
        end,
        opts(@policies)
      ),
      new(
        "adv.join_policy.m2m_exists_aggregate",
        :adversarial,
        exists_cara(:visible),
        fn ctx -> exists_aggregate(ctx, event(ctx, :adv_secure_event), :buyers, actor) end,
        opts(@policies)
      ),
      new(
        "adv.join_policy.through_exists_aggregate",
        :adversarial,
        exists_cara(:visible),
        fn ctx -> exists_aggregate(ctx, through(ctx, :adv_secure_event), :customers, actor) end,
        opts(@policies)
      ),
      new(
        "adv.join_policy.m2m_aggregate_filter",
        :adversarial,
        Model.with_count(:visible, 3),
        fn ctx ->
          events(event(ctx, :adv_secure_event), Ash.Expr.expr(buyer_count == 3), actor)
        end,
        opts(@policies)
      ),
      new(
        "adv.join_policy.m2m_filter_input",
        :adversarial,
        Model.with_customer(:visible, 3),
        fn ctx -> input(event(ctx, :adv_secure_event), %{buyers: %{id: %{eq: 3}}}, actor) end,
        opts(@policies)
      ),
      new(
        "adv.join_policy.through_filter_input",
        :adversarial,
        Model.with_customer(:visible, 3),
        fn ctx ->
          input(through(ctx, :adv_secure_event), %{customers: %{id: %{eq: 3}}}, actor)
        end,
        opts(@policies)
      ),
      new(
        "adv.join_policy.path_filter_input",
        :adversarial,
        Model.with_customer(:visible, 3),
        fn ctx ->
          input(event(ctx, :adv_secure_event), %{orders: %{customer: %{id: %{eq: 3}}}}, actor)
        end,
        opts(@policies)
      )
    ]
  end

  defp exists_cara(scope),
    do: Map.new(Model.loads(scope), fn {event, ids} -> {event, 3 in ids} end)

  # Writes given organisation 2's records while acting for organisation 1.

  defp foreign do
    single = [
      {"update_option", fn note -> Ash.update(note, %{body: "x"}, tenant: 1) end},
      {"update_changeset",
       fn note ->
         note |> Ash.Changeset.for_update(:update, %{body: "x"}, tenant: 1) |> Ash.update()
       end},
      {"destroy_option", fn note -> Ash.destroy(note, tenant: 1) end},
      {"destroy_changeset",
       fn note -> note |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: 1) |> Ash.destroy() end}
    ]

    singles =
      for {name, write} <- single do
        new(
          "adv.foreign.#{name}",
          :adversarial,
          {:refused, Model.notes()},
          fn ctx ->
            note = Ash.get!(note(ctx), 201, tenant: 2, authorize?: false)
            {status(write.(note)), stored_notes(ctx)}
          end,
          opts(@multitenancy)
        )
      end

    # {strategy name, update action, destroy action, strategy}
    strategies = [
      {"atomic", :update, :destroy, :atomic},
      {"atomic_batches", :update, :destroy, :atomic_batches},
      {"stream", :update, :destroy, :stream},
      {"fallback", :edit, :remove, [:atomic, :stream]}
    ]

    bulk =
      for {name, update, destroy, strategy} <- strategies do
        [
          new(
            "adv.foreign.bulk_update.#{name}",
            :adversarial,
            {[101], Model.notes_after(&update_101/1)},
            fn ctx ->
              result =
                Ash.bulk_update(both_tenants(ctx), update, %{body: "x"}, bulk_opts(strategy))

              {returned(result), stored_notes(ctx)}
            end,
            opts(@bulk)
          ),
          new(
            "adv.foreign.bulk_destroy.#{name}",
            :adversarial,
            {[101], Model.notes_after(&destroy_101/1)},
            fn ctx ->
              result = Ash.bulk_destroy(both_tenants(ctx), destroy, %{}, bulk_opts(strategy))
              {returned(result), stored_notes(ctx)}
            end,
            opts(@bulk)
          )
        ]
      end

    # Records from a read across tenants carry no tenant of their own.
    global = [
      new(
        "adv.foreign.bulk_update.stream_global_records",
        :adversarial,
        {[101], Model.notes_after(&update_101/1)},
        fn ctx ->
          records =
            note(ctx)
            |> Ash.Query.for_read(:global, %{}, authorize?: false)
            |> Ash.Query.filter(id in [101, 201])
            |> Ash.read!()

          result = Ash.bulk_update(records, :update, %{body: "x"}, bulk_opts(:stream))
          {returned(result), stored_notes(ctx)}
        end,
        opts(@bulk)
      )
    ]

    singles ++ List.flatten(bulk) ++ global
  end

  defp both_tenants(ctx),
    do: [
      Ash.get!(note(ctx), 101, tenant: 1, authorize?: false),
      Ash.get!(note(ctx), 201, tenant: 2, authorize?: false)
    ]

  defp bulk_opts(strategy),
    do: [
      tenant: 1,
      strategy: strategy,
      return_records?: true,
      return_errors?: true,
      authorize?: Ash.Conformance.Variant.authorize?()
    ]

  defp update_101({101, org, local, _body, list}), do: {101, org, local, "x", list}
  defp update_101(row), do: row
  defp destroy_101({101, _, _, _, _}), do: nil
  defp destroy_101(row), do: row

  # Upserts in organisation 1 whose identity values organisation 2 also has.

  defp upserts do
    local = %{id: 104, local_id: 4, code: "n1-4", body: "mine", value: 4}
    skipped = %{id: 105, local_id: 1, code: "n1-1x", body: "again", value: 1}
    global = %{id: 106, local_id: 6, code: "n2-1", body: "mine", value: 6}

    inserted = Enum.sort(Model.notes() ++ [{104, 1, 4, "mine", nil}])
    upsert = [upsert?: true, upsert_identity: :local_id, upsert_fields: [:body]]

    skip = [
      upsert_condition: Ash.Expr.expr(upsert_conflict(:value) > 100),
      return_skipped_upsert?: true
    ]

    by_code = [upsert?: true, upsert_identity: :code, upsert_fields: [:body]]

    [
      new(
        "adv.upsert.cross_tenant",
        :adversarial,
        {{104, 1, 4, "mine"}, inserted},
        fn ctx -> {single_upsert(ctx, local, upsert), stored_notes(ctx)} end,
        opts(@upserts)
      ),
      new(
        "adv.upsert.cross_tenant_bulk",
        :adversarial,
        {[{104, 1, 4, "mine"}], inserted},
        fn ctx -> {bulk_upsert(ctx, local, upsert), stored_notes(ctx)} end,
        opts(@upserts)
      ),
      new(
        "adv.upsert.skipped",
        :adversarial,
        {{101, 1, 1, "a1"}, Model.notes()},
        fn ctx -> {single_upsert(ctx, skipped, upsert ++ skip), stored_notes(ctx)} end,
        opts(@upserts)
      ),
      new(
        "adv.upsert.skipped_bulk",
        :adversarial,
        {[{101, 1, 1, "a1"}], Model.notes()},
        fn ctx -> {bulk_upsert(ctx, skipped, upsert ++ skip), stored_notes(ctx)} end,
        opts(@upserts)
      ),
      # Whether an upsert in one tenant may update or return another tenant's
      # row through an all-tenants identity is undecided (`all-tenants-upsert`).
      new(
        "adv.upsert.all_tenants",
        :adversarial,
        :unresolved,
        fn ctx -> {single_upsert(ctx, global, by_code), stored_notes(ctx)} end,
        opts(@upserts)
      ),
      new(
        "adv.upsert.all_tenants_skipped_bulk",
        :adversarial,
        :unresolved,
        fn ctx -> {bulk_upsert(ctx, global, by_code ++ skip), stored_notes(ctx)} end,
        opts(@upserts)
      )
    ]
  end

  # Through a changeset: `Ash.create/3` doesn't pass `upsert_condition` on.
  defp single_upsert(ctx, attributes, upsert) do
    note(ctx)
    |> Ash.Changeset.for_create(:create, attributes, [tenant: 1] ++ upsert)
    |> Ash.create(authorize?: Ash.Conformance.Variant.authorize?())
    |> case do
      {:ok, note} -> {note.id, note.org_id, note.local_id, note.body}
      {:error, _} -> :refused
    end
  end

  defp bulk_upsert(ctx, attributes, upsert) do
    Ash.bulk_create(
      [attributes],
      note(ctx),
      :create,
      [
        tenant: 1,
        return_records?: true,
        return_errors?: true,
        authorize?: Ash.Conformance.Variant.authorize?()
      ] ++ upsert
    )
    |> case do
      %{records: records} when is_list(records) and records != [] ->
        Enum.map(records, &{&1.id, &1.org_id, &1.local_id, &1.body})

      %{errors: [_ | _]} ->
        :refused

      _ ->
        []
    end
  end

  # Field policies on write results: a non-admin actor may read no secret,
  # SSN or card number, nor the order count.

  defp field_writes do
    hidden = %{
      secret: :forbidden,
      ssn: :forbidden,
      cards: [:forbidden, :forbidden],
      payment: :forbidden
    }

    loaded = Map.put(hidden, :order_count, :forbidden)
    new_person = hd(Model.person_rows()) |> Map.put(:id, 3)
    actor = [actor: @actor, authorize?: true]

    singles = [
      {"read_control", loaded,
       fn ctx ->
         person(ctx)
         |> Ash.Query.filter(id == 1)
         |> Ash.Query.load(:order_count)
         |> Ash.read_one!(actor)
       end},
      {"create", hidden, fn ctx -> Ash.create!(person(ctx), new_person, actor) end},
      {"update", hidden,
       fn ctx -> ctx |> first_person() |> Ash.update!(%{name: "changed"}, actor) end},
      {"update_load", loaded,
       fn ctx ->
         ctx |> first_person() |> Ash.update!(%{name: "changed"}, [load: [:order_count]] ++ actor)
       end},
      {"destroy", hidden,
       fn ctx -> ctx |> first_person() |> Ash.destroy!([return_destroyed?: true] ++ actor) end},
      {"bulk_create", hidden,
       fn ctx ->
         [new_person]
         |> Ash.bulk_create!(person(ctx), :create, [return_records?: true] ++ actor)
         |> Map.fetch!(:records)
         |> hd()
       end}
    ]

    single_scenarios =
      for {name, expected, run} <- singles do
        new(
          "adv.field_write.#{name}",
          :adversarial,
          expected,
          fn ctx -> ctx |> run.() |> fields() end,
          opts(@policies)
        )
      end

    bulk_scenarios =
      for {kind, strategy} <- [
            update: :atomic,
            update: :atomic_batches,
            update: :stream,
            destroy: :atomic,
            destroy: :stream
          ] do
        new(
          "adv.field_write.bulk_#{kind}.#{strategy}",
          :adversarial,
          loaded,
          fn ctx ->
            query = person(ctx) |> Ash.Query.filter(id == 1) |> Ash.Query.load(:order_count)

            opts =
              [strategy: strategy, return_records?: true, allow_stream_with: :full_read] ++ actor

            result =
              if kind == :update,
                do: Ash.bulk_update!(query, :update, %{name: "changed"}, opts),
                else: Ash.bulk_destroy!(query, :destroy, %{}, opts)

            result.records |> hd() |> fields()
          end,
          opts(@policies)
        )
      end

    single_scenarios ++ bulk_scenarios
  end

  defp first_person(ctx), do: Ash.get!(person(ctx), 1, authorize?: false)

  # Each admin-only value, or `:forbidden`; an unloaded aggregate is left out.
  defp fields(person) do
    base = %{
      secret: field(person.secret),
      ssn: nested(person.profile, & &1.ssn),
      cards: nested(person.cards, fn cards -> Enum.map(cards, &field(&1.number)) end),
      payment: nested(person.payment, &nested(&1.value, fn card -> card.number end))
    }

    case person.order_count do
      %Ash.NotLoaded{} -> base
      count -> Map.put(base, :order_count, field(count))
    end
  end

  defp nested(%Ash.ForbiddenField{}, _fun), do: :forbidden
  defp nested(nil, _fun), do: nil
  defp nested(value, fun), do: field(fun.(value))

  defp field(%Ash.ForbiddenField{}), do: :forbidden
  defp field(value), do: value

  # manage_relationship given another tenant's or a hidden record.

  defp manage do
    attach = fn ctx, list_role, note_ids, opts ->
      ctx.adapter.resource(list_role)
      |> Ash.get!(1, tenant: 1, authorize?: false)
      |> Ash.Changeset.for_update(:attach, %{note_ids: note_ids}, [tenant: 1] ++ opts)
      |> Ash.update()
      |> status()
    end

    plain = [authorize?: Ash.Conformance.Variant.authorize?()]

    [
      new(
        "adv.manage.own_tenant",
        :adversarial,
        {:ok, Model.notes_after(&relate(&1, 102))},
        fn ctx -> {attach.(ctx, :adv_list, [102], plain), stored_notes(ctx)} end,
        opts(@manage)
      ),
      new(
        "adv.manage.foreign_tenant",
        :adversarial,
        {:refused, Model.notes()},
        fn ctx -> {attach.(ctx, :adv_list, [201], plain), stored_notes(ctx)} end,
        opts(@manage)
      ),
      new(
        "adv.manage.hidden",
        :adversarial,
        {:refused, Model.notes()},
        fn ctx ->
          {attach.(ctx, :adv_secure_list, [103], actor: @actor, authorize?: true),
           stored_notes(ctx)}
        end,
        opts(@manage)
      ),
      # Replacing event 1's buyers in organisation 1 leaves organisation 2's
      # orders alone, even where they name the same event.
      new(
        "adv.manage.m2m_replace",
        :adversarial,
        {:ok, Model.order_links() -- [{1, 1, 3}]},
        fn ctx ->
          status =
            ctx.adapter.resource(:adv_event)
            |> Ash.get!(1, authorize?: false)
            |> Ash.Changeset.for_update(:set_buyers, %{customer_ids: [1]},
              tenant: 1,
              authorize?: Ash.Conformance.Variant.authorize?()
            )
            |> Ash.update()
            |> status()

          {status, stored_orders(ctx)}
        end,
        opts(@manage)
      )
    ]
  end

  defp relate({102, org, local, body, _list}, 102), do: {102, org, local, body, 1}
  defp relate(row, _id), do: row

  # Reads and projections

  defp event(ctx, role), do: ctx.adapter.resource(role)

  defp through(ctx, role) do
    {module, _warned?} = Model.through(ctx.adapter, role)
    module
  end

  defp note(ctx), do: ctx.adapter.resource(:adv_note)
  defp person(ctx), do: ctx.adapter.resource(:adv_person)

  defp customer_query(ctx), do: ctx.adapter.resource(:adv_customer)

  defp by_name(ctx, limit, offset \\ 0) do
    customer_query(ctx)
    |> Ash.Query.sort(name: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.Query.offset(offset)
  end

  defp read_opts(opts),
    do: Keyword.put_new(opts, :authorize?, Ash.Conformance.Variant.authorize?())

  defp loads(resource_or_query, load, opts) do
    {name, _query} = load_name(load)

    resource_or_query
    |> Ash.Query.sort(:id)
    |> Ash.Query.load([load])
    |> Ash.read!(read_opts(opts))
    |> Map.new(fn event -> {event.id, event |> Map.fetch!(name) |> ids()} end)
  end

  defp load_name({name, query}), do: {name, query}
  defp load_name(name), do: {name, nil}

  # A to-one load for each event, as the customer's id or nil.
  defp one(resource, load, opts) do
    {name, _query} = load_name(load)

    resource
    |> Ash.Query.sort(:id)
    |> Ash.Query.load([load])
    |> Ash.read!(read_opts(opts))
    |> Map.new(fn event -> {event.id, event |> Map.fetch!(name) |> id()} end)
  end

  # Whether an unsorted has_one is one of the event's own customers.
  defp member(resource, scope, opts) do
    related = Model.loads(scope)

    resource
    |> one(:a_customer, opts)
    |> Map.new(fn {event, id} -> {event, if(id, do: id in Map.fetch!(related, event))} end)
  end

  # One event loaded alone, as a `get` does, with a bounded load.
  defp page(ctx, resource, relationship, limit, offset, opts) do
    resource
    |> Ash.Query.filter(id == 1)
    |> Ash.Query.load([{relationship, by_name(ctx, limit, offset)}])
    |> Ash.read_one!(read_opts(opts))
    |> Map.fetch!(relationship)
    |> Enum.map(& &1.id)
  end

  defp aggregates(resource, names, opts) do
    resource
    |> Ash.Query.sort(:id)
    |> Ash.Query.load(names)
    |> Ash.read!(read_opts(opts))
    |> Map.new(fn event ->
      {event.id, names |> Enum.map(&Map.fetch!(event, &1)) |> List.to_tuple()}
    end)
  end

  defp exists_aggregate(ctx, resource, path, opts) do
    resource
    |> Ash.Query.aggregate(:has_cara, :exists, path,
      query: Ash.Query.filter(customer_query(ctx), id == 3)
    )
    |> Ash.Query.sort(:id)
    |> Ash.read!(read_opts(opts))
    |> Map.new(&{&1.id, &1.aggregates.has_cara})
  end

  defp events(resource, expression, opts) do
    resource
    |> Ash.Query.do_filter(expression)
    |> Ash.Query.sort(:id)
    |> Ash.read!(read_opts(opts))
    |> Enum.map(& &1.id)
  end

  defp input(resource, filter, opts) do
    resource
    |> Ash.Query.filter_input(filter)
    |> Ash.Query.sort(:id)
    |> Ash.read!(read_opts(opts))
    |> Enum.map(& &1.id)
  end

  defp ids(records), do: records |> List.wrap() |> Enum.map(& &1.id) |> Enum.sort()
  defp id(nil), do: nil
  defp id(record), do: record.id

  # What is stored, across tenants and without authorization. The decoy
  # variant's own rows are stored on purpose, so they are left out; a decoy
  # that a write returns still shows in the result.
  defp stored_notes(ctx) do
    note(ctx)
    |> Ash.Query.for_read(:global, %{}, authorize?: false)
    |> Ash.Query.sort(:id)
    |> Ash.read!()
    |> Enum.reject(&Ash.Conformance.Decoy.reserved?(&1.id))
    |> Enum.map(&{&1.id, &1.org_id, &1.local_id, &1.body, &1.list_id})
  end

  defp stored_orders(ctx) do
    ctx.adapter.resource(:adv_order)
    |> Ash.Query.for_read(:global, %{}, authorize?: false)
    |> Ash.read!()
    |> Enum.reject(&Ash.Conformance.Decoy.reserved?(&1.id))
    |> Enum.map(&{&1.org_id, &1.event_id, &1.customer_id})
    |> Enum.sort()
  end

  defp returned(%Ash.BulkResult{records: records}) when is_list(records),
    do: records |> Enum.map(& &1.id) |> Enum.sort()

  defp returned(%Ash.BulkResult{}), do: []

  defp status(:ok), do: :ok
  defp status({:ok, _}), do: :ok
  defp status({:error, _}), do: :refused
end
