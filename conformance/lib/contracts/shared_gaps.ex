# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Contracts.SharedGaps do
  @moduledoc """
  Gaps every data layer shares: Ash's own defects and the semantic decisions
  Ash has not settled. Rendered into `GAPS.md` by `mix conformance.gaps`.
  """

  def all do
    [
      %{
        id: "in-simplification",
        title: "In simplification",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""

        Keep nil logic when simplifying `in` filters. Ash rewrites `not (a in [0]
        and a in [1])` to `true` while it builds the query, as no value is in both
        lists. For a nil `a` the conjunction is nil, not false, so the negation should
        drop the row, as SQL does and as the same filter written with `==` does.
        Every data layer receives `true` and returns every row
        (`nil.not_contradictory_in`). Found by generated filters (`lib/fuzz.ex`),
        shrunk to `(a in [0] and a in [1])`.
        """
      },
      %{
        id: "runtime-nil-logic",
        title: "Runtime nil logic",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""

        Evaluate `and` and `or` with a nil operand as SQL does, in either order. The
        expressions guide says nil behaves like SQL `NULL`, where `NULL AND FALSE` is
        false and `NULL OR FALSE` is `NULL`. Ash's in-memory evaluation
        (`Ash.Expr.eval/2`, `Ash.Filter.Runtime`, and so the ETS data layer) returns
        nil for `nil and false` but false for `false and nil`, and false for `nil or
        false`. A negated filter then keeps or drops the wrong rows:
        `nil.not_and_false` and `nil.not_or_false`. SQLite and Postgres return the SQL
        answers. Found by generated filters (`lib/fuzz.ex`), shrunk to
        `(a == 0 and string_length(t) > 2)` on row 3 (`a` nil, `t` "x").
        """
      },
      %{
        id: "authorized-action-arguments",
        title: "Authorized action arguments",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""
        Keep a prepared query's arguments when authorizing its path. An aggregate
        whose `query:` is prepared for a read action with arguments
        (`Ash.Query.for_read(child, :by_label, %{label: "high"})`) works with
        authorization off. With `authorize?: true`, even on resources with no
        authorizer, Ash raises "argument label is required": `relationship_query/6`
        in `Ash.Filter` takes the action name from the prepared query but builds a
        new query with only the relationship's `read_action_arguments`. Reproduced on
        ETS. Found by the `authorize` variant (`context.prepared_query_arguments`).
        """
      },
      %{
        id: "operator-signature-cast",
        title: "Operator signature cast",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""
        Try the next operator signature when a literal can't be cast to this one.
        `Ash.Query.Operator.try_cast_with_ref/3` walks the operator's `types/0` with
        `Enum.find_value/2`, and `cast_one/2` returns `{:error, ...}` when a literal
        doesn't fit, which ends the search. So `d / ^Decimal.new("0.5")` stops at
        `/`'s first signature, `[:float, :float]`, and raises "Could not cast
        Decimal.new(\"0.5\") as :float" on every data layer, before any query runs
        (`sig.div.decimal_decimal`, `sig.div.float_decimal`, `sig.div.integer_decimal`).
        Dividing by a column or a plain number works. Found by the signature tier.
        """
      },
      %{
        id: "runtime-round-integer",
        title: "Runtime round integer",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""
        Return an integer from `round/1-2` of an integer. `Round` declares `:integer`
        for `[:integer]` and `[:integer, :integer]`, but Ash's in-memory evaluation
        returns `7.0` for `round(7)`, so an integer calculation over it fails to cast
        ("is invalid") on ETS and in any in-memory calculation. SQL data layers are
        right (`sig.round.integer`, `sig.round.integer_places`).
        """
      },
      %{
        id: "runtime-ci-split",
        title: "Runtime CI split",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""
        Split a case-insensitive string into a list. Ash's in-memory evaluation of
        `string_split(ci, "e")` on `"HeLLo"` returns the single value
        `#Ash.CiString<"hllo">` (downcased, with the separator removed) instead of
        `["H", "LLo"]`, and a calculation over it then crashes. It also happens when
        only the separator is case-insensitive. Postgres returns the list
        (`sig.string_split.ci*`, `sig.string_split.ci_separator_trim`).
        """
      },
      %{
        id: "runtime-usec-calculation",
        title: "Runtime usec calculation",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""
        Keep microseconds when an in-memory calculation adds a duration to a
        `utc_datetime_usec` or `time_usec`. `Ash.Expr.eval/2` of `at + ^hour` against a
        record keeps them, but the same expression read as a calculation on ETS
        returns whole seconds, so the loss is in the calculation path, not the
        arithmetic. Postgres keeps them (`sig.plus.usec_duration`,
        `sig.minus.time_usec_duration` and their mirrors).
        """
      },
      %{
        id: "integer-overflow",
        title: "Integer overflow",
        kind: :decision,
        owners: [:ash],
        body: ~S"""
        Decision: what does integer arithmetic past 64 bits return? The expressions
        guide says operators behave as in Elixir, where `9223372036854775807 + 1` is
        `9223372036854775808`, but SQL integers are 64-bit. Postgres raises "bigint
        out of range"; SQLite silently returns 9223372036854775807. Until Ash
        decides, `edge.plus.integer_overflow` is unresolved and each reviewed data
        layer pins what it does.
        """
      },
      %{
        id: "at-negative-index",
        title: "At negative index",
        kind: :decision,
        owners: [:ash],
        body: ~S"""
        Decision: does `at(list, -1)` count from the end? Ash's evaluation uses
        `Enum.at/2`, so it returns the last element; the guide only says "get an
        element from a list". AshSQL renders `list[index + 1]`, so on Postgres -1
        reads index 0, which is nil. Until Ash decides, `edge.at.negative_index` is
        unresolved.
        """
      },
      %{
        id: "in-list-nil",
        title: "In list nil",
        kind: :decision,
        owners: [:ash],
        body: ~S"""

        Decision: is `x in [7, nil]` nil or false when `x` is neither 7 nor nil? The
        expressions guide says nil behaves like SQL `NULL`, where `-7 IN (7, NULL)`
        is `NULL`, so `not (a in [7, nil])` keeps no row but 7's. Ash's in-memory
        evaluation says `false`, so the negation keeps `-7` and `0`. The positive
        filter agrees either way (`record.filter_in_with_nil`). Until Ash decides,
        `nil.not_in_with_nil` is unresolved and each reviewed data layer pins what
        it returns.
        """
      },
      %{
        id: "decimal-avg",
        title: "Decimal avg",
        kind: :decision,
        owners: [:ash],
        body: ~S"""

        Decision: is the average of a decimal field a float or a Decimal? Ash
        declares every `avg` aggregate as a float
        (`Ash.Query.Aggregate.kind_to_type/2`), and AshPostgres and AshSqlite
        return floats. Ash's own ETS data layer averages Decimals exactly and
        returns a Decimal (`Decimal.new("0.15")` for 0.1 and 0.2), added in "Add
        `:decimal` aggregate support to `DataLayer.Ets`" (#841). The aggregate
        guide does not say. A float also loses precision: 12345678901234567.89 and
        0.01 average to `6172839450617284.0`. Until Ash decides,
        `values.decimal_avg` is unresolved, and each reviewed data layer pins what
        it returns. The suite's aggregate helpers used to round Decimals to floats,
        which hid this difference.
        """
      },
      %{
        id: "bulk-stream-forbidden",
        title: "Bulk stream forbidden",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""

        Return a forbidden bulk destroy as an error result. `Ash.bulk_destroy/4`
        with `return_errors?: true` raises `Ash.Error.Forbidden` when the stream
        strategy's read is forbidden: a strict policy, or a filter check on the
        actor with no actor. The raise comes from the read inside the strategy
        (`Ash.Actions.Read.run/3`). Nothing is destroyed. Data layers that take
        the atomic strategy, such as Postgres and ETS, return a `BulkResult` with
        the forbidden error; SQLite falls back to streaming and raises.
        """
      },
      %{
        id: "relationship-context",
        title: "Relationship context",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""

        Make relationship context available before read preparation and avoid retaining
        an earlier filter prepared without it. Both the aggregate and direct
        relationship-load controls return no rows. An explicitly prepared child query
        with the same context returns the two intended records, and parent shared
        context also works. This needs Ash-level investigation as well as adapter work.
        """
      },
      %{
        id: "path-multiplicity",
        title: "Path multiplicity",
        kind: :decision,
        owners: [:ash],
        body: ~S"""

        Decision: when a destination is reached through two different relationship
        paths, does a fieldless count count path occurrences or distinct destinations?
        The repeated many-to-many scenario currently returns three and two in Postgres;
        SQLite rejects the path. These are strict observations, not accepted semantics.
        """
      },
      %{
        id: "keyless-identity",
        title: "Keyless identity",
        kind: :decision,
        owners: [:ash],
        body: ~S"""

        Decision: define distinct-record semantics when the destination has no primary
        key. PostgreSQL currently counts rows and SQLite rejects the operation. Do not
        choose an arbitrary attribute, concatenate values, or assume a SQL rowid exists
        for every resource.
        """
      },
      %{
        id: "many-to-many-bounds-api",
        title: "Many-to-many bounds API",
        kind: :decision,
        owners: [:ash],
        body: ~S"""

        Decision: expose relationship limits/offsets for many-to-many aggregates in Ash.
        The current many-to-many DSL has no `limit` option and `Ash.Query.aggregate`
        rejects a limited target query before either adapter runs. This corrects the
        earlier assumption that the grouped guard alone was blocking a public feature.
        Add the API and settle per-parent ordering before a conformance result is fixed.
        """
      },
      %{
        id: "true-or-nil",
        title: "True or nil",
        kind: :decision,
        owners: [:ash],
        body: ~S"""

        Decision: does `true or nil` evaluate to true, as in SQL, or to nil, as Ash's
        expression guide states? The guide says nil "poisons" `and`, `or` and `not`,
        so `true or nil` returns nil. SQL returns true for `TRUE OR NULL`. With the
        filter `active == true or quantity > 5`, record 7 (active, nil quantity) is
        included if the answer is true and excluded if it is nil. The current results
        are recorded as observations until Ash decides which answer is intended.
        """
      },
      %{
        id: "unique-list-order",
        title: "Unique list order",
        kind: :decision,
        owners: [:ash],
        body: ~S"""

        Decision: choose which occurrence supplies the ordering value when duplicate
        list values have different sort keys. SQLite rejects this shape; Postgres
        raises its DISTINCT/ORDER BY restriction. A representative-row rule would need
        to be defined and implemented for both adapters.
        """
      },
      %{
        id: "value-representation",
        title: "Value representation",
        kind: :decision,
        owners: [:ash],
        body: ~S"""

        Decision: does a value that reads back equal by its type, but in a different
        representation, count as stored unchanged? Postgres returns a `Duration` of
        1 hour 30 minutes with microsecond precision `{0, 6}` added, which is the same
        duration by `Duration`'s own fields but not the same struct. The same question
        covers decimals read back with extra scale (`1.5` as `1.5000000000`) and
        second-precision datetimes read back with microseconds. The storage grid
        reports these as "changed", separately from lost values. The cell is recorded
        as a known defect, linked here, until Ash decides.
        """
      },
      %{
        id: "union-nil",
        title: "Union nil",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""

        Setting a union attribute to nil stores a union that wraps nil. Updating a
        value of `%Ash.Union{type: :text, value: "five"}` to nil reads back as
        `%Ash.Union{type: :text, value: nil}` on every data layer, ETS included. The
        cause is `Ash.Type.Union.handle_change/3` (`lib/ash/type/union.ex`), whose
        clause for a change from a union to nil keeps the old member type. Creating a
        record with nil stores nil.
        """
      },
      %{
        id: "through-limit-one",
        title: "Through limit one",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""

        Keep a `through` relationship's path when its load has a limit of 1. Ash
        marks every `through` relationship `no_attributes?: true`, so its path only
        applies in the lateral join. `lateral_join?/4` (`lib/ash/actions/read/relationships.ex`)
        returns false before reaching its `through` clause when the load's limit is
        1 and either one record is loaded or the relationship is a `has_one` with no
        sort, filter or context of its own. The load then reads the destination with
        no link to the record. Loading event 1's customers sorted by name descending
        with a limit of 1 returns customer 5, which has no order for event 1; an
        offset of 1 returns customer 6, which has no orders at all; and an unsorted
        `has_one through` loaded with a limit of 1 gives every event customer 5
        (`adv.plain.through_limit_one`, `adv.plain.through_offset`,
        `adv.plain.has_one_limit`, and their tenant and schema forms). Two records
        loaded together take the lateral join and are right
        (`adv.plain.through_limit_one_each`). The same happens on every data layer
        that supports `through`.
        """
      },
      %{
        id: "join-resource-policies",
        title: "Join resource policies",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""

        Apply the join resource's read policy to aggregates over `many_to_many` and
        `through` relationships, and to `filter_input` on a `many_to_many`. The
        policies guide says aggregates always authorize the related data they
        reference, and that an input filter's relationship path applies each related
        resource's read policy. Loads do: event 1's `buyers` and `customers` leave
        out customer 3, whose only order is hidden. `count`, `list`, `first` and
        `exists` aggregates over the same relationships count and return customer 3,
        and `filter_input(%{buyers: %{id: %{eq: 3}}})` matches event 1
        (`adv.join_policy.*`). The plain `orders` path is right
        (`adv.join_policy.path_aggregates`, `adv.join_policy.path_filter_input`),
        and so is `filter_input` through a `through` relationship. Aggregates add
        policy filters for the intermediate relationships of their own path
        (`add_join_filters/5` in `lib/ash/actions/read/read.ex`), and a
        `many_to_many` or `through` relationship is one step of that path. The decoy
        variant finds the same on its hidden decoy orders, which double the counts.
        """
      },
      %{
        id: "bulk-stream-tenant",
        title: "Bulk stream tenant",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""

        Apply attribute multitenancy to each record in the `:stream` strategy of
        `Ash.bulk_update/4` and `Ash.bulk_destroy/4`. Given organisation 1's note 101
        and organisation 2's note 201 with `tenant: 1`, the `:atomic` and
        `:atomic_batches` strategies change only 101. `:stream`, and
        `[:atomic, :stream]` with an action that can't run atomically, change or
        delete both and return both (`adv.foreign.bulk_*`), as do records read across
        tenants with no tenant of their own
        (`adv.foreign.bulk_update.stream_global_records`). The single-record actions
        add the tenant filter in `handle_attribute_multitenancy/1`; the stream path
        calls the data layer's `update`/`destroy` without it. On data layers without
        the `:expr_error` capability, such as AshSQLite, Ash runs every bulk destroy
        of records as `:stream`, so `:atomic` and `:atomic_batches` destroys delete
        201 there too.
        """
      },
      %{
        id: "destroy-record-tenant",
        title: "Destroy record tenant",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""

        Keep a destroy changeset's tenant. `Ash.Changeset.for_destroy(note_201,
        :destroy, %{}, tenant: 1) |> Ash.destroy()` deletes organisation 2's note
        201: `Ash.destroy/2` fills `tenant` from the record's metadata and
        `Ash.Actions.Destroy` sets it on the changeset, replacing tenant 1. The same
        changeset for an update, and `Ash.destroy(note_201, tenant: 1)`, are refused
        (`adv.foreign.destroy_changeset`, against `adv.foreign.update_changeset` and
        `adv.foreign.destroy_option`).
        """
      },
      %{
        id: "write-result-field-policies",
        title: "Write result field policies",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""

        Apply field policies inside embedded values to create, update and destroy
        results. A read by a non-admin hides the top-level `secret`, the embedded
        `profile.ssn`, each embedded card's `number` in an array, and the card
        `number` inside a union (`adv.field_write.read_control`). The records
        returned by `Ash.create`, `Ash.update`, `Ash.destroy` with
        `return_destroyed?`, `Ash.bulk_create` and atomic bulk updates and destroys
        hide `secret` but show the embedded values (`adv.field_write.*`). Reads clean
        field-policy results recursively; action results only clean top-level
        fields (`restrict_field_access/2` in `lib/ash/actions/helpers.ex`). The
        `:stream` strategies hide them. On AshPostgres the atomic strategies also
        leave out `order_count`, an aggregate loaded on the bulk query.
        """
      },
      %{
        id: "aggregate-reference-authorization",
        title: "Aggregate reference authorization",
        kind: :implementation,
        owners: [:ash],
        body: ~S"""

        Authorize the related data of an aggregate wherever it is referenced. The
        policies guide says aggregates "referenced *anywhere* will *always*
        authorize access to the related data they reference". Found by the decoy
        variant, whose hidden children and ratings belong to real parents and
        children. With authorization on, these count the hidden rows on SQLite,
        Postgres and ETS:

        - an aggregate in an atomic update, `atomic_update(:threshold,
          expr(child_count))`, in bulk and single updates (`write.atomic_update`,
          `write.single_atomic_update`);
        - an aggregate in the query given to an atomic `Ash.bulk_update/4`:
          `filter(child_sum > 5)` updates parent 2, whose only visible child has
          value 4 (`write.bulk_update_filter`);
        - an aggregate as the field of a root aggregate, `Ash.aggregate(parent,
          {:result, :sum, field: :child_count})` (`field.root_aggregate`; ETS
          returns nil for this one with or without decoys).

        On Postgres and ETS, but not SQLite, an aggregate in another aggregate's
        query filter (`count(children, query: filter(rating_count > 1))`) counts
        hidden ratings too (`filter.aggregate_dependency*`).
        """
      },
      %{
        id: "all-tenants-upsert",
        title: "All-tenants upsert",
        kind: :decision,
        owners: [:ash],
        body: ~S"""

        Decision: may an upsert in one tenant update or return another tenant's row
        through an identity with `all_tenants?: true`? The multitenancy guide says
        such an identity is unique across tenants and that a create in a second
        tenant fails, but not what an upsert does. Ash uses only the identity's keys
        as the conflict target for these identities, so an upsert of code `"n2-1"`
        in organisation 1 updates organisation 2's note 201 on every data layer
        (`adv.upsert.all_tenants`). With a condition that skips it and
        `return_skipped_upsert?`, AshPostgres returns note 201
        (`adv.upsert.all_tenants_skipped_bulk`). Until Ash decides, both are
        unresolved and each reviewed data layer pins what it does.
        """
      }
    ]
  end
end
