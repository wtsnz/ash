# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Fixtures.Records do
  @moduledoc """
  Rows for the `record` role. Each row exists to expose a specific problem:

  | id | code | why |
  | ---: | --- | --- |
  | 1 | a | typical values; quantity 3 ties with 2 |
  | 2 | b | case variant `Apple`; inactive draft |
  | 3 | c | case variant `APPLE`; every other field nil |
  | 4 | d | unicode name, leap day, largest quantity and price |
  | 5 | e | nil name, zero quantity and price |
  | 6 | f | empty name, negative quantity and price |
  | 7 | g | active with a nil quantity, for `true or nil` |
  """

  def rows do
    [
      %{
        id: 1,
        code: "a",
        name: "apple",
        quantity: 3,
        price: Decimal.new("1.50"),
        ratio: 0.25,
        active: true,
        status: :live,
        born_on: ~D[2024-01-31],
        seen_at: ~U[2024-01-31 23:59:59.999999Z],
        opens_at: ~T[09:00:00],
        external_id: "11111111-1111-4111-8111-111111111111",
        tags: ["red", "fruit"],
        metadata: %{"size" => "s", "count" => 1},
        address: %{city: "Auckland", zip: "1010"}
      },
      %{
        id: 2,
        code: "b",
        name: "Apple",
        quantity: 3,
        price: Decimal.new("2.25"),
        ratio: 0.5,
        active: false,
        status: :draft,
        born_on: ~D[2023-12-31],
        seen_at: ~U[2024-02-01 00:00:00.000000Z],
        opens_at: ~T[17:30:00],
        external_id: "22222222-2222-4222-8222-222222222222",
        tags: ["green"],
        metadata: %{"size" => "m"},
        address: %{city: "Wellington", zip: "6011"}
      },
      %{id: 3, code: "c", name: "APPLE"},
      %{
        id: 4,
        code: "d",
        name: "Ünïcode ✓",
        quantity: 10,
        price: Decimal.new("100.00"),
        ratio: 1.0e-5,
        active: true,
        status: :archived,
        born_on: ~D[2024-02-29],
        seen_at: ~U[2024-02-29 12:00:00.000001Z],
        opens_at: ~T[00:00:00],
        external_id: "44444444-4444-4444-8444-444444444444",
        tags: ["red"],
        metadata: %{"size" => "l", "nested" => %{"key" => "value"}},
        address: %{city: "Auckland", zip: "1011"}
      },
      %{
        id: 5,
        code: "e",
        quantity: 0,
        price: Decimal.new("0"),
        ratio: -1.5,
        active: true,
        status: :live,
        tags: []
      },
      %{
        id: 6,
        code: "f",
        name: "",
        quantity: -7,
        price: Decimal.new("-0.01"),
        ratio: 0.1,
        active: false,
        status: :live
      },
      %{id: 7, code: "g", name: "gap", active: true}
    ]
  end

  def seed!(adapter) do
    Ash.Conformance.Fixtures.seed!(adapter, :record, Ash.Conformance.Fixtures.ordered(rows()))
    %{adapter: adapter, record: adapter.resource(:record)}
  end
end
