# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.SQL.Manual do
  @moduledoc "Ecto joins and subqueries for the manual relationship on SQL data layers."
  defmacro __using__(opts) do
    prefix = Keyword.fetch!(opts, :prefix)
    join_fun = String.to_atom("#{prefix}_join")
    subquery_fun = String.to_atom("#{prefix}_subquery")

    quote do
      use Ash.Resource.ManualRelationship
      import Ecto.Query

      defdelegate load(parents, opts, context), to: Ash.Conformance.Resources.PlainManual

      def unquote(join_fun)(query, _opts, parent_binding, child_binding, type, child_query) do
        {:ok,
         join(query, type, [], child in ^child_query,
           as: ^child_binding,
           on: child.parent_id == as(^parent_binding).id
         )}
      end

      def unquote(subquery_fun)(_opts, parent_binding, child_binding, child_query) do
        {:ok,
         from(row in child_query,
           where: field(as(^child_binding), :parent_id) == field(parent_as(^parent_binding), :id)
         )}
      end
    end
  end
end
