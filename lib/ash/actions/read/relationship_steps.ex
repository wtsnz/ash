# SPDX-FileCopyrightText: 2019 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Actions.Read.RelationshipSteps do
  @moduledoc false
  # A relationship path expanded into the steps that reach its records, and the queries that read
  # the records each step arrives at.
  #
  # A `through` relationship becomes the steps of its path, and a `many_to_many` becomes two
  # steps: its join relationship, then a hop from the join resource to its destination. Loads,
  # aggregates and related authorization all expand paths here, so that they read and authorize
  # the same records.

  alias Ash.Actions.Read.RelatedAuthorization

  defmodule Step do
    @moduledoc false
    # - `hop` joins the records the previous step arrived at to the records this step arrives at.
    #   For the second step of a `many_to_many` it's a `belongs_to` from the join resource, which
    #   isn't defined on the join resource.
    # - `relationship` is the relationship whose options (read action, filter, limit, domain and
    #   context) apply to the records this step arrives at.
    # - `accessing_from` is the relationship the records are read as accessed from: the
    #   relationship in the path that arrives at them, or the `through` relationship whose path
    #   ends at them.
    # - `key` is the path of relationship names from the start of the path to the records, with
    #   `through` relationships replaced by their paths. A `many_to_many`'s join resource is at
    #   the path of its join relationship. Every key is a path of relationships defined on the
    #   resources along it.
    defstruct [:hop, :relationship, :accessing_from, :key]

    @type t :: %__MODULE__{
            hop: Ash.Resource.Relationships.relationship(),
            relationship: Ash.Resource.Relationships.relationship(),
            accessing_from: %{source: Ash.Resource.t(), name: atom},
            key: list(atom)
          }
  end

  @type scope :: %{
          actor: term,
          authorize?: boolean,
          tenant: term,
          tracer: term,
          shared: map,
          domain: Ash.Domain.t() | nil,
          arguments: map
        }

  @doc """
  Expands a relationship path into its steps.
  """
  @spec expand(Ash.Resource.t(), list(atom)) :: list(Step.t())
  def expand(resource, path) do
    expand(resource, path, [], [])
  end

  defp expand(_resource, [], _key, acc), do: Enum.reverse(acc)

  defp expand(resource, [name | rest], key, acc) do
    relationship = Ash.Resource.Info.relationship(resource, name)

    if is_nil(relationship) do
      raise Ash.Error.Query.NoSuchRelationship,
        resource: resource,
        relationship: name
    end

    steps = relationship_steps(resource, relationship, key)
    last = List.last(steps)

    expand(last.hop.destination, rest, last.key, Enum.reverse(steps) ++ acc)
  end

  defp relationship_steps(resource, %{through: through} = relationship, key)
       when is_list(through) do
    resource
    |> expand(through, key, [])
    |> List.update_at(-1, &%{&1 | accessing_from: accessing_from(relationship)})
  end

  defp relationship_steps(resource, %{type: :many_to_many} = relationship, key) do
    join_relationship = Ash.Resource.Info.relationship(resource, relationship.join_relationship)

    join_hop = %Ash.Resource.Relationships.BelongsTo{
      name: relationship.name,
      source: relationship.through,
      destination: relationship.destination,
      source_attribute: relationship.destination_attribute_on_join_resource,
      destination_attribute: relationship.destination_attribute,
      domain: relationship.domain
    }

    [
      step(join_relationship, key),
      %Step{
        hop: join_hop,
        relationship: relationship,
        accessing_from: accessing_from(relationship),
        key: key ++ [relationship.name]
      }
    ]
  end

  defp relationship_steps(_resource, relationship, key) do
    [step(relationship, key)]
  end

  defp step(relationship, key) do
    %Step{
      hop: relationship,
      relationship: relationship,
      accessing_from: accessing_from(relationship),
      key: key ++ [relationship.name]
    }
  end

  defp accessing_from(relationship), do: %{source: relationship.source, name: relationship.name}

  @doc """
  The scope that the steps of a relationship read from `source_query` are read in.
  """
  @spec scope(Ash.Query.t(), Ash.Query.t()) :: scope
  def scope(source_query, related_query) do
    %{
      actor: source_query.context[:private][:actor],
      authorize?: source_query.context[:private][:authorize?],
      tenant: source_query.tenant,
      tracer: source_query.context[:private][:tracer],
      shared: source_query.context[:shared] || %{},
      domain: related_query.domain,
      arguments: source_query.arguments
    }
  end

  @doc """
  The query for the records that `relationship` arrives at, partway along a path.

  Options:

  - `:accessing_from` - the relationship the records are accessed from, if not `relationship`
  """
  @spec query(Ash.Resource.Relationships.relationship(), scope, Keyword.t()) :: Ash.Query.t()
  def query(relationship, scope, opts \\ []) do
    relationship.destination
    |> Ash.Query.new()
    |> Ash.Query.set_tenant(scope.tenant)
    |> Ash.Query.set_context(%{
      accessing_from: opts[:accessing_from] || accessing_from(relationship),
      shared: scope.shared
    })
    |> Ash.Query.set_context(relationship.context)
    |> Ash.Query.for_read(
      read_action(relationship),
      Map.get(relationship, :read_action_arguments, %{}),
      authorize?: scope.authorize?,
      actor: scope.actor,
      tenant: scope.tenant,
      tracer: scope.tracer,
      domain: relationship.domain || scope.domain
    )
    |> Ash.Query.do_filter(
      RelatedAuthorization.trusted_filter(
        relationship.destination,
        relationship.filter,
        [relationship.source]
      ),
      parent_stack: [relationship.source]
    )
    |> hydrate_refs(scope.actor, relationship.source, scope.arguments)
  end

  @doc """
  The read action that the records `relationship` arrives at are read with.
  """
  @spec read_action(Ash.Resource.Relationships.relationship()) :: atom
  def read_action(relationship) do
    relationship.read_action ||
      Ash.Resource.Info.primary_action!(relationship.destination, :read).name
  end

  @doc """
  Authorizes a step's query, adding the filter that the actor's read policies require.

  Like a read, this returns an error if the actor can't read the records at all.
  """
  @spec authorize(Ash.Query.t(), scope, term) :: {:ok, Ash.Query.t()} | {:error, term}
  def authorize(step_query, scope, path) do
    if scope.authorize? && Ash.Actions.Helpers.authorizers?(step_query) do
      case Ash.can(
             step_query,
             scope.actor,
             return_forbidden_error?: true,
             pre_flight?: false,
             alter_source?: true,
             run_queries?: false,
             base_query: step_query
           ) do
        {:ok, true} -> {:ok, step_query}
        {:ok, true, authorized_query} -> {:ok, authorized_query}
        {:ok, false, error} -> {:error, Ash.Error.set_path(error, path)}
        {:error, error} -> {:error, Ash.Error.set_path(error, path)}
      end
    else
      {:ok, step_query}
    end
  end

  @doc false
  def hydrate_refs(query, actor, parent, source_args) do
    query.filter
    |> Ash.Expr.fill_template(
      actor: actor,
      tenant: query.to_tenant,
      args: source_args,
      context: query.context
    )
    |> Ash.Filter.hydrate_refs(%{
      resource: query.resource,
      parent_stack: [parent],
      public?: false
    })
    |> case do
      {:ok, hydrated} ->
        %{query | filter: hydrated}

      {:error, error} ->
        Ash.Query.add_error(query, error)
    end
  end
end
