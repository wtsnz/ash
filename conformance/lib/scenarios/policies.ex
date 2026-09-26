# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Scenarios.Policies do
  @moduledoc """
  The policy grid: each policy case on each path, plus field policies, a
  filter check on create, and every path without authorization as a control.
  Expected answers come from `Ash.Conformance.Policy`'s reference model.
  """
  import Ash.Conformance.Scenario, only: [new: 5]
  alias Ash.Conformance.Policy

  @opts [fixture: :policy, semantic_basis: "../documentation/topics/security/policies.md"]

  def all, do: grid() ++ fields() ++ creates() ++ controls()

  defp grid do
    for {case_id, shape, actor} <- Policy.cases(),
        path <- Policy.paths(),
        Policy.applies?(shape, actor, path) do
      run = fn ctx -> Policy.run(ctx.adapter, shape, actor, path, true) end
      expected = Policy.expected(shape, actor, path)
      new("policy.#{case_id}.#{path}", :policies, expected, run, opts(path))
    end
  end

  defp fields do
    for path <- Policy.field_paths() do
      run = fn ctx -> Policy.run(ctx.adapter, :field, :user, path, true) end
      expected = Policy.expected_field(path, :authorized)
      new("policy.field.#{path}", :policies, expected, run, opts(path))
    end
  end

  defp creates do
    for path <- Policy.create_paths() do
      run = fn ctx -> Policy.run(ctx.adapter, :owner, :user, path, true) end
      expected = Policy.expected_create(path, :authorized)
      new("policy.owner.#{path}", :policies, expected, run, opts(path))
    end
  end

  # Each policy cell requires its path's control.
  defp opts(path), do: [requires: ["policy.control.#{path}"]] ++ @opts

  # The same operations with authorization off: a policy cell is only
  # meaningful where its path works at all.
  defp controls do
    grid =
      for path <- Policy.paths() do
        run = fn ctx -> Policy.run(ctx.adapter, :owner, :user, path, false) end
        new("policy.control.#{path}", :policies, Policy.control(path), run, @opts)
      end

    fields =
      for path <- Policy.field_paths() do
        run = fn ctx -> Policy.run(ctx.adapter, :field, :user, path, false) end
        expected = Policy.expected_field(path, :control)
        new("policy.control.#{path}", :policies, expected, run, @opts)
      end

    creates =
      for path <- Policy.create_paths() do
        run = fn ctx -> Policy.run(ctx.adapter, :owner, :user, path, false) end
        expected = Policy.expected_create(path, :control)
        new("policy.control.#{path}", :policies, expected, run, @opts)
      end

    grid ++ fields ++ creates
  end
end
