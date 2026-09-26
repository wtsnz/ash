# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Identities do
  @moduledoc """
  Identities and upserts over a key that can be nil. By default nil values
  never conflict; with `nils_distinct?: false` they do (`Ash.Resource.Identity`).
  The upsert action only updates `value` (`upsert_fields`).
  """
  import Ash.Conformance.Scenario, only: [new: 5]
  import Ash.Conformance.Scenarios.RecordHelpers, only: [error_shape: 1]

  @identities "../lib/ash/resource/identity.ex"
  @upserts "../documentation/topics/actions/create-actions.md"
  @opts [fixture: :empty]

  def all do
    [
      new(
        "identity.nils_distinct",
        :identity,
        {:ok, 2},
        fn ctx ->
          first(ctx, :identity_row)
          {status(create(ctx, :identity_row, 2, 2)), count(ctx, :identity_row)}
        end,
        [semantic_basis: @identities] ++ @opts
      ),
      new(
        "identity.nils_not_distinct",
        :identity,
        {{Ash.Error.Invalid, [{Ash.Error.Changes.InvalidAttribute, :code}]}, 1},
        fn ctx ->
          first(ctx, :strict_identity_row)
          {status(create(ctx, :strict_identity_row, 2, 2)), count(ctx, :strict_identity_row)}
        end,
        [semantic_basis: @identities] ++ @opts
      ),
      # Nil keys never conflict by default, so the upsert inserts a second row.
      new(
        "upsert.nil_key",
        :writes,
        [{1, 1}, {2, 5}],
        fn ctx ->
          first(ctx, :identity_row)
          upsert(ctx, :identity_row, %{id: 2, code: "a", scope: nil, value: 5})
          rows(ctx, :identity_row, &{&1.id, &1.value})
        end,
        [semantic_basis: @upserts] ++ @opts
      ),
      # With `nils_distinct?: false` the nil keys conflict: row 1 is updated.
      new(
        "upsert.nil_key_not_distinct",
        :writes,
        [{1, 5}],
        fn ctx ->
          first(ctx, :strict_identity_row)
          upsert(ctx, :strict_identity_row, %{id: 2, code: "a", scope: nil, value: 5})
          rows(ctx, :strict_identity_row, &{&1.id, &1.value})
        end,
        [semantic_basis: @upserts] ++ @opts
      ),
      # Only `value` is an upsert field, so the note keeps its stored value.
      new(
        "upsert.fields",
        :writes,
        [{1, 5, "old"}],
        fn ctx ->
          Ash.create!(
            ctx.adapter.resource(:identity_row),
            %{id: 1, code: "b", scope: "s", value: 1, note: "old"},
            authorize?: false
          )

          upsert(ctx, :identity_row, %{id: 2, code: "b", scope: "s", value: 5, note: "new"})
          rows(ctx, :identity_row, &{&1.id, &1.value, &1.note})
        end,
        [semantic_basis: @upserts] ++ @opts
      )
    ]
  end

  # Row 1: code "a" with a nil scope.
  defp first(ctx, role), do: {:ok, _} = create(ctx, role, 1, 1)

  defp create(ctx, role, id, value),
    do:
      Ash.create(
        ctx.adapter.resource(role),
        %{id: id, code: "a", scope: nil, value: value},
        authorize?: false
      )

  defp upsert(ctx, role, input) do
    ctx.adapter.resource(role)
    |> Ash.Changeset.for_create(:upsert, input, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  defp status({:ok, _record}), do: :ok
  defp status(other), do: error_shape(other)

  defp count(ctx, role), do: Ash.count!(ctx.adapter.resource(role), authorize?: false)

  defp rows(ctx, role, project) do
    ctx.adapter.resource(role)
    |> Ash.Query.sort(:id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(project)
  end
end
