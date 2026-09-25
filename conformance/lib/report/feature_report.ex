# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Report.FeatureReport do
  @moduledoc """
  What each data layer can do, feature by feature, from the basics up.

  Statuses come from scenario results (or, for the committed `FEATURES.md`,
  from the declared contracts, which a passing run matches exactly). Each
  feature also compares the adapter's capability claims with what happened.
  """
  alias Ash.Conformance.{
    Adapter,
    Contracts.Capabilities,
    Contracts.Features,
    Contracts.Gaps,
    Report
  }

  @labels %{
    works: "✅ Works",
    partial: "🟡 Partial",
    not_supported: "⛔ Not supported",
    broken: "❌ Broken",
    open_question: "❓ Open question",
    untested: "⚪ Untested",
    not_applicable: "➖ Not applicable",
    changed: "⚠️ Changed"
  }

  def label(status), do: Map.fetch!(@labels, status)

  @doc "The committed report, from the declared contracts for every adapter."
  def declared, do: markdown(Report.declaration_rows(), Adapter.all(), :declared)

  @doc """
  One feature's result on one adapter: status, passing count, total and gaps.
  A check whose run did not match its contract marks the feature as changed.
  """
  def summarize(feature, rows) do
    rows = Enum.filter(rows, &(&1.scenario in feature.scenarios))
    statuses = Enum.map(rows, & &1.status)

    status =
      if Enum.any?(rows, &(Map.get(&1, :execution) == :failed)),
        do: :changed,
        else: Features.status(feature, statuses)

    %{
      status: status,
      passing: Enum.count(statuses, &(&1 == :supported)),
      total: length(rows),
      gaps:
        rows
        |> Enum.map(& &1.task)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.map(&Gaps.id/1),
      # Unreviewed surveys have no gap records, so the failing scenarios stand in.
      failing:
        rows
        |> Enum.filter(&(&1.status != :supported and Map.has_key?(&1, :classification)))
        |> Enum.map(&{&1.scenario, &1.classification})
    }
  end

  @doc "Whether an adapter's claims for a feature agree with its result."
  # Nothing ran, or it awaits a decision, so there is nothing to compare; the
  # adapter's resources may not even be defined.
  def claim_check(feature, _adapter, summary)
      when feature.claims == [] or
             summary.status in [:untested, :not_applicable, :open_question],
      do: nil

  def claim_check(feature, adapter, summary) do
    # A data layer whose resources failed to compile has no claims to probe.
    if Enum.all?(feature.claims, fn {role, _} -> Code.ensure_loaded?(adapter.resource(role)) end),
      do: compare_claims(feature, adapter, summary)
  end

  defp compare_claims(feature, adapter, summary) do
    claims =
      Enum.map(feature.claims, fn {role, claim} -> Capabilities.probe(adapter, role, claim) end)

    advertised = Enum.count(claims, & &1.advertised)

    cond do
      advertised == length(claims) and summary.status in [:not_supported, :broken] ->
        {:advertised_but_fails, claims}

      advertised < length(claims) and summary.status == :works ->
        {:works_without_claim, Enum.reject(claims, & &1.advertised)}

      # The worst case for users: the claim is honest, but nothing rejects the
      # operation and it returns a wrong answer.
      advertised < length(claims) and summary.status == :broken ->
        {:unadvertised_but_wrong, Enum.reject(claims, & &1.advertised)}

      true ->
        nil
    end
  end

  def markdown(rows, adapters, source) do
    detail = if source == :unreviewed, do: :failing, else: :gaps
    {sections, summaries} = feature_tables(rows, adapters, detail: detail)

    """
    <!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
    <!-- SPDX-License-Identifier: MIT -->
    # What each data layer supports

    #{intro(source)}

    Feature catalog version #{Features.version()}: #{length(Features.all())} features and #{Features.all() |> Enum.flat_map(& &1.scenarios) |> length()} scenarios.

    #{legend()}

    Counts are passing scenarios out of those run. Gap links explain everything
    that is not fully working, and who owns the fix.

    #{sections}
    #{claims_section(adapters, summaries)}
    """
  end

  @doc "The table explaining each feature status."
  def legend do
    """
    | Status | Meaning |
    | --- | --- |
    | #{label(:works)} | Every scenario returns the answer Ash defines. |
    | #{label(:partial)} | Some scenarios work; others are rejected or wrong. |
    | #{label(:not_supported)} | Every scenario is rejected with a documented error. |
    | #{label(:broken)} | Nothing works, and at least one scenario gives a wrong answer or crashes. |
    | #{label(:open_question)} | The remaining scenarios need a semantic decision in Ash. |
    | #{label(:untested)} | Listed so the specification is complete; no scenario verifies it yet. |
    | #{label(:not_applicable)} | The data layer does not provide this storage profile. |
    | #{label(:changed)} | A result no longer matches its recorded contract. |
    """
    |> String.trim_trailing()
  end

  @doc """
  One table per feature level, with a column per adapter.

  Options: `detail:` adds a last column of `:gaps` (reviewed) or `:failing`
  scenarios (unreviewed), or `:none`; `unavailable:` maps adapter IDs that
  could not run to a reason, shown as not run.
  """
  def feature_tables(rows, adapters, opts \\ []) do
    detail = Keyword.get(opts, :detail, :gaps)
    unavailable = Keyword.get(opts, :unavailable, %{})
    ids = Enum.map(adapters, & &1.id())
    rows_by_adapter = Enum.group_by(rows, & &1.adapter)

    summaries =
      for feature <- Features.all(), adapter <- adapters, into: %{} do
        {{feature.id, adapter.id()},
         summarize(feature, Map.get(rows_by_adapter, adapter.id(), []))}
      end

    sections =
      Enum.map_join(Features.sections(), "\n", fn {level, name, _} ->
        features = Enum.filter(Features.all(), &(&1.level == level))

        rows =
          Enum.map_join(features, "\n", fn feature ->
            cells =
              Enum.map_join(ids, " | ", fn id ->
                if Map.has_key?(unavailable, id),
                  do: "➖ Not run",
                  else: cell(Map.fetch!(summaries, {feature.id, id}))
              end)

            case detail_cell(detail, ids, feature, summaries) do
              nil -> "| #{feature.title} | #{cells} |"
              text -> "| #{feature.title} | #{cells} | #{text} |"
            end
          end)

        detail_header =
          case detail do
            :gaps -> " Gaps |"
            :failing -> " Not working |"
            :none -> ""
          end

        detail_rule = if detail == :none, do: "", else: " --- |"

        """
        ## #{level}. #{name}

        | Feature | #{Enum.join(ids, " | ")} |#{detail_header}
        | --- | #{Enum.map_join(ids, " | ", fn _ -> "---" end)} |#{detail_rule}
        #{rows}
        """
      end)

    {sections, summaries}
  end

  defp detail_cell(:none, _ids, _feature, _summaries), do: nil

  defp detail_cell(:failing, ids, feature, summaries) do
    ids
    |> Enum.flat_map(&Map.fetch!(summaries, {feature.id, &1}).failing)
    |> Enum.map_join(", ", fn {scenario, classification} ->
      "`#{scenario}` #{String.replace(to_string(classification), "_", " ")}"
    end)
  end

  defp detail_cell(:gaps, ids, feature, summaries) do
    ids
    |> Enum.flat_map(&Map.fetch!(summaries, {feature.id, &1}).gaps)
    |> Enum.uniq()
    |> Enum.map_join(", ", &"[#{&1}](GAPS.md##{&1})")
  end

  defp intro(:declared),
    do:
      "Generated by `mix conformance.features` from the declared contracts. A green run matches these exactly. Each run also writes this report from its own results to `results/`."

  defp intro(:observed),
    do: "Generated from this run's results. It shows what actually happened on each data layer."

  defp intro(:unreviewed),
    do:
      "Generated from an unreviewed run: each result was classified automatically against the intended answer. Nothing here has been reviewed."

  defp cell(%{status: status} = summary) when status in [:untested, :not_applicable],
    do: label(summary.status)

  defp cell(summary), do: "#{label(summary.status)} #{summary.passing}/#{summary.total}"

  @doc "Features whose capability claims disagree with their results."
  def claims_section(adapters, summaries) do
    mismatches =
      for feature <- Features.all(),
          adapter <- adapters,
          check = claim_check(feature, adapter, Map.fetch!(summaries, {feature.id, adapter.id()})),
          check != nil do
        {kind, claims} = check
        claims = Enum.map_join(claims, ", ", &"`#{&1.role}: #{&1.feature}`")

        meaning =
          case kind do
            :advertised_but_fails ->
              "Advertised, but #{label(Map.fetch!(summaries, {feature.id, adapter.id()}).status)}"

            :works_without_claim ->
              "Works without advertising #{claims}"

            :unadvertised_but_wrong ->
              "Not advertising #{claims}, but not rejected either: wrong answers"
          end

        "| #{feature.title} | #{adapter.id()} | #{meaning} |"
      end

    body =
      if mismatches == [],
        do: "No feature's claims disagree with its result.",
        else:
          "| Feature | Adapter | Mismatch |\n| --- | --- | --- |\n" <> Enum.join(mismatches, "\n")

    """
    ## Claims versus results

    A data layer's `can?/2` claims never decide what runs. This lists features
    whose claims disagree with the result:

    - advertised, but not working;
    - working without being advertised, usually because Ash provides it;
    - not advertised, yet not rejected, and giving wrong answers.

    #{body}
    """
  end
end
