defmodule TapTest.Target do
  @moduledoc false

  def add(a, b), do: a + b

  def add(a, b, c), do: a + b + c

  def double(a), do: add(a, a)

  def fail(message), do: raise(ArgumentError, message)

  def identity(value), do: value
end

defmodule TapTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  require Tap

  alias TapTest.Target

  @stopped "Trace stopped: limit of 2 events reached"

  doctest Tap

  # Doctests start traces without calling the traced functions, so each
  # trace stops when the doctest process exits. The stop line goes to the
  # group leader, which is redirected to a device that discards it instead
  # of the terminal.
  setup_all do
    %{null_device: spawn(&discard_io/0)}
  end

  setup context do
    if context[:doctest], do: Process.group_leader(self(), context.null_device)
    :ok
  end

  describe "call/2" do
    test "prints the call and its return value" do
      assert trace(fn ->
               Tap.call(Target.add(_, _), 2)
               Target.add(1, 2)
             end) == [
               "TapTest.Target.add(1, 2)",
               "TapTest.Target.add/2 --> 3",
               @stopped
             ]
    end

    test "prints the call and its exception" do
      assert trace(fn ->
               Tap.call(Target.fail(_), 2)
               assert_raise ArgumentError, fn -> Target.fail("boom") end
             end) == [
               ~s|TapTest.Target.fail("boom")|,
               "TapTest.Target.fail/1 ** (ArgumentError) boom",
               @stopped
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
               @stopped
             ]
    end

    test "prints arguments and return values containing a tilde" do
      assert trace(fn ->
               Tap.call(Target.identity(_), 2)
               Target.identity("~p")
             end) == [
               ~s|TapTest.Target.identity("~p")|,
               ~s|TapTest.Target.identity/1 --> "~p"|,
               @stopped
             ]
    end
  end

  describe "options" do
    test "raises for an unknown option" do
      assert_raise ArgumentError,
                   """
                   errors were found at the given arguments:

                     * 2nd argument: unknown options [:max]
                   """,
                   fn -> Tap.call(Target.add(_, _), max: 2) end
    end
  end

  describe "templates" do
    test "prints only calls with the template's arity" do
      assert trace(fn ->
               Tap.call(Target.add(_, _), 2)
               Target.add(1, 2, 3)
               Target.add(1, 2)
             end) == [
               "TapTest.Target.add(1, 2)",
               "TapTest.Target.add/2 --> 3",
               @stopped
             ]
    end

    test "raises for an undefined function" do
      assert_raise UndefinedFunctionError,
                   "function TapTest.Target.missing/1 is undefined or private",
                   fn -> Tap.call(Target.missing(_), 2) end
    end

    test "raises for an undefined arity" do
      assert_raise UndefinedFunctionError,
                   "function TapTest.Target.add/4 is undefined or private",
                   fn -> Tap.call(Target.add(_, _, _, _), 2) end
    end

    test "raises for an undefined module" do
      assert_raise UndefinedFunctionError,
                   "function TapTest.Missing.f/0 is undefined (module TapTest.Missing is not available)",
                   fn -> Tap.call(TapTest.Missing.f(), 2) end
    end
  end

  describe "sessions" do
    test "concurrent traces print only their own events" do
      added =
        trace(fn ->
          Tap.call(Target.add(_, _), 2)

          identified =
            trace(fn ->
              Tap.call(Target.identity(_), 2)
              Target.identity(1)
            end)

          assert identified == [
                   "TapTest.Target.identity(1)",
                   "TapTest.Target.identity/1 --> 1",
                   @stopped
                 ]

          Target.add(1, 2)
        end)

      assert added == [
               "TapTest.Target.add(1, 2)",
               "TapTest.Target.add/2 --> 3",
               @stopped
             ]
    end
  end

  describe "scope" do
    test "traces local calls with the scope :local" do
      assert trace(fn ->
               Tap.call(Target.add(_, _), scope: :local)
               Target.double(1)
             end) == [
               "TapTest.Target.add(1, 1)",
               "TapTest.Target.add/2 --> 2",
               @stopped
             ]
    end

    test "raises for an unknown scope" do
      assert_raise ArgumentError,
                   """
                   errors were found at the given arguments:

                     * 2nd argument: scope must be :global or :local
                   """,
                   fn -> Tap.call(Target.add(_, _), scope: :x) end
    end
  end

  describe "processes" do
    test "traces only the given process" do
      assert trace(fn ->
               Tap.call(Target.add(_, _), pid: self())
               Task.await(Task.async(fn -> Target.add(1, 1) end))
               Target.add(1, 2)
             end) == [
               "TapTest.Target.add(1, 2)",
               "TapTest.Target.add/2 --> 3",
               @stopped
             ]
    end

    test "traces only the given processes" do
      assert trace(fn ->
               task =
                 Task.async(fn -> receive(do: (:go -> Target.add(1, 1))) end)

               Tap.call(Target.add(_, _), pid: [task.pid], limit: 2)
               Target.add(1, 2)
               send(task.pid, :go)
               Task.await(task)
             end) == [
               "TapTest.Target.add(1, 1)",
               "TapTest.Target.add/2 --> 2",
               @stopped
             ]
    end

    for pid <- [:x, [], [:x]] do
      test "raises for the pid #{inspect(pid)}" do
        assert_raise ArgumentError,
                     """
                     errors were found at the given arguments:

                       * 2nd argument: pid must be a pid, a non-empty list of pids, or one of :all, :new or :existing
                     """,
                     fn -> Tap.call(Target.add(_, _), pid: unquote(pid)) end
      end
    end

    test "raises for a dead process" do
      dead = dead_pid()

      assert_raise ArgumentError,
                   """
                   errors were found at the given arguments:

                     * 2nd argument: process #{inspect(dead)} is not alive
                   """,
                   fn -> Tap.call(Target.add(_, _), pid: dead) end
    end

    test "raises for a process on another node" do
      remote = remote_pid()

      assert_raise ArgumentError,
                   """
                   errors were found at the given arguments:

                     * 2nd argument: process #{inspect(remote)} is not on this node
                   """,
                   fn -> Tap.call(Target.add(_, _), pid: remote) end
    end

    test "skips dead processes and processes on other nodes in a list" do
      dead = dead_pid()
      remote = remote_pid()

      assert trace(fn ->
               Tap.call(Target.add(_, _), pid: [dead, self(), remote])
               Target.add(1, 2)
             end) == [
               "Trace skipped: #{inspect(dead)} is not alive",
               "Trace skipped: #{inspect(remote)} is not on this node",
               "TapTest.Target.add(1, 2)",
               "TapTest.Target.add/2 --> 3",
               @stopped
             ]
    end

    test "raises if no process in a list can be traced" do
      dead = dead_pid()

      output =
        capture_io(fn ->
          assert_raise ArgumentError,
                       """
                       errors were found at the given arguments:

                         * 2nd argument: no process in the list can be traced
                       """,
                       fn -> Tap.call(Target.add(_, _), pid: [dead]) end
        end)

      assert output =~
               ~r/^[\d:.]+ Trace skipped: #{inspect(dead)} is not alive\n$/
    end

    test "traces only new processes" do
      assert trace(fn ->
               Tap.call(Target.add(_, _), pid: :new)
               Target.add(1, 2)
               Task.await(Task.async(fn -> Target.add(1, 1) end))
             end) == [
               "TapTest.Target.add(1, 1)",
               "TapTest.Target.add/2 --> 2",
               @stopped
             ]
    end
  end

  describe "owner" do
    test "stops the trace when the process that started it exits" do
      output =
        trace(fn ->
          {pid, ref} = spawn_monitor(fn -> Tap.call(Target.add(_, _), 10) end)
          assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
          send(self(), {:owner, pid})
        end)

      assert_received {:owner, pid}
      assert output == ["Trace stopped: #{inspect(pid)} exited"]
    end

    # The shell calls common functions itself, so these trace Integer.gcd/2.
    @tag :tmp_dir
    test "keeps a trace started in IEx when the evaluator crashes", context do
      output =
        iex(context.tmp_dir, """
        require Tap
        Tap.call(Integer.gcd(_, _), 2)
        Process.exit(self(), :kill)
        Integer.gcd(4, 6)
        Process.sleep(300)
        """)

      assert output =~ ~r/#PID<[\d.]+> Integer.gcd\(4, 6\)\n/
      assert output =~ ~r/#PID<[\d.]+> Integer.gcd\/2 --> 2\n/
      assert output =~ " #{@stopped}\n"
    end

    @tag :tmp_dir
    test "stops a trace started by a process spawned in IEx when it exits",
         context do
      output =
        iex(context.tmp_dir, """
        require Tap
        pid = spawn(fn -> Tap.call(Integer.gcd(_, _), 2); Process.sleep(:infinity) end)
        IO.puts("owner: " <> inspect(pid))
        Process.sleep(100)
        Process.exit(pid, :kill)
        Process.sleep(300)
        """)

      [_, owner] = Regex.run(~r/owner: (#PID<[\d.]+>)\n/, output)
      assert output =~ " Trace stopped: #{owner} exited\n"
    end

    # Peer nodes have no user_drv, so they cannot start a shell.
    test "traces on a node without a shell" do
      peer = peer()

      assert trace(fn ->
               Process.group_leader(peer, Process.group_leader())

               :peer.call(peer, Code, :eval_string, [
                 "require Tap; Tap.call(Integer.gcd(_, _), 2); Integer.gcd(4, 6)"
               ])
             end) == ["Integer.gcd(4, 6)", "Integer.gcd/2 --> 2", @stopped]
    end
  end

  describe "limit" do
    for opts <- [3, [limit: 3]] do
      test "stops after three events for the options #{inspect(opts)}" do
        assert trace(fn ->
                 Tap.call(Target.add(_, _), unquote(opts))
                 Target.add(1, 1)
                 Target.add(1, 2)
               end) == [
                 "TapTest.Target.add(1, 1)",
                 "TapTest.Target.add/2 --> 2",
                 "TapTest.Target.add(1, 2)",
                 "Trace stopped: limit of 3 events reached"
               ]
      end
    end

    for limit <- [0, :x] do
      test "raises for the limit #{inspect(limit)}" do
        assert_raise ArgumentError,
                     """
                     errors were found at the given arguments:

                       * 2nd argument: limit must be a positive integer
                     """,
                     fn -> Tap.call(Target.add(_, _), limit: unquote(limit)) end
      end
    end

    test "stops after two events by default" do
      assert trace(fn ->
               Tap.call(Target.add(_, _), [])
               Target.add(1, 1)
               Target.add(1, 2)
             end) == [
               "TapTest.Target.add(1, 1)",
               "TapTest.Target.add/2 --> 2",
               @stopped
             ]
    end
  end

  describe "trace output" do
    test "ends each line with a single newline" do
      output =
        capture(fn ->
          Tap.call(Target.add(_, _), 2)
          Target.add(1, 1)
        end)

      assert [_, _, stop] = String.split(output, ~r/(?<=\n)/, trim: true)
      assert stop =~ ~r/ #{@stopped}\n$/
    end

    test "prefixes each event with a zero-padded timestamp and the pid" do
      output =
        capture(fn ->
          Tap.call(Target.add(_, _), 2)
          Target.add(1, 2)
        end)

      [call, return, _stop] = String.split(output, "\n", trim: true)
      prefix = ~S"^\d{2}:\d{2}:\d{2}\.\d{6} #PID<[\d.]+> "
      assert call =~ ~r/#{prefix}TapTest.Target.add\(1, 2\)$/
      assert return =~ ~r/#{prefix}TapTest.Target.add\/2 --> 3$/
    end

    test "prefixes the stop message with a zero-padded timestamp" do
      output =
        capture(fn ->
          Tap.call(Target.add(_, _), 1)
          Target.add(1, 2)
        end)

      [_call, stop] = String.split(output, "\n", trim: true)

      assert stop =~
               ~r/^\d{2}:\d{2}:\d{2}\.\d{6} Trace stopped: limit of 1 events reached$/
    end
  end

  # An IO device that discards all output.
  defp discard_io do
    receive do
      {:io_request, from, reply_as, _request} ->
        send(from, {:io_reply, reply_as, :ok})
        discard_io()
    end
  end

  defp dead_pid do
    {pid, ref} = spawn_monitor(fn -> :ok end)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}
    pid
  end

  # The pid of a process on a peer node that has stopped since.
  defp remote_pid do
    {:ok, peer, _node} =
      :peer.start(%{name: :peer.random_name(), connection: :standard_io})

    pid = :peer.call(peer, :erlang, :spawn, [:timer, :sleep, [:infinity]])
    :peer.stop(peer)
    pid
  end

  # Pipes input into IEx with the test build of tap and returns its output.
  # IEx does not echo piped input, and exits at its end.
  defp iex(dir, input) do
    file = Path.join(dir, "input.exs")
    File.write!(file, input)
    ebin = Path.dirname(:code.which(Tap))
    args = ["-c", ~s(iex -pa "$1" < "$2"), "sh", ebin, file]
    {output, 0} = System.cmd("sh", args, stderr_to_stdout: true)
    output
  end

  # A peer node with the code paths of the test node and Elixir started. The
  # returned process prints the peer's output to its group leader.
  defp peer do
    args = Enum.flat_map(:code.get_path(), &[~c"-pa", &1])

    {:ok, peer, _node} =
      :peer.start(%{
        name: :peer.random_name(),
        connection: :standard_io,
        args: args
      })

    on_exit(fn -> :peer.stop(peer) end)

    {:ok, _apps} =
      :peer.call(peer, :application, :ensure_all_started, [:elixir])

    peer
  end

  # Runs fun and returns its trace output as lines without timestamp and pid.
  # Stop lines have a timestamp but no pid.
  defp trace(fun) do
    fun
    |> capture()
    |> String.split("\n", trim: true)
    |> Enum.map(&String.replace(&1, ~r/^[\d:.]+ (#PID<[\d.]+> )?/, ""))
  end

  # Runs fun with its trace output captured. A trace prints to the group
  # leader of the process that starts it, and prints a stop line last.
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
      output =~ "Trace stopped: " ->
        output

      retries == 0 ->
        flunk("Trace did not finish, output: #{inspect(output)}")

      true ->
        Process.sleep(10)
        await_output(io, retries - 1)
    end
  end
end
