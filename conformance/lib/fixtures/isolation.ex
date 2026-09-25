# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures.Isolation do
  @moduledoc "Two tenants share local identities; hidden high values change sort and bounds."

  def parents do
    for {tenant, owners} <- [{1, [1, 1, 2]}, {2, [1, 2, 1]}],
        {owner, local} <- Enum.with_index(owners, 1) do
      %{
        id: tenant * 100 + local,
        tenant_id: tenant,
        local_id: local,
        owner_id: owner,
        name: "parent-#{local}"
      }
    end
  end

  def items do
    [
      {1, 1, 1, 2, 1, 1},
      {1, 2, 1, 3, 1, 2},
      {1, 3, 1, 99, 2, 2},
      {1, 4, 2, 8, 1, 1},
      {1, 5, 3, 50, 2, 2},
      {2, 1, 1, 700, 1, 1},
      {2, 2, 1, 600, 2, 2},
      {2, 3, 2, 900, 2, 2},
      {2, 4, 3, 1000, 1, 1}
    ]
    |> Enum.map(fn {tenant, local, parent, value, owner, department} ->
      %{
        id: tenant * 1000 + local,
        tenant_id: tenant,
        local_id: local,
        parent_key: parent,
        value: value,
        owner_id: owner,
        department: department
      }
    end)
  end

  def seed!(adapter) do
    for {role, rows} <- [tenant_parent: parents(), tenant_item: items()] do
      adapter.persist!(role, Ash.Conformance.Fixtures.ordered(rows), [])
    end

    %{adapter: adapter}
  end
end
