# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Invariants.Known do
  @moduledoc """
  Checks that fail today, each with why. A listed check must still fail: once
  it passes, its test fails until the entry is removed.

  Each entry is `{kind, layers, patterns, reason}`. The kind says what goes
  wrong (`kinds/0`). A pattern matches a check's name,
  `"<shape>/<operation> <check>"` or `"<shape>/<group> agrees"`, where `*`
  matches anything but a space.
  """

  @kinds [
    tenant_read: "Reads another tenant's data",
    tenant_write: "Writes another tenant's data",
    policy: "Counts or returns rows a read policy hides",
    field_policy: "Shows or reveals a field the actor can't see",
    wrong: "Wrong answer, whoever asks",
    raises: "Raises instead of answering"
  ]

  @doc "What goes wrong, by kind, in the order entries are listed."
  def kinds, do: @kinds

  @all [:ets, :sqlite, :postgres]

  def all do
    [
      {:tenant_read, [:postgres],
       [
         "schema/agg.count_m2m correct",
         "schema/agg.count_m2m isolation",
         "schema/agg.count_filtered_m2m isolation",
         "schema/agg.exists_m2m isolation",
         "schema/agg.first_m2m correct",
         "schema/agg.first_m2m isolation",
         "schema/agg.list_m2m correct",
         "schema/agg.list_m2m isolation",
         "schema/filter.count_m2m correct",
         "schema/filter.count_m2m isolation",
         "schema/filter.exists_m2m isolation",
         "schema/filter.input_m2m isolation",
         "schema/filter.input_path isolation",
         "schema/filter.path_m2m isolation",
         "schema/filter.path_orders isolation",
         "schema/count agrees",
         "schema/single agrees",
         "schema/reach agrees"
       ],
       "Under schema-based tenancy, a statement planned for one tenant's joined query is reused " <>
         "for the next tenant (the planner cache key misses the join's prefix)"},
      {:tenant_read, [:sqlite],
       [
         "tenant/write.record_count isolation",
         "tenant/write.record_count_stream isolation",
         "tenant/recorded agrees"
       ],
       "An update of a record that isn't multitenant, referencing an aggregate over a multitenant " <>
         "resource, counts every tenant's rows (single and streaming updates)"},
      {:tenant_write, @all,
       [
         "tenant/foreign.bulk_update.stream correct",
         "tenant/foreign.bulk_update.stream untouched",
         "tenant/foreign.bulk_update.fallback correct",
         "tenant/foreign.bulk_update.fallback untouched",
         "tenant/foreign.bulk_update.global_records correct",
         "tenant/foreign.bulk_update.global_records untouched",
         "tenant/foreign.bulk_destroy.stream correct",
         "tenant/foreign.bulk_destroy.stream untouched",
         "tenant/foreign.bulk_destroy.fallback correct",
         "tenant/foreign.bulk_destroy.fallback untouched",
         "tenant/bulk_update agrees"
       ], "Streaming bulk updates and destroys given records write another tenant's records"},
      {:tenant_write, [:ets, :postgres], ["tenant/bulk_destroy agrees"],
       "Streaming bulk destroys given records destroy another tenant's records"},
      {:tenant_write, [:sqlite],
       [
         "tenant/foreign.bulk_destroy.atomic correct",
         "tenant/foreign.bulk_destroy.atomic untouched",
         "tenant/foreign.bulk_destroy.atomic_batches correct",
         "tenant/foreign.bulk_destroy.atomic_batches untouched"
       ],
       "Bulk destroys given records stream on AshSqlite, and destroy another tenant's records"},
      {:tenant_write, @all,
       [
         "tenant/foreign.destroy_changeset correct",
         "tenant/foreign.destroy_changeset untouched",
         "tenant/foreign agrees"
       ], "Destroying a changeset built with a tenant destroys a record of another tenant"},
      {:tenant_write, @all,
       [
         "tenant/upsert.primary_key correct",
         "tenant/upsert.primary_key untouched",
         "tenant/upsert.primary_key_bulk correct",
         "tenant/upsert.primary_key_bulk untouched"
       ],
       "An upsert on the primary key under attribute multitenancy updates another tenant's record"},
      {:policy, @all,
       [
         "secure/agg.count_m2m isolation",
         "secure/agg.list_m2m isolation",
         "secure/agg.exists_m2m isolation",
         "secure/agg.count_filtered_m2m isolation",
         "secure/filter.input_m2m isolation",
         "secure/count agrees",
         "secure/customers agrees",
         "secure/reach agrees"
       ], "Aggregates and filter_input over a many_to_many skip the join resource's read policy"},
      {:policy, [:ets, :postgres],
       ["secure/agg.count_through isolation", "secure/agg.list_through isolation"],
       "Aggregates over a has_many through skip the read policy of the resources in its path"},
      {:policy, [:ets], ["secure/agg.exists_through isolation"],
       "An exists aggregate over a has_many through skips the read policy of the resources in its path"},
      {:policy, @all,
       [
         "secure/total.root_aggregate isolation",
         "secure/total agrees",
         "secure/write.record_count* isolation"
       ],
       "An aggregate referenced as a root aggregate's field or in an atomic update counts rows the read policy hides"},
      {:policy, [:ets],
       [
         "tenant/fields.bulk_update.atomic isolation",
         "tenant/fields.bulk_destroy.atomic isolation"
       ],
       "Atomic bulk results on ETS show an admin-only aggregate, counting rows the read policy hides"},
      {:policy, @all,
       ["secure/input.inline_count_unauthorized isolation", "secure/order_thresholds agrees"],
       "An inline aggregate in client input can turn off authorization"},
      {:field_policy, @all,
       [
         "tenant/fields.create correct",
         "tenant/fields.create secrets",
         "tenant/fields.update correct",
         "tenant/fields.update secrets",
         "tenant/fields.update noninterference",
         "tenant/fields.destroy correct",
         "tenant/fields.destroy secrets",
         "tenant/fields.destroy noninterference",
         "tenant/fields.bulk_create correct",
         "tenant/fields.bulk_create secrets",
         "tenant/fields.bulk_update.atomic correct",
         "tenant/fields.bulk_update.atomic secrets",
         "tenant/fields.bulk_update.atomic noninterference",
         "tenant/fields.bulk_update.atomic_batches correct",
         "tenant/fields.bulk_update.atomic_batches secrets",
         "tenant/fields.bulk_update.atomic_batches noninterference",
         "tenant/person_fields agrees"
       ],
       "Write results show admin-only values in embedded resources, arrays of them and unions"},
      {:field_policy, [:ets, :postgres],
       [
         "tenant/fields.bulk_destroy.atomic correct",
         "tenant/fields.bulk_destroy.atomic secrets",
         "tenant/fields.bulk_destroy.atomic noninterference"
       ],
       "Atomic bulk destroy results show admin-only values in embedded resources, arrays and unions"},
      {:field_policy, [:ets],
       [
         "tenant/fields.bulk_update.stream correct",
         "tenant/fields.bulk_update.stream secrets",
         "tenant/fields.bulk_update.stream noninterference"
       ],
       "Streaming bulk update results on ETS show admin-only values in embedded resources, arrays and unions"},
      {:field_policy, @all,
       [
         "tenant/input.calculation_argument correct",
         "tenant/input.calculation_argument noninterference",
         "tenant/input.sort_calculation_argument correct",
         "tenant/input.sort_calculation_argument noninterference",
         "tenant/match_hidden agrees"
       ],
       "A calculation argument given as an expression in client input reads a field the actor can't see"},
      {:field_policy, [:postgres],
       [
         "tenant/input.inline_aggregate_parent correct",
         "tenant/input.inline_aggregate_parent noninterference"
       ],
       "An inline aggregate's filter in client input reads the parent's fields the actor can't see"},
      {:field_policy, @all,
       [
         "tenant/trusted.keyset_hidden_cursor secrets",
         "tenant/trusted.keyset_action_hidden_cursor secrets",
         "tenant/trusted.keyset_action_private_cursor secrets"
       ],
       "A keyset cursor carries the values the application sorted on, including a calculation " <>
         "the actor can't see and an attribute that isn't public"},
      {:wrong, [:postgres],
       [
         "tenant/agg.exists_through correct",
         "secure/agg.exists_through correct",
         "schema/agg.exists_through correct",
         "tenant/reach agrees"
       ], "An exists aggregate over a has_many through isn't correlated with its source record"},
      {:wrong, [:sqlite],
       [
         "tenant/load.m2m_limit_one_together correct",
         "tenant/load.m2m_offset_one correct",
         "tenant/load.m2m_offset_one_together correct",
         "secure/load.m2m_limit_one_together correct",
         "secure/load.m2m_offset_one correct",
         "secure/load.m2m_offset_one_together correct",
         "tenant/first agrees",
         "secure/first agrees"
       ], "many_to_many loads with a limit or offset return the wrong records"},
      {:raises, [:postgres],
       [
         "schema/load.through correct",
         "schema/load.through_long correct",
         "schema/load.through_buyers correct",
         "schema/load.through_limit_one correct",
         "schema/load.through_offset_one correct",
         "schema/load.has_one_through correct",
         "schema/customers agrees",
         "schema/first agrees",
         "schema/second agrees"
       ],
       "Under schema-based tenancy, has_many through loads raise: they look for a shared " <>
         "destination in the tenant's schema"},
      {:raises, @all,
       ["tenant/input.sort_hidden_aggregate correct", "tenant/hidden_order agrees"],
       "sort_input on an aggregate the actor can't see raises"},
      {:raises, [:sqlite],
       ["tenant/input.exists_parent correct", "tenant/input.inline_aggregate_parent correct"],
       "parent/1 in client input raises: in exists (a missing parent binding) and in an inline aggregate's filter"},
      {:raises, [:ets],
       ["tenant/write.record_count* correct", "schema/write.record_count* correct"],
       "An atomic update of a record that isn't multitenant, referencing an aggregate over a " <>
         "multitenant resource, raises that the aggregate needs a tenant"}
    ]
  end

  @doc "Why a check is expected to fail, or nil."
  def reason(layer, name) do
    Enum.find_value(all(), fn {_kind, layers, patterns, reason} ->
      if layer in layers and Enum.any?(patterns, &matches?(&1, name)), do: reason
    end)
  end

  defp matches?(pattern, name) do
    regex = pattern |> String.split("*") |> Enum.map_join("[^ ]*", &Regex.escape/1)
    Regex.match?(~r/\A#{regex}\z/, name)
  end
end
