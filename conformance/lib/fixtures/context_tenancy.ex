# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures.ContextTenancy do
  @moduledoc false
  def seed!(adapter) do
    for {tenant, rows} <- [
          {"dc_tenant_a", [%{id: 1, parent_id: 1, value: 2}, %{id: 2, parent_id: 1, value: 3}]},
          {"dc_tenant_b", [%{id: 1, parent_id: 1, value: 70}, %{id: 2, parent_id: 2, value: 90}]}
        ] do
      parents = Ash.Conformance.Fixtures.ordered([%{id: 1}, %{id: 2}])
      Ash.Conformance.Fixtures.seed!(adapter, :schema_parent, parents, tenant: tenant)

      items = Ash.Conformance.Fixtures.ordered(rows)
      Ash.Conformance.Fixtures.seed!(adapter, :schema_item, items, tenant: tenant)
    end

    %{adapter: adapter}
  end
end
