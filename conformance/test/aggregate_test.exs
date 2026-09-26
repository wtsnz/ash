# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.AggregateTest do
  use ExUnit.Case, async: false
  alias Ash.Conformance.{Adapter, Catalog, Report.Formatter, Runner}

  for adapter <- Adapter.selected(), scenario <- Catalog.for_adapter(adapter) do
    @tag adapter: adapter.id(), scenario: scenario.id, area: scenario.area
    test "#{adapter.id()} #{scenario.id}" do
      adapter = unquote(adapter)
      scenario = Enum.find(Catalog.all(), &(&1.id == unquote(scenario.id)))

      Runner.execute!(
        scenario,
        adapter,
        &Formatter.record(scenario.id, adapter.id(), &1),
        &Formatter.record_fallback(scenario.id, adapter.id(), &1)
      )
    end
  end
end
