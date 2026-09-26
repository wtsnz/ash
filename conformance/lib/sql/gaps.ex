# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Gaps do
  @moduledoc """
  Gaps AshSQL causes on every data layer built on it, here SQLite and
  Postgres. Rendered into `GAPS.md` by `mix conformance.gaps`.
  """

  def all do
    [
      %{
        id: "bind-parameter-limit",
        title: "Bind parameter limit",
        kind: :implementation,
        owners: [:ash_sql, :ash_postgres, :ash_sqlite],
        body: ~S"""

        Split a bulk insert whose rows need more bind parameters than the database
        allows in one statement. `Ash.bulk_create/4` takes `batch_size` as the number
        of records per batch and documents no other limit, but 22,000 rows of three
        fields (66,000 parameters) in one batch fail on both data layers
        (`large.bulk_create_parameters`). SQLite stops at 32,766 ("variable number
        must be between ?1 and ?32766") and Postgres at 65,535 ("postgresql protocol
        can not handle 66000 parameters"). A wide resource reaches the same limit at
        Ash's default batch of 100.

        Postgres is worse: the error disconnects the connection, and the surrounding
        transaction is lost with it, so the fixture's 2,000 rows are gone when the
        scenario counts afterwards. If Ash decides batches past the limit are the
        caller's problem, the intended result becomes a clean error, but never a
        dropped connection.
        """
      },
      %{
        id: "temporal-difference",
        title: "Temporal difference",
        kind: :implementation,
        owners: [:ash_sql, :ash_sqlite],
        body: ~S"""
        Subtract datetimes and times as whole seconds, and dates as days, as Ash's
        evaluation does (`DateTime.diff/2`, `Date.diff/2`). AshSQL casts the difference
        to `bigint`: on Postgres a datetime or time difference is an `interval`, which
        cannot be cast ("ERROR 42846 cannot cast type interval to bigint"), so every
        `sig.minus.*_*` of two datetimes, naive datetimes or times crashes. Date minus
        date is an integer there and works. On SQLite the values are text, and `-`
        subtracts their leading digits, so every difference is 0 (the year minus the
        year), or 13 for `23:59:59 - 10:00:00`, silently. Found by the signature tier.
        """
      },
      %{
        id: "string-position-ci",
        title: "String position CI",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""
        Compare case-insensitively in `string_position/2` when the substring is a
        `ci_string` and the string isn't. `string_position("Hello World", ^ci("WORLD"))`
        is 6 in Ash's evaluation, but nil on Postgres and SQLite. `contains/2` gets the
        same combination right on Postgres (`sig.string_position.string_ci`).
        """
      },
      %{
        id: "start-of-day-zone",
        title: "Start of day zone",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""
        Convert from UTC before truncating in `start_of_day/2`. AshSQL emits
        `timezone('UTC', timezone(zone, date_trunc('day', timezone(zone, value))))`,
        which assumes a `timestamptz`. AshPostgres stores `utc_datetime` as `timestamp`
        without a time zone, so the innermost `timezone(zone, value)` reads the stored
        UTC value as local time and the offset applies in the wrong direction: for
        "Etc/GMT+5" (UTC-5), 2024-01-31 10:30 UTC starts its day at 2024-01-30 19:00 UTC
        instead of 2024-01-31 05:00 UTC. A date lands a day early. Ash's evaluation
        shifts the value into the zone first (`sig.start_of_day.*_zone`).
        """
      },
      %{
        id: "string-split-empty",
        title: "String split empty",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""
        Split an empty string as `String.split/3` does. Ash's evaluation of
        `string_split("", "o")` is `[""]`, and `[]` with `trim?: true`. Postgres's
        `string_to_array('', ...)` returns `{}`, and the `trim?: true` path returns nil,
        which reads as if the input were nil (`sig.string_split.*`, row 2).
        """
      },
      %{
        id: "grapheme-length",
        title: "Grapheme length",
        kind: :limitation,
        owners: [:ash_sql],
        body: ~S"""
        Limitation: SQL data layers can't count graphemes, as
        `Ash.Query.Function.StringLength` documents, so `string_length(s, :graphemes)` is rejected with an unsupported
        expression error. Without a unit, `string_length/1` counts codepoints, which
        both data layers do. The expressions guide still describes `string_length/1`
        as `String.length/1` (graphemes), which disagrees with the module and should
        be updated (`edge.string_length.*`).
        """
      },
      %{
        id: "exists-path-authorization",
        title: "Exists path authorization",
        kind: :implementation,
        owners: [:ash_sql, :ash],
        body: ~S"""
        Resolve a policy filter's relationship path from the right resource in an
        `exists` aggregate over two or more hops. With a filter policy on the path's
        resources, sorting or filtering by such an aggregate raises "no such
        relationship ...ShapeIntegerLeaf.integer_mids" in
        `AshSql.Join.relationship_path_to_relationships/3`. AshSQL's `exists`
        translation builds the last hop's subquery (`AshSql.Join.related_subquery/3`)
        and filters it with a policy filter whose path starts at the root, so the
        path is resolved from the leaf. Loading the aggregate works, and so do
        `count` and `sum` over the same paths, one-hop paths, a policy that allows
        everything, and `authorize?: true` with no authorizer. Whether Ash builds the
        wrong path or AshSQL applies it at the wrong binding is not settled. Found by
        the `filter_policy` variant on the shapes grid
        (`shape.exists.*.depth_2.*` and `depth_3`, `sort` and `filter`).
        """
      },
      %{
        id: "root-relationship",
        title: "Root relationship",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""

        Implement root aggregation over relationship paths, preserving root scope and
        endpoint fields. SQLite rejects this explicitly. The Postgres comparator also
        fails the tested public `Ash.aggregate` call by resolving `value` against the
        parent instead of the child. Do not assume this gap is SQLite-only.
        """
      },
      %{
        id: "parent-through-load",
        title: "Parent through load",
        kind: :implementation,
        owners: [:ash_sql, :ash],
        body: ~S"""
        The `KeyError` comes from AshSQL's parent expression handling while Ash loads
        the join relationship. Ash may need to supply the parent context.

        Load many-to-many relationships whose join relationship filter uses `parent`.
        Loading `same_tenant_tags` directly raises `KeyError` for `:parent_bindings`
        on both adapters, and on AshSQL main. The Postgres aggregate over the same
        relationship returns the intended sum, so the failure is in relationship
        loading rather than aggregation.
        """
      },
      %{
        id: "nested-parent",
        title: "Nested parent",
        kind: :implementation,
        owners: [:ash, :ash_sql],
        body: ~S"""
        The read control is Ash's. `Ash.Query.Exists.new/3` merges
        `exists(children, exists(ratings, expr))` into `exists(children.ratings, expr)`
        and leaves `parent` references in `expr` unchanged, so they point one level too
        far out. `parent(parent(threshold))` then has no record to refer to: AshSQL
        raises `KeyError` for `:parent_bindings`, ETS returns no records, and with
        `authorize?: true` Ash raises a `MatchError` in `Ash.Filter.update_aggregates/5`
        before any data layer runs. Written so the `exists` cannot be merged
        (`exists(children, value == -1 or exists(ratings, ...))`), the same filter
        returns the intended parents on AshPostgres and ETS, with and without
        authorization. A single `parent(...)` in a nested `exists` is affected too.

        The aggregate (`filter.nested_parent`) has a single `exists`, so the merge
        does not explain it. The Postgres aggregate raises an unsupported expression
        error, and SQLite rejects parent-dependent aggregate filters. Whether Ash or
        AshSQL owns it is not settled. The same `KeyError` appears under
        [Parent through load](#parent-through-load).
        """
      },
      %{
        id: "no-attributes",
        title: "No attributes",
        kind: :implementation,
        owners: [:ash_sql, :ash_sqlite],
        body: ~S"""
        AshSQLite's `can?` gate changes too. The Postgres error also comes from AshSQL's
        lateral query.

        Support grouped attribute-free relationships, separating independent inputs
        from parent-dependent ones. Postgres's independent ad hoc count currently
        errors on a missing selected field, while the parent-dependent count passes.
        The direct relationship-load control returns all five children for each parent.
        """
      },
      %{
        id: "filter-fanout",
        title: "Filter fanout",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""

        Use membership EXISTS or row-identity deduplication so filter joins do not
        multiply records being aggregated. Two children with equal value 2 and three
        matching ratings must sum to 4, not 6, and count as two records. The average
        scenario adds a different value to expose weighting errors. Deduplicating
        values is not a valid substitute for deduplicating filter matches.

        A per-predicate EXISTS rewrite must keep the combined meaning of the filter.
        AND and OR cases also multiply on Postgres. Their intended records, and those
        of the NOT and nil-check counts, come from direct reads with the same filter.
        A negated to-many reference matches a child with a rating that fails the
        predicate, not a child without a matching rating. Fieldless counts already
        return these records on both adapters.

        SQLite rejects the affected aggregate shapes; Postgres currently returns the
        multiplied sum/count/list/custom/average. The direct read control returns
        distinct child records on Postgres; SQLite's duplicate is a separate read
        regression, recorded under [Sorted distinct reads](#sorted-distinct-reads).
        Composite-key count coverage also exposes Postgres's filter multiplication.
        """
      },
      %{
        id: "from-many",
        title: "From many",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""

        Respect the implicit one-row bound of `from_many?`. Both extraction strategies
        currently count four children for the first parent. The separately stacked fix
        is intentionally absent from this branch; merging it must cause an unexpected
        pass until the expectation is promoted.
        """
      },
      %{
        id: "default-sort",
        title: "Default sort",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""
        Ash applies `default_sort` only when loading relationships directly. Both AshSQL
        strategies read only the relationship's `sort`.

        Apply relationship `default_sort` when there is no explicit sort. SQLite
        chooses 2 instead of 7. Postgres takes whichever child is stored first: 2 when
        rows are seeded forward, 7 in reverse or rotated order. Direct relationship
        loading returns the expected child with value 7 on both adapters.
        """
      },
      %{
        id: "authorization-bounds",
        title: "Authorization bounds",
        kind: :implementation,
        owners: [:ash, :ash_sql],
        body: ~S"""
        Ash orders the policy and aggregate filters. AshSQL then applies them around the
        bound.

        Apply destination authorization before choosing limited relationship rows.
        The aggregate's own predicate must remain after the bound. Both adapters return
        nil for the first parent after selecting its hidden highest-valued child.
        Direct authorized relationship loading returns the visible child with value 2.
        Ash currently combines policy and aggregate filters, so this may require an
        Ash change to preserve their distinct ordering. The combination grid finds it
        again for a named `list` aggregate over a limited relationship
        (`combo.list.top_items.value_gt.global.actor.loaded`): owner 1 returns `[5]`
        instead of `[5, 3]`.
        """
      }
    ]
  end
end
