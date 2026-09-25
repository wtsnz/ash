# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.NoCustomAggregate do
  @moduledoc """
  The custom aggregate for adapters without their own. It has no data-layer
  implementation, so custom-aggregate scenarios show whether the data layer
  rejects it or fails.
  """
  use Ash.Resource.Aggregate.CustomAggregate
end
