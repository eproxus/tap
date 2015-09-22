defmodule Tap do

  @default [formatter: &__MODULE__.format/1]

  @doc ~S"""
  Traces calls, return values and exceptions from the function call template
  given as an argument.

  ## Examples

  Trace calls to `&String.starts_with?/2` and print the first two events:

      iex> Tap.call(String.starts_with?(_, _), 2)
      1

  Trace calls to `&String.starts_with?/2` when the second argument is
  `"b"` and print the first event:

      iex> Tap.call(String.starts_with?(_, "b"), 1)
      1
  """
  defmacro call(mfa, n) do
    {{:., _, [module, function]}, _, args} = mfa
    args = Enum.map(args, fn {:_, _, nil} -> :_; arg -> arg end)
    quote do
      Tap.calls(
        [{
          unquote(module),
          unquote(function),
          [{unquote(args), [], [{:exception_trace}]}]
        }],
        unquote(n)
      )
    end
  end

  @doc ~S"""
  Traces on the function patterns given as an argument.

  ## Examples

  Trace calls (but not return values) to `&String.strip` with any number of
  arguments and print the first ten events:

      iex> Tap.calls([{String, :strip, :_}], max: 10)
      2

  Trace calls and return values from `&String.strip/2` and print the first ten
  events:

      iex> Tap.calls([{String, :strip, {2, :return}}], max: 10)
      2

  """
  def calls(tspecs, opts) when is_integer(opts), do: calls(tspecs, max: opts)
  def calls(tspecs, opts) do
    max = Keyword.get(opts, :max, 1)
    opts = Keyword.merge(@default, Keyword.drop(opts, [:max]))
    :recon_trace.calls(expand(tspecs), max, opts)
  end

  def format(event) do
    {type, info, meta} = extract(event)
    case {type, info} do
      ## {:trace, pid, :receive, msg}
      {:receive, [msg]} ->
        format(meta, "< #{inspect(msg, pretty: true)}")
      ## {trace, Pid, send, Msg, To}
      # {send, [Msg, To]} ->
      #     {" > ~p: ~p", [To, Msg]};
      ## {trace, Pid, send_to_non_existing_process, Msg, To}
      # {send_to_non_existing_process, [Msg, To]} ->
      #     {" > (non_existent) ~p: ~p", [To, Msg]};
      ## {trace, Pid, call, {M, F, Args}}
      {:call, [{m, f, a}]} ->
        format(meta, Exception.format_mfa(m, f, a))
      ## {trace, Pid, return_to, {M, F, Arity}}
      # {return_to, [{M,F,Arity}]} ->
      #     {"~p:~p/~p", [M,F,Arity]};
      ## {trace, Pid, return_from, {M, F, Arity}, ReturnValue}
      {:return_from, [{m, f, a}, return]} ->
        format(meta, [Exception.format_mfa(m, f, a), " --> ", inspect(return, pretty: true)])
      ## {trace, Pid, exception_from, {M, F, Arity}, {Class, Value}}
      {:exception_from, [{m, f, a}, {class, reason}]} ->
        format(meta, [Exception.format_mfa(m, f, a), ?\s, Exception.format(class, reason)])
          # {"~p:~p/~p ~p ~p", [M,F,Arity, Class, Val]};
      ## {trace, Pid, spawn, Spawned, {M, F, Args}}
      # {spawn, [Spawned, {M,F,Args}]}  ->
      #     {"spawned ~p as ~p:~p~s", [Spawned, M, F, format_args(Args)]};
      ## {trace, Pid, exit, Reason}
      # {exit, [Reason]} ->
      #     {"EXIT ~p", [Reason]};
      ## {trace, Pid, link, Pid2}
      # {link, [Linked]} ->
      #     {"link(~p)", [Linked]};
      ## {trace, Pid, unlink, Pid2}
      # {unlink, [Linked]} ->
      #     {"unlink(~p)", [Linked]};
      ## {trace, Pid, getting_linked, Pid2}
      # {getting_linked, [Linker]} ->
      #     {"getting linked by ~p", [Linker]};
      ## {trace, Pid, getting_unlinked, Pid2}
      # {getting_unlinked, [Unlinker]} ->
      #     {"getting unlinked by ~p", [Unlinker]};
      ## {trace, Pid, register, RegName}
      # {register, [Name]} ->
      #     {"registered as ~p", [Name]};
      ## {trace, Pid, unregister, RegName}
      # {unregister, [Name]} ->
      #     {"no longer registered as ~p", [Name]};
      ## {trace, Pid, in, {M, F, Arity} | 0}
      # {in, [{M,F,Arity}]} ->
      #     {"scheduled in for ~p:~p/~p", [M,F,Arity]};
      # {in, [0]} ->
      #     {"scheduled in", []};
      ## {trace, Pid, out, {M, F, Arity} | 0}
      # {out, [{M,F,Arity}]} ->
      #     {"scheduled out from ~p:~p/~p", [M, F, Arity]};
      # {out, [0]} ->
      #     {"scheduled out", []};
      ## {trace, Pid, gc_start, Info}
      # {gc_start, [Info]} ->
      #     HeapSize = proplists:get_value(heap_size, Info),
      #     {"gc beginning -- heap ~p bytes", [HeapSize]};
      ## {trace, Pid, gc_end, Info}
      # {gc_end, [Info]} ->
      #     [Info] = TraceInfo,
      #     HeapSize = proplists:get_value(heap_size, Info),
      #     OldHeapSize = proplists:get_value(old_heap_size, Info),
      #     {"gc finished -- heap ~p bytes (recovered ~p bytes)",
      #      [HeapSize, OldHeapSize-HeapSize]};
      # _ ->
      #     {"unknown trace type ~p -- ~p", [Type, TraceInfo]}
      _ ->
        :recon_trace.format(event)
    end
  end

  def format({{hour, min, sec}, pid}, message) do
    "#{hour}:#{min}:#{Float.to_string(sec, decimals: 6)} #{inspect pid} #{message}\n\n"
  end

  defp expand(specs), do: for(s <- specs, do: spec(s))

  defp spec({m, f, p}), do: {m, f, pattern(p)}
  defp spec(s), do: s

  defp pattern({arity, :return}) do
    [{for(_ <- 1..arity, do: :_), [], [{:exception_trace}]}]
  end
  defp pattern({arity, :r}), do: pattern({arity, :return})
  defp pattern(:return), do: [{:_, [], [{:exception_trace}]}]
  defp pattern(:r), do: pattern(:return)
  defp pattern(p), do: p

  defp extract(event) do
    case Tuple.to_list(event) do
      [:trace_ts, pid, type | rest] ->
        {meta, [stamp]} = Enum.split(rest, length(rest) - 1)
        {type, meta, {time(stamp), pid}}
      [:trace, pid, type | meta] ->
        {type, meta, {time(:os.timestamp), pid}}
    end
  end

  defp time({_, _, micro} = stamp) do
    {_, {h, m, s}} = :calendar.now_to_local_time(stamp)
    {h, m, s + micro / 1000000}
  end

end
