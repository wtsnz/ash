# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Records do
  @moduledoc """
  Basic behaviour on one resource: reading, writing, types, errors, filters,
  sorting, pagination and calculations. See `Ash.Conformance.RecordFixtures`
  for the rows; answers below cite them by ID.
  """
  import Ash.Conformance.Scenario, only: [new: 5]
  require Ash.Query
  require Ash.Expr

  @crud "../documentation/topics/actions/actions.md"
  @attributes "../documentation/topics/resources/attributes.md"
  @expressions "../documentation/topics/reference/expressions.md"
  @reads "../documentation/topics/actions/read-actions.md"
  @calculations "../documentation/topics/resources/calculations.md"

  def all, do: basics() ++ types() ++ errors() ++ filters() ++ sorting() ++ paging()

  defp basics do
    [
      scenario("record.read_all", :reads, [1, 2, 3, 4, 5, 6, 7], @reads, &ids(query(&1))),
      scenario("record.get_primary_key", :reads, "Ünïcode ✓", @reads, fn ctx ->
        Ash.get!(ctx.record, 4, authorize?: false).name
      end),
      scenario(
        "record.get_identity",
        :reads,
        2,
        "../documentation/topics/resources/identities.md",
        fn ctx ->
          Ash.get!(ctx.record, [code: "b"], authorize?: false).id
        end
      ),
      scenario("record.select", :reads, {"apple", true}, @reads, fn ctx ->
        record =
          ctx.record
          |> Ash.Query.select([:name])
          |> Ash.Query.filter(id == 1)
          |> Ash.read_one!(authorize?: false)

        {record.name, match?(%Ash.NotLoaded{}, record.quantity)}
      end),
      scenario("record.create", :writes, {8, "fig", [1, 2, 3, 4, 5, 6, 7, 8]}, @crud, fn ctx ->
        record = Ash.create!(ctx.record, %{id: 8, code: "h", name: "fig"}, authorize?: false)
        {record.id, record.name, ids(query(ctx))}
      end),
      scenario("record.update", :writes, {"apricot", 4, "apricot"}, @crud, fn ctx ->
        updated =
          ctx.record
          |> Ash.get!(1, authorize?: false)
          |> Ash.update!(%{name: "apricot", quantity: 4}, authorize?: false)

        {updated.name, updated.quantity, Ash.get!(ctx.record, 1, authorize?: false).name}
      end),
      scenario("record.update_to_nil", :writes, {nil, nil}, @crud, fn ctx ->
        ctx.record
        |> Ash.get!(1, authorize?: false)
        |> Ash.update!(%{name: nil, tags: nil}, authorize?: false)

        record = Ash.get!(ctx.record, 1, authorize?: false)
        {record.name, record.tags}
      end),
      scenario("record.destroy", :writes, [1, 2, 4, 5, 6, 7], @crud, fn ctx ->
        ctx.record |> Ash.get!(3, authorize?: false) |> Ash.destroy!(authorize?: false)
        ids(query(ctx))
      end),
      scenario(
        "record.atomic_update",
        :writes,
        {4, 3},
        "../documentation/topics/actions/update-actions.md",
        fn ctx ->
          ctx.record
          |> Ash.get!(1, authorize?: false)
          |> Ash.Changeset.for_update(:update, %{})
          |> Ash.Changeset.atomic_update(:quantity, Ash.Expr.expr(quantity + 1))
          |> Ash.update!(authorize?: false)

          {Ash.get!(ctx.record, 1, authorize?: false).quantity,
           Ash.get!(ctx.record, 2, authorize?: false).quantity}
        end
      )
    ]
  end

  # Each type group is written, then read back in a fresh query.
  defp types do
    [
      round_trip("record.types_scalar", %{
        name: "kiwi",
        quantity: 42,
        active: false,
        status: :archived
      }),
      round_trip("record.types_numeric", %{
        price: Decimal.new("12345.678"),
        ratio: -0.125,
        quantity: -9_007_199_254_740_993
      }),
      round_trip("record.types_temporal", %{
        born_on: ~D[2000-02-29],
        seen_at: ~U[1999-12-31 23:59:59.123456Z],
        opens_at: ~T[23:59:59]
      }),
      round_trip("record.types_uuid", %{external_id: "99999999-9999-4999-8999-999999999999"}),
      round_trip("record.types_strings", %{name: "it's \"quoted\"\nnew line\t✓"}),
      round_trip("record.types_array", %{tags: ["b", "a", "b", ""]}),
      round_trip("record.types_map", %{
        metadata: %{"a" => 1, "nested" => %{"b" => [true, nil, "c"]}}
      }),
      round_trip("record.types_embedded", %{address: %{city: "Nelson", zip: "7010"}}),
      round_trip("record.types_nil", %{
        name: nil,
        quantity: nil,
        price: nil,
        ratio: nil,
        active: nil,
        status: nil,
        born_on: nil,
        seen_at: nil,
        opens_at: nil,
        external_id: nil,
        tags: nil,
        metadata: nil,
        address: nil
      })
    ]
  end

  defp round_trip(id, attributes) do
    fields = Map.keys(attributes)

    scenario(id, :types, project(attributes), @attributes, fn ctx ->
      Ash.create!(ctx.record, Map.merge(%{id: 9, code: "rt"}, attributes), authorize?: false)
      ctx.record |> Ash.get!(9, authorize?: false) |> Map.take(fields) |> project()
    end)
  end

  # Embedded records compare by their attributes.
  defp project(values) do
    Map.new(values, fn
      {key, %Ash.Conformance.Address{} = address} -> {key, Map.take(address, [:city, :zip])}
      {key, value} -> {key, value}
    end)
  end

  defp errors do
    [
      scenario(
        "record.not_found",
        :errors,
        {Ash.Error.Invalid, [{Ash.Error.Query.NotFound, nil}]},
        @crud,
        &error_shape(Ash.get(&1.record, 999, authorize?: false))
      ),
      scenario(
        "record.invalid_value",
        :errors,
        {Ash.Error.Invalid, [{Ash.Error.Changes.InvalidAttribute, :status}]},
        @attributes,
        &error_shape(
          Ash.create(&1.record, %{id: 10, code: "x", status: :bogus}, authorize?: false)
        )
      ),
      scenario(
        "record.required",
        :errors,
        {Ash.Error.Invalid, [{Ash.Error.Changes.Required, :code}]},
        @attributes,
        &error_shape(Ash.create(&1.record, %{id: 10}, authorize?: false))
      ),
      scenario(
        "record.identity_conflict",
        :errors,
        {{Ash.Error.Invalid, [{Ash.Error.Changes.InvalidAttribute, :code}]},
         [1, 2, 3, 4, 5, 6, 7]},
        "../documentation/topics/resources/identities.md",
        fn ctx ->
          result = Ash.create(ctx.record, %{id: 10, code: "a"}, authorize?: false)
          {error_shape(result), ids(query(ctx))}
        end
      )
    ]
  end

  defp error_shape({:error, %class{errors: errors}}),
    do: {class, errors |> Enum.map(&{&1.__struct__, Map.get(&1, :field)}) |> Enum.sort()}

  defp error_shape(other), do: {:unexpected, other}

  # Nil comparisons are nil and exclude the row, as in SQL.
  defp filters do
    [
      filter("record.filter_equal", [1, 2], Ash.Expr.expr(quantity == 3)),
      filter("record.filter_not_equal", [4, 5, 6], Ash.Expr.expr(quantity != 3)),
      filter("record.filter_range", [1, 2], Ash.Expr.expr(quantity > 0 and quantity < 10)),
      filter("record.filter_in_with_nil", [1, 2], Ash.Expr.expr(quantity in [3, nil])),
      filter("record.filter_is_nil", [3, 7], Ash.Expr.expr(is_nil(quantity))),
      filter("record.filter_not_nil", [1, 2, 4, 5, 6], Ash.Expr.expr(not is_nil(quantity))),
      filter("record.filter_not", [5, 6], Ash.Expr.expr(not (quantity > 2))),
      filter("record.filter_boolean", [2, 6], Ash.Expr.expr(active == false)),
      filter("record.filter_atom", [1, 5, 6], Ash.Expr.expr(status == :live)),
      filter("record.filter_atom_as_string", [1, 5, 6], Ash.Expr.expr(status == "live")),
      filter("record.filter_decimal", [2, 4], Ash.Expr.expr(price > 1.5)),
      filter("record.filter_date", [1, 4], Ash.Expr.expr(born_on >= ^~D[2024-01-01])),
      filter(
        "record.filter_datetime_precision",
        [4],
        Ash.Expr.expr(seen_at > ^~U[2024-02-29 12:00:00.000000Z])
      ),
      filter("record.filter_contains", [1, 2], Ash.Expr.expr(contains(name, "pp"))),
      filter(
        "record.filter_case_insensitive",
        [1, 2, 3],
        Ash.Expr.expr(contains(string_downcase(name), "apple"))
      ),
      filter("record.filter_unicode", [4], Ash.Expr.expr(name == "Ünïcode ✓")),
      filter("record.filter_empty_string", [6], Ash.Expr.expr(name == "")),
      filter("record.filter_array_member", [1, 4], Ash.Expr.expr("red" in tags)),
      filter("record.filter_map_key", [2], Ash.Expr.expr(metadata["size"] == "m")),
      filter("record.filter_embedded", [1, 4], Ash.Expr.expr(address[:city] == "Auckland")),
      filter("record.filter_calculation", [4], Ash.Expr.expr(double_quantity > 10)),
      # Ash documents `true or nil` as nil, unlike SQL, where it is true.
      filter(
        "record.filter_true_or_nil",
        :unresolved,
        Ash.Expr.expr(active == true or quantity > 5)
      )
    ]
  end

  defp filter(id, expected, expression) do
    scenario(id, :filters, expected, @expressions, fn ctx ->
      ctx |> query() |> Ash.Query.do_filter(expression) |> ids()
    end)
  end

  defp sorting do
    [
      sort("record.sort_desc_nils_last", [4, 1, 2, 5, 6, 3, 7],
        quantity: :desc_nils_last,
        id: :asc
      ),
      sort("record.sort_asc_nils_first", [3, 7, 6, 5, 1, 2, 4],
        quantity: :asc_nils_first,
        id: :asc
      ),
      sort(
        "record.sort_tie_break",
        [2, 1],
        [quantity: :asc, id: :desc],
        Ash.Expr.expr(quantity == 3)
      ),
      sort("record.sort_string", [7, 6, 5, 4, 3, 2, 1], code: :desc),
      sort("record.sort_decimal", [6, 5, 1, 2, 4, 3, 7], price: :asc_nils_last, id: :asc),
      sort("record.sort_date", [2, 1, 4, 3, 5, 6, 7], born_on: :asc_nils_last, id: :asc),
      scenario("record.sort_calculation", :ordering, [4, 1, 2, 5, 6], @calculations, fn ctx ->
        ctx.record
        |> Ash.Query.filter(not is_nil(quantity))
        |> Ash.Query.sort(double_quantity: :desc, id: :asc)
        |> ids()
      end)
    ]
  end

  defp sort(id, expected, sort, filter \\ nil) do
    scenario(id, :ordering, expected, @reads, fn ctx ->
      query = ctx.record |> Ash.Query.sort(sort)
      query = if filter, do: Ash.Query.do_filter(query, filter), else: query
      query |> Ash.read!(authorize?: false) |> Enum.map(& &1.id)
    end)
  end

  defp paging do
    [
      scenario("record.limit_offset", :pagination, [3, 4], @reads, fn ctx ->
        ctx |> query() |> Ash.Query.limit(2) |> Ash.Query.offset(2) |> ids()
      end),
      scenario("record.count", :pagination, {5, true, false}, @reads, fn ctx ->
        present = Ash.Query.filter(ctx.record, not is_nil(quantity))
        missing = Ash.Query.filter(ctx.record, quantity > 100)

        {Ash.count!(present, authorize?: false), Ash.exists?(present, authorize?: false),
         Ash.exists?(missing, authorize?: false)}
      end),
      scenario("record.stream", :pagination, [1, 2, 3, 4, 5, 6, 7], @reads, fn ctx ->
        ctx.record
        |> Ash.Query.for_read(:streamable)
        |> Ash.Query.sort(:id)
        |> Ash.stream!(batch_size: 2, authorize?: false)
        |> Enum.map(& &1.id)
      end),
      scenario(
        "record.offset_pages",
        :pagination,
        {[[1, 2, 3], [4, 5, 6], [7]], 7, false},
        @reads,
        fn ctx ->
          first = page(ctx, offset: 0, limit: 3, count: true)
          second = Ash.page!(first, :next)
          last = Ash.page!(second, :next)

          {Enum.map([first, second, last], &Enum.map(&1.results, fn r -> r.id end)), first.count,
           last.more?}
        end
      ),
      scenario("record.keyset_pages", :pagination, {[4, 5, 6], [1, 2, 3], 7}, @reads, fn ctx ->
        first = page(ctx, limit: 3, count: true)
        next = Ash.page!(first, :next)
        previous = Ash.page!(next, :prev)

        {Enum.map(next.results, & &1.id), Enum.map(previous.results, & &1.id), first.count}
      end),
      scenario(
        "record.calculation_load",
        :calculations,
        %{1 => 6, 3 => nil, 6 => -14},
        @calculations,
        fn ctx ->
          ctx.record
          |> Ash.Query.filter(id in [1, 3, 6])
          |> Ash.Query.load(:double_quantity)
          |> Ash.read!(authorize?: false)
          |> Map.new(&{&1.id, &1.double_quantity})
        end
      ),
      # String arguments are trimmed by default, so the suffix has no spaces.
      scenario("record.calculation_argument", :calculations, "apple-pie", @calculations, fn ctx ->
        ctx.record
        |> Ash.Query.filter(id == 1)
        |> Ash.Query.load(suffixed: %{suffix: "-pie"})
        |> Ash.read_one!(authorize?: false)
        |> Map.fetch!(:suffixed)
      end)
    ]
  end

  defp page(ctx, opts) do
    ctx.record
    |> Ash.Query.for_read(:paged)
    |> Ash.Query.sort(:id)
    |> Ash.read!(page: opts, authorize?: false)
  end

  defp scenario(id, area, expected, basis, run),
    do: new(id, area, expected, run, fixture: :records, semantic_basis: basis)

  defp query(ctx), do: Ash.Query.sort(ctx.record, :id)

  defp ids(query), do: query |> Ash.read!(authorize?: false) |> Enum.map(& &1.id)
end
