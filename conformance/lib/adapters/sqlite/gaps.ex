# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Sqlite.Gaps do
  @moduledoc """
  Gaps only SQLite shows. Rendered into `GAPS.md` by `mix conformance.gaps`.
  """

  def all do
    [
      %{
        id: "error-expressions",
        title: "Error expressions",
        kind: :limitation,
        owners: [:ash_sqlite],
        body: ~S"""
        Limitation: AshSqlite has no error expressions.

        Ash's policy guide lists `authorize_with: :error`, which reports a hidden
        record as forbidden instead of not found, for "all of the core data layers
        except AshSqlite". Reading with it raises a `RuntimeError` asking for the
        `ash-functions` extension, which AshSqlite does not provide, instead of a
        rejection from `can?/2`. Every `policy.*.get_error` scenario records it.
        """
      },
      %{
        id: "root-kinds",
        title: "Root kinds",
        kind: :implementation,
        owners: [:ash_sql, :ash_sqlite],
        body: ~S"""
        AshSQLite enables the kinds in `can?({:query_aggregate, kind})`.

        Add root SQLite custom and list aggregates. Reuse bounded root inputs,
        custom expressions, windowed JSON lists, result types and defaults. An empty
        input produces no window row, so apply list defaults outside the window. Promote
        each kind with its empty, default and bounded scenarios.
        """
      },
      %{
        id: "many-to-many-paths",
        title: "Many-to-many paths",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""

        Generalize grouped input construction for intermediate many-to-many hops and
        first/list/custom at the end of a multi-hop path. Carry attachment identity
        through each prepared through and destination input. Scalar final-hop,
        single-hop list/first, empty-parent and shared-destination controls pass.
        """
      },
      %{
        id: "parent-correlation",
        title: "Parent correlation",
        kind: :implementation,
        owners: [:ash_sql, :ash_sqlite],
        body: ~S"""
        AshSQLite's `can?` gates reject parent-dependent relationships, so they change
        too.

        Support parent values in grouped relationship, aggregate, join and unrelated
        filters. Prototype correlated scalar queries or parent-inclusive grouped input.
        Keep relationship scope before bounds and aggregate predicates after them.
        The public query options must hydrate parent references against the parent;
        prehydrating a child query with no parent context is not equivalent.
        Parent-dependent through filters and inline aggregates used in parent filters
        and sorts follow the same path. Postgres returns the intended results for
        both.
        """
      },
      %{
        id: "manual",
        title: "Manual",
        kind: :implementation,
        owners: [:ash_sql, :ash_sqlite],
        body: ~S"""
        AshSQLite's `can?` gate and manual relationship callbacks change too.

        Support SQL-capable manual relationships using existing adapter join/subquery
        callbacks where possible. The shared fixture is a normal foreign-key manual
        relationship. Non-equality callbacks and nested parent aliases need further
        scenarios before broader support is advertised.
        """
      },
      %{
        id: "filter-dependencies",
        title: "Filter dependencies",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""

        Attach aggregate dependencies to the endpoint input before compiling its filter.
        The scenarios count children with more than one rating or with any tag, and
        sum children with two ratings above five. A calculation over an aggregate is
        also a dependency. A dependency on the parent's aggregate, through a to-one
        relationship, already works on SQLite. Add alias
        and cycle cases as the implementation expands.
        """
      },
      %{
        id: "record-identity",
        title: "Record identity",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""

        Support distinct record counts with all components of a composite key. Grouped
        counts currently reject them explicitly. Include attachment keys in the
        deduplication subquery. Loading aggregates on keyless source resources is also
        rejected by grouped; determine which operations can use relationship keys and
        which require an explicit row identity. Ordinary keyless destination counts
        already work.
        """
      },
      %{
        id: "sorted-distinct-reads",
        title: "Sorted distinct reads",
        kind: :implementation,
        owners: [:ash_sqlite, :ash_sql],
        body: ~S"""
        The regression enters through AshSQLite #232. The fix may belong in
        `AshSql.Query.return_query/2`, which both adapters use.

        Keep sorted SQLite reads distinct when a filter joins a to-many relationship.
        This is a regression in AshSQLite #232, not an aggregate gap: upstream
        AshSQLite returns the two matching children. #232 adds `return_query/2`, so
        sorted DISTINCT queries go through `AshSql.Query.return_query/2`. That selects
        `row_number() OVER "order"` inside the DISTINCT subquery. Postgres deduplicates
        with `DISTINCT ON`, which the row number does not affect. SQLite's plain
        `DISTINCT` keeps every joined row, so a sorted page of two returns child 11
        twice and omits child 12 while the page count is two. Unsorted reads and
        `Ash.count` are unaffected.
        """
      },
      %{
        id: "decimal-precision",
        title: "Decimal precision",
        kind: :implementation,
        owners: [:ash_sqlite],
        body: ~S"""

        Keep decimal values and sums exact on SQLite. A `DECIMAL` column has numeric
        affinity, so SQLite stores 12345678901234567.89 as the float
        12345678901234568 even though ecto_sqlite3 writes decimals as text. The direct
        read control shows the loss happens on write, before any aggregate runs. Sums
        are also floating point: 0.1 and 0.2 sum to 0.30000000000000004. Postgres
        returns the exact values.

        SQLite has no exact decimal arithmetic built in. Options include storing
        decimals as text and using SQLite's optional decimal extension, or documenting
        the limit. Averages are floats in Ash, so they match after rounding. Dates,
        times and microsecond datetimes aggregate correctly on both adapters.
        """
      },
      %{
        id: "query-distinct",
        title: "Query distinct",
        kind: :implementation,
        owners: [:ash_sqlite],
        body: ~S"""

        Support `Ash.Query.distinct/2`. AshSQLite does not advertise `:distinct`, so
        Ash rejects the query with "Data layer does not support distincting". Ash's
        distinct keeps one record per distinct value, chosen by the sort, like
        Postgres's `DISTINCT ON`. SQLite has no `DISTINCT ON`, but a window function
        ranked by the sort can pick the same records. Postgres returns children 13, 21,
        11 and 14 for labels high, other, same and nil.
        """
      },
      %{
        id: "query-combinations",
        title: "Query combinations",
        kind: :implementation,
        owners: [:ash_sqlite],
        body: ~S"""

        Support combination queries such as `union`. AshSQLite does not advertise
        `:combine`, so Ash rejects the read with "Data layer does not support combining
        queries". SQLite has `UNION`, `UNION ALL` and `INTERSECT`, so this is
        implementation work. Postgres returns children 11, 12 and 13.
        """
      },
      %{
        id: "row-locks",
        title: "Row locks",
        kind: :limitation,
        owners: [:ash_sqlite],
        body: ~S"""
        Limitation: SQLite has no row-level locks. Ash's `LockNotSupported` error for
        `lock(:for_update)` is the intended result on SQLite.

        Postgres locks and returns the row inside a transaction. No implementation task
        is recorded; revisit only if AshSQLite chooses to map a lock type to SQLite's
        database-level locking.
        """
      },
      %{
        id: "many-to-many-load-limit",
        title: "Many-to-many load limit",
        kind: :implementation,
        owners: [:ash, :ash_sqlite],
        body: ~S"""
        SQLite does not advertise lateral joins, so Ash chooses how to apply the
        bound. It is correct for has-many loads with the same limit and offset.

        Apply a limit on a many-to-many load query to each parent. Loading tags with
        `limit(1)` should give parent 1 tag 202 and parent 2 tag 201, as in Ash's own
        load tests and on Postgres. SQLite gives parent 2 no tags: the limit is applied
        across all parents together.
        """
      },
      %{
        id: "through-fallback",
        title: "Through fallback",
        kind: :implementation,
        owners: [:ash, :ash_sqlite],
        body: ~S"""
        Ash checks `:through_relationship` when a resource is defined, but the failed
        check is only printed as a warning, so the resource still compiles.

        Reject or correctly load `through` relationships on data layers that do not
        support them. On SQLite, loading `ratings` through `[:children, :ratings]`
        gives every parent parent 1's four ratings; parents 2 and 3 have none. The
        aggregate over the same relationship is correct. Postgres returns the intended
        ratings and counts without a warning.
        """
      },
      %{
        id: "upsert-conditions",
        title: "Upsert conditions",
        kind: :implementation,
        owners: [:ash_sqlite],
        body: ~S"""

        Support `upsert_condition` expressions that use `upsert_conflict/1`. AshSQLite
        advertises upserts, including atomic upserts, but raises "Unsupported
        expression" for `upsert_conflict(:value)`, or passes it as an unsupported
        parameter in the generated SQL. SQLite's `ON CONFLICT ... DO UPDATE ... WHERE`
        can express the condition using `excluded`.
        """
      },
      %{
        id: "unsorted-bounds",
        title: "Unsorted bounds",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""

        Avoid an empty `ORDER BY` in grouped relationship windows. The bounded count
        must be one regardless of which child is chosen; the fixture does not depend
        on an unspecified ordering. SQLite currently raises a syntax error.
        """
      },
      %{
        id: "duration-storage",
        title: "Duration storage",
        kind: :implementation,
        owners: [:ash_sqlite],
        body: ~S"""

        Store `:duration` attributes on SQLite. AshSqlite's migration generator gives
        them a `duration` column, but Exqlite cannot bind a `%Duration{}`, so every
        create fails with "unsupported type: %Duration{...}" before anything is
        stored. AshPostgres stores them once the repo decodes intervals as `Duration`,
        which its documentation requires.

        Tier 2 cannot store its duration rows either, so every `ops.duration.*`
        cell is recorded as not run.
        """
      },
      %{
        id: "ci-string-sort",
        title: "CI-string sort",
        kind: :implementation,
        owners: [:ash_sqlite],
        body: ~S"""

        Sort case-insensitive strings case-insensitively. Ash compares them
        ignoring case (`Ash.CiString.compare/2`), and AshPostgres sorts `citext`
        that way. AshSqlite's migration generator gives them a `citext` column,
        which SQLite does not know: it has text affinity and the default binary
        collation, so `ops.ci_string.sort` returns Banana, Cherry, apple. Equality
        filters already ignore case. A `COLLATE NOCASE` column, or sorting on
        `lower(...)`, would match Ash.
        """
      },
      %{
        id: "json-null",
        title: "JSON null",
        kind: :implementation,
        owners: [:ecto_sqlite3, :ash_sqlite],
        body: ~S"""

        Store nil maps, arrays, embedded resources and unions as SQL `NULL`. They
        are stored as the JSON text `null`: Ecto passes nil through each adapter
        dumper, and `ecto_sqlite3`'s `Codec.json_encode/1` encodes it with Jason
        (checked with a direct `SELECT typeof(value)`, which returns `text`). Reads
        decode it back to nil, so tier 1 passes, but `is_nil(value)` finds none
        of these rows and `count` of the field counts them. A plain Ecto schema
        with a nil `:map` field stores the same. `ecto_sqlite3` main encodes nil
        the same way; no issue was found upstream. AshSqlite could bind nil
        itself until it is fixed there.
        """
      },
      %{
        id: "binary-in-lists",
        title: "Binary IN lists",
        kind: :implementation,
        owners: [:ash_sqlite],
        body: ~S"""

        Filter binaries with `in`. `value in ^[<<1, 0>>, <<2, 0>>]` crashes with an
        `Ecto.QueryError` ("invalid keyword list in query"): AshSqlite's IN list
        binds each binary as an Exqlite `{:blob, value}` tuple, and Ecto reads the
        list of tuples as a keyword list. Equality on a single binary works.
        """
      }
    ]
  end
end
