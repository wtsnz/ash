# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Inventory do
  @moduledoc "Versioned coverage boundaries, including work that has never run."
  alias Ash.Conformance.{Adapter, Capabilities, Catalog, Report}

  def areas do
    [
      {:reads, :implemented, "Filtering, expression calculations, selection, deterministic sort",
       "read.,use.,filter."},
      {:aggregates, :implemented, "146 inherited semantic and gap contracts; all nine kinds",
       "loaded.,root.,path.,values.,field.,bounds.,ordering.,identity.,context."},
      {:calculations, :implemented,
       "Expression and aggregate fields; runtime calculation combinations planned",
       "field.calculation,use.calculation,read.selection_expression"},
      {:relationships, :implemented,
       "Direct, multi-hop, many-to-many, manual, bounds and from_many",
       "path.,bounds.,tenant.bounds,auth.bounds"},
      {:attribute_tenancy, :implemented,
       "Two tenants with overlapping local identities; actor/context interactions",
       "tenant.,auth.tenant_interaction"},
      {:context_tenancy, :implemented,
       "Separate Postgres provisioning profile; no SQLite schema requirement", "schema."},
      {:authorization, :implemented,
       "Actor policy, relationships, aggregates, pages, shared context",
       "auth.,context.authorization"},
      {:pagination, :implemented, "Static offset/keyset pages, aggregate ordering and counts",
       "tenant.aggregate_,auth.offset_page,auth.keyset_pages,use.pagination"},
      {:distinctness, :implemented,
       "Aggregate uniqueness, composite identities, fanout controls; query DISTINCT planned",
       "values.distinct_,identity.,filter.fanout"},
      {:writes, :implemented, "Create/update/destroy lifecycle with attribute tenancy",
       "write.lifecycle"},
      {:upsert, :planned, "Conflict targets, tenant-aware identities and skipped records",
       "planned.upsert"},
      {:bulk_atomic, :planned,
       "Partial failure, return records, atomic changes and fallback strategies",
       "planned.bulk_atomic"},
      {:transactions_locking, :planned,
       "Isolation, rollback and locks need a separate concurrency profile",
       "planned.transactions_locking"},
      {:types_constraints, :implemented,
       "Constrained aggregate types, nils and strings; broader persistence planned",
       "values.constrained_scalar,values.string_constraints"},
      {:query_combinations, :planned, "Union, union_all and intersection semantics by resource",
       "planned.query_combinations"},
      {:concurrent_pagination, :planned,
       "Mutating datasets and consistency guarantees need a decision",
       "planned.concurrent_pagination"},
      {:generated_cases, :planned,
       "Bounded deterministic generators after the static isolation corpus",
       "planned.generated_cases"}
    ]
  end

  def document do
    %{
      schema_version: 1,
      inventory_version: 1,
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
    # Coverage inventory v1

    Generated by `mix conformance.inventory`. JSON includes the full current feature typespec,
    callback groups, optional callback exports, resource-specific capability probes, profiles,
    scenario expectations and evidence links. Claims are never used to skip operations.
    Per-scenario results in `results/` distinguish semantic passes, matched gaps and failures.

    | Area | Coverage | Boundary |
    | --- | --- | --- |
    #{rows}

    The context-tenancy profile is Postgres-only. SQLite has no schema-provisioning obligation.
    Missing profiles are not passing tests. Fallback evidence is limited to instrumented core
    dispatch tests; adapter scenarios report `unobserved` unless instrumentation proves a path.
    A false capability and a correct answer alone do not prove fallback execution.

    #{length(Catalog.all())} executable scenarios are registered. See [MATRIX.md](MATRIX.md) for individual contracts.
    """
  end
end
