# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SignaturesTest do
  @moduledoc """
  Every signature Ash declares has a scenario or a written exclusion, and the
  hand-written answers agree with Ash's own in-memory evaluation, run through
  the ETS data layer, except where a difference is recorded below.
  """
  use ExUnit.Case, async: false
  alias Ash.Conformance.{Catalog, Probe, Report}
  alias Ash.Conformance.Scenarios.Signatures

  # Operators whose `types/0` name concrete types. The comparison and boolean
  # operators take any type and are covered by the expressions and operations tiers.
  @operators [:<>, :/, :-, :*, :+]

  defp declared do
    functions =
      for module <- Ash.Filter.builtin_functions(),
          signature <- List.wrap(signatures(module.args())),
          do: {:function, module.name(), signature}

    operators =
      for module <- Ash.Filter.builtin_operators(),
          module.operator() in @operators,
          signature <- module.types(),
          do: {:operator, module.operator(), normalize(signature)}

    functions ++ operators
  end

  defp signatures(:var_args), do: [:var_args]
  defp signatures(list), do: Enum.map(list, &normalize/1)

  # Options such as `{:atom, one_of: [...]}` are named by their type alone.
  defp normalize(signature), do: Enum.map(signature, &type_name/1)
  defp type_name({type, opts}) when type in [:atom, :keyword] and is_list(opts), do: type
  defp type_name(type), do: type

  test "every declared signature has a scenario or an exclusion" do
    covered = Map.values(Signatures.signatures()) ++ Enum.map(Signatures.excluded(), &elem(&1, 0))
    declared = declared()

    assert declared -- covered == [], "signatures without a scenario or exclusion"
    assert covered -- declared == [], "scenarios or exclusions for signatures Ash doesn't declare"
    assert length(covered) == length(Enum.uniq(covered)), "a signature is covered twice"
  end

  # Where Ash's in-memory evaluation differs from the written answer: the gap,
  # and a pattern for what ETS returns instead.
  @ci_split {"runtime-ci-split", ~r/Enumerable not implemented for Ash\.CiString/}
  @usec {"runtime-usec-calculation",
         ~r/^%\{1 => \{:(datetime|time), \d+000000\}, 2 => \{:(datetime|time), \d+000000\}, 3 => nil\}$/}
  @decimal {"operator-signature-cast", ~r/Could not cast Decimal\.new\("[-0-9.]+"\) as :float/}
  # This app configures no time zone database, so Elixir can only shift to UTC.
  @no_zones {:environment, ~r/utc_only_time_zone_database/}

  @evaluator_differs %{
    "sig.string_split.ci" => @ci_split,
    "sig.string_split.ci_separator" => @ci_split,
    "sig.string_split.ci_ci" => @ci_split,
    "sig.string_split.ci_trim" => @ci_split,
    "sig.string_split.ci_ci_trim" => @ci_split,
    "sig.string_split.ci_separator_trim" => @ci_split,
    "sig.plus.usec_duration" => @usec,
    "sig.plus.duration_usec" => @usec,
    "sig.minus.usec_duration" => @usec,
    "sig.plus.time_usec_duration" => @usec,
    "sig.plus.duration_time_usec" => @usec,
    "sig.minus.time_usec_duration" => @usec,
    "sig.round.integer" => {"runtime-round-integer", ~r/\* is invalid/},
    "sig.round.integer_places" => {"runtime-round-integer", ~r/\* is invalid/},
    "sig.div.decimal_decimal" => @decimal,
    "sig.div.float_decimal" => @decimal,
    "sig.div.integer_decimal" => @decimal,
    "sig.div.decimal_float" => @decimal,
    "sig.div.decimal_integer" => @decimal,
    "sig.start_of_day.datetime_zone" => @no_zones,
    "sig.start_of_day.date_zone" => @no_zones
  }

  test "every recorded evaluator difference names a known gap" do
    gaps = Ash.Conformance.Contracts.Gaps.ids()

    for {_id, {gap, _pattern}} <- @evaluator_differs, gap != :environment do
      assert gap in gaps
    end
  end

  for {id, _signature} <- Signatures.signatures() do
    test "Ash's evaluation agrees with #{id}" do
      scenario = Enum.find(Catalog.all(), &(&1.id == unquote(id)))
      report = Probe.run(scenario, Ash.Conformance.Ets)

      case Map.fetch(@evaluator_differs, scenario.id) do
        {:ok, {_gap, pattern}} -> assert report.observation.actual =~ pattern
        :error -> assert report.observation.actual == Report.value(scenario.expected)
      end
    end
  end
end
