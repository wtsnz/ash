# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures.Aggregate do
  @moduledoc "Parents, children, ratings, tags, links, events and readings for the aggregate scenarios."

  @doc "Aggregate fixture children, also used as an in-memory reference."

  def children do
    [
      %{id: 11, parent_id: 1, label: "same", value: 2, visible: true, tenant_id: "a"},
      %{id: 12, parent_id: 1, label: "same", value: 2, visible: true, tenant_id: "a"},
      %{id: 13, parent_id: 1, label: "high", value: 7, visible: false, tenant_id: "b"},
      %{id: 14, parent_id: 1, label: nil, value: nil, visible: true, tenant_id: "a"},
      %{id: 21, parent_id: 2, label: "other", value: 4, visible: true, tenant_id: "b"}
    ]
  end

  def seed!(adapter) do
    parents = [
      %{id: 1, label: "alpha", threshold: 3, tenant_id: "a"},
      %{id: 2, label: "beta", threshold: 5, tenant_id: "b"},
      %{id: 3, label: "empty", threshold: 9, tenant_id: "a"}
    ]

    children = children()

    ratings = [
      %{id: 101, child_id: 11, score: 8},
      %{id: 102, child_id: 11, score: 9},
      %{id: 103, child_id: 12, score: 8},
      %{id: 104, child_id: 13, score: 1}
    ]

    tags = [%{id: 201, label: "red", value: 3}, %{id: 202, label: "blue", value: 8}]

    links = [
      %{parent_id: 1, tag_id: 201, tenant_id: "a"},
      %{parent_id: 1, tag_id: 202, tenant_id: "b"},
      %{parent_id: 2, tag_id: 201, tenant_id: "a"}
    ]

    child_tags = [%{child_id: 11, tag_id: 201}, %{child_id: 12, tag_id: 202}]
    events = [%{parent_id: 1, value: 2}, %{parent_id: 1, value: 3}]

    # Exact decimals and sub-second times expose float or text storage.
    readings = [
      %{
        id: 301,
        parent_id: 1,
        amount: Decimal.new("0.1"),
        taken_on: ~D[2024-01-09],
        taken_at: ~U[2024-01-01 09:59:59.999999Z],
        taken_time: ~T[09:30:00]
      },
      %{
        id: 302,
        parent_id: 1,
        amount: Decimal.new("0.2"),
        taken_on: ~D[2024-01-10],
        taken_at: ~U[2024-01-01 10:00:00.000000Z],
        taken_time: ~T[10:15:00]
      },
      %{
        id: 303,
        parent_id: 2,
        amount: Decimal.new("12345678901234567.89"),
        taken_on: ~D[2023-12-31],
        taken_at: ~U[2023-12-31 23:59:59.000001Z],
        taken_time: ~T[23:59:59]
      },
      %{
        id: 304,
        parent_id: 2,
        amount: Decimal.new("0.01"),
        taken_on: ~D[2024-02-01],
        taken_at: ~U[2024-02-01 00:00:00.000000Z],
        taken_time: ~T[00:00:00]
      }
    ]

    for {role, rows} <- [
          parent: parents,
          child: children,
          rating: ratings,
          tag: tags,
          link: links,
          child_tag: child_tags,
          event: events,
          reading: readings
        ],
        row <- Ash.Conformance.Fixtures.ordered(rows) do
      adapter.persist!(role, [row], [])
    end

    %{adapter: adapter, parent: adapter.resource(:parent), child: adapter.resource(:child)}
  end
end
