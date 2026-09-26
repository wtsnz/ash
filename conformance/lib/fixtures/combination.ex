# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures.Combination do
  @moduledoc "Owners, items and links for the combination grid (`Ash.Conformance.Combinations`)."
  alias Ash.Conformance.{Combinations, Fixtures}

  def seed!(adapter) do
    for {role, rows} <- [
          combo_owner: Combinations.owners(),
          combo_item: Combinations.items(),
          combo_link: Combinations.links()
        ] do
      Fixtures.seed!(adapter, role, Fixtures.ordered(rows))
    end

    %{adapter: adapter}
  end
end
