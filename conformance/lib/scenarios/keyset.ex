# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Keyset do
  @moduledoc """
  Keyset pagination on awkward sort keys, over the records fixture, two
  records a page. Quantities by record: 1 and 2 are 3, 3 and 7 are nil, 4
  is 10, 5 is 0 and 6 is -7.

  Walking every page must give the same order as one sorted read, whatever
  the key: nils, duplicates with a tie-breaker, descending order, a
  calculation, and walking backwards from the last page.
  """
  require Ash.Conformance.Scenario
  import Ash.Conformance.Scenarios.RecordHelpers

  @pagination "../documentation/topics/advanced/pagination.livemd"
  @pages 10

  def all do
    [
      scenario(
        "keyset.nullable_asc",
        :pagination,
        [[6, 5], [1, 2], [4, 3], [7]],
        @pagination,
        &forward(&1, quantity: :asc_nils_last, id: :asc)
      ),
      scenario(
        "keyset.nullable_desc",
        :pagination,
        [[3, 7], [4, 1], [2, 5], [6]],
        @pagination,
        &forward(&1, quantity: :desc_nils_first, id: :asc)
      ),
      scenario(
        "keyset.duplicates_descending_tie",
        :pagination,
        [[7, 3], [6, 5], [2, 1], [4]],
        @pagination,
        &forward(&1, quantity: :asc_nils_first, id: :desc)
      ),
      # `double_quantity` is `quantity * 2`.
      scenario(
        "keyset.calculation",
        :pagination,
        [[4, 1], [2, 5], [6, 3], [7]],
        @pagination,
        &forward(&1, double_quantity: :desc_nils_last, id: :asc)
      ),
      scenario(
        "keyset.backward",
        :pagination,
        [[7], [4, 3], [1, 2], [6, 5]],
        @pagination,
        &backward(&1, quantity: :asc_nils_last, id: :asc)
      )
    ]
  end

  @doc false
  def forward(ctx, sort), do: ctx |> keyset_page([limit: 2], sort) |> walk(:next, [])

  @doc false
  def backward(ctx, sort) do
    last = ctx |> keyset_page([limit: 2], sort) |> last_page(@pages)
    walk(last, :prev, [])
  end

  defp walk(page, direction, pages) when length(pages) < @pages do
    pages = [Enum.map(page.results, & &1.id) | pages]

    if page.results == [] or not more?(page, direction, pages),
      do: pages |> Enum.reject(&(&1 == [])) |> Enum.reverse(),
      else: walk(Ash.page!(page, direction), direction, pages)
  end

  defp walk(_page, _direction, pages), do: Enum.reverse(pages)

  # Going forward, the page says whether more follow. Going back, the walk
  # stops at an empty page.
  defp more?(page, :next, _pages), do: page.more?
  defp more?(_page, :prev, _pages), do: true

  defp last_page(page, 0), do: page
  defp last_page(%{more?: false} = page, _left), do: page
  defp last_page(page, left), do: page |> Ash.page!(:next) |> last_page(left - 1)
end
