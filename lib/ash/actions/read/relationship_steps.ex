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
    # - `read_action_relationship` is the relationship whose read action and arguments they're
    #   read with: `relationship`, or the `through` relationship whose path ends at them, if it
    #   has a read action of its own, as when it's loaded.
    # - `accessing_from` is the relationship the records are read as accessed from: the
    #   relationship in the path that arrives at them, or the `through` relationship whose path
    #   ends at them.
    # - `key` is the path of relationship names from the start of the path to the records, with
    #   `through` relationships replaced by their paths. A `many_to_many`'s join resource is at
    #   the path of its join relationship. Every key is a path of relationships defined on the
    #   resources along it.
    defstruct [:hop, :relationship, :read_action_relationship, :accessing_from, :key]

    @type t :: %__MODULE__{
            hop: Ash.Resource.Relationships.relationship(),
            relationship: Ash.Resource.Relationships.relationship(),
            read_action_relationship: Ash.Resource.Relationships.relationship(),
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

  Options:

  - `:many_to_many` - `:keep` to keep each `many_to_many` as one step, for expressions, which
    can only refer to relationships that are defined. Defaults to `:expand`.
  """
  @spec expand(Ash.Resource.t(), list(atom), Keyword.t()) :: list(Step.t())
  def expand(resource, path, opts \\ []) do
    expand(resource, path, [], [], opts[:many_to_many] || :expand)
  end

  @doc """
  The last step of a relationship path.
  """
  @spec last_step(Ash.Resource.t(), list(atom), Keyword.t()) :: Step.t() | nil
  def last_step(resource, path, opts \\ []) do
    resource
    |> expand(path, opts)
    |> List.last()
  end

  defp expand(_resource, [], _key, acc, _many_to_many), do: Enum.reverse(acc)

  defp expand(resource, [name | rest], key, acc, many_to_many) do
    relationship = Ash.Resource.Info.relationship(resource, name)

    if is_nil(relationship) do
      raise Ash.Error.Query.NoSuchRelationship,
        resource: resource,
        relationship: name
    end

    steps = relationship_steps(resource, relationship, key, many_to_many)
    last = List.last(steps)

    expand(last.hop.destination, rest, last.key, Enum.reverse(steps) ++ acc, many_to_many)
  end

  defp relationship_steps(resource, %{through: through} = relationship, key, many_to_many)
       when is_list(through) do
    resource
    |> expand(through, key, [], many_to_many)
    |> List.update_at(-1, fn step ->
      step = %{step | accessing_from: accessing_from(relationship)}

      if relationship.read_action do
        %{step | read_action_relationship: relationship}
      else
        step
      end
    end)
  end

  defp relationship_steps(resource, %{type: :many_to_many} = relationship, key, :expand) do
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
        read_action_relationship: relationship,
        accessing_from: accessing_from(relationship),
        key: key ++ [relationship.name]
      }
    ]
  end

  defp relationship_steps(_resource, relationship, key, _many_to_many) do
    [step(relationship, key)]
  end

  defp step(relationship, key) do
    %Step{
      hop: relationship,
      relationship: relationship,
      read_action_relationship: relationship,
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
  - `:base_query` - the query the records are read with, at the end of a path, such as an
    aggregate's query. Its action and arguments are used.
  - `:read_action_relationship` - the relationship whose read action and arguments are used, if
    not `relationship`
  - `:filter?` - whether to add the relationship's filter. Defaults to `true`.
  """
  @spec query(Ash.Resource.Relationships.relationship(), scope, Keyword.t()) :: Ash.Query.t()
  def query(relationship, scope, opts \\ []) do
    read_action_relationship = opts[:read_action_relationship] || relationship
    action = read_action(read_action_relationship, opts[:base_query])

    relationship.destination
    |> Ash.Query.new()
    |> Ash.Query.set_tenant(scope.tenant)
    |> Ash.Query.set_context(%{
      accessing_from: opts[:accessing_from] || accessing_from(relationship),
      shared: scope.shared
    })
    |> Ash.Query.set_context(relationship.context)
    |> Ash.Query.for_read(
      action,
      read_action_arguments(read_action_relationship, opts[:base_query], action),
      authorize?: scope.authorize?,
      actor: scope.actor,
      tenant: scope.tenant,
      tracer: scope.tracer,
      domain: relationship.domain || scope.domain
    )
    |> then(fn query ->
      if Keyword.get(opts, :filter?, true) do
        query
        |> Ash.Query.do_filter(
          RelatedAuthorization.trusted_filter(
            relationship.destination,
            relationship.filter,
            [relationship.source]
          ),
          parent_stack: [relationship.source]
        )
        |> hydrate_refs(scope.actor, relationship.source, scope.arguments)
      else
        query
      end
    end)
  end

  @doc """
  The read action that the records `relationship` arrives at are read with: the action of the
  query they're read with, if there is one, then the relationship's read action.
  """
  @spec read_action(Ash.Resource.Relationships.relationship(), Ash.Query.t() | nil) :: atom
  def read_action(relationship, base_query \\ nil)

  def read_action(_relationship, %Ash.Query{action: %{name: name}}), do: name

  def read_action(relationship, _base_query) do
    relationship.read_action ||
      Ash.Resource.Info.primary_action!(relationship.destination, :read).name
  end

  # The base query's arguments were given for its own action, and the relationship's for its
  # read action. As when loading, the base query's take precedence.
  defp read_action_arguments(relationship, base_query, action) do
    base_arguments =
      case base_query do
        %Ash.Query{action: %{name: ^action}, arguments: arguments} -> arguments || %{}
        _ -> %{}
      end

    relationship_arguments =
      if is_nil(relationship.read_action) || relationship.read_action == action do
        Map.get(relationship, :read_action_arguments, %{})
      else
        %{}
      end

    Map.merge(relationship_arguments, base_arguments)
  end

  @doc """
  The key that a step's read policy filter is stored under: the relationship it's accessed from,
  and the action and arguments it's read with, which policies can depend on. `base_query` is
  the query the records are read with, if any, as for `query/3`.
  """
  @spec policy_key(Step.t(), Ash.Query.t() | nil) :: {Ash.Resource.t(), atom, atom, map}
  def policy_key(%Step{} = step, base_query \\ nil) do
    action = read_action(step.read_action_relationship, base_query)
    arguments = read_action_arguments(step.read_action_relationship, base_query, action)

    {step.accessing_from.source, step.accessing_from.name, action, arguments}
  end

  @doc """
  The filter that the actor's read policies add to the records a step arrives at, stored in
  `filters` under its `policy_key/2`.

  Unlike `authorize/3`, a forbidden read is the filter `false`, since the records are only
  referred to, not read.
  """
  @spec add_policy_filter(map, Step.t(), scope, Ash.Query.t() | nil) ::
          {:ok, map} | {:error, term}
  def add_policy_filter(filters, step, scope, base_query \\ nil) do
    related_query =
      query(step.relationship, %{scope | authorize?: true},
        accessing_from: step.accessing_from,
        base_query: base_query,
        read_action_relationship: step.read_action_relationship,
        filter?: false
      )

    key = policy_key(step, base_query)

    cond do
      Map.has_key?(filters, key) ->
        {:ok, filters}

      related_query.errors != [] ->
        {:error, related_query.errors}

      true ->
        related_query
        |> Ash.Query.select([])
        |> Map.put(:filter, nil)
        |> Ash.can(scope.actor,
          run_queries?: false,
          pre_flight?: false,
          alter_source?: true,
          no_check?: true,
          return_forbidden_error?: true,
          maybe_is: false
        )
        |> case do
          {:ok, true, %{filter: %Ash.Filter{} = filter}} ->
            {:ok, Map.put(filters, key, filter)}

          {:ok, true, _} ->
            {:ok,
             Map.put(filters, key, %Ash.Filter{expression: true, resource: step.hop.destination})}

          {:ok, true} ->
            {:ok,
             Map.put(filters, key, %Ash.Filter{expression: true, resource: step.hop.destination})}

          {:ok, false, _error} ->
            {:ok,
             Map.put(filters, key, %Ash.Filter{expression: false, resource: step.hop.destination})}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  @doc """
  The read policy filters for the records that each step of `path` arrives at, except the last,
  keyed by the step's key. These are an aggregate's join filters.

  Steps whose filter isn't in `policy_filters` or is `true` have none.
  """
  @spec join_filters(Ash.Resource.t(), list(atom), map) :: %{list(atom) => Ash.Expr.t()}
  def join_filters(resource, path, policy_filters) do
    resource
    |> expand(path)
    |> Enum.drop(-1)
    |> Enum.reduce(%{}, fn step, join_filters ->
      case Map.get(policy_filters, policy_key(step)) do
        %Ash.Filter{expression: true} -> join_filters
        %Ash.Filter{expression: expression} -> Map.put(join_filters, step.key, expression)
        nil -> join_filters
      end
    end)
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

  @doc """
  Sets filters for the steps within a relationship, by their keys relative to its source, on the
  query that the relationship is loaded with. The steps' queries are filtered by them.

  The ETS data layer loads an aggregate's path to compute it, and uses these for the aggregate's
  join filters on a `many_to_many`'s join resource or the steps of a `through` relationship.
  """
  @spec put_step_filters(Ash.Query.t(), %{list(atom) => Ash.Expr.t()}) :: Ash.Query.t()
  def put_step_filters(query, step_filters) do
    Ash.Query.set_context(query, %{private: %{relationship_step_filters: step_filters}})
  end

  @doc """
  Adds the filter set by `put_step_filters/2` for the step with `key` to its query.
  """
  @spec filter_step(Ash.Query.t(), Ash.Query.t(), list(atom)) :: Ash.Query.t()
  def filter_step(step_query, related_query, key) do
    case related_query.context[:private][:relationship_step_filters][key] do
      nil -> step_query
      filter -> Ash.Query.do_filter(step_query, filter)
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
