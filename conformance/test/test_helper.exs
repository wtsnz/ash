# SPDX-FileCopyrightText: 2026 ash_sql contributors <https://github.com/ash-project/ash_sql/graphs/contributors>
#
# SPDX-License-Identifier: MIT
Ash.Conformance.Catalog.validate!(
  Ash.Conformance.Catalog.all(),
  Ash.Conformance.Contracts.Expectations.all(),
  Ash.Conformance.Adapter.all()
)

ExUnit.start(formatters: [ExUnit.CLIFormatter, Ash.Conformance.Report.Formatter])

for adapter <- Ash.Conformance.Adapter.selected() do
  adapter.setup!()
end
