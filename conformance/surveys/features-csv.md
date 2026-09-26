<!-- SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors> -->
<!-- SPDX-License-Identifier: MIT -->
# What each data layer supports

Generated from an unreviewed run: each result was classified automatically against the intended answer. Nothing here has been reviewed.

Feature catalog version 1: 155 features and 869 scenarios.

| Status | Meaning |
| --- | --- |
| ✅ Works | Every scenario ran and returns the answer Ash defines. |
| 🔸 Incomplete | Everything that ran works, but some scenarios could not run. |
| 🟡 Partial | Some scenarios work; others are rejected or wrong. |
| ⛔ Not supported | Every scenario that ran is rejected with a documented error. |
| ❌ Broken | Nothing that ran works, and at least one scenario gives a wrong answer or crashes. |
| ❓ Open question | The remaining scenarios need a semantic decision in Ash. |
| ❔ Unknown | No scenario could run, usually because the data layer could not store its fixture. Never means not supported. |
| ⚪ Untested | Listed so the specification is complete; no scenario verifies it yet. |
| ➖ Not applicable | The data layer does not run these scenarios: a storage profile or fixture it does not opt in to, such as the combination grid, which runs on SQLite and Postgres. |
| ⚠️ Changed | A result no longer matches its recorded contract. |

Counts are passing scenarios out of those that ran, then how many could
not run, then how many failures have a failing prerequisite (blocked).
Gap links explain everything that is not fully working, and who owns the
fix.

## 1. Storage

| Feature | csv | Not working |
| --- | --- | --- |
| Integers | ✅ Works 3/3 |  |
| Floats | 🟡 Partial 1/3 | `storage.float.edge` wrong, `storage.float.ordinary` wrong |
| Decimals | ✅ Works 3/3 |  |
| Strings | 🟡 Partial 2/3 | `storage.string.edge` wrong |
| Case-insensitive strings | 🟡 Partial 2/3 | `storage.ci_string.edge` wrong |
| Binaries | 🟡 Partial 1/3 | `storage.binary.edge` wrong, `storage.binary.ordinary` wrong |
| Booleans | 🟡 Partial 1/2 | `storage.boolean.ordinary` wrong |
| Atoms with one_of | ✅ Works 2/2 |  |
| Dates | ✅ Works 3/3 |  |
| Times | ✅ Works 3/3 |  |
| Microsecond times | ✅ Works 3/3 |  |
| UTC datetimes | ✅ Works 3/3 |  |
| Microsecond UTC datetimes | ✅ Works 3/3 |  |
| Naive datetimes | ✅ Works 3/3 |  |
| Durations | 🟡 Partial 1/3 | `storage.duration.edge` wrong, `storage.duration.ordinary` wrong |
| UUIDs | ✅ Works 3/3 |  |
| UUIDv7s | ✅ Works 2/2 |  |
| Maps | 🟡 Partial 1/3 | `storage.map.edge` wrong, `storage.map.ordinary` wrong |
| Arrays of strings | 🟡 Partial 1/3 | `storage.strings.edge` wrong, `storage.strings.ordinary` wrong |
| Arrays of integers | 🟡 Partial 1/3 | `storage.integers.edge` wrong, `storage.integers.ordinary` wrong |
| Embedded resources | 🟡 Partial 1/3 | `storage.embedded.edge` wrong, `storage.embedded.ordinary` wrong |
| Arrays of embedded resources | 🟡 Partial 1/3 | `storage.embeddeds.edge` wrong, `storage.embeddeds.ordinary` wrong |
| Unions | 🟡 Partial 1/2 | `storage.union.ordinary` wrong |

## 2. Operations on each type

| Feature | csv | Not working |
| --- | --- | --- |
| Integers | 🟡 Partial 5/10 | `ops.integer.count` rejected, `ops.integer.first` rejected, `ops.integer.max` rejected, `ops.integer.min` rejected, `ops.integer.sum` rejected |
| Floats | ❔ Unknown 10 not run | `ops.float.count` setup failed (blocked by `storage.float.ordinary`), `ops.float.eq` setup failed (blocked by `storage.float.ordinary`), `ops.float.first` setup failed (blocked by `storage.float.ordinary`), `ops.float.gt` setup failed (blocked by `storage.float.ordinary`), `ops.float.in` setup failed (blocked by `storage.float.ordinary`), `ops.float.is_nil` setup failed (blocked by `storage.float.ordinary`), `ops.float.max` setup failed (blocked by `storage.float.ordinary`), `ops.float.min` setup failed (blocked by `storage.float.ordinary`), `ops.float.sort` setup failed (blocked by `storage.float.ordinary`), `ops.float.sum` setup failed (blocked by `storage.float.ordinary`) |
| Decimals | 🟡 Partial 5/10 · 5 blocked | `ops.decimal.count` rejected (blocked by `ops.integer.count`), `ops.decimal.first` rejected (blocked by `ops.integer.first`), `ops.decimal.max` rejected (blocked by `ops.integer.max`), `ops.decimal.min` rejected (blocked by `ops.integer.min`), `ops.decimal.sum` rejected (blocked by `ops.integer.sum`) |
| Strings | 🟡 Partial 5/9 · 4 blocked | `ops.string.count` rejected (blocked by `ops.integer.count`), `ops.string.first` rejected (blocked by `ops.integer.first`), `ops.string.max` rejected (blocked by `ops.integer.max`), `ops.string.min` rejected (blocked by `ops.integer.min`) |
| Case-insensitive strings | 🟡 Partial 5/9 · 4 blocked | `ops.ci_string.count` rejected (blocked by `ops.integer.count`), `ops.ci_string.first` rejected (blocked by `ops.integer.first`), `ops.ci_string.max` rejected (blocked by `ops.integer.max`), `ops.ci_string.min` rejected (blocked by `ops.integer.min`) |
| Binaries | 🟡 Partial 3/5 · 2 blocked | `ops.binary.count` rejected (blocked by `ops.integer.count`), `ops.binary.first` rejected (blocked by `ops.integer.first`) |
| Booleans | ❔ Unknown 5 not run | `ops.boolean.count` setup failed (blocked by `storage.boolean.ordinary`), `ops.boolean.eq` setup failed (blocked by `storage.boolean.ordinary`), `ops.boolean.first` setup failed (blocked by `storage.boolean.ordinary`), `ops.boolean.in` setup failed (blocked by `storage.boolean.ordinary`), `ops.boolean.is_nil` setup failed (blocked by `storage.boolean.ordinary`) |
| Atoms with one_of | 🟡 Partial 3/5 · 2 blocked | `ops.atom.count` rejected (blocked by `ops.integer.count`), `ops.atom.first` rejected (blocked by `ops.integer.first`) |
| Dates | 🟡 Partial 5/9 · 4 blocked | `ops.date.count` rejected (blocked by `ops.integer.count`), `ops.date.first` rejected (blocked by `ops.integer.first`), `ops.date.max` rejected (blocked by `ops.integer.max`), `ops.date.min` rejected (blocked by `ops.integer.min`) |
| Times | 🟡 Partial 5/9 · 4 blocked | `ops.time.count` rejected (blocked by `ops.integer.count`), `ops.time.first` rejected (blocked by `ops.integer.first`), `ops.time.max` rejected (blocked by `ops.integer.max`), `ops.time.min` rejected (blocked by `ops.integer.min`) |
| Microsecond times | 🟡 Partial 5/9 · 4 blocked | `ops.time_usec.count` rejected (blocked by `ops.integer.count`), `ops.time_usec.first` rejected (blocked by `ops.integer.first`), `ops.time_usec.max` rejected (blocked by `ops.integer.max`), `ops.time_usec.min` rejected (blocked by `ops.integer.min`) |
| UTC datetimes | 🟡 Partial 5/9 · 4 blocked | `ops.utc_datetime.count` rejected (blocked by `ops.integer.count`), `ops.utc_datetime.first` rejected (blocked by `ops.integer.first`), `ops.utc_datetime.max` rejected (blocked by `ops.integer.max`), `ops.utc_datetime.min` rejected (blocked by `ops.integer.min`) |
| Microsecond UTC datetimes | 🟡 Partial 5/9 · 4 blocked | `ops.utc_datetime_usec.count` rejected (blocked by `ops.integer.count`), `ops.utc_datetime_usec.first` rejected (blocked by `ops.integer.first`), `ops.utc_datetime_usec.max` rejected (blocked by `ops.integer.max`), `ops.utc_datetime_usec.min` rejected (blocked by `ops.integer.min`) |
| Naive datetimes | 🟡 Partial 5/9 · 4 blocked | `ops.naive_datetime.count` rejected (blocked by `ops.integer.count`), `ops.naive_datetime.first` rejected (blocked by `ops.integer.first`), `ops.naive_datetime.max` rejected (blocked by `ops.integer.max`), `ops.naive_datetime.min` rejected (blocked by `ops.integer.min`) |
| Durations | ❔ Unknown 5 not run | `ops.duration.count` setup failed (blocked by `storage.duration.ordinary`), `ops.duration.eq` setup failed (blocked by `storage.duration.ordinary`), `ops.duration.first` setup failed (blocked by `storage.duration.ordinary`), `ops.duration.in` setup failed (blocked by `storage.duration.ordinary`), `ops.duration.is_nil` setup failed (blocked by `storage.duration.ordinary`) |
| UUIDs | 🟡 Partial 3/5 · 2 blocked | `ops.uuid.count` rejected (blocked by `ops.integer.count`), `ops.uuid.first` rejected (blocked by `ops.integer.first`) |
| UUIDv7s | 🟡 Partial 3/5 · 2 blocked | `ops.uuid_v7.count` rejected (blocked by `ops.integer.count`), `ops.uuid_v7.first` rejected (blocked by `ops.integer.first`) |
| Maps | ❔ Unknown 3 not run | `ops.map.count` setup failed (blocked by `storage.map.ordinary`), `ops.map.first` setup failed (blocked by `storage.map.ordinary`), `ops.map.is_nil` setup failed (blocked by `storage.map.ordinary`) |
| Arrays of strings | ❔ Unknown 3 not run | `ops.strings.count` setup failed (blocked by `storage.strings.ordinary`), `ops.strings.first` setup failed (blocked by `storage.strings.ordinary`), `ops.strings.is_nil` setup failed (blocked by `storage.strings.ordinary`) |
| Arrays of integers | ❔ Unknown 3 not run | `ops.integers.count` setup failed (blocked by `storage.integers.ordinary`), `ops.integers.first` setup failed (blocked by `storage.integers.ordinary`), `ops.integers.is_nil` setup failed (blocked by `storage.integers.ordinary`) |
| Embedded resources | ❔ Unknown 3 not run | `ops.embedded.count` setup failed (blocked by `storage.embedded.ordinary`), `ops.embedded.first` setup failed (blocked by `storage.embedded.ordinary`), `ops.embedded.is_nil` setup failed (blocked by `storage.embedded.ordinary`) |
| Arrays of embedded resources | ❔ Unknown 3 not run | `ops.embeddeds.count` setup failed (blocked by `storage.embeddeds.ordinary`), `ops.embeddeds.first` setup failed (blocked by `storage.embeddeds.ordinary`), `ops.embeddeds.is_nil` setup failed (blocked by `storage.embeddeds.ordinary`) |
| Unions | ❔ Unknown 3 not run | `ops.union.count` setup failed (blocked by `storage.union.ordinary`), `ops.union.first` setup failed (blocked by `storage.union.ordinary`), `ops.union.is_nil` setup failed (blocked by `storage.union.ordinary`) |

