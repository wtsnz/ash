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
      }
    ]
  end
end
