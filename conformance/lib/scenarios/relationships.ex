# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Relationships do
  @moduledoc """
  Relationship loads with per-parent bounds, and `through` relationships.

  A limit or offset on a load query applies to each parent separately, as in
  Ash's own load tests. Parent 1's children, by value descending, are 13, 11,
  12 and 14; parent 2 has only 21; parent 3 has none. Parent 1 links to tags
  201 (value 3) and 202 (value 8); parent 2 links to 201.
  """
  import Ash.Conformance.Scenario, only: [new: 5]

  @loads [semantic_basis: "../test/actions/load_test.exs"]

  def all do
    [
      # Each relationship kind, loaded directly.
      new(
        "load.belongs_to",
        :relationships,
        %{11 => 1, 12 => 1, 13 => 1, 14 => 1, 21 => 2},
        fn ctx ->
          ctx.child
          |> Ash.Query.load(:parent)
          |> Ash.read!(authorize?: false)
          |> Map.new(&{&1.id, &1.parent.id})
        end,
        semantic_basis: "../documentation/topics/resources/relationships.md"
      ),
      new(
        "load.has_one",
        :relationships,
        %{1 => 13, 2 => 21, 3 => nil},
        fn ctx ->
          ctx.parent
          |> Ash.Query.load(:top_child)
          |> Ash.read!(authorize?: false)
          |> Map.new(&{&1.id, &1.top_child && &1.top_child.id})
        end,
        semantic_basis: "../documentation/topics/resources/relationships.md"
      ),
      new(
        "load.has_many",
        :relationships,
        %{1 => [11, 12, 13, 14], 2 => [21], 3 => []},
        fn ctx -> loaded_ids(ctx, :children, Ash.Query.sort(ctx.child, :id)) end,
        semantic_basis: "../documentation/topics/resources/relationships.md"
      ),
      new(
        "load.many_to_many",
        :relationships,
        %{1 => [201, 202], 2 => [201], 3 => []},
        fn ctx -> loaded_ids(ctx, :tags, Ash.Query.sort(ctx.adapter.resource(:tag), :id)) end,
        semantic_basis: "../documentation/topics/resources/relationships.md"
      ),
      new(
        "load.limit_per_parent",
        :relationships,
        %{1 => [13, 11], 2 => [21], 3 => []},
        fn ctx -> loaded_ids(ctx, :children, children_by_value(ctx) |> Ash.Query.limit(2)) end,
        @loads ++ [capabilities: [parent: :limit]]
      ),
      new(
        "load.offset_per_parent",
        :relationships,
        %{1 => [11, 12], 2 => [], 3 => []},
        fn ctx ->
          query = children_by_value(ctx) |> Ash.Query.limit(2) |> Ash.Query.offset(1)
          loaded_ids(ctx, :children, query)
        end,
        @loads ++ [capabilities: [parent: :limit, parent: :offset]]
      ),
      new(
        "load.many_to_many_limit_per_parent",
        :relationships,
        %{1 => [202], 2 => [201], 3 => []},
        fn ctx ->
          query = ctx.adapter.resource(:tag) |> Ash.Query.sort(value: :desc) |> Ash.Query.limit(1)
          loaded_ids(ctx, :tags, query)
        end,
        @loads ++ [capabilities: [parent: :limit]]
      ),
      # The resource is compiled inside the operation, because Ash checks
      # `:through_relationship` support when a resource is defined. The first
      # element records whether that check warned.
      new(
        "load.through",
        :relationships,
        {false, %{1 => [101, 102, 103, 104], 2 => [], 3 => []}},
        fn ctx -> through(ctx, :ratings, fn record -> Enum.map(record.ratings, & &1.id) end) end,
        semantic_basis: "../documentation/topics/resources/relationships.md",
        capabilities: [parent: :through_relationship]
      ),
      # The same relationship as an aggregate path, judged separately.
      new(
        "path.through_count",
        :relationships,
        {false, %{1 => 4, 2 => 0, 3 => 0}},
        fn ctx -> through(ctx, :rating_count, & &1.rating_count) end,
        semantic_basis: "../documentation/topics/resources/relationships.md",
        capabilities: [parent: :through_relationship]
      )
    ]
  end

  defp children_by_value(ctx), do: Ash.Query.sort(ctx.child, value: :desc_nils_last, id: :asc)

  defp loaded_ids(ctx, relationship, query) do
    ctx.parent
    |> Ash.Query.sort(:id)
    |> Ash.Query.load([{relationship, query}])
    |> Ash.read!(authorize?: false)
    |> Map.new(fn row -> {row.id, row |> Map.fetch!(relationship) |> Enum.map(& &1.id)} end)
  end

  defp through(ctx, load, project) do
    {module, warned?} = through_resource(ctx.adapter)

    loads =
      module
      |> Ash.Query.sort(:id)
      |> Ash.Query.load(load)
      |> Ash.read!(authorize?: false)
      |> Map.new(&{&1.id, project.(&1)})

    {warned?, loads}
  end

  # Compiled once per adapter and VM; the warning from the first compile is kept.
  defp through_resource(adapter) do
    module = Module.concat([adapter.resource(:parent), Through])
    key = {__MODULE__, module}

    case :persistent_term.get(key, nil) do
      nil ->
        # Capturing needs ExUnit's capture server, which mix tasks do not start.
        {:ok, _} = Application.ensure_all_started(:ex_unit)

        {_, output} =
          ExUnit.CaptureIO.with_io(:stderr, fn ->
            Code.compile_quoted(through_definition(module, adapter))
          end)

        warned? = output =~ "does not support `through` relationships"
        :persistent_term.put(key, warned?)
        {module, warned?}

      warned? ->
        {module, warned?}
    end
  end

  defp through_definition(module, adapter) do
    quote do
      defmodule unquote(module) do
        use Ash.Conformance.Resources.Base, adapter: unquote(adapter.id()), table: "ac_parents"

        attributes do
          attribute(:id, :integer, primary_key?: true, allow_nil?: false, public?: true)
        end

        relationships do
          has_many(:children, unquote(adapter.resource(:child)),
            destination_attribute: :parent_id
          )

          has_many(:ratings, unquote(adapter.resource(:rating)),
            through: [:children, :ratings],
            sort: [id: :asc]
          )
        end

        aggregates do
          count(:rating_count, :ratings)
        end
      end
    end
  end
end
