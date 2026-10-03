# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Domain do
  @moduledoc false
  use Ash.Domain

  resources do
    allow_unregistered?(true)
  end
end
