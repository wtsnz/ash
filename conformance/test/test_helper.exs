# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT
Ash.Conformance.Catalog.validate!(
  Ash.Conformance.Catalog.all(),
  Ash.Conformance.Contracts.Expectations.all(),
  Ash.Conformance.Adapter.all()
)

# The committed reports describe the default dependency set; another set's
# contracts and claims rightly differ from them.
committed? = Ash.Conformance.Report.dependency_set() == "release"

ExUnit.start(
  formatters: [ExUnit.CLIFormatter, Ash.Conformance.Report.Formatter],
  exclude: if(committed?, do: [], else: [:committed_report])
)

for adapter <- Ash.Conformance.Adapter.selected() do
  adapter.setup!()
end
