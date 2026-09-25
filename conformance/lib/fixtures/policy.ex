# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures.Policy do
  @moduledoc """
  Documents, notes and memberships for the policy grid, seeded through the
  base roles, which allow everything. The rows are in `Ash.Conformance.Policy`
  so the reference model and the fixture cannot drift apart.
  """
  alias Ash.Conformance.{Fixtures, Policy}

  def seed!(adapter) do
    for {role, rows} <- [
          policy_doc: Policy.doc_rows(),
          policy_note: Policy.note_rows(),
          policy_member: Policy.member_rows()
        ] do
      Fixtures.seed!(adapter, role, Fixtures.ordered(rows))
    end

    %{adapter: adapter}
  end
end
