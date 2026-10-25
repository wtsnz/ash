# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Error.Invalid.TenantMismatch do
  @moduledoc "Used when a changeset built for one tenant is run with another"

  use Splode.Error, fields: [:resource, :tenant, :given], class: :invalid

  def message(%{resource: resource, tenant: tenant, given: given}) do
    "A changeset for #{inspect(resource)} was built for tenant #{inspect(tenant)}, " <>
      "so it can't be run in tenant #{inspect(given)}. Build it again for that tenant."
  end
end
