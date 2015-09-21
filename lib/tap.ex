defmodule Tap do

  @default [formatter: &__MODULE__.format/1]

  def calls(m, max) when is_atom(m), do: calls([{m, :_, :_}], max)
  def calls({m, f, a}, max),         do: calls([{m, f, a}], max)
  def calls([_|_] = tspecs, max),    do: calls(tspecs, max, [])

  def calls({m, f, a}, max, opts), do: calls([{m, f, a}], max, opts)
  def calls([_|_] = tspecs, max, opts) do
    :recon_trace.calls(tspecs, max, Keyword.merge(@default, opts))
  end

  def format(event) do
    {type, info, meta} = extract(event)
    case {type, info} do
      ## {:trace, pid, :receive, msg}
      {:receive, [msg]} ->
        format(meta, "< #{inspect msg}")
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
        format(meta, [Exception.format_mfa(m, f, a), " --> ", inspect(return)])
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
    "#{hour}:#{min}:#{Float.to_string(sec, decimals: 6)} #{inspect pid} #{message}\n"
  end

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