## 3. Records

| Feature | csv | Not working |
| --- | --- | --- |
| Read records | ❔ Unknown 1 not run | `record.read_all` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Get one record by primary key or identity | ❔ Unknown 2 not run | `record.get_identity` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.get_primary_key` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Select only some attributes | 🔸 Incomplete 1/1 · 1 not run | `record.select` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Create a record | ❔ Unknown 1 not run | `record.create` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Update a record, including to nil | ❔ Unknown 2 not run | `record.update` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.update_to_nil` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Destroy a record | ❔ Unknown 1 not run | `record.destroy` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Update a record atomically from its current value | ❔ Unknown 1 not run | `record.atomic_update` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Not found, invalid, missing and duplicate values are errors | ❔ Unknown 4 not run | `record.identity_conflict` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.invalid_value` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.not_found` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.required` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |

## 4. Types

| Feature | csv | Not working |
| --- | --- | --- |
| Strings, integers, booleans, atoms and nil round-trip | ❔ Unknown 3 not run | `record.types_nil` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.types_scalar` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.types_strings` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Large integers, floats and decimals round-trip | ❔ Unknown 2 not run | `record.types_numeric` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `values.decimal_read_control` setup failed (blocked by `storage.boolean.ordinary`) |
| Dates, microsecond datetimes and times round-trip | ❔ Unknown 2 not run | `record.types_temporal` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `values.temporal_read_control` setup failed (blocked by `storage.boolean.ordinary`) |
| UUIDs round-trip | ❔ Unknown 1 not run | `record.types_uuid` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Arrays round-trip, keeping order and duplicates | ❔ Unknown 1 not run | `record.types_array` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Maps round-trip, including nested values | ❔ Unknown 1 not run | `record.types_map` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Embedded resources round-trip | ❔ Unknown 1 not run | `record.types_embedded` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |

## 5. Querying

| Feature | csv | Not working |
| --- | --- | --- |
| Filter with comparisons on numbers, decimals and dates | ❔ Unknown 6 not run | `record.filter_date` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_datetime_precision` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_decimal` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_equal` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_not_equal` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_range` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Nil behaves like SQL NULL in filters | ❔ Unknown 5 not run | `record.filter_in_with_nil` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_is_nil` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_not` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_not_nil` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_true_or_nil` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Filter booleans and atoms, including atoms as strings | ❔ Unknown 3 not run | `record.filter_atom` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_atom_as_string` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_boolean` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Filter strings: contains, case, unicode and empty | ❔ Unknown 4 not run | `record.filter_case_insensitive` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_contains` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_empty_string` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_unicode` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Filter inside arrays, maps and embedded resources | ❔ Unknown 3 not run | `record.filter_array_member` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_embedded` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.filter_map_key` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Arithmetic and rounding, with integer division as a float | ❔ Unknown 10 not run | `expr.add` setup failed (blocked by `storage.float.ordinary`), `expr.decimal_multiply` setup failed (blocked by `storage.float.ordinary`), `expr.divide` setup failed (blocked by `storage.float.ordinary`), `expr.divide_float` setup failed (blocked by `storage.float.ordinary`), `expr.filter.divide` setup failed (blocked by `storage.float.ordinary`), `expr.filter.round` setup failed (blocked by `storage.float.ordinary`), `expr.multiply` setup failed (blocked by `storage.float.ordinary`), `expr.round` setup failed (blocked by `storage.float.ordinary`), `expr.round_decimal` setup failed (blocked by `storage.float.ordinary`), `expr.subtract` setup failed (blocked by `storage.float.ordinary`) |
| String functions, including non-ASCII text | ❔ Unknown 11 not run | `expr.concat` setup failed (blocked by `storage.float.ordinary`), `expr.contains_unicode` setup failed (blocked by `storage.float.ordinary`), `expr.filter.concat` setup failed (blocked by `storage.float.ordinary`), `expr.filter.string_downcase` setup failed (blocked by `storage.float.ordinary`), `expr.filter.string_length` setup failed (blocked by `storage.float.ordinary`), `expr.string_downcase` setup failed (blocked by `storage.float.ordinary`), `expr.string_join` setup failed (blocked by `storage.float.ordinary`), `expr.string_length` setup failed (blocked by `storage.float.ordinary`), `expr.string_position` setup failed (blocked by `storage.float.ordinary`), `expr.string_trim` setup failed (blocked by `storage.float.ordinary`), `expr.type_to_string` setup failed (blocked by `storage.float.ordinary`) |
| if, cond, || and && | ❔ Unknown 5 not run | `expr.and_then` setup failed (blocked by `storage.float.ordinary`), `expr.cond` setup failed (blocked by `storage.float.ordinary`), `expr.filter.or_else` setup failed (blocked by `storage.float.ordinary`), `expr.if` setup failed (blocked by `storage.float.ordinary`), `expr.or_else` setup failed (blocked by `storage.float.ordinary`) |
| Date and datetime arithmetic | ❔ Unknown 5 not run | `expr.date_add_day` setup failed (blocked by `storage.float.ordinary`), `expr.date_add_month` setup failed (blocked by `storage.float.ordinary`), `expr.datetime_add` setup failed (blocked by `storage.float.ordinary`), `expr.filter.date_add_month` setup failed (blocked by `storage.float.ordinary`), `expr.start_of_day` setup failed (blocked by `storage.float.ordinary`) |
| Negation, column comparisons and and/or with nil | ❔ Unknown 13 not run | `nil.and` setup failed (blocked by `storage.float.ordinary`), `nil.compare_columns` setup failed (blocked by `storage.float.ordinary`), `nil.compare_columns_negated` setup failed (blocked by `storage.float.ordinary`), `nil.not_and` setup failed (blocked by `storage.float.ordinary`), `nil.not_and_false` setup failed (blocked by `storage.float.ordinary`), `nil.not_contradictory_in` setup failed (blocked by `storage.float.ordinary`), `nil.not_equal` setup failed (blocked by `storage.float.ordinary`), `nil.not_equal_negated` setup failed (blocked by `storage.float.ordinary`), `nil.not_in_with_nil` setup failed (blocked by `storage.float.ordinary`), `nil.not_or_false` setup failed (blocked by `storage.float.ordinary`), `nil.or` setup failed (blocked by `storage.float.ordinary`), `nil.partition` setup failed (blocked by `storage.float.ordinary`), `nil.pinned_nil` setup failed (blocked by `storage.float.ordinary`) |
| Filters through to-many relationships return each record once | 🟡 Partial 1/9 | `read.join_count` crashed, `read.join_limit` crashed, `read.join_many_to_many_count` crashed, `read.join_negated` crashed, `read.join_or_paths` crashed, `read.join_page` crashed, `read.join_same_row` crashed, `read.join_to_many` crashed |
| Sort by a related record's attribute | ⛔ Not supported 0/1 | `read.sort_to_one` rejected |
| Calculations feed aggregates, filters and sorts | 🟡 Partial 1/5 | `calc.aggregate_over_calculation` rejected, `calc.argument_sort` rejected, `calc.filter_over_aggregate` crashed, `calc.over_aggregate` rejected |
| Filter by a calculation | ❔ Unknown 1 not run | `record.filter_calculation` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Sort by one or more fields, with explicit nil order | ❔ Unknown 6 not run | `record.sort_asc_nils_first` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.sort_date` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.sort_decimal` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.sort_desc_nils_last` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.sort_string` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.sort_tie_break` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Sort by a calculation | ❔ Unknown 1 not run | `record.sort_calculation` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Limit and offset a query | ❔ Unknown 1 not run | `record.limit_offset` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Count and check existence | ❔ Unknown 1 not run | `record.count` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Stream records in batches | ❔ Unknown 1 not run | `record.stream` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Distinct records by a field | ❔ Unknown 1 not run | `query.distinct` setup failed (blocked by `storage.boolean.ordinary`) |
| Combine queries with union | ❔ Unknown 1 not run | `query.union` setup failed (blocked by `storage.boolean.ordinary`) |
| Combine queries with union all, intersect and except | ❔ Unknown 3 not run | `query.except` setup failed (blocked by `storage.boolean.ordinary`), `query.intersect` setup failed (blocked by `storage.boolean.ordinary`), `query.union_all` setup failed (blocked by `storage.boolean.ordinary`) |
| Load expression calculations, with arguments | ❔ Unknown 3 not run | `calc.in_memory` setup failed (blocked by `storage.boolean.ordinary`), `record.calculation_argument` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `record.calculation_load` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Offset pagination with counts | ❔ Unknown 1 not run | `record.offset_pages` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Keyset pagination, forwards and backwards | ❔ Unknown 1 not run | `record.keyset_pages` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Keyset pagination on nullable, duplicate, descending and calculated keys | ❔ Unknown 5 not run | `keyset.backward` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `keyset.calculation` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `keyset.duplicates_descending_tie` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `keyset.nullable_asc` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`), `keyset.nullable_desc` setup failed (blocked by `storage.boolean.ordinary`, `storage.embedded.ordinary`, `storage.float.ordinary`, `storage.map.ordinary`, `storage.strings.ordinary`) |
| Long in-lists, bulk creates past parameter limits, deep pages and aggregates over thousands of rows | ➖ Not applicable |  |
| Pagination while records change | ⚪ Untested |  |

## 6. Relationships

| Feature | csv | Not working |
| --- | --- | --- |
| Filter across to-many relationships without duplicates | ❔ Unknown 3 not run | `filter.fanout_read_control` setup failed (blocked by `storage.boolean.ordinary`), `use.fanout_count` setup failed (blocked by `storage.boolean.ordinary`), `use.fanout_read_page` setup failed (blocked by `storage.boolean.ordinary`) |
| Limit and offset a has-many load for each parent | ❔ Unknown 2 not run | `load.limit_per_parent` setup failed (blocked by `storage.boolean.ordinary`), `load.offset_per_parent` setup failed (blocked by `storage.boolean.ordinary`) |
| Limit a many-to-many load for each parent | ❔ Unknown 1 not run | `load.many_to_many_limit_per_parent` setup failed (blocked by `storage.boolean.ordinary`) |
| Relationships through other relationships | ❔ Unknown 1 not run | `load.through` setup failed (blocked by `storage.boolean.ordinary`) |
| Relationship default sort applies when loading | ❔ Unknown 1 not run | `bounds.default_sort_control` setup failed (blocked by `storage.boolean.ordinary`) |
| Relationships with no attributes load everything | ❔ Unknown 1 not run | `path.no_attributes_control` setup failed (blocked by `storage.boolean.ordinary`) |
| Relationship context reaches the read action | ❔ Unknown 2 not run | `context.prepared_context_control` setup failed (blocked by `storage.boolean.ordinary`), `context.relationship_context_control` setup failed (blocked by `storage.boolean.ordinary`) |
| Parent references in nested and through relationship filters | ❔ Unknown 2 not run | `filter.nested_parent_control` setup failed (blocked by `storage.boolean.ordinary`), `filter.parent_through_control` setup failed (blocked by `storage.boolean.ordinary`) |
| Load belongs-to, has-one, has-many and many-to-many relationships | ❔ Unknown 4 not run | `load.belongs_to` setup failed (blocked by `storage.boolean.ordinary`), `load.has_many` setup failed (blocked by `storage.boolean.ordinary`), `load.has_one` setup failed (blocked by `storage.boolean.ordinary`), `load.many_to_many` setup failed (blocked by `storage.boolean.ordinary`) |
| Create and update related records with manage_relationship | 🟡 Partial 1/2 | `write.manage_direct_control` rejected |

## 7. Aggregates

| Feature | csv | Not working |
| --- | --- | --- |
| Load each aggregate kind on records | ❔ Unknown 9 not run | `loaded.avg` setup failed (blocked by `storage.boolean.ordinary`), `loaded.count` setup failed (blocked by `storage.boolean.ordinary`), `loaded.custom` setup failed (blocked by `storage.boolean.ordinary`), `loaded.exists` setup failed (blocked by `storage.boolean.ordinary`), `loaded.first` setup failed (blocked by `storage.boolean.ordinary`), `loaded.list` setup failed (blocked by `storage.boolean.ordinary`), `loaded.max` setup failed (blocked by `storage.boolean.ordinary`), `loaded.min` setup failed (blocked by `storage.boolean.ordinary`), `loaded.sum` setup failed (blocked by `storage.boolean.ordinary`) |
| Run each aggregate kind over a whole query | ❔ Unknown 15 not run | `root.avg` setup failed (blocked by `storage.boolean.ordinary`), `root.count` setup failed (blocked by `storage.boolean.ordinary`), `root.custom` setup failed (blocked by `storage.boolean.ordinary`), `root.custom_empty` setup failed (blocked by `storage.boolean.ordinary`), `root.exists` setup failed (blocked by `storage.boolean.ordinary`), `root.first` setup failed (blocked by `storage.boolean.ordinary`), `root.list` setup failed (blocked by `storage.boolean.ordinary`), `root.list_default_empty` setup failed (blocked by `storage.boolean.ordinary`), `root.list_empty` setup failed (blocked by `storage.boolean.ordinary`), `root.list_unsorted` setup failed (blocked by `storage.boolean.ordinary`), `root.max` setup failed (blocked by `storage.boolean.ordinary`), `root.min` setup failed (blocked by `storage.boolean.ordinary`), `root.sum` setup failed (blocked by `storage.boolean.ordinary`), `root.unsorted_first_empty` setup failed (blocked by `storage.boolean.ordinary`), `values.root_empty` setup failed (blocked by `storage.boolean.ordinary`) |
| Defaults, nils, uniqueness and field counts | ❔ Unknown 12 not run | `query.uniq_sum_rejected` setup failed (blocked by `storage.boolean.ordinary`), `values.distinct_count` setup failed (blocked by `storage.boolean.ordinary`), `values.distinct_list` setup failed (blocked by `storage.boolean.ordinary`), `values.field_count` setup failed (blocked by `storage.boolean.ordinary`), `values.filtered_first_default` setup failed (blocked by `storage.boolean.ordinary`), `values.include_nil_first` setup failed (blocked by `storage.boolean.ordinary`), `values.include_nil_list` setup failed (blocked by `storage.boolean.ordinary`), `values.list_default` setup failed (blocked by `storage.boolean.ordinary`), `values.list_unsorted` setup failed (blocked by `storage.boolean.ordinary`), `values.same_name_distinct_definitions` setup failed (blocked by `storage.boolean.ordinary`), `values.scalar_default` setup failed (blocked by `storage.boolean.ordinary`), `values.string_name` setup failed (blocked by `storage.boolean.ordinary`) |
| Aggregate decimals, dates, times and constrained types | ❔ Unknown 15 not run | `root.datetime_max` setup failed (blocked by `storage.boolean.ordinary`), `root.decimal_sum` setup failed (blocked by `storage.boolean.ordinary`), `values.constrained_scalar` setup failed (blocked by `storage.boolean.ordinary`), `values.date_list` setup failed (blocked by `storage.boolean.ordinary`), `values.date_list_desc` setup failed (blocked by `storage.boolean.ordinary`), `values.date_max` setup failed (blocked by `storage.boolean.ordinary`), `values.date_min` setup failed (blocked by `storage.boolean.ordinary`), `values.datetime_first` setup failed (blocked by `storage.boolean.ordinary`), `values.datetime_max` setup failed (blocked by `storage.boolean.ordinary`), `values.datetime_min` setup failed (blocked by `storage.boolean.ordinary`), `values.decimal_avg` setup failed (blocked by `storage.boolean.ordinary`), `values.decimal_max` setup failed (blocked by `storage.boolean.ordinary`), `values.decimal_sum` setup failed (blocked by `storage.boolean.ordinary`), `values.string_constraints` setup failed (blocked by `storage.boolean.ordinary`), `values.time_min` setup failed (blocked by `storage.boolean.ordinary`) |
| Order first and list aggregates, including nils and ties | ❔ Unknown 9 not run | `ordering.asc_nils_first` setup failed (blocked by `storage.boolean.ordinary`), `ordering.asc_nils_last` setup failed (blocked by `storage.boolean.ordinary`), `ordering.desc_nils_first` setup failed (blocked by `storage.boolean.ordinary`), `ordering.desc_nils_last` setup failed (blocked by `storage.boolean.ordinary`), `ordering.expression_first` setup failed (blocked by `storage.boolean.ordinary`), `ordering.expression_list` setup failed (blocked by `storage.boolean.ordinary`), `ordering.list_desc` setup failed (blocked by `storage.boolean.ordinary`), `ordering.ties` setup failed (blocked by `storage.boolean.ordinary`), `ordering.unique_other_field` setup failed (blocked by `storage.boolean.ordinary`) |
| Aggregate calculations and other aggregates | ❔ Unknown 3 not run | `field.aggregate` setup failed (blocked by `storage.boolean.ordinary`), `field.calculation` setup failed (blocked by `storage.boolean.ordinary`), `field.root_aggregate` setup failed (blocked by `storage.boolean.ordinary`) |
| Filter the records an aggregate uses | ❔ Unknown 6 not run | `filter.exists` setup failed (blocked by `storage.boolean.ordinary`), `filter.join` setup failed (blocked by `storage.boolean.ordinary`), `filter.not_exists` setup failed (blocked by `storage.boolean.ordinary`), `filter.or_exists` setup failed (blocked by `storage.boolean.ordinary`), `filter.ordinary` setup failed (blocked by `storage.boolean.ordinary`), `filter.sibling_independence` setup failed (blocked by `storage.boolean.ordinary`) |
| Aggregate filters through to-many relationships count each record once | ❔ Unknown 11 not run | `filter.fanout_and` setup failed (blocked by `storage.boolean.ordinary`), `filter.fanout_avg` setup failed (blocked by `storage.boolean.ordinary`), `filter.fanout_count` setup failed (blocked by `storage.boolean.ordinary`), `filter.fanout_count_records` setup failed (blocked by `storage.boolean.ordinary`), `filter.fanout_custom` setup failed (blocked by `storage.boolean.ordinary`), `filter.fanout_list` setup failed (blocked by `storage.boolean.ordinary`), `filter.fanout_nil_count` setup failed (blocked by `storage.boolean.ordinary`), `filter.fanout_not_count` setup failed (blocked by `storage.boolean.ordinary`), `filter.fanout_or` setup failed (blocked by `storage.boolean.ordinary`), `filter.fanout_sum` setup failed (blocked by `storage.boolean.ordinary`), `identity.composite_fanout_count` setup failed (blocked by `storage.boolean.ordinary`) |
| Aggregate filters that use other aggregates | ❔ Unknown 5 not run | `filter.aggregate_dependency` setup failed (blocked by `storage.boolean.ordinary`), `filter.aggregate_dependency_calculation` setup failed (blocked by `storage.boolean.ordinary`), `filter.aggregate_dependency_filtered` setup failed (blocked by `storage.boolean.ordinary`), `filter.aggregate_dependency_many_to_many` setup failed (blocked by `storage.boolean.ordinary`), `filter.aggregate_dependency_to_one` setup failed (blocked by `storage.boolean.ordinary`) |
| Aggregate filters that reference the parent record | ❔ Unknown 8 not run | `filter.nested_parent` setup failed (blocked by `storage.boolean.ordinary`), `filter.parent` setup failed (blocked by `storage.boolean.ordinary`), `filter.parent_join` setup failed (blocked by `storage.boolean.ordinary`), `filter.parent_relationship` setup failed (blocked by `storage.boolean.ordinary`), `filter.parent_through` setup failed (blocked by `storage.boolean.ordinary`), `filter.parent_unrelated` setup failed (blocked by `storage.boolean.ordinary`), `use.parent_filter` setup failed (blocked by `storage.boolean.ordinary`), `use.parent_sort` setup failed (blocked by `storage.boolean.ordinary`) |
| Aggregate over to-one, multi-hop and many-to-many paths | ❔ Unknown 17 not run | `path.final_many_to_many_custom` setup failed (blocked by `storage.boolean.ordinary`), `path.final_many_to_many_first` setup failed (blocked by `storage.boolean.ordinary`), `path.final_many_to_many_list` setup failed (blocked by `storage.boolean.ordinary`), `path.final_many_to_many_scalar` setup failed (blocked by `storage.boolean.ordinary`), `path.intermediate_many_to_many` setup failed (blocked by `storage.boolean.ordinary`), `path.many_to_many` setup failed (blocked by `storage.boolean.ordinary`), `path.many_to_many_first` setup failed (blocked by `storage.boolean.ordinary`), `path.many_to_many_list` setup failed (blocked by `storage.boolean.ordinary`), `path.multi_hop` setup failed (blocked by `storage.boolean.ordinary`), `path.repeated_many_to_many` setup failed (blocked by `storage.boolean.ordinary`), `path.root_relationship` setup failed (blocked by `storage.boolean.ordinary`), `path.through_count` setup failed (blocked by `storage.boolean.ordinary`), `path.to_one` setup failed (blocked by `storage.boolean.ordinary`), `path.to_one_to_many_first` setup failed (blocked by `storage.boolean.ordinary`), `path.to_one_to_many_list` setup failed (blocked by `storage.boolean.ordinary`), `path.to_one_to_many_sum` setup failed (blocked by `storage.boolean.ordinary`), `path.unrelated` setup failed (blocked by `storage.boolean.ordinary`) |
| Aggregate over manual and attribute-free relationships | ❔ Unknown 3 not run | `path.manual` setup failed (blocked by `storage.boolean.ordinary`), `path.no_attributes` setup failed (blocked by `storage.boolean.ordinary`), `path.no_attributes_parent` setup failed (blocked by `storage.boolean.ordinary`) |
| Aggregate over limited, offset and from-many relationships | ❔ Unknown 9 not run | `bounds.default_sort` setup failed (blocked by `storage.boolean.ordinary`), `bounds.filter_after_limit` setup failed (blocked by `storage.boolean.ordinary`), `bounds.from_many` setup failed (blocked by `storage.boolean.ordinary`), `bounds.list_filter_after_limit` setup failed (blocked by `storage.boolean.ordinary`), `bounds.many_to_many_query_limit` setup failed (blocked by `storage.boolean.ordinary`), `bounds.relationship_limit` setup failed (blocked by `storage.boolean.ordinary`), `bounds.relationship_offset` setup failed (blocked by `storage.boolean.ordinary`), `bounds.relationship_offset_only` setup failed (blocked by `storage.boolean.ordinary`), `bounds.unsorted_limit` setup failed (blocked by `storage.boolean.ordinary`) |
| Root aggregates over sorted, limited and offset queries | ❔ Unknown 7 not run | `bounds.root_custom_limit` setup failed (blocked by `storage.boolean.ordinary`), `bounds.root_first_distinct_sort` setup failed (blocked by `storage.boolean.ordinary`), `bounds.root_limit` setup failed (blocked by `storage.boolean.ordinary`), `bounds.root_list_limit` setup failed (blocked by `storage.boolean.ordinary`), `bounds.root_offset_only` setup failed (blocked by `storage.boolean.ordinary`), `bounds.root_order_then_limit` setup failed (blocked by `storage.boolean.ordinary`), `bounds.root_zero` setup failed (blocked by `storage.boolean.ordinary`) |
| Distinct counts over composite and missing keys | ❔ Unknown 5 not run | `identity.composite_count` setup failed (blocked by `storage.boolean.ordinary`), `identity.keyless_count` setup failed (blocked by `storage.boolean.ordinary`), `identity.keyless_distinct` setup failed (blocked by `storage.boolean.ordinary`), `identity.keyless_source` setup failed (blocked by `storage.boolean.ordinary`), `identity.root_composite_count` setup failed (blocked by `storage.boolean.ordinary`) |
| Filter, sort, paginate and calculate with aggregates | ❔ Unknown 10 not run | `use.calculation` setup failed (blocked by `storage.boolean.ordinary`), `use.filter` setup failed (blocked by `storage.boolean.ordinary`), `use.keyset_pagination` setup failed (blocked by `storage.boolean.ordinary`), `use.nested_limited_load` setup failed (blocked by `storage.boolean.ordinary`), `use.pagination` setup failed (blocked by `storage.boolean.ordinary`), `use.related_exists` setup failed (blocked by `storage.boolean.ordinary`), `use.related_filter` setup failed (blocked by `storage.boolean.ordinary`), `use.sort` setup failed (blocked by `storage.boolean.ordinary`), `use.to_one_filter` setup failed (blocked by `storage.boolean.ordinary`), `use.to_one_sort` setup failed (blocked by `storage.boolean.ordinary`) |
| Aggregates respect read actions, arguments, actor and context | ❔ Unknown 9 not run | `context.actor` setup failed (blocked by `storage.boolean.ordinary`), `context.arguments` setup failed (blocked by `storage.boolean.ordinary`), `context.intermediate_action` setup failed (blocked by `storage.boolean.ordinary`), `context.intermediate_actor` setup failed (blocked by `storage.boolean.ordinary`), `context.prepared_query_arguments` setup failed (blocked by `storage.boolean.ordinary`), `context.read_action` setup failed (blocked by `storage.boolean.ordinary`), `context.relationship_context` setup failed (blocked by `storage.boolean.ordinary`), `context.shared` setup failed (blocked by `storage.boolean.ordinary`), `context.through_arguments` setup failed (blocked by `storage.boolean.ordinary`) |
| Seeded filtered aggregates match an in-memory reference | ❔ Unknown 23 not run | `generated.loaded.count.gt_6` setup failed (blocked by `storage.boolean.ordinary`), `generated.loaded.count.gt_7` setup failed (blocked by `storage.boolean.ordinary`), `generated.loaded.count.gte_6` setup failed (blocked by `storage.boolean.ordinary`), `generated.loaded.count.lt_5` setup failed (blocked by `storage.boolean.ordinary`), `generated.loaded.exists.gt_0` setup failed (blocked by `storage.boolean.ordinary`), `generated.loaded.exists.lt_2` setup failed (blocked by `storage.boolean.ordinary`), `generated.loaded.exists.lt_5` setup failed (blocked by `storage.boolean.ordinary`), `generated.loaded.min.gt_2` setup failed (blocked by `storage.boolean.ordinary`), `generated.loaded.min.gt_6` setup failed (blocked by `storage.boolean.ordinary`), `generated.loaded.min.lt_8` setup failed (blocked by `storage.boolean.ordinary`), `generated.loaded.sum.lt_0` setup failed (blocked by `storage.boolean.ordinary`), `generated.loaded.sum.lt_7` setup failed (blocked by `storage.boolean.ordinary`), `generated.root.count.gte_0` setup failed (blocked by `storage.boolean.ordinary`), `generated.root.count.gte_1` setup failed (blocked by `storage.boolean.ordinary`), `generated.root.count.gte_5` setup failed (blocked by `storage.boolean.ordinary`), `generated.root.exists.gt_7` setup failed (blocked by `storage.boolean.ordinary`), `generated.root.max.gte_5` setup failed (blocked by `storage.boolean.ordinary`), `generated.root.max.lt_2` setup failed (blocked by `storage.boolean.ordinary`), `generated.root.min.lt_0` setup failed (blocked by `storage.boolean.ordinary`), `generated.root.min.lt_2` setup failed (blocked by `storage.boolean.ordinary`), `generated.root.sum.gt_2` setup failed (blocked by `storage.boolean.ordinary`), `generated.root.sum.gte_0` setup failed (blocked by `storage.boolean.ordinary`), `generated.root.sum.gte_4` setup failed (blocked by `storage.boolean.ordinary`) |

## 8. Writes

| Feature | csv | Not working |
| --- | --- | --- |
| Upsert on an identity, in bulk, with conditions | 🟡 Partial 2/4 | `upsert.condition` wrong, `upsert.skipped_record` wrong |
| Identities and upserts on keys that can be nil, and upsert fields | 🟡 Partial 2/5 | `identity.nils_distinct` rejected, `identity.nils_not_distinct` rejected, `upsert.nil_key_not_distinct` wrong |
| Bulk create with partial success | ❌ Broken 0/1 | `bulk.partial_success` crashed |
| Bulk update atomically | ❌ Broken 0/1 | `bulk.atomic_increment` wrong |
| Writes that filter by or read aggregates | ❔ Unknown 4 not run | `write.atomic_update` setup failed (blocked by `storage.boolean.ordinary`), `write.bulk_destroy_filter` setup failed (blocked by `storage.boolean.ordinary`), `write.bulk_update_filter` setup failed (blocked by `storage.boolean.ordinary`), `write.single_atomic_update` setup failed (blocked by `storage.boolean.ordinary`) |
| Atomic updates with expressions, and bulk writes over sorted, limited queries | 🟡 Partial 2/4 | `write.atomic_expression` rejected, `write.bulk_create_sorted` crashed |

## 9. Transactions and locks

| Feature | csv | Not working |
| --- | --- | --- |
| Failed actions and transactions roll back | 🟡 Partial 1/4 | `txn.after_action_rollback` wrong, `txn.explicit_rollback` wrong, `txn.raise_rollback` wrong |
| Lock rows for update | ❔ Unknown 1 not run | `query.lock_for_update` setup failed (blocked by `storage.boolean.ordinary`) |
| Isolation between concurrent transactions | ⚪ Untested |  |

## 10. Multitenancy

| Feature | csv | Not working |
| --- | --- | --- |
| Attribute tenancy scopes reads and requires a tenant | 🟡 Partial 5/6 | `tenant.invalid` wrong |
| Tenancy scopes related records and their bounds | 🟡 Partial 3/4 | `tenant.relationship_filter` crashed |
| Tenancy scopes aggregates, including explicit bypass | ⛔ Not supported 0/3 · 5 not run | `context.attribute_tenant` setup failed (blocked by `storage.boolean.ordinary`), `context.bypass_sibling` setup failed (blocked by `storage.boolean.ordinary`), `context.tenant_bypass` setup failed (blocked by `storage.boolean.ordinary`), `context.through_bypass` setup failed (blocked by `storage.boolean.ordinary`), `context.through_tenant` setup failed (blocked by `storage.boolean.ordinary`), `tenant.aggregate_filter_sort` rejected, `tenant.loaded_aggregates` rejected, `tenant.root_aggregates` rejected |
| Tenancy scopes pages and counts | ⛔ Not supported 0/2 | `tenant.aggregate_keyset_pages` rejected, `tenant.aggregate_offset_page` rejected |
| Tenancy scopes creates, updates and destroys | ✅ Works 3/3 |  |
| Schema-based (context) tenancy | ➖ Not applicable |  |

## 11. Authorization

| Feature | csv | Not working |
| --- | --- | --- |
| Policies filter reads | ✅ Works 3/3 |  |
| Policies filter related records before bounds | 🔸 Incomplete 4/4 · 1 not run | `context.authorization_bounds_control` setup failed (blocked by `storage.boolean.ordinary`) |
| Policies filter what aggregates count | ⛔ Not supported 0/6 · 2 not run | `auth.aggregate_filter` rejected, `auth.aggregate_sort` rejected, `auth.context_aggregates` rejected, `auth.context_root` rejected, `auth.loaded_aggregates` rejected, `auth.root_aggregates` rejected, `context.authorization` setup failed (blocked by `storage.boolean.ordinary`), `context.authorization_before_bounds` setup failed (blocked by `storage.boolean.ordinary`) |
| Policies filter pages and counts | ⛔ Not supported 0/3 | `auth.keyset_pages` rejected, `auth.offset_page` rejected, `auth.tenant_interaction` rejected |
| Policies filter and forbid writes | 🟡 Partial 3/4 | `auth.write_bulk_update_stream` wrong |

## 12. Policies

| Feature | csv | Not working |
| --- | --- | --- |
| A filter policy on the actor | 🟡 Partial 7/16 · 8 blocked | `policy.owner.aggregate_filter` rejected (blocked by `policy.control.aggregate_filter`), `policy.owner.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.owner.count` rejected (blocked by `policy.control.count`), `policy.owner.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.owner.get_error` crashed, `policy.owner.loaded_count` rejected (blocked by `policy.control.loaded_count`), `policy.owner.loaded_sum` rejected (blocked by `policy.control.loaded_sum`), `policy.owner.offset_page` rejected (blocked by `policy.control.offset_page`), `policy.owner.sum` rejected (blocked by `policy.control.sum`) |
| The same policy with no actor | 🟡 Partial 10/16 · 5 blocked | `policy.owner_nil_actor.aggregate_filter` rejected (blocked by `policy.control.aggregate_filter`), `policy.owner_nil_actor.bulk_destroy` wrong, `policy.owner_nil_actor.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.owner_nil_actor.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.owner_nil_actor.loaded_count` rejected (blocked by `policy.control.loaded_count`), `policy.owner_nil_actor.loaded_sum` rejected (blocked by `policy.control.loaded_sum`) |
| forbid_if before authorize_if | 🟡 Partial 7/16 · 8 blocked | `policy.forbid.aggregate_filter` rejected (blocked by `policy.control.aggregate_filter`), `policy.forbid.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.forbid.count` rejected (blocked by `policy.control.count`), `policy.forbid.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.forbid.get_error` crashed, `policy.forbid.loaded_count` rejected (blocked by `policy.control.loaded_count`), `policy.forbid.loaded_sum` rejected (blocked by `policy.control.loaded_sum`), `policy.forbid.offset_page` rejected (blocked by `policy.control.offset_page`), `policy.forbid.sum` rejected (blocked by `policy.control.sum`) |
| A bypass policy, for an actor it does not let through | 🟡 Partial 7/16 · 8 blocked | `policy.bypass.aggregate_filter` rejected (blocked by `policy.control.aggregate_filter`), `policy.bypass.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.bypass.count` rejected (blocked by `policy.control.count`), `policy.bypass.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.bypass.get_error` crashed, `policy.bypass.loaded_count` rejected (blocked by `policy.control.loaded_count`), `policy.bypass.loaded_sum` rejected (blocked by `policy.control.loaded_sum`), `policy.bypass.offset_page` rejected (blocked by `policy.control.offset_page`), `policy.bypass.sum` rejected (blocked by `policy.control.sum`) |
| A bypass policy, for an actor it lets through | 🟡 Partial 5/13 · 8 blocked | `policy.bypass_admin.aggregate_filter` rejected (blocked by `policy.control.aggregate_filter`), `policy.bypass_admin.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.bypass_admin.count` rejected (blocked by `policy.control.count`), `policy.bypass_admin.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.bypass_admin.loaded_count` rejected (blocked by `policy.control.loaded_count`), `policy.bypass_admin.loaded_sum` rejected (blocked by `policy.control.loaded_sum`), `policy.bypass_admin.offset_page` rejected (blocked by `policy.control.offset_page`), `policy.bypass_admin.sum` rejected (blocked by `policy.control.sum`) |
| Two policies that must both pass | 🟡 Partial 7/16 · 8 blocked | `policy.all_of.aggregate_filter` rejected (blocked by `policy.control.aggregate_filter`), `policy.all_of.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.all_of.count` rejected (blocked by `policy.control.count`), `policy.all_of.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.all_of.get_error` crashed, `policy.all_of.loaded_count` rejected (blocked by `policy.control.loaded_count`), `policy.all_of.loaded_sum` rejected (blocked by `policy.control.loaded_sum`), `policy.all_of.offset_page` rejected (blocked by `policy.control.offset_page`), `policy.all_of.sum` rejected (blocked by `policy.control.sum`) |
| One policy whose checks either pass | 🟡 Partial 7/16 · 8 blocked | `policy.any_of.aggregate_filter` rejected (blocked by `policy.control.aggregate_filter`), `policy.any_of.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.any_of.count` rejected (blocked by `policy.control.count`), `policy.any_of.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.any_of.get_error` crashed, `policy.any_of.loaded_count` rejected (blocked by `policy.control.loaded_count`), `policy.any_of.loaded_sum` rejected (blocked by `policy.control.loaded_sum`), `policy.any_of.offset_page` rejected (blocked by `policy.control.offset_page`), `policy.any_of.sum` rejected (blocked by `policy.control.sum`) |
| A policy on a to-one relationship | 🟡 Partial 1/16 · 8 blocked | `policy.related.aggregate_filter` rejected (blocked by `policy.control.aggregate_filter`), `policy.related.bulk_destroy` crashed, `policy.related.bulk_update` crashed (blocked by `policy.control.bulk_update`), `policy.related.count` crashed (blocked by `policy.control.count`), `policy.related.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.related.get_error` crashed, `policy.related.get_hidden` crashed, `policy.related.keyset_pages` crashed, `policy.related.load` crashed, `policy.related.loaded_count` rejected (blocked by `policy.control.loaded_count`), `policy.related.loaded_sum` rejected (blocked by `policy.control.loaded_sum`), `policy.related.offset_page` crashed (blocked by `policy.control.offset_page`), `policy.related.read` crashed, `policy.related.sum` crashed (blocked by `policy.control.sum`), `policy.related.update_hidden` crashed |
| A policy on a multi-hop exists | 🟡 Partial 7/16 · 8 blocked | `policy.member.aggregate_filter` rejected (blocked by `policy.control.aggregate_filter`), `policy.member.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.member.count` rejected (blocked by `policy.control.count`), `policy.member.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.member.get_error` crashed, `policy.member.loaded_count` rejected (blocked by `policy.control.loaded_count`), `policy.member.loaded_sum` rejected (blocked by `policy.control.loaded_sum`), `policy.member.offset_page` rejected (blocked by `policy.control.offset_page`), `policy.member.sum` rejected (blocked by `policy.control.sum`) |
| A policy composed with can_read | 🟡 Partial 7/16 · 8 blocked | `policy.can_read.aggregate_filter` rejected (blocked by `policy.control.aggregate_filter`), `policy.can_read.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.can_read.count` rejected (blocked by `policy.control.count`), `policy.can_read.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.can_read.get_error` crashed, `policy.can_read.loaded_count` rejected (blocked by `policy.control.loaded_count`), `policy.can_read.loaded_sum` rejected (blocked by `policy.control.loaded_sum`), `policy.can_read.offset_page` rejected (blocked by `policy.control.offset_page`), `policy.can_read.sum` rejected (blocked by `policy.control.sum`) |
| A strict policy, for an actor it forbids | 🟡 Partial 10/16 · 5 blocked | `policy.strict.aggregate_filter` rejected (blocked by `policy.control.aggregate_filter`), `policy.strict.bulk_destroy` wrong, `policy.strict.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.strict.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.strict.loaded_count` rejected (blocked by `policy.control.loaded_count`), `policy.strict.loaded_sum` rejected (blocked by `policy.control.loaded_sum`) |
| A strict policy, for an actor it allows | 🟡 Partial 5/13 · 8 blocked | `policy.strict_admin.aggregate_filter` rejected (blocked by `policy.control.aggregate_filter`), `policy.strict_admin.bulk_update` wrong (blocked by `policy.control.bulk_update`), `policy.strict_admin.count` rejected (blocked by `policy.control.count`), `policy.strict_admin.exists_filter_input` crashed (blocked by `policy.control.exists_filter_input`), `policy.strict_admin.loaded_count` rejected (blocked by `policy.control.loaded_count`), `policy.strict_admin.loaded_sum` rejected (blocked by `policy.control.loaded_sum`), `policy.strict_admin.offset_page` rejected (blocked by `policy.control.offset_page`), `policy.strict_admin.sum` rejected (blocked by `policy.control.sum`) |
| Field policies hide values, in reads, filters and aggregates | 🟡 Partial 3/4 · 1 blocked | `policy.field.field_aggregate` rejected (blocked by `policy.control.field_aggregate`) |
| A filter check on create runs after the insert | 🟡 Partial 1/2 | `policy.owner.create_other` wrong |
| Every policy path, without authorization | 🟡 Partial 13/22 | `policy.control.aggregate_filter` rejected, `policy.control.bulk_update` wrong, `policy.control.count` rejected, `policy.control.exists_filter_input` crashed, `policy.control.field_aggregate` rejected, `policy.control.loaded_count` rejected, `policy.control.loaded_sum` rejected, `policy.control.offset_page` rejected, `policy.control.sum` rejected |

## 13. Combinations

| Feature | csv | Not working |
| --- | --- | --- |
| Each combined feature works on its own | ➖ Not applicable |  |
| Features work together, pair by pair | ➖ Not applicable |  |

## 14. Consistency checks

| Feature | csv | Not working |
| --- | --- | --- |
| Counts match loads, and root sums match an in-memory reference | ⛔ Not supported 0/2 | `equivalence.root_reference` rejected, `equivalence.visible_count_load` rejected |

## Claims versus results

A data layer's `can?/2` claims never decide what runs. This lists features
whose claims disagree with the result:

- advertised, but not working;
- working without being advertised, usually because Ash provides it;
- not advertised, yet not rejected, and giving wrong answers.

| Feature | Adapter | Mismatch |
| --- | --- | --- |
| Bulk create with partial success | csv | Not advertising `tenant_item: :bulk_create_with_partial_success`, but not rejected either: wrong answers |
| Bulk update atomically | csv | Not advertising `tenant_item: :update_query`, `tenant_item: {:atomic, :update}`, but not rejected either: wrong answers |
| Tenancy scopes creates, updates and destroys | csv | Works without advertising `tenant_item: :destroy_query` |
| Policies filter pages and counts | csv | Advertised, but ⛔ Not supported |


## Storage

Each cell shows the ordinary, edge and nil values, in that order. ✅ reads
back unchanged; ≈ reads back equal but in another representation, such as
`1.5` as `1.5000000000`; ❌ is lost or rejected; 🚫 the table could not be
created; 🔀 differs between seed orders; ❔ did not run; – the type has no
values of that class.

| Type | Column | Ordinary | Edge | Nil | First problem |
| --- | --- | --- | --- | --- | --- |
| Integers | `—` | ✅ | ✅ | ✅ |  |
| Floats | `—` | ❌ | ❌ | ✅ | ordinary, create: stored value for value could not be casted from the stored value to type Ash.Type.Float: "1.5" |
| Decimals | `—` | ✅ | ✅ | ✅ |  |
| Strings | `—` | ✅ | ❌ | ✅ | edge, read: nil |
| Case-insensitive strings | `—` | ✅ | ❌ | ✅ | edge, read: nil |
| Binaries | `—` | ❌ | ❌ | ✅ | ordinary, update: "dGV4dA==" |
| Booleans | `—` | ❌ | – | ✅ | ordinary, create: stored value for value could not be casted from the stored value to type Ash.Type.Boolean: "true" |
| Atoms with one_of | `—` | ✅ | – | ✅ |  |
| Dates | `—` | ✅ | ✅ | ✅ |  |
| Times | `—` | ✅ | ✅ | ✅ |  |
| Microsecond times | `—` | ✅ | ✅ | ✅ |  |
| UTC datetimes | `—` | ✅ | ✅ | ✅ |  |
| Microsecond UTC datetimes | `—` | ✅ | ✅ | ✅ |  |
| Naive datetimes | `—` | ✅ | ✅ | ✅ |  |
| Durations | `—` | ❌ | ❌ | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol String.Chars not implemented for Duration (a struct) |
| UUIDs | `—` | ✅ | ✅ | ✅ |  |
| UUIDv7s | `—` | ✅ | – | ✅ |  |
| Maps | `—` | ❌ | ❌ | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol String.Chars not implemented for Map |
| Arrays of strings | `—` | ❌ | ❌ | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol Enumerable not implemented for BitString |
| Arrays of integers | `—` | ❌ | ❌ | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol Enumerable not implemented for BitString |
| Embedded resources | `—` | ❌ | ❌ | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol String.Chars not implemented for Ash.Conformance.Resources.Address (a struct) |
| Arrays of embedded resources | `—` | ❌ | ❌ | ✅ | ordinary, create: ** (ArgumentError) cannot convert the given list to a string. |
| Unions | `—` | ❌ | – | ✅ | ordinary, create: ** (Protocol.UndefinedError) protocol String.Chars not implemented for Ash.Union (a struct) |

## Operations

✅ returns the answer Ash defines; ❌ does not, while the same operation
works on integers and the type stores; ◌ blocked: the operation fails on
integers too, or the type does not store; 🔀 the answer changes with the
order rows were stored in; ❔ did not run; – does not apply to the type.

| Type | `eq` | `in` | `is_nil` | `gt` | `sort` | `count` | `min` | `max` | `sum` | `first` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Integers | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Floats | ❔ | ❔ | ❔ | ❔ | ❔ | ❔ | ❔ | ❔ | ❔ | ❔ |
| Decimals | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ◌ | ◌ |
| Strings | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | – | ◌ |
| Case-insensitive strings | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | – | ◌ |
| Binaries | ✅ | ✅ | ✅ | – | – | ◌ | – | – | – | ◌ |
| Booleans | ❔ | ❔ | ❔ | – | – | ❔ | – | – | – | ❔ |
| Atoms with one_of | ✅ | ✅ | ✅ | – | – | ◌ | – | – | – | ◌ |
| Dates | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | – | ◌ |
| Times | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | – | ◌ |
| Microsecond times | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | – | ◌ |
| UTC datetimes | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | – | ◌ |
| Microsecond UTC datetimes | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | – | ◌ |
| Naive datetimes | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | – | ◌ |
| Durations | ❔ | ❔ | ❔ | – | – | ❔ | – | – | – | ❔ |
| UUIDs | ✅ | ✅ | ✅ | – | – | ◌ | – | – | – | ◌ |
| UUIDv7s | ✅ | ✅ | ✅ | – | – | ◌ | – | – | – | ◌ |
| Maps | – | – | ❔ | – | – | ❔ | – | – | – | ❔ |
| Arrays of strings | – | – | ❔ | – | – | ❔ | – | – | – | ❔ |
| Arrays of integers | – | – | ❔ | – | – | ❔ | – | – | – | ❔ |
| Embedded resources | – | – | ❔ | – | – | ❔ | – | – | – | ❔ |
| Arrays of embedded resources | – | – | ❔ | – | – | ❔ | – | – | – | ❔ |
| Unions | – | – | ❔ | – | – | ❔ | – | – | – | ❔ |

## Policies

✅ returns the answer Ash's policy semantics define; ❌ does not, while the
same path works without authorization; ◌ the path fails even without
authorization, so the policy cannot be judged; 🔀 the answer changes with
the order rows were stored in; ❔ did not run; – does not apply, such as
getting a hidden record when the actor may read every note.

| Case | `read` | `get_hidden` | `get_error` | `count` | `sum` | `offset_page` | `keyset_pages` | `load` | `loaded_count` | `loaded_sum` | `aggregate_filter` | `exists_filter` | `exists_filter_input` | `bulk_update` | `bulk_destroy` | `update_hidden` | `field_read` | `field_filter` | `field_filter_input` | `field_aggregate` | `create_own` | `create_other` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| owner | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | ✅ | ❌ |
| owner_nil_actor | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ❌ | ✅ | – | – | – | – | – | – |
| forbid | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| bypass | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| bypass_admin | ✅ | – | – | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | – | – | – | – | – | – | – |
| all_of | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| any_of | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| related | ❌ | ❌ | ❌ | ◌ | ◌ | ◌ | ❌ | ❌ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ❌ | ❌ | – | – | – | – | – | – |
| member | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| can_read | ✅ | ✅ | ❌ | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | ✅ | – | – | – | – | – | – |
| strict | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ❌ | ✅ | – | – | – | – | – | – |
| strict_admin | ✅ | – | – | ◌ | ◌ | ◌ | ✅ | ✅ | ◌ | ◌ | ◌ | ✅ | ◌ | ◌ | ✅ | – | – | – | – | – | – | – |
| field | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | – | ✅ | ✅ | ✅ | ◌ | – | – |
| control (no authorization) | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |


## Blockers

| Blocker | Its result | Not run | Failing | Only blocker of |
| --- | --- | ---: | ---: | ---: |
| `storage.boolean.ordinary` | error at create: stored value for value could not be casted from the stored value to type Ash.Type.Boolean: "true" | 282 | 0 | 219 |
| `storage.float.ordinary` | error at create: stored value for value could not be casted from the stored value to type Ash.Type.Float: "1.5" | 117 | 0 | 54 |
| `storage.embedded.ordinary` | error at create: ** (Protocol.UndefinedError) protocol String.Chars not implemented for Ash.Conformance.Resources.Address (a struct) | 66 | 0 | 3 |
| `storage.map.ordinary` | error at create: ** (Protocol.UndefinedError) protocol String.Chars not implemented for Map | 66 | 0 | 3 |
| `storage.strings.ordinary` | error at create: ** (Protocol.UndefinedError) protocol Enumerable not implemented for BitString | 66 | 0 | 3 |
| `ops.integer.count` | rejected | 0 | 13 | 13 |
| `ops.integer.first` | rejected | 0 | 13 | 13 |
| `policy.control.aggregate_filter` | rejected | 0 | 12 | 12 |
| `policy.control.bulk_update` | wrong | 0 | 12 | 12 |
| `policy.control.exists_filter_input` | crashed | 0 | 12 | 12 |
| `policy.control.loaded_count` | rejected | 0 | 12 | 12 |
| `policy.control.loaded_sum` | rejected | 0 | 12 | 12 |
| `policy.control.count` | rejected | 0 | 10 | 10 |
| `policy.control.offset_page` | rejected | 0 | 10 | 10 |
| `policy.control.sum` | rejected | 0 | 10 | 10 |
| `ops.integer.max` | rejected | 0 | 9 | 9 |
| `ops.integer.min` | rejected | 0 | 9 | 9 |
| `storage.duration.ordinary` | error at create: ** (Protocol.UndefinedError) protocol String.Chars not implemented for Duration (a struct) | 5 | 0 | 5 |
| `storage.embeddeds.ordinary` | error at create: ** (ArgumentError) cannot convert the given list to a string. | 3 | 0 | 3 |
| `storage.integers.ordinary` | error at create: ** (Protocol.UndefinedError) protocol Enumerable not implemented for BitString | 3 | 0 | 3 |
| `storage.union.ordinary` | error at create: ** (Protocol.UndefinedError) protocol String.Chars not implemented for Ash.Union (a struct) | 3 | 0 | 3 |
| `ops.integer.sum` | rejected | 0 | 1 | 1 |
| `policy.control.field_aggregate` | rejected | 0 | 1 | 1 |
