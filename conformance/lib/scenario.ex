# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenario do
  @moduledoc """
  A public Ash operation with an adapter-independent expected result.

  `requires:` lists the scenarios this one builds on, such as a control that
  runs the same path without the feature under test, or a tier-1 storage
  cell (`Ash.Conformance.Storage.stored/2`). When this scenario fails and a
  prerequisite fails too, reports label it as blocked by that prerequisite.
  """
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
    requires: [],
    benchmark: false,
    fallback: nil,
    detail: nil,
    semantic_basis: "../documentation/topics/resources/aggregates.md"
  ]

  @doc "Adds prerequisites to a scenario built by a helper that takes no options."
  def requires(%__MODULE__{} = scenario, ids),
    do: %{scenario | requires: scenario.requires ++ ids}

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
        requires: Keyword.get(unquote(opts), :requires, []),
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
