# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures.Adversarial do
  @moduledoc """
  The adversarial fixture (`Ash.Conformance.Adversarial`). Orders are stored
  through the tenant-scoped role, with their organisation in each row; the
  schema-based fixture stores each organisation's orders in its own schema.
  """
  alias Ash.Conformance.{Adversarial, Fixtures}

  def seed!(adapter) do
    for {role, rows} <- [
          adv_event: Adversarial.event_rows(),
          adv_customer: Adversarial.customer_rows(),
          adv_order: Adversarial.order_rows(),
          adv_list: Adversarial.list_rows(),
          adv_note: Adversarial.note_rows(),
          adv_person: Adversarial.person_rows()
        ] do
      Fixtures.seed!(adapter, role, Fixtures.ordered(rows))
    end

    %{adapter: adapter}
  end

  def seed_context!(adapter) do
    Fixtures.seed!(adapter, :adv_event, Fixtures.ordered(Adversarial.event_rows()))
    Fixtures.seed!(adapter, :adv_customer, Fixtures.ordered(Adversarial.customer_rows()))

    for {org, schema} <- Adversarial.schemas() do
      rows =
        for order <- Adversarial.order_rows(),
            order.org_id == org,
            do: Map.delete(order, :org_id)

      Fixtures.seed!(adapter, :adv_schema_order, Fixtures.ordered(rows), tenant: schema)
    end

    %{adapter: adapter}
  end
end
