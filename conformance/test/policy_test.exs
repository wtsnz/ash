# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.PolicyTest do
  use ExUnit.Case, async: true
  alias Ash.Conformance.{Policy, Report.PolicyGrid}

  # Worked out by hand from the fixture in lib/policy.ex, not from the model:
  # notes 11..17 with owners 1,2,1,2,2,1,1; teams 10,10,20,10,20,20,10;
  # drafts 12, 13 and 17; docs 1 and 2 in team 10, doc 3 in team 20; user 1
  # is a member of docs 1 and 3.
  test "each shape shows user 1 the notes its documented rule allows" do
    assert Policy.visible(:owner, :user) == [11, 13, 16, 17]
    assert Policy.visible(:forbid, :user) == [11, 14, 15, 16]
    assert Policy.visible(:bypass, :user) == [11, 13, 16, 17]
    assert Policy.visible(:bypass, :admin) == [11, 12, 13, 14, 15, 16, 17]
    assert Policy.visible(:all_of, :user) == [11, 17]
    assert Policy.visible(:any_of, :user) == [11, 13, 14, 15, 16, 17]
    assert Policy.visible(:related, :user) == [11, 12, 13, 14, 17]
    assert Policy.visible(:member, :user) == [11, 12, 15, 16, 17]
    assert Policy.visible(:can_read, :user) == [11, 12, 13, 14, 17]
    assert Policy.visible(:strict, :user) == :forbidden
    assert Policy.visible(:strict, :admin) == [11, 12, 13, 14, 15, 16, 17]
    assert Policy.visible(:owner, :none) == :forbidden
  end

  test "paths follow from the visible notes" do
    assert Policy.expected(:owner, :user, :count) == 4
    assert Policy.expected(:owner, :user, :sum) == 5 + 11 + 17 + 19
    assert Policy.expected(:owner, :user, :offset_page) == {[11, 13], 4}
    assert Policy.expected(:owner, :user, :load) == %{1 => [11, 17], 2 => [13], 3 => [16]}
    assert Policy.expected(:owner, :user, :aggregate_filter) == [1]
    assert Policy.expected(:owner, :user, :get_hidden) == :not_found
    assert Policy.hidden(:owner, :user) == 12

    # can_read also hides doc 3, which is in team 20.
    assert Policy.expected(:can_read, :user, :load) == %{1 => [11, 12, 17], 2 => [13, 14]}

    # A plain filter is not authorized, so every draft counts; filter_input
    # only sees the drafts the actor may read.
    assert Policy.expected(:forbid, :user, :exists_filter) == [1, 2]
    assert Policy.expected(:forbid, :user, :exists_filter_input) == []

    # Forbidden notes: reads are forbidden, aggregates count nothing.
    assert Policy.expected(:strict, :user, :read) == :forbidden
    assert Policy.expected(:strict, :user, :loaded_count) == %{1 => 0, 2 => 0, 3 => 0}

    assert {:forbidden, [11, 12, 13, 14, 15, 16, 17]} =
             Policy.expected(:strict, :user, :bulk_destroy)

    refute Policy.applies?(:bypass, :admin, :get_hidden)
  end

  test "a policy cell is blamed on the policy only when its path works without authorization" do
    rows = [
      %{scenario: "policy.owner.read", classification: :wrong},
      %{scenario: "policy.control.read", classification: :works},
      %{scenario: "policy.owner.count", classification: :wrong},
      %{scenario: "policy.control.count", classification: :crashed},
      %{scenario: "policy.owner.sum", classification: :works},
      %{scenario: "policy.control.sum", classification: :works}
    ]

    detail = PolicyGrid.detail(rows)
    assert detail =~ ~r/\| owner \| ❌ \| – \| – \| ◌ \| ✅ \|/

    summary = PolicyGrid.markdown([%{adapter: Ash.Conformance.Ets, rows: rows, unavailable: nil}])
    assert summary =~ "| owner | ❌ 1/2 · 1 ◌ |"
  end
end
