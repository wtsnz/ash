# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.RefCalculation do
  @moduledoc """
  A calculation module whose expression is a lone reference to a related field,
  built with `Ash.Expr.ref/2`, as a Spark extension generating one calculation
  per configured field would write it. The same expression written inline in
  the DSL is a separate case (`Ash.Conformance.Shapes`).
  """
  use Ash.Resource.Calculation
  import Ash.Expr

  @impl true
  def expression(opts, _context), do: expr(^ref([opts[:relationship]], opts[:field]))
end
