# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.PlainManual do
  @moduledoc """
  The manual relationship for adapters without their own: it loads children by
  `parent_id` through a normal read, so it has no join or subquery form.
  """
  use Ash.Resource.ManualRelationship

  def load(parents, _opts, %{query: query, actor: actor, authorize?: authorize?}) do
    ids = Enum.map(parents, & &1.id)

    rows =
      query
      |> Ash.Query.do_filter(parent_id: [in: ids])
      |> Ash.read!(actor: actor, authorize?: authorize?)

    {:ok, Enum.group_by(rows, & &1.parent_id)}
  end
end
