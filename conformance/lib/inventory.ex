# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Inventory do
  @moduledoc "Versioned coverage boundaries, including work that has never run."
  alias Ash.Conformance.{Adapter, Capabilities, Catalog, Report}

  def areas do
    [
      {:reads, :implemented, "Filtering, expression calculations, selection, deterministic sort",
       "read.,use.,filter."},
      {:aggregates, :implemented,
       "169 scenarios ported from the AshSQL suite, seeded generated cases; owners per gap",
       "loaded.,root.,path.,values.,field.,bounds.,ordering.,identity.,context.,generated."},
      {:calculations, :implemented,
       "Expression and aggregate fields; in-memory Ash.calculate with fallback evidence",
       "field.calculation,use.calculation,read.selection_expression,calc."},
      {:relationships, :implemented,
       "Direct, multi-hop, many-to-many, manual, through, bounds, per-parent load limits, from_many",
       "path.,bounds.,load.,tenant.bounds,auth.bounds"},
      {:attribute_tenancy, :implemented,
       "Two tenants with overlapping local identities; actor/context interactions",
       "tenant.,auth.tenant_interaction,upsert."},
      {:context_tenancy, :implemented,
       "Separate Postgres provisioning profile; no SQLite schema requirement", "schema."},
      {:authorization, :implemented,
       "Actor policy, relationships, aggregates, pages, shared context",
       "auth.,context.authorization"},
      {:pagination, :implemented, "Static offset/keyset pages, aggregate ordering and counts",
       "tenant.aggregate_,auth.offset_page,auth.keyset_pages,use.pagination"},
      {:distinctness, :implemented,
       "Query distinct, aggregate uniqueness, composite identities and fanout controls",
       "query.distinct,values.distinct_,identity.,filter.fanout"},
      {:writes, :implemented,
       "Create/update/destroy lifecycle; atomic bulk writes that filter by or read aggregates",
       "write."},
      {:upsert, :implemented,
       "Tenant-scoped identities, bulk upserts, conditions and skipped records", "upsert."},
      {:bulk_atomic, :implemented,
       "Partial success, tenant-scoped atomic updates; stream strategy fallback planned",
       "bulk.,write.atomic_update,write.bulk_"},
      {:transactions_locking, :implemented,
       "Rollback on hook failure, raise and explicit rollback, commit, row locks; isolation levels and concurrent locking planned",
       "txn.,query.lock_for_update"},
      {:types_constraints, :implemented,
       "Constrained types, strings, decimals, dates, times and microsecond datetimes in aggregates",
       "values.,root.decimal_sum,root.datetime_max"},
      {:query_combinations, :implemented, "Union; union_all and intersection planned",
       "query.union"},
      {:concurrent_pagination, :planned,
       "Mutating datasets and consistency guarantees need a decision",
       "planned.concurrent_pagination"},
      {:generated_cases, :implemented,
       "24 seeded filtered-aggregate cases checked against an in-memory reference", "generated."}
    ]
  end

  def document do
    %{
      schema_version: 1,
      inventory_version: 2,
      contract: "../lib/ash/data_layer/data_layer.ex",
      feature_typespec: feature_typespec(),
      additional_callsite_capabilities: Capabilities.callsite_only(),
      capability_sources: [
        "../lib/ash/query/query.ex",
        "../lib/ash/filter/filter.ex",
        "../lib/ash/actions/read/relationships.ex",
        "../lib/ash/actions/create/bulk.ex",
        "../lib/ash/actions/update/update_many.ex",
        "../lib/ash/actions/aggregate.ex"
      ],
      callback_groups: %{
        queries:
          ~w(resource_to_query transform_query set_context set_tenant run_query return_query),
        filtering_ordering: ~w(filter sort distinct distinct_sort limit offset select),
        aggregates_calculations:
          ~w(add_aggregate add_aggregates run_aggregate_query add_calculation add_calculations calculate),
        relationships:
          ~w(run_query_with_lateral_join run_aggregate_query_with_lateral_join prefer_lateral_join_for_many_to_many?),
        writes:
          ~w(create update destroy upsert bulk_create update_query destroy_query update_many),
        transactions:
          ~w(transaction in_transaction? rollback lock prefer_transaction? prefer_transaction_for_atomic_updates?),
        combinations: ~w(combination_of combination_acc),
        integration:
          ~w(can? functions source attribute_ecto_type default_bulk_batch_size data_layer_keyset_by_default?)
      },
      areas:
        Enum.map(areas(), fn {id, status, scope, scenarios} ->
          %{
            id: id,
            status: status,
            scope: scope,
            scenario_ids_or_prefixes: scenarios,
            execution: :see_run_report
          }
        end),
      profiles:
        Enum.map(
          Adapter.all(),
          &%{
            adapter: &1.id(),
            supported: &1.profiles(),
            context_tenancy:
              if(:context_tenancy in &1.profiles(), do: :available, else: :not_applicable)
          }
        ),
      scenarios: Report.declaration_rows(),
      adapter_contracts:
        Enum.map(
          Adapter.all(),
          &%{
            adapter: &1.id(),
            capabilities: Capabilities.matrix(&1),
            callbacks: Capabilities.callbacks(&1)
          }
        ),
      fallback_evidence: [
        %{
          id: "framework.single_aggregate",
          location: "../test/ash/data_layer/dispatch_contract_test.exs",
          scope:
            "Dedicated dispatch tests record actual single/batch callback execution; not adapter run evidence"
        },
        %{
          id: "scenario.fallback",
          location: "lib/scenario.ex",
          scope:
            "Scenarios that name a fallback record the data-layer query count of the operation in adapter runs"
        }
      ],
      meaning:
        "Implemented means a scenario exists, not that every adapter conforms. Planned is never a pass."
    }
  end

  def feature_typespec do
    path = Path.expand("../../lib/ash/data_layer/data_layer.ex", __DIR__)
    source = File.read!(path)

    [_, feature] =
      Regex.run(~r/@type feature\(\) ::([\s\S]*?)\n  @type lateral_join_link/, source)

    String.trim(feature)
  end

  def markdown do
    rows =
      Enum.map_join(areas(), "\n", fn {id, status, scope, _} ->
        "| #{id} | #{status} | #{scope} |"
      end)

    """
    <!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
    <!-- SPDX-License-Identifier: MIT -->
    # Coverage inventory v2

    Generated by `mix conformance.inventory`. Version 2 moves upsert, bulk and atomic writes,
    transactions and locks, query combinations, query distinct and generated cases from planned
    to implemented, and adds per-parent loads, `through` relationships and fallback evidence.

    JSON includes the full current feature typespec,
    callback groups, optional callback exports, resource-specific capability probes, profiles,
    scenario expectations and evidence links. Claims are never used to skip operations.
    Per-scenario results in `results/` distinguish semantic passes, matched gaps and failures.

    | Area | Coverage | Boundary |
    | --- | --- | --- |
    #{rows}

    The context-tenancy profile is Postgres-only. SQLite has no schema-provisioning obligation.
    Missing profiles are not passing tests. Fallback evidence comes from instrumented core
    dispatch tests and from scenarios that name a fallback, which record the operation's
    data-layer query count. Other adapter scenarios report `unobserved`. A false capability
    and a correct answer alone do not prove fallback execution.

    #{length(Catalog.all())} executable scenarios are registered. See [MATRIX.md](MATRIX.md) for individual contracts.
    """
  end
end
