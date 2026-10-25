# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures.Shapes do
  @moduledoc "Roots, and both key types' mids, leaves and tips, for the shapes grid (`Ash.Conformance.Shapes`)."
  alias Ash.Conformance.{Fixtures, Shapes}

  def seed!(adapter) do
    Fixtures.seed!(adapter, :shape_root, Fixtures.ordered(Shapes.roots()))

    for key <- [:integer, :uuid], level <- [:mids, :leaves, :tips] do
      role = :"shape_#{key}_#{level |> to_string() |> String.trim_trailing("s") |> singular()}"
      Fixtures.seed!(adapter, role, Fixtures.ordered(Shapes.rows(level, key)))
    end

    %{adapter: adapter}
  end

  defp singular("leave"), do: "leaf"
  defp singular(level), do: level
end
