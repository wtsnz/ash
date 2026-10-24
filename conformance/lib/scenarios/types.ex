# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Types do
  @moduledoc "Each attribute type group written and read back, including nil."
  require Ash.Conformance.Scenario
  import Ash.Conformance.Scenario, only: [requires: 2]
  import Ash.Conformance.Scenarios.RecordHelpers
  import Ash.Conformance.Storage, only: [stored: 1, stored: 2]

  def all, do: types()

  # Each type group is written, then read back in a fresh query. Each
  # requires the storage cells of its types, except strings, whose edge cell
  # also covers a NUL byte this scenario does not write.
  defp types do
    [
      round_trip("record.types_scalar", %{
        name: "kiwi",
        quantity: 42,
        active: false,
        status: :archived
      })
      |> requires(stored([:boolean, :atom])),
      round_trip("record.types_numeric", %{
        price: Decimal.new("12345.678"),
        ratio: -0.125,
        quantity: -9_007_199_254_740_993
      })
      |> requires(stored([:decimal, :float]) ++ stored(:integer, :edge)),
      round_trip("record.types_temporal", %{
        born_on: ~D[2000-02-29],
        seen_at: ~U[1999-12-31 23:59:59.123456Z],
        opens_at: ~T[23:59:59]
      })
      |> requires(stored([:date, :utc_datetime_usec, :time])),
      round_trip("record.types_uuid", %{external_id: "99999999-9999-4999-8999-999999999999"})
      |> requires(stored(:uuid)),
      round_trip("record.types_strings", %{name: "it's \"quoted\"\nnew line\t✓"}),
      round_trip("record.types_array", %{tags: ["b", "a", "b", ""]})
      |> requires(stored(:strings)),
      round_trip("record.types_map", %{
        metadata: %{"a" => 1, "nested" => %{"b" => [true, nil, "c"]}}
      })
      |> requires(stored(:map)),
      round_trip("record.types_embedded", %{address: %{city: "Nelson", zip: "7010"}})
      |> requires(stored(:embedded)),
      round_trip("record.types_nil", %{
        name: nil,
        quantity: nil,
        price: nil,
        ratio: nil,
        active: nil,
        status: nil,
        born_on: nil,
        seen_at: nil,
        opens_at: nil,
        external_id: nil,
        tags: nil,
        metadata: nil,
        address: nil
      })
      |> requires(
        stored(
          ~w(string integer decimal float boolean atom date utc_datetime_usec time uuid strings map embedded)a,
          :null
        )
      )
    ]
  end
end
