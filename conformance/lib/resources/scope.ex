# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources.Scope do
  @moduledoc false
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, opts, context) do
    value =
      case opts[:from] do
        :actor -> context.actor && context.actor.label
        :context -> query.context[:visible_label]
        :tenant -> context.tenant
      end

    Ash.Query.do_filter(query, [{opts[:field] || :label, value || "missing-context"}])
  end
end
