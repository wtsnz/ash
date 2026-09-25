# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.AggregateTest do
  use ExUnit.Case, async: false
  alias Ash.Conformance.{Adapter, Catalog, Formatter, Runner}

  for adapter <- Adapter.selected(), scenario <- Catalog.for_adapter(adapter) do
    @tag adapter: adapter.id(), scenario: scenario.id, area: scenario.area
    test "#{adapter.id()} #{scenario.id}" do
      adapter = unquote(adapter)
      scenario = Enum.find(Catalog.all(), &(&1.id == unquote(scenario.id)))

      Runner.execute!(scenario, adapter, fn outcome ->
        Formatter.record(scenario.id, adapter.id(), outcome)
      end)
    end
  end
end
