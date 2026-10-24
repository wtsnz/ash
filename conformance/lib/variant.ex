# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Variant do
  @moduledoc """
  Ways of running a scenario that must not change its answer.

  A scenario fixes one way of running its query shape. A variant runs the
  same scenario another way, and the answer must match the scenario's own
  expectation record: the intended answer where the data layer is supported,
  or the same recorded gap where it isn't. No new expected values are needed,
  so a variant covers every scenario it applies to.

  The variants turn authorization on without changing what the actor may see:

  - `:authorize`: `authorize?: true` on the same resources, which have no
    authorizer. Ash still rewrites filters, sorts, aggregates and
    calculations for authorization (`update_aggregate_filters`,
    `relationship_filters`, `authorize_sorts`), and skips only the
    authorizers themselves.
  - `:permit_policy`: every resource without its own authorizer gets
    `Ash.Policy.Authorizer` and a policy that allows everything.
  - `:filter_policy`: as `:permit_policy`, but reads, updates and destroys are
    allowed by a filter every stored row passes (`EveryRow`), so a policy
    filter is added to every query, subquery, `exists`, aggregate and load.

  Those three are benign by design: nothing is hidden, so they cannot show
  a path that forgets a filter. The fourth is adversarial:

  - `:decoy`: every fixture row gets a hidden copy (`Ash.Conformance.Decoy`),
    in a mirror tenant with colliding local identities where the table is
    multitenant by attribute, and otherwise with a reserved id that a read
    policy hides (`NotDecoy`). The answer must not change, and no decoy id,
    value or marker may appear anywhere in the outcome. Every scenario that
    runs under it becomes a leak test without a new expected value. Resources
    with their own policies keep them and also get `NotDecoy`.

  Scenarios call `authorize?/0` wherever they would pass `authorize?: false`.
  Reads that already pass an actor and `authorize?: true` are unchanged.
  Policy variants read from their own resource set over the same tables,
  defined by `use Ash.Conformance.Resources, variants: true`; `resource/2`
  picks the set, so fixtures and scenarios need no change.

  The current variant is kept in the calling process. Scenario code runs in
  that process; Ash tasks it starts only see resource modules and options
  chosen before they start.
  """

  @variants [:authorize, :permit_policy, :filter_policy, :decoy]
  @namespaces %{permit_policy: PermitPolicy, filter_policy: FilterPolicy, decoy: Decoy}
  @key {__MODULE__, :current}

  # Areas that are already an authorization matrix of their own.
  @own_axis %{
    policies: "the policy grid runs every path with and without authorization",
    combinations: "the combination grid has its own policy axis",
    authorization: "these scenarios choose their actor and authorization themselves"
  }

  def all, do: @variants

  @doc """
  The opt-out for a scenario that filters through a relationship with a plain
  filter. The policies guide authorizes relationship paths only in
  `filter_input`, so decoys a policy hides rightly match a plain filter.
  """
  def plain_relationship_filter,
    do:
      {:except, [:decoy],
       "filters through a relationship with a plain filter, which policies don't " <>
         "authorize (policies guide), so policy-hidden decoys rightly match"}

  @doc "The opt-out for a scenario that reads across tenants on purpose."
  def across_tenants,
    do:
      {:except, [:decoy],
       "reads every tenant on purpose, so the decoys' mirror tenants rightly appear"}

  @doc "The variant the calling process is running, or `:base`."
  def current, do: Process.get(@key, :base)

  @doc "Runs `fun` under `variant`, then restores the previous one."
  def run(variant, fun) when variant in @variants do
    previous = Process.put(@key, variant)

    try do
      fun.()
    after
      if previous, do: Process.put(@key, previous), else: Process.delete(@key)
    end
  end

  @doc """
  The `authorize?` option for an operation the scenario runs without
  authorization: false in the base run, true under every variant.
  """
  def authorize?, do: current() != :base

  @doc "The resource module for `role` in the current variant's resource set."
  def resource(adapter, role) do
    Module.concat(
      [adapter] ++ List.wrap(Map.get(@namespaces, current())) ++ [Macro.camelize("#{role}")]
    )
  end

  @doc """
  Replaces the policy variants' resource set names in an outcome's text with
  the base set's, so a message naming `Sqlite.PermitPolicy.Child` matches a
  record that names `Sqlite.Child`.
  """
  def normalize(outcome) when is_binary(outcome),
    do:
      String.replace(
        outcome,
        ~r/\.(#{Enum.map_join(@namespaces, "|", fn {_, ns} -> inspect(ns) end)})\./,
        "."
      )

  def normalize(outcome) when is_tuple(outcome),
    do: outcome |> Tuple.to_list() |> Enum.map(&normalize/1) |> List.to_tuple()

  def normalize(outcome) when is_list(outcome), do: Enum.map(outcome, &normalize/1)

  def normalize(%_{} = outcome), do: outcome

  def normalize(outcome) when is_map(outcome),
    do: Map.new(outcome, fn {key, value} -> {normalize(key), normalize(value)} end)

  def normalize(outcome), do: outcome

  @doc "The namespaces of the policy variants' resource sets, below an adapter's."
  def namespaces, do: @namespaces

  @doc "Whether an adapter defines `variant`'s resource set, or every set without one."
  def supported?(adapter, variant \\ :permit_policy)

  def supported?(adapter, :authorize), do: supported?(adapter, :permit_policy)

  def supported?(adapter, variant),
    do: Code.ensure_loaded?(Module.concat([adapter, Map.fetch!(@namespaces, variant), Parent]))

  @doc """
  Whether a scenario runs under `variant`, and if not, why. A scenario opts
  out with `variants: {:none, reason}` or `{:except, variants, reason}`.
  """
  def applies?(%{area: area}, _variant) when is_map_key(@own_axis, area),
    do: {false, Map.fetch!(@own_axis, area)}

  def applies?(%{variants: {:none, reason}}, _variant), do: {false, reason}

  def applies?(%{variants: {:except, variants, reason}}, variant) do
    if variant in variants, do: {false, reason}, else: true
  end

  def applies?(_scenario, _variant), do: true

  @doc """
  The policy variant a resource module belongs to, from its namespace, or nil.
  `Ash.Conformance.Resources.Base` adds that variant's policies.
  """
  def policy(module) do
    segments = module |> Module.split() |> Enum.map(&String.to_atom("Elixir." <> &1))
    Enum.find_value(@namespaces, fn {variant, namespace} -> namespace in segments && variant end)
  end

  @doc "The policies block `Ash.Conformance.Resources.Base` adds for a policy variant."
  def policies(nil), do: nil

  def policies(:permit_policy) do
    quote do
      policies do
        policy always() do
          authorize_if(always())
        end
      end
    end
  end

  def policies(:decoy) do
    quote do
      policies do
        policy action_type([:read, :update, :destroy]) do
          authorize_if(Ash.Conformance.Variant.NotDecoy)
        end

        policy action_type([:create, :action]) do
          authorize_if(always())
        end
      end
    end
  end

  def policies(:filter_policy) do
    quote do
      policies do
        policy action_type([:read, :update, :destroy]) do
          authorize_if(Ash.Conformance.Variant.EveryRow)
        end

        policy action_type([:create, :action]) do
          authorize_if(always())
        end
      end
    end
  end

  @doc """
  The policy the decoy set adds to a resource that has its own policies.
  Ash requires every applicable policy to pass, so the resource's own rules
  still decide, and decoys are hidden as well.
  """
  def own_policies(:decoy) do
    quote do
      policies do
        policy action_type([:read, :update, :destroy]) do
          authorize_if(Ash.Conformance.Variant.NotDecoy)
        end
      end
    end
  end

  def own_policies(_variant), do: nil
end

defmodule Ash.Conformance.Variant.EveryRow do
  @moduledoc """
  A filter policy every stored row passes: the first primary key field is not
  nil. A resource with no primary key gets `true`, which Ash may simplify away.
  """
  use Ash.Policy.FilterCheck
  require Ash.Expr

  @impl true
  def describe(_opts), do: "every row"

  @impl true
  def filter(_actor, _context, opts) do
    case Ash.Resource.Info.primary_key(opts[:resource]) do
      [key | _] -> Ash.Expr.expr(not is_nil(^Ash.Expr.ref(key)))
      [] -> true
    end
  end
end

defmodule Ash.Conformance.Variant.NotDecoy do
  @moduledoc """
  The decoy variant's read policy: hides rows whose first primary key is in
  `Ash.Conformance.Decoy`'s reserved range. A resource multitenant by
  attribute keeps its decoys in a mirror tenant instead, so tenancy alone
  hides them and a tenancy leak is not masked by this policy; it gets a
  filter every row passes, as `EveryRow`. A `global?` one can be read
  without a tenant, so it is hidden by id as well.
  """
  use Ash.Policy.FilterCheck
  require Ash.Expr

  @impl true
  def describe(_opts), do: "not a decoy"

  @impl true
  def filter(_actor, _context, opts) do
    resource = opts[:resource]
    first..last//_ = Ash.Conformance.Decoy.range()

    case Ash.Resource.Info.primary_key(resource) do
      [key | _] ->
        if (Ash.Resource.Info.multitenancy_strategy(resource) == :attribute and
              not Ash.Resource.Info.multitenancy_global?(resource)) or
             Ash.Resource.Info.attribute(resource, key).type != Ash.Type.Integer,
           do: Ash.Expr.expr(not is_nil(^Ash.Expr.ref(key))),
           else:
             Ash.Expr.expr(
               not is_nil(^Ash.Expr.ref(key)) and
                 (^Ash.Expr.ref(key) < ^first or ^Ash.Expr.ref(key) > ^last)
             )

      [] ->
        true
    end
  end
end
