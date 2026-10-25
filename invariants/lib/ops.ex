# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Invariants.Op do
  @moduledoc """
  One operation, run as an actor in one organisation.

  - `group`: operations in a group ask the same question, so they must give
    the same answer.
  - `shapes`: the shapes it runs under; `:tenant` alone for operations on
    notes, lists and people.
  - `kind`: `:read` runs as each organisation in turn; `:write` as
    organisation 1, once per database.
  - `isolation?`: false where the intended answer depends on rows the actor
    can't see, such as a write given another organisation's record.
  - `refusable?`: client input, which may also be refused with an
    `Ash.Error.Invalid` instead of answering.
  - `needs`: data-layer features it needs, such as `:through`.
  - `run`: `fn ctx -> answer end`; see `Ash.Invariants.Ops`.
  """
  @enforce_keys [:id, :group, :run]
  defstruct [
    :id,
    :group,
    :run,
    shapes: [:tenant],
    kind: :read,
    isolation?: true,
    refusable?: false,
    needs: []
  ]
end

defmodule Ash.Invariants.Ops do
  @moduledoc """
  Every operation, and each group's intended answer from the fixture
  (`Ash.Invariants.World`).

  An operation gets a context with the layer, the shape, the organisation
  (`org`), the tenant to pass (`tenant`) and `role.(name)`, the resource for a
  role under the layer. It returns a plain term: ids, counts, or what was
  returned and stored.
  """
  alias Ash.Invariants.{Op, World}
  require Ash.Query
  require Ash.Expr
  # An inline aggregate's `filter:` in an expression is an `expr/1` of its own.
  import Ash.Expr, only: [expr: 1]

  @shapes [:tenant, :secure, :schema]
  @actor %{id: 1, admin: false}

  def all do
    reads() ++
      calculations() ++
      client_input() ++
      pages() ++ event_writes() ++ note_writes() ++ upserts() ++ manage() ++ fields()
  end

  # Reads over events, under every shape

  defp reads do
    [
      # Each event's customers, six ways.
      read("load.m2m", :customers, &loads(&1, :buyers)),
      read("load.through", :customers, &loads(&1, :customers), [:through]),
      read("load.through_long", :customers, &loads(&1, :customers_via_event), [:through]),
      read("load.through_buyers", :customers, &loads(&1, :customers_via_buyers), [:through]),
      read("load.path", :customers, &path_loads/1),
      read("agg.list_m2m", :customers, &aggregate(&1, :buyer_ids)),
      read("agg.list_through", :customers, &aggregate(&1, :customer_ids), [:through]),
      read("agg.list_path", :customers, &aggregate(&1, :path_ids)),
      # How many.
      read("agg.count_m2m", :count, &aggregate(&1, :buyer_count)),
      read("agg.count_through", :count, &aggregate(&1, :customer_count), [:through]),
      read("agg.count_path", :count, &aggregate(&1, :path_count)),
      read("load.count_m2m", :count, &(&1 |> loads(:buyers) |> counts())),
      # The first by name, descending.
      read("load.has_one_through", :first, &first_customer/1, [:through]),
      read("agg.first_m2m", :first, &aggregate(&1, :top_buyer)),
      read("agg.first_through", :first, &aggregate(&1, :top_customer), [:through]),
      read("agg.first_path", :first, &aggregate(&1, :top_path)),
      read("load.m2m_limit_one", :first, &(&1 |> each_alone(:buyers, 0) |> firsts())),
      read("load.through_limit_one", :first, &(&1 |> each_alone(:customers, 0) |> firsts()), [
        :through
      ]),
      read("load.m2m_limit_one_together", :first, &(&1 |> together(:buyers, 0) |> firsts())),
      # The second by name, descending.
      read("load.m2m_offset_one", :second, &(&1 |> each_alone(:buyers, 1) |> firsts())),
      read("load.through_offset_one", :second, &(&1 |> each_alone(:customers, 1) |> firsts()), [
        :through
      ]),
      read("load.m2m_offset_one_together", :second, &(&1 |> together(:buyers, 1) |> firsts())),
      # The events that reach Cara (3), whose only order is hidden. Filters
      # an application writes are not authorized, so they only check tenancy.
      tenancy(
        read("filter.exists_m2m", :reach, &events(&1, Ash.Expr.expr(exists(buyers, id == 3))))
      ),
      tenancy(
        read(
          "filter.exists_through",
          :reach,
          &events(&1, Ash.Expr.expr(exists(customers, id == 3))),
          [
            :through
          ]
        )
      ),
      tenancy(
        read(
          "filter.exists_path",
          :reach,
          &events(&1, Ash.Expr.expr(exists(orders, customer_id == 3)))
        )
      ),
      tenancy(read("filter.path_m2m", :reach, &events(&1, Ash.Expr.expr(buyers.id == 3)))),
      tenancy(
        read("filter.path_orders", :reach, &events(&1, Ash.Expr.expr(orders.customer.id == 3)))
      ),
      read("filter.input_m2m", :reach, &input(&1, %{buyers: %{id: %{eq: 3}}})),
      read("filter.input_path", :reach, &input(&1, %{orders: %{customer: %{id: %{eq: 3}}}})),
      read("agg.exists_m2m", :reach, &reaches(&1, :exists, :buyers)),
      read("agg.exists_through", :reach, &reaches(&1, :exists, :customers), [:through]),
      read("agg.count_filtered_m2m", :reach, &reaches(&1, :count, :buyers)),
      # The events with exactly one customer.
      read("filter.count_m2m", :single, &events(&1, Ash.Expr.expr(buyer_count == 1))),
      read("filter.count_through", :single, &events(&1, Ash.Expr.expr(customer_count == 1)), [
        :through
      ]),
      read("filter.count_path", :single, &events(&1, Ash.Expr.expr(path_count == 1))),
      # Every order the actor may see, counted per event and summed.
      read("total.root_aggregate", :total, &Ash.sum!(event(&1), :order_count, opts(&1))),
      read("total.loaded", :total, &(&1 |> aggregate(:order_count) |> Map.values() |> Enum.sum()))
    ]
  end

  defp read(id, group, run, needs \\ []),
    do: %Op{id: id, group: group, run: run, shapes: @shapes, needs: needs}

  defp tenancy(op), do: %{op | shapes: [:tenant, :schema]}

  # Aggregates referenced in calculations and in client input. Calculations
  # don't authorize their dependencies, but aggregates referenced anywhere do.

  defp calculations do
    at_least = fn filter -> fn ctx -> Map.new(0..4, &{&1, filter.(ctx, &1)}) end end

    Enum.map(
      [
        read("agg.order_count", :order_counts, &aggregate(&1, :order_count)),
        read("calc.order_total", :order_counts, &aggregate(&1, :order_total)),
        read("calc.inline_count", :order_counts, &aggregate(&1, :inline_count)),
        read(
          "input.order_count",
          :order_thresholds,
          at_least.(&input(&1, %{order_count: %{greater_than_or_equal: &2}}))
        ),
        read(
          "input.order_total",
          :order_thresholds,
          at_least.(&input(&1, %{order_total: %{greater_than_or_equal: &2}}))
        ),
        read(
          "input.inline_count",
          :order_thresholds,
          at_least.(fn ctx, n -> input(ctx, Ash.Expr.expr(count(orders) >= ^n)) end)
        ),
        read(
          "input.inline_count_unauthorized",
          :order_thresholds,
          at_least.(fn ctx, n ->
            input(ctx, Ash.Expr.expr(count(orders, authorize?: false) >= ^n))
          end)
        ),
        read(
          "filter.order_total",
          :order_thresholds,
          at_least.(fn ctx, n -> events(ctx, Ash.Expr.expr(order_total >= ^n)) end)
        ),
        read(
          "filter.inline_count",
          :order_thresholds,
          at_least.(fn ctx, n -> events(ctx, Ash.Expr.expr(inline_count >= ^n)) end)
        )
      ],
      &if(String.starts_with?(&1.id, "input."), do: %{&1 | refusable?: true}, else: &1)
    )
  end

  # Client filters and sorts over a person's admin-only `secret`. The policies
  # guide: a field the actor can't see is `nil` in client input, so no filter
  # on it matches and no sort on it orders. Person 1's secret is the value
  # matched against.

  defp client_input do
    value = World.person(1).secret
    filter = fn input -> &Ash.Query.filter_input(&1, input) end
    sort = fn input -> &Ash.Query.sort_input(&1, input) end

    [
      person("input.filter_hidden", :match_hidden, filter.(%{secret: %{eq: value}})),
      person("input.filter_hidden_expr", :match_hidden, filter.(Ash.Expr.expr(secret == ^value))),
      person(
        "input.calculation_argument",
        :match_hidden,
        filter.(Ash.Expr.expr(echo(value: secret) == ^value))
      ),
      person(
        "input.exists_parent",
        :match_hidden,
        filter.(Ash.Expr.expr(exists(orders, parent(secret) == ^value)))
      ),
      person(
        "input.inline_aggregate_parent",
        :match_hidden,
        filter.(Ash.Expr.expr(count(orders, filter: expr(parent(secret) == ^value)) > 0))
      ),
      person("input.sort_hidden", :hidden_order, sort.(secret: :desc, id: :asc)),
      person(
        "input.sort_calculation_argument",
        :hidden_order,
        sort.(echo: {%{value: Ash.Expr.expr(secret)}, :desc}, id: :asc)
      ),
      person("input.sort_hidden_aggregate", :hidden_order, sort.(order_count: :asc, id: :asc))
    ]
  end

  defp person(id, group, build) do
    run = fn ctx ->
      ctx.role.(Person) |> build.() |> Ash.read!(opts(ctx)) |> Enum.map(& &1.id)
    end

    %Op{id: id, group: group, run: run, refusable?: true}
  end

  # Keyset and offset pagination: every page together is the unpaged read,
  # and a cursor holds only what the actor may see.

  defp pages do
    hidden_sort = &(&1.role.(Person) |> Ash.Query.sort_input(secret: :desc, id: :asc))
    notes = &(&1.role.(SecureNote) |> Ash.Query.sort(:id))
    # A cursor a client wrote: the people whose secret sorts after "SECRET-m".
    probe = Base.encode64(:erlang.term_to_binary(["SECRET-m", 0]))

    [
      %Op{
        id: "page.keyset_hidden_sort",
        refusable?: true,
        group: :hidden_order,
        run: &(&1 |> hidden_sort.() |> keyset_pages(opts(&1)) |> Enum.map(fn p -> p.id end))
      },
      %Op{
        id: "page.keyset_hidden_cursor",
        refusable?: true,
        group: :hidden_cursor,
        run: &(&1 |> hidden_sort.() |> keyset_pages(opts(&1)) |> Enum.map(fn p -> cursor(p) end))
      },
      %Op{
        id: "page.keyset_probe",
        refusable?: true,
        group: :hidden_probe,
        run: fn ctx ->
          ctx.role.(Person)
          |> Ash.Query.sort_input(secret: :asc, id: :asc)
          |> Ash.read!([action: :paged, page: [limit: 5, after: probe]] ++ opts(ctx))
          |> Map.fetch!(:results)
          |> Enum.map(& &1.id)
        end
      },
      %Op{
        id: "page.notes",
        group: :visible_notes,
        shapes: [:secure],
        run: &(&1 |> notes.() |> Ash.read!(opts(&1)) |> Enum.map(fn n -> n.id end))
      },
      %Op{
        id: "page.notes_keyset",
        group: :visible_notes,
        shapes: [:secure],
        run: &(&1 |> notes.() |> keyset_pages(opts(&1)) |> Enum.map(fn n -> n.id end))
      },
      %Op{
        id: "page.notes_offset",
        group: :visible_notes,
        shapes: [:secure],
        run: &(&1 |> notes.() |> offset_pages(opts(&1)) |> Enum.map(fn n -> n.id end))
      }
    ]
  end

  # Every record, one keyset page of one record at a time.
  defp keyset_pages(query, opts, page \\ [], acc \\ []) do
    %{results: results, more?: more?} =
      Ash.read!(query, [action: :paged, page: [limit: 1] ++ page] ++ opts)

    acc = acc ++ results

    if more? and results != [],
      do: keyset_pages(query, opts, [after: List.last(results).__metadata__.keyset], acc),
      else: acc
  end

  defp offset_pages(query, opts, offset \\ 0, acc \\ []) do
    %{results: results, more?: more?} =
      Ash.read!(query, [action: :paged, page: [limit: 1, offset: offset]] ++ opts)

    if more?, do: offset_pages(query, opts, offset + 1, acc ++ results), else: acc ++ results
  end

  # A keyset decoded to the sort values it carries.
  defp cursor(record) do
    keyset = record.__metadata__.keyset

    with {:ok, binary} <- Base.decode64(keyset),
         {:ok, values} <- safe_term(binary) do
      values
    else
      _ -> keyset
    end
  end

  defp safe_term(binary) do
    {:ok, :erlang.binary_to_term(binary, [:safe])}
  rescue
    ArgumentError -> :error
  end

  # Writes to events: an aggregate referenced in an atomic update, and a
  # `many_to_many` replaced in one organisation.

  defp event_writes do
    record = fn strategy ->
      fn ctx ->
        query = Ash.Query.sort(event(ctx), :id)

        if strategy == :single do
          for event <- Ash.read!(query, opts(ctx)),
              do: Ash.update!(event, %{}, [action: :record_count] ++ opts(ctx))
        else
          Ash.bulk_update!(query, :record_count, %{}, [strategy: strategy] ++ opts(ctx))
        end

        ctx |> event() |> Ash.read!(authorize?: false) |> Map.new(&{&1.id, &1.recorded})
      end
    end

    replace = fn ctx ->
      result =
        ctx
        |> event()
        |> Ash.get!(1, authorize?: false)
        |> Ash.Changeset.for_update(:set_buyers, %{customer_ids: [1]}, opts(ctx))
        |> Ash.update()
        |> status()

      {result, orders(ctx)}
    end

    [
      %Op{
        id: "write.record_count",
        group: :recorded,
        shapes: @shapes,
        kind: :write,
        run: record.(:single)
      },
      %Op{
        id: "write.record_count_atomic",
        group: :recorded,
        shapes: @shapes,
        kind: :write,
        run: record.(:atomic)
      },
      %Op{
        id: "write.record_count_stream",
        group: :recorded,
        shapes: @shapes,
        kind: :write,
        run: record.(:stream)
      },
      %Op{
        id: "write.set_buyers",
        group: :set_buyers,
        shapes: [:tenant, :schema],
        kind: :write,
        run: replace
      }
    ]
  end

  # Writes given organisation 2's notes while acting for organisation 1.

  defp note_writes do
    singles =
      for {id, write} <- [
            {"foreign.update", &Ash.update(&1, %{body: "x"}, tenant: 1)},
            {"foreign.update_changeset",
             &(&1 |> Ash.Changeset.for_update(:update, %{body: "x"}, tenant: 1) |> Ash.update())},
            {"foreign.destroy", &Ash.destroy(&1, tenant: 1)},
            {"foreign.destroy_changeset",
             &(&1 |> Ash.Changeset.for_destroy(:destroy, %{}, tenant: 1) |> Ash.destroy())}
          ] do
        foreign(id, :foreign, fn ctx -> {status(write.(foreign_note(ctx))), notes(ctx)} end)
      end

    bulk =
      for {name, update, destroy, strategy} <- [
            {"atomic", :update, :destroy, :atomic},
            {"atomic_batches", :update, :destroy, :atomic_batches},
            {"stream", :update, :destroy, :stream},
            {"fallback", :edit, :remove, [:atomic, :stream]}
          ] do
        bulk = [tenant: 1, strategy: strategy, return_records?: true, return_errors?: true]

        [
          foreign("foreign.bulk_update.#{name}", :bulk_update, fn ctx ->
            result = Ash.bulk_update(both_notes(ctx), update, %{body: "x"}, bulk)
            {returned(result), notes(ctx)}
          end),
          foreign("foreign.bulk_destroy.#{name}", :bulk_destroy, fn ctx ->
            result = Ash.bulk_destroy(both_notes(ctx), destroy, %{}, bulk)
            {returned(result), notes(ctx)}
          end)
        ]
      end

    # Records read across organisations carry no tenant of their own.
    global =
      foreign("foreign.bulk_update.global_records", :bulk_update, fn ctx ->
        records =
          ctx.role.(Note)
          |> Ash.Query.for_read(:global, %{}, authorize?: false)
          |> Ash.Query.filter(id in [101, 201])
          |> Ash.read!()

        bulk = [tenant: 1, strategy: :stream, return_records?: true, return_errors?: true]
        {returned(Ash.bulk_update(records, :update, %{body: "x"}, bulk)), notes(ctx)}
      end)

    singles ++ List.flatten(bulk) ++ [global]
  end

  defp foreign(id, group, run),
    do: %Op{id: id, group: group, kind: :write, isolation?: false, run: run}

  defp foreign_note(ctx), do: Ash.get!(ctx.role.(Note), 201, tenant: 2, authorize?: false)

  defp both_notes(ctx),
    do: [Ash.get!(ctx.role.(Note), 101, tenant: 1, authorize?: false), foreign_note(ctx)]

  # Upserts in organisation 1 whose identity values organisation 2 also has.

  defp upserts do
    by_local = [upsert?: true, upsert_identity: :local_id, upsert_fields: [:body]]
    insert = %{id: 104, local_id: 4, body: "mine", value: 4}

    skip = [
      upsert_condition: Ash.Expr.expr(upsert_conflict(:value) > 100),
      return_skipped_upsert?: true
    ]

    skipped = %{id: 105, local_id: 1, body: "again", value: 1}
    # The primary key of organisation 2's note 201, with no identity: the
    # upsert's conflict target is the primary key.
    by_key = [upsert?: true, upsert_fields: [:body]]
    taken = %{id: 201, local_id: 9, body: "mine", value: 9}

    [
      upsert("upsert.insert", :upsert_insert, &upsert_changeset(&1, insert, by_local)),
      upsert("upsert.insert_bulk", :upsert_insert, &upsert_bulk(&1, insert, by_local)),
      upsert("upsert.skipped", :upsert_skipped, &upsert_changeset(&1, skipped, by_local ++ skip)),
      upsert(
        "upsert.skipped_create",
        :upsert_skipped,
        &upsert_create(&1, skipped, by_local ++ skip)
      ),
      upsert("upsert.skipped_bulk", :upsert_skipped, &upsert_bulk(&1, skipped, by_local ++ skip)),
      %{
        upsert("upsert.primary_key", :upsert_key, &upsert_changeset(&1, taken, by_key))
        | isolation?: false
      },
      %{
        upsert("upsert.primary_key_bulk", :upsert_key, &upsert_bulk(&1, taken, by_key))
        | isolation?: false
      }
    ]
  end

  defp upsert(id, group, run), do: %Op{id: id, group: group, kind: :write, run: run}

  defp upsert_changeset(ctx, attributes, upsert) do
    ctx.role.(Note)
    |> Ash.Changeset.for_create(:create, attributes, [tenant: 1] ++ upsert)
    |> Ash.create()
    |> upserted(ctx)
  end

  defp upsert_create(ctx, attributes, upsert),
    do: ctx.role.(Note) |> Ash.create(attributes, [tenant: 1] ++ upsert) |> upserted(ctx)

  defp upserted({:ok, note}, ctx), do: {[note_row(note)], notes(ctx)}
  defp upserted({:error, _}, ctx), do: {:refused, notes(ctx)}

  defp upsert_bulk(ctx, attributes, upsert) do
    opts = [tenant: 1, return_records?: true, return_errors?: true] ++ upsert

    case Ash.bulk_create([attributes], ctx.role.(Note), :create, opts) do
      %{errors: [_ | _]} -> {:refused, notes(ctx)}
      %{records: records} -> {Enum.map(records || [], &note_row/1), notes(ctx)}
    end
  end

  # manage_relationship given another organisation's note, or a hidden one.

  defp manage do
    attach = fn list, ids ->
      fn ctx ->
        result =
          ctx.role.(list)
          |> Ash.get!(1, tenant: 1, authorize?: false)
          |> Ash.Changeset.for_update(:attach, %{note_ids: ids}, opts(ctx))
          |> Ash.update()
          |> status()

        {result, notes(ctx)}
      end
    end

    [
      %Op{id: "manage.own", group: :manage_own, kind: :write, run: attach.(List, [102])},
      %Op{id: "manage.foreign", group: :manage_refused, kind: :write, run: attach.(List, [201])},
      %Op{
        id: "manage.hidden",
        group: :manage_refused,
        shapes: [:secure],
        kind: :write,
        run: attach.(SecureList, [103])
      }
    ]
  end

  # Write results under field policies: the actor may read no `SECRET` value
  # and no order count, from any action.

  defp fields do
    load = [load: [:order_count]]
    person = fn ctx -> Ash.get!(ctx.role.(Person), 1, authorize?: false) end

    query = fn ctx ->
      ctx.role.(Person) |> Ash.Query.filter(id == 1) |> Ash.Query.load(:order_count)
    end

    new = World.person(3) |> Map.update!(:payment, & &1.value)

    bulk = fn strategy ->
      [strategy: strategy, return_records?: true, allow_stream_with: :full_read]
    end

    writes = [
      {"fields.read", fn ctx -> ctx |> query.() |> Ash.read_one!(opts(ctx)) end},
      {"fields.create", fn ctx -> Ash.create!(ctx.role.(Person), new, load ++ opts(ctx)) end},
      {"fields.update",
       fn ctx -> ctx |> person.() |> Ash.update!(%{name: "x"}, load ++ opts(ctx)) end},
      {"fields.destroy",
       fn ctx ->
         ctx |> person.() |> Ash.destroy!([return_destroyed?: true] ++ load ++ opts(ctx))
       end},
      {"fields.bulk_create",
       fn ctx ->
         [new]
         |> Ash.bulk_create!(
           ctx.role.(Person),
           :create,
           [return_records?: true] ++ load ++ opts(ctx)
         )
         |> Map.fetch!(:records)
         |> hd()
       end}
    ]

    bulks =
      for {kind, strategy} <- [
            update: :atomic,
            update: :atomic_batches,
            update: :stream,
            destroy: :atomic,
            destroy: :stream
          ] do
        {"fields.bulk_#{kind}.#{strategy}",
         fn ctx ->
           opts = bulk.(strategy) ++ opts(ctx)

           result =
             if kind == :update,
               do: Ash.bulk_update!(query.(ctx), :update, %{name: "x"}, opts),
               else: Ash.bulk_destroy!(query.(ctx), :destroy, %{}, opts)

           hd(result.records)
         end}
      end

    for {id, write} <- writes ++ bulks do
      kind = if id == "fields.read", do: :read, else: :write
      %Op{id: id, group: :person_fields, kind: kind, run: &(&1 |> write.() |> person_fields())}
    end
  end

  # Each admin-only value as the result shows it, or `:forbidden`.
  defp person_fields(person) do
    %{
      secret: field(person.secret),
      ssn: nested(person.profile, & &1.ssn),
      cards: nested(person.cards, fn cards -> Enum.map(cards, &field(&1.number)) end),
      payment: nested(person.payment, &nested(&1.value, fn card -> card.number end)),
      order_count: field(person.order_count)
    }
  end

  defp nested(%Ash.ForbiddenField{}, _fun), do: :forbidden
  defp nested(nil, _fun), do: nil
  defp nested(value, fun), do: field(fun.(value))

  defp field(%Ash.ForbiddenField{}), do: :forbidden
  defp field(%Ash.NotLoaded{}), do: :not_loaded
  defp field(value), do: value

  # Each group's intended answer for organisation `org` under a view.

  @doc "The intended answer of a group for a view, or nil where it has none."
  def expected(group, {shape, _org} = view) do
    orders = World.visible(view).orders
    customers = Map.new(for event <- 1..3, do: {event, related(orders, event)})

    case group do
      :customers ->
        customers

      :count ->
        Map.new(customers, fn {event, ids} -> {event, length(ids)} end)

      :first ->
        Map.new(customers, fn {event, ids} -> {event, ids |> by_name() |> Enum.at(0)} end)

      :second ->
        Map.new(customers, fn {event, ids} -> {event, ids |> by_name() |> Enum.at(1)} end)

      :reach ->
        for {event, ids} <- customers, 3 in ids, do: event

      :single ->
        for {event, ids} <- customers, length(ids) == 1, do: event

      :total ->
        length(orders)

      :recorded ->
        order_counts(orders)

      :order_counts ->
        order_counts(orders)

      :order_thresholds ->
        Map.new(0..4, &{&1, for({e, c} <- order_counts(orders), c >= &1, do: e)})

      :match_hidden ->
        []

      :hidden_order ->
        [1, 2]

      :visible_notes ->
        for(note <- World.visible(view).notes, do: note.id) |> Enum.sort()

      :set_buyers when shape != :secure ->
        {:ok, [{1, 1}, {2, 4}]}

      :foreign ->
        {:refused, notes_after(view, %{})}

      :bulk_update ->
        {[101], notes_after(view, %{101 => {:body, "x"}})}

      :bulk_destroy ->
        {[101], notes_after(view, %{101 => :destroy})}

      :upsert_insert ->
        {[{104, 1, 4, "mine"}], Enum.sort(notes_after(view, %{}) ++ [{104, 1, 4, "mine", nil}])}

      :upsert_skipped ->
        {[{101, 1, 1, "a1"}], notes_after(view, %{})}

      :manage_own ->
        {:ok, notes_after(view, %{102 => {:list_id, 1}})}

      :manage_refused ->
        {:refused, notes_after(view, %{})}

      :person_fields ->
        %{
          secret: :forbidden,
          ssn: :forbidden,
          cards: [:forbidden],
          payment: :forbidden,
          order_count: :forbidden
        }

      _ ->
        nil
    end
  end

  defp order_counts(orders),
    do: Map.new(1..3, fn event -> {event, Enum.count(orders, &(&1.event_id == event))} end)

  defp related(orders, event),
    do: for(%{event_id: ^event} = o <- orders, do: o.customer_id) |> Enum.uniq() |> Enum.sort()

  @names Map.new([{1, "Ann"}, {2, "Bob"}, {3, "Cara"}, {4, "Dan"}, {5, "Zed"}, {6, "Yan"}])
  defp by_name(ids), do: Enum.sort_by(ids, &Map.fetch!(@names, &1), :desc)

  # The stored notes a view may see after changes by id, as `notes/1` shows them.
  defp notes_after(view, changes) do
    for note <- World.rows().notes,
        World.visible?(view, :notes, note),
        Map.get(changes, note.id) != :destroy do
      row = {note.id, note.org_id, note.local_id, note.body, nil}

      case Map.get(changes, note.id) do
        {:body, body} -> put_elem(row, 3, body)
        {:list_id, list} -> put_elem(row, 4, list)
        nil -> row
      end
    end
  end

  # Reads and projections

  defp opts(ctx), do: [tenant: ctx.tenant, actor: @actor, authorize?: true]

  defp event(ctx), do: ctx.role.("#{Macro.camelize(to_string(ctx.shape))}Event")

  defp read_events(ctx, load) do
    ctx |> event() |> Ash.Query.sort(:id) |> Ash.Query.load(load) |> Ash.read!(opts(ctx))
  end

  defp loads(ctx, relationship) do
    ctx
    |> read_events([relationship])
    |> Map.new(&{&1.id, &1 |> Map.fetch!(relationship) |> ids()})
  end

  defp path_loads(ctx) do
    ctx
    |> read_events(orders: :customer)
    |> Map.new(fn event -> {event.id, event.orders |> Enum.map(& &1.customer) |> ids()} end)
  end

  defp first_customer(ctx) do
    ctx
    |> read_events([:first_customer])
    |> Map.new(&{&1.id, &1.first_customer && &1.first_customer.id})
  end

  defp aggregate(ctx, name),
    do: ctx |> read_events([name]) |> Map.new(&{&1.id, Map.fetch!(&1, name)})

  defp counts(loads), do: Map.new(loads, fn {event, ids} -> {event, length(ids)} end)

  defp by_name_query(ctx, offset) do
    ctx.role.(Customer)
    |> Ash.Query.sort(name: :desc)
    |> Ash.Query.limit(1)
    |> Ash.Query.offset(offset)
  end

  # Each event read on its own, as a `get` does, with a bounded load.
  defp each_alone(ctx, relationship, offset) do
    Map.new(1..3, fn id ->
      event =
        ctx
        |> event()
        |> Ash.Query.filter(id == ^id)
        |> Ash.Query.load([{relationship, by_name_query(ctx, offset)}])
        |> Ash.read_one!(opts(ctx))

      {id, event |> Map.fetch!(relationship) |> ids()}
    end)
  end

  # Every event read together, with the same bounded load.
  defp together(ctx, relationship, offset) do
    ctx
    |> read_events([{relationship, by_name_query(ctx, offset)}])
    |> Map.new(&{&1.id, &1 |> Map.fetch!(relationship) |> Enum.map(fn c -> c.id end)})
  end

  defp firsts(loads), do: Map.new(loads, fn {event, ids} -> {event, Enum.at(ids, 0)} end)

  defp events(ctx, expression) do
    ctx
    |> event()
    |> Ash.Query.do_filter(expression)
    |> Ash.Query.sort(:id)
    |> Ash.read!(opts(ctx))
    |> Enum.map(& &1.id)
  end

  defp input(ctx, filter) do
    ctx
    |> event()
    |> Ash.Query.filter_input(filter)
    |> Ash.Query.sort(:id)
    |> Ash.read!(opts(ctx))
    |> Enum.map(& &1.id)
  end

  # The events whose `kind` aggregate over `path`, limited to Cara, says yes.
  defp reaches(ctx, kind, path) do
    cara = Ash.Query.filter(ctx.role.(Customer), id == 3)

    ctx
    |> event()
    |> Ash.Query.aggregate(:cara, kind, path, query: cara)
    |> Ash.Query.sort(:id)
    |> Ash.read!(opts(ctx))
    |> Enum.filter(&reached?(&1.aggregates.cara))
    |> Enum.map(& &1.id)
  end

  defp reached?(true), do: true
  defp reached?(count) when is_integer(count), do: count > 0
  defp reached?(_), do: false

  defp ids(records), do: records |> List.wrap() |> Enum.map(& &1.id) |> Enum.uniq() |> Enum.sort()

  # The organisation's stored orders as `{event, customer}`, read without authorization.
  defp orders(ctx) do
    ctx.role.("#{Macro.camelize(to_string(ctx.shape))}Order")
    |> Ash.read!(tenant: ctx.tenant, authorize?: false)
    |> Enum.map(&{&1.event_id, &1.customer_id})
    |> Enum.sort()
  end

  # The stored notes the view may see, as `{id, org, local id, body, list}`.
  defp notes(ctx) do
    ctx.role.(Note)
    |> Ash.Query.for_read(:global, %{}, authorize?: false)
    |> Ash.read!()
    |> Enum.filter(&World.visible?(ctx.view, :notes, &1))
    |> Enum.map(&note_row(&1, :list))
    |> Enum.sort()
  end

  defp note_row(note), do: {note.id, note.org_id, note.local_id, note.body}
  defp note_row(note, :list), do: {note.id, note.org_id, note.local_id, note.body, note.list_id}

  defp returned(%Ash.BulkResult{records: records}) when is_list(records),
    do: records |> Enum.map(& &1.id) |> Enum.sort()

  defp returned(%Ash.BulkResult{}), do: []

  defp status(:ok), do: :ok
  defp status({:ok, _}), do: :ok
  defp status({:error, _}), do: :refused
end
