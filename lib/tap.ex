defmodule Tap do
  @moduledoc """
  Tracing of Elixir and Erlang functions.

  Each trace runs in its own OTP trace session, so concurrent traces do not
  affect each other.
  """

  @doc ~S"""
  Traces calls, return values and exceptions from the function call template
  given as an argument.

  The template names a module, a function and its arguments. An argument is
  either `_`, which matches any value, or a value that the argument must
  equal. Only the template's arity is traced. Raises
  `UndefinedFunctionError` if the function does not exist.

  Each event is printed to the group leader of the calling process. Returns
  the number of traced functions.

  A trace stops, and prints the reason, when the limit is reached or when its
  owner exits. A trace started at the shell prompt belongs to the shell, so
  errors in the shell do not stop it. A trace started in any other process
  belongs to that process.

  ## Options

  `opts` is a keyword list, or an integer as a shorthand for `limit:`.

    * `:limit` - the number of events after which the trace stops, a
      positive integer. A call and its return value or exception are two
      events. Defaults to `2`.
    * `:pid` - the processes to trace: a pid, a non-empty list of pids,
      `:all`, `:new` or `:existing`. Defaults to `:all`. Raises if a single
      pid is dead or on another node. A list skips such pids, prints a line
      for each, and raises if none is left.
    * `:scope` - `:global` traces only fully qualified calls, `:local` also
      traces local calls. Defaults to `:global`.

  ## Examples

  Trace calls to `&String.starts_with?/2` and print the first two events:

      iex> Tap.call(String.starts_with?(_, _), 2)
      1

  Trace calls to `&String.starts_with?/2` when the second argument is
  `"b"` and print the first event:

      iex> Tap.call(String.starts_with?(_, "b"), limit: 1)
      1

  Trace calls from the current process only:

      iex> Tap.call(String.starts_with?(_, _), pid: self())
      1
  """
  defmacro call(mfa, opts) do
    {{:., _, [module, function]}, _, args} = mfa

    args =
      Enum.map(args, fn
        {:_, _, nil} -> :_
        arg -> arg
      end)

    quote do
      Tap.__trace__(
        {unquote(module), unquote(function), unquote(args)},
        unquote(opts)
      )
    end
  end

  @doc false
  def __trace__(template, limit) when is_integer(limit),
    do: __trace__(template, limit: limit)

  def __trace__(template, opts) do
    :tap_trace.start(
      template,
      opts
      |> Map.new()
      |> Map.merge(%{formatter: &format/1, inspect: &inspect/1})
    )
  end

  defp format({:stop, {:limit, limit}, _time}),
    do: "Trace stopped: limit of #{limit} events reached"

  defp format({:stop, {:exit, :shell, pid}, _time}),
    do: "Trace stopped: shell #{inspect(pid)} exited"

  defp format({:stop, {:exit, :process, pid}, _time}),
    do: "Trace stopped: #{inspect(pid)} exited"

  defp format({:skip, {:not_alive, pid}, _time}),
    do: "Trace skipped: #{inspect(pid)} is not alive"

  defp format({:skip, {:remote, pid}, _time}),
    do: "Trace skipped: #{inspect(pid)} is not on this node"

  defp format({:trace_ts, pid, :call, {m, f, args}, _time}),
    do: format(pid, Exception.format_mfa(m, f, args))

  defp format({:trace_ts, pid, :return_from, {m, f, a}, return, _time}) do
    format(pid, [
      Exception.format_mfa(m, f, a),
      " --> ",
      inspect(return, pretty: true)
    ])
  end

  defp format(
         {:trace_ts, pid, :exception_from, {m, f, a}, {class, reason}, _time}
       ) do
    format(pid, [
      Exception.format_mfa(m, f, a),
      ?\s,
      Exception.format(class, reason)
    ])
  end

  defp format(pid, message), do: [inspect(pid), ?\s, message]
end
