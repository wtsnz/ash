# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Address do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute(:city, :string, public?: true)
    attribute(:zip, :string, public?: true)
  end
end
