# SPDX-FileCopyrightText: 2026 ash contributors <https://github.com/ash-project/ash/graphs/contributors>
# SPDX-License-Identifier: MIT

defmodule Ash.Conformance.Resources do
  @moduledoc """
  Every shared resource role for one adapter, in a single `use`:

      defmodule MyAdapter.Resources do
        use Ash.Conformance.Resources, namespace: MyAdapter, adapter: MyAdapter
      end

  Surveyed adapters can instead call `compile!/1` from `setup!/0`. Ash checks a
  resource against its data layer when the resource is defined, and reports
  what the data layer cannot support as warnings; compiling at setup keeps
  those warnings as findings rather than build failures.
  """

  defmacro __using__(opts) do
    quote do
      use Ash.Conformance.Resources.Aggregate, unquote(opts)
      use Ash.Conformance.Resources.Records, unquote(opts)
      use Ash.Conformance.Resources.Isolation, unquote(opts)
      use Ash.Conformance.Resources.Writes, unquote(opts)
      use Ash.Conformance.Resources.Storage, unquote(opts)
      use Ash.Conformance.Resources.Policy, unquote(opts)
    end
  end

  @doc """
  Defines `<adapter>.Resources` once per VM and returns the definition
  warnings Ash printed, one entry per distinct message.
  """
  def compile!(adapter) do
    key = {__MODULE__, adapter}

    case :persistent_term.get(key, nil) do
      nil ->
        {:ok, _} = Application.ensure_all_started(:ex_unit)

        {_, output} =
          ExUnit.CaptureIO.with_io(:stderr, fn ->
            Code.compile_quoted(
              quote do
                defmodule unquote(Module.concat(adapter, Resources)) do
                  use Ash.Conformance.Resources,
                    namespace: unquote(adapter),
                    adapter: unquote(adapter)
                end
              end
            )
          end)

        warnings = definition_warnings(output)
        :persistent_term.put(key, warnings)
        warnings

      warnings ->
        warnings
    end
  end

  @doc "The definition warnings kept by `compile!/1`, or `[]` if it has not run."
  def warnings(adapter), do: :persistent_term.get({__MODULE__, adapter}, [])

  # Spark prints each verifier failure as a DslError naming the resource, an
  # optional `section -> entity defined in file:line:` location, then the
  # reason. Keep the reason, without the resource, location or stack.
  defp definition_warnings(output) do
    output
    |> String.split(~r/warning: \*\* \(Spark\.Error\.DslError\)/)
    |> Enum.drop(1)
    |> Enum.map(fn chunk ->
      chunk
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(
        &(&1 == "" or String.starts_with?(&1, ["(", "[", "│", "└", "warning:"]) or
            &1 =~ ~r/ -> .* defined in \S*:\d*:$/)
      )
      |> Enum.take(1)
      |> Enum.join()
    end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {message, count} -> {-count, message} end)
  end
end
