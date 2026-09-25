# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Aggregates.Writes do
  @moduledoc false
  import Ash.Conformance.Scenario, only: [new: 4]
  require Ash.Query

  # Atomic strategies run the aggregate inside the data layer's update or
  # delete query instead of loading records first.
  def all do
    [
      new(
        "write.bulk_update_filter",
        :writes,
        [{1, "big"}, {2, "beta"}, {3, "empty"}],
        fn ctx ->
          ctx.parent
          |> Ash.Query.filter(child_sum > 5)
          |> Ash.bulk_update!(:relabel, %{label: "big"}, strategy: :atomic, authorize?: false)

          parents(ctx, &{&1.id, &1.label})
        end
      ),
      new("write.bulk_destroy_filter", :writes, [1, 2], fn ctx ->
        ctx.parent
        |> Ash.Query.filter(child_count == 0)
        |> Ash.bulk_destroy!(:destroy, %{}, strategy: :atomic, authorize?: false)

        parents(ctx, & &1.id)
      end),
      new("write.atomic_update", :writes, [{1, 4}, {2, 1}, {3, 0}], fn ctx ->
        Ash.bulk_update!(ctx.parent, :record_child_count, %{},
          strategy: :atomic,
          authorize?: false
        )

        parents(ctx, &{&1.id, &1.threshold})
      end),
      new("write.single_atomic_update", :writes, 1, fn ctx ->
        ctx.parent
        |> Ash.get!(2, authorize?: false)
        |> Ash.update!(%{}, action: :record_child_count, authorize?: false)
        |> Map.fetch!(:threshold)
      end)
    ]
  end

  defp parents(ctx, fun) do
    ctx.parent
    |> Ash.Query.sort(:id)
    |> Ash.read!(authorize?: false)
    |> Enum.map(fun)
  end
end
