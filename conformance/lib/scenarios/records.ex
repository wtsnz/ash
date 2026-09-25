# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Records do
  @moduledoc """
  Reading, writing and errors on one resource. See `Ash.Conformance.Fixtures.Records`
  for the rows; answers below cite them by ID.
  """
  require Ash.Conformance.Scenario
  import Ash.Conformance.Scenarios.RecordHelpers
  require Ash.Query
  require Ash.Expr

  @crud "../documentation/topics/actions/actions.md"
  @reads "../documentation/topics/actions/read-actions.md"
  @attributes "../documentation/topics/resources/attributes.md"

  def all, do: basics() ++ errors()

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
end
