# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenario do
  @moduledoc "A public Ash operation with an adapter-independent expected result."
  @enforce_keys [:id, :area, :expected, :run]
  defstruct [
    :id,
    :area,
    :expected,
    :run,
    :source,
    :description,
    fixture: :aggregate,
    profile: :shared,
    capabilities: [],
    benchmark: false,
    fallback: nil,
    detail: nil,
    semantic_basis: "../documentation/topics/resources/aggregates.md"
  ]

  defmacro new(id, area, expected, run, opts \\ []) do
    source = %{
      file: Path.relative_to(__CALLER__.file, Path.expand("..", __DIR__)),
      line: __CALLER__.line
    }

    quote do
      %Ash.Conformance.Scenario{
        id: unquote(id),
        area: unquote(area),
        expected: unquote(expected),
        run: unquote(run),
        source: unquote(Macro.escape(source)),
        description: Keyword.get(unquote(opts), :description, unquote(id)),
        fixture: Keyword.get(unquote(opts), :fixture, :aggregate),
        profile: Keyword.get(unquote(opts), :profile, :shared),
        capabilities: Keyword.get(unquote(opts), :capabilities, []),
        benchmark: Keyword.get(unquote(opts), :benchmark, false),
        fallback: Keyword.get(unquote(opts), :fallback),
        detail: Keyword.get(unquote(opts), :detail),
        semantic_basis:
          Keyword.get(
            unquote(opts),
            :semantic_basis,
            "../documentation/topics/resources/aggregates.md"
          )
      }
    end
  end
end
