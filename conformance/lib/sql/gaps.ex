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
        owners: [:ash_sql, :ash],
        body: ~S"""
        The control's `KeyError` is raised in AshSQL's parent expression handling. In
        the aggregate, the nested reference reaches AshSQL without a resource, so Ash
        may also need to resolve it.

        Support `parent(parent(...))` inside nested `exists`. A plain read filtering
        parents by `exists(children, exists(ratings, score >= parent(parent(threshold))))`
        raises `KeyError` for `:parent_bindings` on both adapters, and on AshSQL main.
        The Postgres aggregate with the same inner filter raises an unsupported
        expression error. SQLite rejects parent-dependent aggregate filters. AshPostgres's
        own tests use `parent(parent(...))` in a relationship filter, so the feature is
        supported by Ash in that context. The same `KeyError` appears under
        [Parent through load](#parent-through-load); one fix may cover both.
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
