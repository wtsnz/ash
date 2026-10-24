# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.AdvProfile do
  @moduledoc "An embedded profile whose `ssn` only an admin may read."
  use Ash.Resource, data_layer: :embedded, authorizers: [Ash.Policy.Authorizer]

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  field_policies do
    field_policy :ssn do
      authorize_if(actor_attribute_equals(:admin, true))
    end

    field_policy :* do
      authorize_if(always())
    end
  end

  attributes do
    attribute(:bio, :string, public?: true)
    attribute(:ssn, :string, public?: true)
  end
end

defmodule Ash.Conformance.Resources.AdvCard do
  @moduledoc "An embedded card whose `number` only an admin may read."
  use Ash.Resource, data_layer: :embedded, authorizers: [Ash.Policy.Authorizer]

  policies do
    policy always() do
      authorize_if(always())
    end
  end

  field_policies do
    field_policy :number do
      authorize_if(actor_attribute_equals(:admin, true))
    end

    field_policy :* do
      authorize_if(always())
    end
  end

  attributes do
    attribute(:label, :string, public?: true)
    attribute(:number, :string, public?: true)
  end
end
