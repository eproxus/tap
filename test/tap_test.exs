defmodule TapTest.Target do
  @moduledoc false

  def add(a, b), do: a + b

  def add(a, b, c), do: a + b + c

  def fail(message), do: raise(ArgumentError, message)

  def identity(value), do: value
end

defmodule TapTest do
  use ExUnit.Case, async: false

  require Tap

  alias TapTest.Target

  @tripped "Recon tracer rate limit tripped."

  doctest Tap

  setup do
    on_exit(&:recon_trace.clear/0)
  end

  describe "call/2" do
    test "prints the call and its return value" do
      assert trace(fn ->
               Tap.call(Target.add(_, _), 2)
               Target.add(1, 2)
             end) == [
               "TapTest.Target.add(1, 2)",
               "TapTest.Target.add/2 --> 3",
               @tripped
             ]
    end

    test "prints the call and its exception" do
      assert trace(fn ->
               Tap.call(Target.fail(_), 2)
               assert_raise ArgumentError, fn -> Target.fail("boom") end
             end) == [
               ~s|TapTest.Target.fail("boom")|,
               "TapTest.Target.fail/1 ** (ArgumentError) boom",
               @tripped
             ]
    end

    test "prints only calls that match the template's arguments" do
      assert trace(fn ->
               Tap.call(Target.add(_, 2), 2)
               Target.add(1, 1)
               Target.add(1, 2)
             end) == [
               "TapTest.Target.add(1, 2)",
               "TapTest.Target.add/2 --> 3",
               @tripped
             ]
    end

    test "prints arguments and return values containing a tilde" do
      assert trace(fn ->
               Tap.call(Target.identity(_), 2)
               Target.identity("~p")
             end) == [
               ~s|TapTest.Target.identity("~p")|,
               ~s|TapTest.Target.identity/1 --> "~p"|,
               @tripped
             ]
    end
  end

  describe "calls/2" do
    test "prints only calls for the pattern :_" do
      assert trace(fn ->
               Tap.calls([{Target, :add, :_}], 1)
               Target.add(1, 2)
             end) == ["TapTest.Target.add(1, 2)", @tripped]
    end

    for pattern <- [:return, :r, {2, :return}, {2, :r}] do
      test "prints return values for the pattern #{inspect(pattern)}" do
        assert trace(fn ->
                 Tap.calls([{Target, :add, unquote(pattern)}], 2)
                 Target.add(1, 2)
               end) == [
                 "TapTest.Target.add(1, 2)",
                 "TapTest.Target.add/2 --> 3",
                 @tripped
               ]
      end
    end

    test "prints only calls with the arity in the pattern {arity, :return}" do
      assert trace(fn ->
               Tap.calls([{Target, :add, {2, :return}}], 2)
               Target.add(1, 2, 3)
               Target.add(1, 2)
             end) == [
               "TapTest.Target.add(1, 2)",
               "TapTest.Target.add/2 --> 3",
               @tripped
             ]
    end

    for opts <- [2, [max: 2], []] do
      test "stops after two events for the options #{inspect(opts)}" do
        assert trace(fn ->
                 Tap.calls([{Target, :add, :_}], unquote(opts))
                 Target.add(1, 1)
                 Target.add(1, 2)
                 Target.add(1, 3)
               end) == [
                 "TapTest.Target.add(1, 1)",
                 "TapTest.Target.add(1, 2)",
                 @tripped
               ]
      end
    end
  end

  describe "trace output" do
    test "ends each event with a single newline" do
      output =
        capture(fn ->
          Tap.calls([{Target, :add, :_}], 2)
          Target.add(1, 1)
          Target.add(1, 2)
        end)

      assert [_, _, @tripped <> "\n"] =
               String.split(output, ~r/(?<=\n)/, trim: true)
    end

    test "prefixes each event with a zero-padded timestamp" do
      output =
        capture(fn ->
          Tap.call(Target.add(_, _), 1)
          Target.add(1, 2)
        end)

      [event | _] = String.split(output, "\n")

      assert event =~
               ~r/^\d{2}:\d{2}:\d{2}\.\d{6} #PID<[\d.]+> TapTest.Target.add\(1, 2\)$/
    end
  end

  describe "format/1" do
    test "zero-pads every timestamp component" do
      [utc] =
        :calendar.local_time_to_universal_time_dst({{2026, 1, 15}, {9, 5, 3}})

      seconds = :calendar.datetime_to_gregorian_seconds(utc) - 62_167_219_200
      stamp = {div(seconds, 1_000_000), rem(seconds, 1_000_000), 42}
      pid = self()

      assert Tap.format({:trace_ts, pid, :call, {Target, :add, [1, 2]}, stamp}) ==
               "09:05:03.000042 #{inspect(pid)} TapTest.Target.add(1, 2)\n"
    end
  end

  # Runs fun and returns its trace output as lines without timestamp and pid.
  defp trace(fun) do
    fun
    |> capture()
    |> String.split("\n", trim: true)
    |> Enum.map(&String.replace(&1, ~r/^\S+ #PID<[\d.]+> /, ""))
  end

  # Runs fun with its trace output captured. Recon's formatter prints to the
  # group leader of the process that starts the trace, and prints the rate
  # limit line after the last event.
  defp capture(fun) do
    {:ok, io} = StringIO.open("")
    leader = Process.group_leader()
    Process.group_leader(self(), io)

    try do
      fun.()
    after
      Process.group_leader(self(), leader)
    end

    await_output(io, 100)
  end

  defp await_output(io, retries) do
    {_input, output} = StringIO.contents(io)

    cond do
      output =~ @tripped ->
        output

      retries == 0 ->
        flunk("Trace did not finish, output: #{inspect(output)}")

      true ->
        Process.sleep(10)
        await_output(io, retries - 1)
    end
  end
end
