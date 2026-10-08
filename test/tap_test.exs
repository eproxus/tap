defmodule TapTest.Target do
  @moduledoc false

  def add(a, b), do: a + b

  def add(a, b, c), do: a + b + c

  def fail(message), do: raise(ArgumentError, message)
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

  # Runs fun with its trace output captured. Recon's formatter prints to the
  # group leader of the process that starts the trace, and prints the rate
  # limit line after the last event.
  defp trace(fun) do
    {:ok, io} = StringIO.open("")
    leader = Process.group_leader()
    Process.group_leader(self(), io)

    try do
      fun.()
    after
      Process.group_leader(self(), leader)
    end

    io
    |> await_output(100)
    |> String.split("\n", trim: true)
    |> Enum.map(&String.replace(&1, ~r/^\S+ #PID<[\d.]+> /, ""))
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
