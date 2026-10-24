# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Postgres.Gaps do
  @moduledoc """
  Gaps only Postgres shows. Rendered into `GAPS.md` by `mix conformance.gaps`.
  """

  def all do
    [
      %{
        id: "root-first",
        title: "Root first",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""
        The crash is in AshSQL's lateral `add_subquery_aggregate_select/6`.

        Postgres root `first` without an explicit sort dereferences a missing first
        relationship. The empty-input scenario should return nil. Explicitly sorted
        first and empty-input controls already pass.
        """
      },
      %{
        id: "skipped-upsert-tenant",
        title: "Skipped upsert tenant",
        kind: :implementation,
        owners: [:ash_postgres],
        body: ~S"""
        The lookup for skipped records filters by the identity's attributes and sets
        the tenant on the query. It then calls `data_layer_query/1` directly, so Ash
        never applies the attribute tenant filter.

        Return the skipped record from the upsert's own tenant. With
        `return_skipped_upsert?: true`, a tenant 1 upsert of local ID 1 whose condition
        skips the write returns record 2001 from tenant 2, with its value 700. The
        intended record is tenant 1's record 1001. This exposes another tenant's data.

        The recorded wrong record depends on row order. The lookup runs
        `WHERE local_id = 1` with no tenant filter and matches both 1001 and 2001.
        AshPostgres keys the results by `local_id`, so whichever row comes back last
        wins. The suite seeds rows in three orders: forward gives 2001, while reverse
        and rotated give 1001. Because the wrong record depends on order, all three
        observations are pinned, and the scenario can pass only when every order
        returns 1001. Before promoting it, also confirm the lookup includes
        `tenant_id`.
        """
      },
      %{
        id: "root-bounds",
        title: "Root bounds",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""

        Preserve root ordering when materializing a limited aggregate input. The
        Postgres comparator discards the ordering and aggregates value 2 instead of 7.
        A list's own sort also replaces the root ordering: the two highest IDs have
        values 4 and nil, but Postgres lists `[2, 2]`. The unsorted custom aggregate
        over the same input only looks correct: the limit takes whichever rows are
        stored first, which happens to give 4 when rows are seeded forward or in
        reverse, and 7 when seeding starts from the middle.

        These Postgres results depend on row order, so the suite pins the observation
        for each seeding order. The fix must make every order return the intended
        answer.
        An offset-only root count also raises instead of returning three. Keep root
        ordering distinct from a first/list aggregate's own ordering.
        """
      },
      %{
        id: "unsorted-list-nil",
        title: "Unsorted list nil",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""
        In the lateral strategy, a list aggregate with no sort, either on the
        aggregate or on the relationship, is built as a plain `array_agg(?)`. Only
        the sorted branch adds `FILTER (WHERE ? IS NOT NULL)`.

        Exclude nils from list aggregates unless `include_nil?` is true, which is
        Ash's default, whether or not the list is sorted. Postgres lists
        `[2, 2, 7, nil]` for parent 1 and `[2, 2, 4, 7, nil]` at the root. The
        comparison sorts the lists because their order is unspecified. The same
        happens with AshSQL main `e3c9d26`, so it predates the extraction. SQLite
        excludes the nil. Every other list scenario sorts, which is why none caught it.
        """
      },
      %{
        id: "prepared-query",
        title: "Prepared query",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""
        The crash is in AshSQL's lateral `add_aggregates/6`, which reduces over an error
        from reading the prepared query.

        Retain a prepared endpoint query's action and arguments. SQLite returns the
        correct count; the Postgres comparator crashes in `Enumerable.List.reduce/3`.
        Configured-action and intermediate-action controls pass on both adapters.
        """
      },
      %{
        id: "tenant-bypass",
        title: "Tenant bypass",
        kind: :implementation,
        owners: [:ash_sql],
        body: ~S"""
        AshSQL's lateral strategy applies attribute tenancy without the aggregate's read
        action. The grouped strategy passes it and returns the intended results.

        Honor explicit aggregate tenancy bypass on endpoints and through resources,
        without changing a scoped sibling. The SQLite cases pass. Postgres returns
        scoped values for these bypass cases. Investigate where Ash has already added
        tenant predicates before changing adapter behavior.
        """
      },
      %{
        id: "nul-in-text",
        title: "NUL in text",
        kind: :limitation,
        owners: [:ash_postgres],
        body: ~S"""
        Limitation: PostgreSQL's `text` cannot contain the NUL character.

        A string with `\0` is rejected with "invalid byte sequence for encoding UTF8:
        0x00". Ash's string type accepts it and SQLite stores it. The rejection is the
        intended result unless AshPostgres chooses to reject such strings earlier with
        a clearer error.
        """
      }
    ]
  end
end
