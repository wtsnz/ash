# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Contracts.Features do
  @moduledoc """
  The master list of behaviour a data layer provides to Ash users, from the
  basics up.

  Each feature says what a user can do, where Ash defines the behaviour, which
  capability claims relate to it and which scenarios verify it. Every scenario
  belongs to exactly one feature. A feature with no scenarios is listed as
  untested, never as working. The per-adapter feature report is derived from
  this catalog and the scenario results.
  """

  @version 1

  @docs "../documentation/topics"

  def version, do: @version

  def sections do
    [
      {1, "Storage", storage()},
      {2, "Records",
       [
         feature("records.read", "Read records", "#{@docs}/actions/read-actions.md",
           claims: [record: :read],
           scenarios: ~w(record.read_all)
         ),
         feature(
           "records.get",
           "Get one record by primary key or identity",
           "#{@docs}/resources/identities.md",
           claims: [record: :read, record: :filter],
           scenarios: ~w(record.get_primary_key record.get_identity)
         ),
         feature(
           "records.select",
           "Select only some attributes",
           "#{@docs}/actions/read-actions.md",
           claims: [record: :select],
           scenarios: ~w(record.select read.selection_expression)
         ),
         feature("records.create", "Create a record", "#{@docs}/actions/create-actions.md",
           claims: [record: :create],
           scenarios: ~w(record.create)
         ),
         feature(
           "records.update",
           "Update a record, including to nil",
           "#{@docs}/actions/update-actions.md",
           claims: [record: :update],
           scenarios: ~w(record.update record.update_to_nil)
         ),
         feature("records.destroy", "Destroy a record", "#{@docs}/actions/destroy-actions.md",
           claims: [record: :destroy],
           scenarios: ~w(record.destroy)
         ),
         feature(
           "records.atomic_update",
           "Update a record atomically from its current value",
           "#{@docs}/actions/update-actions.md",
           claims: [record: {:atomic, :update}],
           scenarios: ~w(record.atomic_update)
         ),
         feature(
           "records.errors",
           "Not found, invalid, missing and duplicate values are errors",
           "#{@docs}/resources/identities.md",
           claims: [record: :create],
           scenarios:
             ~w(record.not_found record.invalid_value record.required record.identity_conflict)
         )
       ]},
      {3, "Types",
       [
         feature(
           "types.scalar",
           "Strings, integers, booleans, atoms and nil round-trip",
           "#{@docs}/resources/attributes.md",
           claims: [record: :create, record: :read],
           scenarios: ~w(record.types_scalar record.types_strings record.types_nil)
         ),
         feature(
           "types.numeric",
           "Large integers, floats and decimals round-trip",
           "#{@docs}/resources/attributes.md",
           claims: [record: :create, record: :read],
           scenarios: ~w(record.types_numeric values.decimal_read_control)
         ),
         feature(
           "types.temporal",
           "Dates, microsecond datetimes and times round-trip",
           "#{@docs}/resources/attributes.md",
           claims: [record: :create, record: :read],
           scenarios: ~w(record.types_temporal)
         ),
         feature("types.uuid", "UUIDs round-trip", "#{@docs}/resources/attributes.md",
           claims: [record: :create, record: :read],
           scenarios: ~w(record.types_uuid)
         ),
         feature(
           "types.array",
           "Arrays round-trip, keeping order and duplicates",
           "#{@docs}/resources/attributes.md",
           claims: [record: :create, record: :read],
           scenarios: ~w(record.types_array)
         ),
         feature(
           "types.map",
           "Maps round-trip, including nested values",
           "#{@docs}/resources/attributes.md",
           claims: [record: :create, record: :read],
           scenarios: ~w(record.types_map)
         ),
         feature(
           "types.embedded",
           "Embedded resources round-trip",
           "#{@docs}/resources/embedded-resources.md",
           claims: [record: :create, record: :read],
           scenarios: ~w(record.types_embedded)
         )
       ]},
      {4, "Querying",
       [
         feature(
           "filter.comparison",
           "Filter with comparisons on numbers, decimals and dates",
           "#{@docs}/reference/expressions.md",
           claims: [record: :filter],
           scenarios:
             ~w(record.filter_equal record.filter_not_equal record.filter_range record.filter_decimal record.filter_date record.filter_datetime_precision)
         ),
         feature(
           "filter.nil",
           "Nil behaves like SQL NULL in filters",
           "#{@docs}/reference/expressions.md",
           claims: [record: :filter, record: :boolean_filter],
           scenarios:
             ~w(record.filter_is_nil record.filter_not_nil record.filter_in_with_nil record.filter_not record.filter_true_or_nil)
         ),
         feature(
           "filter.values",
           "Filter booleans and atoms, including atoms as strings",
           "#{@docs}/reference/expressions.md",
           claims: [record: :filter],
           scenarios: ~w(record.filter_boolean record.filter_atom record.filter_atom_as_string)
         ),
         feature(
           "filter.strings",
           "Filter strings: contains, case, unicode and empty",
           "#{@docs}/reference/expressions.md",
           claims: [record: :filter],
           scenarios:
             ~w(record.filter_contains record.filter_case_insensitive record.filter_unicode record.filter_empty_string)
         ),
         feature(
           "filter.structured",
           "Filter inside arrays, maps and embedded resources",
           "#{@docs}/reference/expressions.md",
           claims: [record: :filter],
           scenarios: ~w(record.filter_array_member record.filter_map_key record.filter_embedded)
         ),
         feature(
           "filter.calculation",
           "Filter by a calculation",
           "#{@docs}/resources/calculations.md",
           claims: [record: :expression_calculation],
           scenarios: ~w(record.filter_calculation)
         ),
         feature(
           "sort.values",
           "Sort by one or more fields, with explicit nil order",
           "#{@docs}/actions/read-actions.md",
           claims: [record: :sort],
           scenarios:
             ~w(record.sort_desc_nils_last record.sort_asc_nils_first record.sort_tie_break record.sort_string record.sort_decimal record.sort_date)
         ),
         feature(
           "sort.calculation",
           "Sort by a calculation",
           "#{@docs}/resources/calculations.md",
           claims: [record: :expression_calculation_sort],
           scenarios: ~w(record.sort_calculation)
         ),
         feature(
           "query.limit_offset",
           "Limit and offset a query",
           "#{@docs}/actions/read-actions.md",
           claims: [record: :limit, record: :offset],
           scenarios: ~w(record.limit_offset)
         ),
         feature("query.count", "Count and check existence", "#{@docs}/actions/read-actions.md",
           claims: [record: {:query_aggregate, :count}, record: {:query_aggregate, :exists}],
           scenarios: ~w(record.count)
         ),
         feature("query.stream", "Stream records in batches", "#{@docs}/actions/read-actions.md",
           claims: [record: :keyset],
           scenarios: ~w(record.stream)
         ),
         feature("query.distinct", "Distinct records by a field", "../lib/ash/query/query.ex",
           claims: [child: :distinct, child: :distinct_sort],
           scenarios: ~w(query.distinct)
         ),
         feature(
           "query.union",
           "Combine queries with union",
           "#{@docs}/advanced/combination-queries.md",
           claims: [child: :combine, parent: {:combine, :union}],
           scenarios: ~w(query.union)
         ),
         feature(
           "query.union_all",
           "Combine queries with union all and intersection",
           "#{@docs}/advanced/combination-queries.md",
           claims: [parent: {:combine, :union_all}, parent: {:combine, :intersection}],
           scenarios: []
         ),
         feature(
           "calc.expression",
           "Load expression calculations, with arguments",
           "#{@docs}/resources/calculations.md",
           claims: [record: :expression_calculation, record: :calculate],
           scenarios: ~w(record.calculation_load record.calculation_argument calc.in_memory)
         ),
         feature(
           "pagination.offset",
           "Offset pagination with counts",
           "#{@docs}/advanced/pagination.livemd",
           claims: [record: :offset],
           scenarios: ~w(record.offset_pages)
         ),
         feature(
           "pagination.keyset",
           "Keyset pagination, forwards and backwards",
           "#{@docs}/advanced/pagination.livemd",
           claims: [record: :keyset],
           scenarios: ~w(record.keyset_pages)
         ),
         feature(
           "pagination.concurrent",
           "Pagination while records change",
           "#{@docs}/advanced/pagination.livemd",
           claims: [],
           scenarios: []
         )
       ]},
      {5, "Relationships",
       [
         feature(
           "relationships.filter_to_many",
           "Filter across to-many relationships without duplicates",
           "#{@docs}/reference/expressions.md",
           claims: [child: {:filter_relationship, :ratings}],
           scenarios: ~w(filter.fanout_read_control use.fanout_read_page use.fanout_count)
         ),
         feature(
           "relationships.load_bounds",
           "Limit and offset a has-many load for each parent",
           "../test/actions/load_test.exs",
           claims: [parent: {:lateral_join, :children}],
           scenarios: ~w(load.limit_per_parent load.offset_per_parent)
         ),
         feature(
           "relationships.load_many_to_many_bounds",
           "Limit a many-to-many load for each parent",
           "../test/actions/load_test.exs",
           claims: [parent: {:lateral_join, :tags}],
           scenarios: ~w(load.many_to_many_limit_per_parent)
         ),
         feature(
           "relationships.through",
           "Relationships through other relationships",
           "#{@docs}/resources/relationships.md",
           claims: [parent: :through_relationship],
           scenarios: ~w(load.through)
         ),
         feature(
           "relationships.default_sort",
           "Relationship default sort applies when loading",
           "../test/query/default_sort_in_relationship_test.exs",
           claims: [parent: :sort],
           scenarios: ~w(bounds.default_sort_control)
         ),
         feature(
           "relationships.no_attributes",
           "Relationships with no attributes load everything",
           "#{@docs}/resources/relationships.md",
           claims: [parent: {:filter_relationship, :all_children}],
           scenarios: ~w(path.no_attributes_control)
         ),
         feature(
           "relationships.context",
           "Relationship context reaches the read action",
           "#{@docs}/resources/relationships.md",
           claims: [parent: :read],
           scenarios: ~w(context.relationship_context_control context.prepared_context_control)
         ),
         feature(
           "relationships.parent_references",
           "Parent references in nested and through relationship filters",
           "#{@docs}/reference/expressions.md",
           claims: [parent: {:filter_relationship, :same_tenant_tags}],
           scenarios: ~w(filter.parent_through_control filter.nested_parent_control)
         ),
         feature(
           "relationships.load",
           "Load belongs-to, has-one, has-many and many-to-many relationships",
           "#{@docs}/resources/relationships.md",
           claims: [child: {:filter_relationship, :parent}, parent: {:filter_relationship, :tags}],
           scenarios: ~w(load.belongs_to load.has_one load.has_many load.many_to_many)
         ),
         feature(
           "relationships.manage",
           "Create and update related records with manage_relationship",
           "#{@docs}/resources/relationships.md",
           claims: [],
           scenarios: []
         )
       ]},
      {6, "Aggregates",
       [
         feature(
           "aggregates.loaded",
           "Load each aggregate kind on records",
           "#{@docs}/resources/aggregates.md",
           claims:
             for(
               kind <- [:count, :sum, :avg, :min, :max, :exists, :first, :list, :custom],
               do: {:parent, {:aggregate, kind}}
             ),
           scenarios:
             ~w(loaded.count loaded.sum loaded.avg loaded.min loaded.max loaded.exists loaded.first loaded.list loaded.custom)
         ),
         feature(
           "aggregates.root",
           "Run each aggregate kind over a whole query",
           "#{@docs}/resources/aggregates.md",
           claims:
             for(
               kind <- [:count, :sum, :avg, :min, :max, :exists, :first, :list, :custom],
               do: {:child, {:query_aggregate, kind}}
             ),
           scenarios:
             ~w(root.count root.sum root.avg root.min root.max root.exists root.first root.list root.custom root.custom_empty root.list_empty root.list_default_empty root.list_unsorted root.unsorted_first_empty values.root_empty)
         ),
         feature(
           "aggregates.results",
           "Defaults, nils, uniqueness and field counts",
           "#{@docs}/resources/aggregates.md",
           claims: [parent: {:aggregate, :list}, parent: {:aggregate, :count}],
           scenarios:
             ~w(values.field_count values.distinct_count values.distinct_list values.include_nil_list values.include_nil_first values.scalar_default values.list_default values.filtered_first_default values.list_unsorted values.same_name_distinct_definitions values.string_name query.uniq_sum_rejected)
         ),
         feature(
           "aggregates.types",
           "Aggregate decimals, dates, times and constrained types",
           "#{@docs}/resources/aggregates.md",
           claims: [parent: {:aggregate, :sum}, parent: {:aggregate, :max}],
           scenarios:
             ~w(values.constrained_scalar values.string_constraints values.decimal_sum values.decimal_max values.decimal_avg root.decimal_sum values.date_min values.date_max values.date_list values.date_list_desc values.datetime_min values.datetime_max values.datetime_first values.time_min root.datetime_max)
         ),
         feature(
           "aggregates.ordering",
           "Order first and list aggregates, including nils and ties",
           "#{@docs}/resources/aggregates.md",
           claims: [parent: {:aggregate, :first}, parent: {:aggregate, :list}],
           scenarios:
             ~w(ordering.asc_nils_first ordering.asc_nils_last ordering.desc_nils_first ordering.desc_nils_last ordering.expression_first ordering.expression_list ordering.list_desc ordering.ties ordering.unique_other_field)
         ),
         feature(
           "aggregates.fields",
           "Aggregate calculations and other aggregates",
           "#{@docs}/resources/aggregates.md",
           claims: [parent: {:aggregate, :sum}],
           scenarios: ~w(field.aggregate field.calculation field.root_aggregate)
         ),
         feature(
           "aggregates.filters",
           "Filter the records an aggregate uses",
           "#{@docs}/resources/aggregates.md",
           claims: [parent: :aggregate_filter],
           scenarios:
             ~w(filter.ordinary filter.exists filter.not_exists filter.or_exists filter.join filter.sibling_independence)
         ),
         feature(
           "aggregates.fanout",
           "Aggregate filters through to-many relationships count each record once",
           "#{@docs}/resources/aggregates.md",
           claims: [child: {:filter_relationship, :ratings}],
           scenarios:
             ~w(filter.fanout_sum filter.fanout_avg filter.fanout_count filter.fanout_list filter.fanout_custom filter.fanout_and filter.fanout_or filter.fanout_count_records filter.fanout_nil_count filter.fanout_not_count identity.composite_fanout_count)
         ),
         feature(
           "aggregates.dependencies",
           "Aggregate filters that use other aggregates",
           "#{@docs}/resources/aggregates.md",
           claims: [child: :aggregate_filter],
           scenarios:
             ~w(filter.aggregate_dependency filter.aggregate_dependency_calculation filter.aggregate_dependency_filtered filter.aggregate_dependency_many_to_many filter.aggregate_dependency_to_one)
         ),
         feature(
           "aggregates.parent",
           "Aggregate filters that reference the parent record",
           "#{@docs}/reference/expressions.md",
           claims: [parent: {:aggregate_relationship, :above_threshold}],
           scenarios:
             ~w(filter.parent filter.parent_join filter.parent_relationship filter.parent_through filter.parent_unrelated filter.nested_parent use.parent_filter use.parent_sort)
         ),
         feature(
           "aggregates.paths",
           "Aggregate over to-one, multi-hop and many-to-many paths",
           "#{@docs}/resources/aggregates.md",
           claims: [parent: {:aggregate_relationship, :tags}, parent: {:aggregate, :unrelated}],
           scenarios:
             ~w(path.to_one path.through_count path.multi_hop path.many_to_many path.many_to_many_first path.many_to_many_list path.final_many_to_many_scalar path.final_many_to_many_first path.final_many_to_many_list path.final_many_to_many_custom path.intermediate_many_to_many path.repeated_many_to_many path.to_one_to_many_sum path.to_one_to_many_first path.to_one_to_many_list path.unrelated path.root_relationship)
         ),
         feature(
           "aggregates.special_relationships",
           "Aggregate over manual and attribute-free relationships",
           "#{@docs}/resources/relationships.md",
           claims: [
             parent: {:aggregate_relationship, :manual_children},
             parent: {:aggregate_relationship, :all_children}
           ],
           scenarios: ~w(path.manual path.no_attributes path.no_attributes_parent)
         ),
         feature(
           "aggregates.bounds",
           "Aggregate over limited, offset and from-many relationships",
           "#{@docs}/resources/relationships.md",
           claims: [parent: {:aggregate_relationship, :top_children}],
           scenarios:
             ~w(bounds.relationship_limit bounds.relationship_offset bounds.relationship_offset_only bounds.filter_after_limit bounds.list_filter_after_limit bounds.unsorted_limit bounds.from_many bounds.default_sort bounds.many_to_many_query_limit)
         ),
         feature(
           "aggregates.root_bounds",
           "Root aggregates over sorted, limited and offset queries",
           "#{@docs}/resources/aggregates.md",
           claims: [child: {:query_aggregate, :sum}, child: :limit],
           scenarios:
             ~w(bounds.root_limit bounds.root_zero bounds.root_offset_only bounds.root_order_then_limit bounds.root_first_distinct_sort bounds.root_list_limit bounds.root_custom_limit)
         ),
         feature(
           "aggregates.identity",
           "Distinct counts over composite and missing keys",
           "#{@docs}/resources/aggregates.md",
           claims: [parent: :composite_primary_key],
           scenarios:
             ~w(identity.composite_count identity.root_composite_count identity.keyless_count identity.keyless_distinct identity.keyless_source)
         ),
         feature(
           "aggregates.usage",
           "Filter, sort, paginate and calculate with aggregates",
           "#{@docs}/resources/aggregates.md",
           claims: [parent: :aggregate_filter, parent: :aggregate_sort],
           scenarios:
             ~w(use.filter use.sort use.calculation use.pagination use.keyset_pagination use.related_filter use.related_exists use.to_one_filter use.to_one_sort use.nested_limited_load)
         ),
         feature(
           "aggregates.context",
           "Aggregates respect read actions, arguments, actor and context",
           "#{@docs}/resources/aggregates.md",
           claims: [parent: {:aggregate_relationship, :children}],
           scenarios:
             ~w(context.read_action context.arguments context.actor context.shared context.intermediate_action context.intermediate_actor context.through_arguments context.prepared_query_arguments context.relationship_context)
         ),
         feature(
           "aggregates.generated",
           "Seeded filtered aggregates match an in-memory reference",
           "#{@docs}/resources/aggregates.md",
           claims: [parent: {:aggregate, :count}, child: {:query_aggregate, :count}],
           scenarios: ~w(generated.filtered_aggregates)
         )
       ]},
      {7, "Writes",
       [
         feature(
           "writes.upsert",
           "Upsert on an identity, in bulk, with conditions",
           "#{@docs}/actions/create-actions.md",
           claims: [
             tenant_item: :upsert,
             tenant_item: {:atomic, :upsert},
             tenant_item: :bulk_upsert_return_skipped
           ],
           scenarios:
             ~w(upsert.tenant_identity upsert.bulk upsert.condition upsert.skipped_record)
         ),
         feature(
           "writes.bulk_create",
           "Bulk create with partial success",
           "../test/actions/bulk/bulk_create_test.exs",
           claims: [tenant_item: :bulk_create, tenant_item: :bulk_create_with_partial_success],
           scenarios: ~w(bulk.partial_success)
         ),
         feature(
           "writes.bulk_update",
           "Bulk update atomically",
           "#{@docs}/actions/update-actions.md",
           claims: [tenant_item: :update_query, tenant_item: {:atomic, :update}],
           scenarios: ~w(bulk.atomic_increment)
         ),
         feature(
           "writes.aggregates",
           "Writes that filter by or read aggregates",
           "#{@docs}/actions/update-actions.md",
           claims: [parent: :update_query, parent: :destroy_query],
           scenarios:
             ~w(write.bulk_update_filter write.bulk_destroy_filter write.atomic_update write.single_atomic_update)
         )
       ]},
      {8, "Transactions and locks",
       [
         feature(
           "transactions.rollback",
           "Failed actions and transactions roll back",
           "#{@docs}/advanced/multi-step-actions.md",
           claims: [ledger: :transact],
           scenarios:
             ~w(txn.after_action_rollback txn.raise_rollback txn.explicit_rollback txn.commit)
         ),
         feature("transactions.locks", "Lock rows for update", "../lib/ash/query/query.ex",
           claims: [parent: {:lock, :for_update}],
           scenarios: ~w(query.lock_for_update)
         ),
         feature(
           "transactions.isolation",
           "Isolation between concurrent transactions",
           "#{@docs}/advanced/multi-step-actions.md",
           claims: [ledger: :transact],
           scenarios: []
         )
       ]},
      {9, "Multitenancy",
       [
         feature(
           "tenancy.reads",
           "Attribute tenancy scopes reads and requires a tenant",
           "#{@docs}/advanced/multitenancy.md",
           claims: [tenant_parent: :filter],
           scenarios:
             ~w(tenant.read tenant.identities tenant.missing tenant.invalid tenant.unknown tenant.explicit_global)
         ),
         feature(
           "tenancy.relationships",
           "Tenancy scopes related records and their bounds",
           "#{@docs}/advanced/multitenancy.md",
           claims: [tenant_parent: :filter],
           scenarios:
             ~w(tenant.relationship_load tenant.relationship_filter tenant.bounds tenant.from_many)
         ),
         feature(
           "tenancy.aggregates",
           "Tenancy scopes aggregates, including explicit bypass",
           "#{@docs}/advanced/multitenancy.md",
           claims: [tenant_parent: {:aggregate, :count}],
           scenarios:
             ~w(tenant.loaded_aggregates tenant.root_aggregates tenant.aggregate_filter_sort context.attribute_tenant context.through_tenant context.tenant_bypass context.bypass_sibling context.through_bypass)
         ),
         feature(
           "tenancy.pagination",
           "Tenancy scopes pages and counts",
           "#{@docs}/advanced/multitenancy.md",
           claims: [tenant_parent: :offset, tenant_parent: :keyset],
           scenarios: ~w(tenant.aggregate_offset_page tenant.aggregate_keyset_pages)
         ),
         feature(
           "tenancy.writes",
           "Tenancy scopes creates, updates and destroys",
           "#{@docs}/advanced/multitenancy.md",
           claims: [tenant_item: :update, tenant_item: :destroy_query],
           scenarios: ~w(write.lifecycle tenant.write_local_identity tenant.write_bulk_destroy)
         ),
         feature(
           "tenancy.context",
           "Schema-based (context) tenancy",
           "#{@docs}/advanced/multitenancy.md",
           claims: [],
           scenarios:
             ~w(schema.direct schema.relationships schema.loaded_aggregates schema.root_aggregate schema.filtered_page)
         )
       ]},
      {10, "Authorization",
       [
         feature(
           "authorization.reads",
           "Policies filter reads",
           "../test/policy/context_shared_test.exs",
           claims: [secure_parent: :filter],
           scenarios: ~w(auth.read auth.children auth.context_read)
         ),
         feature(
           "authorization.relationships",
           "Policies filter related records before bounds",
           "../test/policy/context_shared_test.exs",
           claims: [secure_parent: :filter],
           scenarios:
             ~w(auth.relationship_load auth.context_relationship auth.bounds auth.from_many context.authorization_bounds_control)
         ),
         feature(
           "authorization.aggregates",
           "Policies filter what aggregates count",
           "#{@docs}/resources/aggregates.md",
           claims: [secure_parent: {:aggregate, :count}],
           scenarios:
             ~w(auth.loaded_aggregates auth.root_aggregates auth.aggregate_filter auth.aggregate_sort auth.context_aggregates auth.context_root context.authorization context.authorization_before_bounds)
         ),
         feature(
           "authorization.pagination",
           "Policies filter pages and counts",
           "../test/policy/context_shared_test.exs",
           claims: [secure_parent: :offset],
           scenarios: ~w(auth.offset_page auth.keyset_pages auth.tenant_interaction)
         ),
         feature("authorization.writes", "Policies filter and forbid writes", "../lib/ash.ex",
           claims: [secure_item: :update_query, secure_item: :destroy_query],
           scenarios:
             ~w(auth.write_bulk_update_atomic auth.write_bulk_update_stream auth.write_bulk_destroy auth.write_forbidden)
         )
       ]},
      {11, "Policies", policies()},
      {12, "Consistency checks",
       [
         feature(
           "consistency.equivalences",
           "Counts match loads, and root sums match an in-memory reference",
           "#{@docs}/resources/aggregates.md",
           claims: [secure_parent: {:aggregate, :count}],
           scenarios: ~w(equivalence.visible_count_load equivalence.root_reference)
         )
       ]}
    ]
  end

  # One feature per tier-1 type: its values round-trip unchanged.
  defp storage do
    for type <- Ash.Conformance.Storage.types() do
      feature(
        "storage.#{type.name}",
        type.label,
        "../lib/ash/type/type.ex",
        claims: [],
        scenarios:
          Enum.map(
            Ash.Conformance.Storage.cells(type),
            &Ash.Conformance.Storage.scenario_id(type.name, &1)
          )
      )
    end
  end

  @policy_titles %{
    "owner" => "A filter policy on the actor",
    "owner_nil_actor" => "The same policy with no actor",
    "forbid" => "forbid_if before authorize_if",
    "bypass" => "A bypass policy, for an actor it does not let through",
    "bypass_admin" => "A bypass policy, for an actor it lets through",
    "all_of" => "Two policies that must both pass",
    "any_of" => "One policy whose checks either pass",
    "related" => "A policy on a to-one relationship",
    "member" => "A policy on a multi-hop exists",
    "can_read" => "A policy composed with can_read",
    "strict" => "A strict policy, for an actor it forbids",
    "strict_admin" => "A strict policy, for an actor it allows"
  }

  # One feature per policy case, each on every path; then field policies,
  # filter checks on create, and the paths without authorization.
  defp policies do
    ids = Enum.map(Ash.Conformance.Scenarios.Policies.all(), & &1.id)
    with_prefix = fn prefix -> Enum.filter(ids, &String.starts_with?(&1, prefix)) end
    basis = "#{@docs}/security/policies.md"

    cases =
      for {case_id, _shape, _actor} <- Ash.Conformance.Policy.cases() do
        scenarios =
          "policy.#{case_id}."
          |> with_prefix.()
          |> Enum.reject(&String.contains?(&1, ".create_"))

        feature("policy.#{case_id}", Map.fetch!(@policy_titles, case_id), basis,
          claims: [],
          scenarios: scenarios
        )
      end

    cases ++
      [
        feature(
          "policy.field",
          "Field policies hide values, in reads, filters and aggregates",
          basis,
          claims: [],
          scenarios: with_prefix.("policy.field.")
        ),
        feature("policy.create", "A filter check on create runs after the insert", basis,
          claims: [policy_owner_note: :transact],
          scenarios: ~w(policy.owner.create_own policy.owner.create_other)
        ),
        feature("policy.controls", "Every policy path, without authorization", basis,
          claims: [],
          scenarios: with_prefix.("policy.control.")
        )
      ]
  end

  def all do
    for {level, section, features} <- sections(), feature <- features do
      feature |> Map.put(:level, level) |> Map.put(:section, section)
    end
  end

  def claims_for(scenario_id) do
    Enum.find_value(all(), [], fn feature ->
      if scenario_id in feature.scenarios, do: feature.claims
    end)
  end

  defp feature(id, title, basis, opts) do
    %{
      id: id,
      title: title,
      semantic_basis: basis,
      claims: Keyword.fetch!(opts, :claims),
      scenarios: Keyword.fetch!(opts, :scenarios)
    }
  end

  @doc """
  A feature's status on one adapter, from its scenarios' contract statuses.

  Scenarios that never ran (`:unknown`, such as a fixture the data layer could
  not store) say nothing about the feature, so the verdict comes from the rest:

  - `:works`: every scenario ran and returns the intended answer.
  - `:incomplete`: everything that ran works, but some scenarios could not run.
  - `:partial`: some work; others are unsupported or defective.
  - `:not_supported`: every scenario that ran is a documented rejection.
  - `:broken`: nothing that ran works, and at least one scenario is defective.
  - `:open_question`: the only non-working scenarios await a semantic decision.
  - `:unknown`: no scenario could run.
  - `:untested`: no scenario verifies it yet.
  - `:not_applicable`: the adapter does not provide this profile.
  """
  def status(%{scenarios: []}, _statuses), do: :untested
  def status(_feature, []), do: :not_applicable

  def status(_feature, statuses) do
    case Enum.reject(statuses, &(&1 == :unknown)) do
      [] ->
        :unknown

      ran ->
        case verdict(ran) do
          :works when length(ran) < length(statuses) -> :incomplete
          verdict -> verdict
        end
    end
  end

  defp verdict(statuses) do
    counts = Enum.frequencies(statuses)
    supported = Map.get(counts, :supported, 0)
    defects = Map.get(counts, :known_defect, 0)
    unsupported = Map.get(counts, :unsupported, 0)

    cond do
      supported == length(statuses) -> :works
      defects == 0 and unsupported == 0 -> :open_question
      supported == 0 and defects == 0 -> :not_supported
      supported == 0 -> :broken
      true -> :partial
    end
  end
end
