-module(tap_trace).
-moduledoc false.

-define(FLAGS, [call, monotonic_timestamp]).
-define(DEFAULTS, #{
    limit => 2, pid => all, scope => global, inspect => fun inspect/1
}).

% API
-export([start/2, format_error/2]).

% Types
-export_type([template/0, opts/0, event/0, formatter/0, inspector/0]).

-type template() :: {module(), atom(), [term()]}.
-type processes() :: pid() | [pid()] | all | new | existing.
-type opts() :: #{
    limit => pos_integer(),
    pid => processes(),
    scope => global | local,
    inspect => inspector(),
    formatter := formatter()
}.
-type time() :: integer().
% erlang:trace_match_spec/0 is not exported.
-type match_spec() :: [{[term()], [term()], [term()]}].
-type owner() :: {shell | process, pid()}.
-type stop_reason() :: {limit, pos_integer()} | {exit, shell | process, pid()}.
-type event() ::
    {trace_ts, pid(), call, {module(), atom(), [term()]}, time()}
    | {trace_ts, pid(), return_from, mfa(), term(), time()}
    | {trace_ts, pid(), exception_from, mfa(), {atom(), term()}, time()}
    | {skip, unreachable(), time()}
    | {stop, stop_reason(), time()}.
-type unreachable() :: {not_alive | remote, pid()}.
-type formatter() :: fun((event()) -> unicode:chardata()).
-type inspector() :: fun((term()) -> unicode:chardata()).
-type cause() ::
    not_a_map
    | {unknown, [term()]}
    | limit
    | pid
    | scope
    | inspect
    | unreachable()
    | no_process.
-type config() :: #{
    mfa := mfa(),
    match_spec := match_spec(),
    limit := pos_integer(),
    pids := processes(),
    scope := global | local,
    formatter := formatter(),
    io := pid(),
    caller := pid(),
    owner := owner()
}.
-type state() :: #{
    limit := pos_integer(),
    formatter := formatter(),
    io := pid(),
    owner := owner(),
    session := trace:session(),
    count := non_neg_integer()
}.

%--- API -----------------------------------------------------------------------

% Starts a trace session for one function template. Options other than the
% formatter default to ?DEFAULTS. Trace events and {stop, Reason, Time} are
% passed to the formatter, and its output is printed to the group leader of the
% caller. All times are monotonic times in native units. Error messages print
% terms with the inspect fun, so that they match the syntax of the caller.
-spec start(template(), opts()) -> pos_integer().
start(Template, Opts) ->
    case trace(Template, Opts) of
        {error, Cause} ->
            Info = #{module => ?MODULE, cause => {Cause, inspector(Opts)}},
            erlang:error(badarg, [Template, Opts], [{error_info, Info}]);
        Matches ->
            Matches
    end.

% Explains errors raised by start/2, see erl_error:format_exception/3.
-spec format_error(term(), erlang:stacktrace()) ->
    #{pos_integer() => unicode:chardata()}.
format_error(badarg, [{?MODULE, start, _, Info} | _]) ->
    {Cause, Inspect} = cause(proplists:get_value(error_info, Info)),
    #{2 => message(Cause, Inspect)}.

%--- Internal ------------------------------------------------------------------

% Errors are returned, so that start/2 raises them with its own arguments.
-spec trace(template(), opts()) -> pos_integer() | {error, cause()}.
trace(Template, Opts) ->
    case check(Opts) of
        ok -> start_tracer(Template, maps:merge(?DEFAULTS, Opts));
        Error -> Error
    end.

-spec check(term()) -> ok | {error, cause()}.
check(Opts) when not is_map(Opts) -> {error, not_a_map};
check(Opts) ->
    case maps:keys(maps:without(maps:keys(?DEFAULTS) ++ [formatter], Opts)) of
        [] -> check_values(maps:merge(?DEFAULTS, Opts));
        Extra -> {error, {unknown, Extra}}
    end.

-spec check_values(map()) -> ok | {error, cause()}.
check_values(#{limit := L}) when not is_integer(L); L < 1 -> {error, limit};
check_values(#{scope := S}) when S =/= global, S =/= local -> {error, scope};
check_values(#{inspect := I}) when not is_function(I, 1) -> {error, inspect};
check_values(#{pid := Pids}) ->
    case is_processes(Pids) of
        true -> ok;
        false -> {error, pid}
    end.

-spec is_processes(term()) -> boolean().
is_processes(P) when is_pid(P); P =:= all; P =:= new; P =:= existing -> true;
is_processes([_ | _] = Pids) -> lists:all(fun is_pid/1, Pids);
is_processes(_) -> false.

% An invalid inspect option falls back to the default, so that its own error
% can be printed.
-spec inspector(opts()) -> inspector().
inspector(#{inspect := Inspect}) when is_function(Inspect, 1) -> Inspect;
inspector(_Opts) -> fun inspect/1.

-spec inspect(term()) -> unicode:chardata().
inspect(Term) -> io_lib:format("~tp", [Term]).

% The error info holds what start/2 stored in it.
-spec cause(dynamic()) -> {cause(), inspector()}.
cause(#{cause := {Cause, Inspect}}) -> {Cause, Inspect}.

-spec message(cause(), inspector()) -> unicode:chardata().
message(not_a_map, _I) ->
    ~"options must be a map";
message({unknown, Keys}, I) ->
    [~"unknown options ", I(Keys)];
message(limit, _I) ->
    ~"limit must be a positive integer";
message(pid, I) ->
    [
        ~"pid must be a pid, a non-empty list of pids, or one of ",
        I(all),
        ~", ",
        I(new),
        ~" or ",
        I(existing)
    ];
message(scope, I) ->
    [~"scope must be ", I(global), ~" or ", I(local)];
message(inspect, _I) ->
    ~"inspect must be a fun of arity 1";
message({not_alive, Pid}, I) ->
    [~"process ", I(Pid), ~" is not alive"];
message({remote, Pid}, I) ->
    [~"process ", I(Pid), ~" is not on this node"];
message(no_process, _I) ->
    ~"no process in the list can be traced".

-spec start_tracer(template(), opts()) -> pos_integer() | {error, cause()}.
start_tracer({M, F, Args}, #{
    limit := Limit, pid := Pids, scope := Scope, formatter := Formatter
}) ->
    Config = #{
        mfa => {M, F, length(Args)},
        match_spec => [{Args, [], [{exception_trace}]}],
        limit => Limit,
        pids => Pids,
        scope => Scope,
        formatter => Formatter,
        io => group_leader(),
        caller => self(),
        owner => owner()
    },
    {Tracer, Ref} = spawn_monitor(fun() -> init(Config) end),
    Reply =
        receive
            {Tracer, R} ->
                demonitor(Ref, [flush]),
                R;
            {'DOWN', Ref, process, Tracer, Reason} ->
                exit(Reason)
        end,
    case Reply of
        0 -> raise_undef({M, F, length(Args)});
        Matches -> Matches
    end.

% Tie the owner to the shell server if it is started from the shell (so it
% survives shell crashes) or to the caller process.
-spec owner() -> owner().
owner() ->
    Self = self(),
    maybe
        % Is there a shell on this node?
        {ok, Shell} ?=
            try shell:whereis() of
                Pid when is_pid(Pid), node(Pid) =:= node() -> {ok, Pid};
                _ -> none
            catch
                % Handle peer nodes (erlang/otp#11819)
                _:_ -> none
            end,
        % Is the shell still alive?
        [{links, Links}, {monitors, Monitors}] ?=
            erlang:process_info(Shell, [links, monitors]),
        % Is the caller the shell's evaluator (linked in erl, monitored in IEx)?
        true ?=
            lists:member(Self, Links) orelse
            lists:member({process, Self}, Monitors),
        {shell, Shell}
    else
        _ -> {process, Self}
    end.

-spec init(config()) -> ok.
init(#{
    mfa := {M, _, _} = MFA,
    match_spec := MatchSpec,
    limit := Limit,
    pids := Pids,
    scope := Scope,
    formatter := Formatter,
    io := IO,
    caller := Caller,
    owner := {_, Owner} = OwnerSpec
}) ->
    monitor(process, Owner),
    Session = trace:session_create(tap, self(), []),
    _ = code:ensure_loaded(M),
    case trace:function(Session, MFA, MatchSpec, [Scope]) of
        0 ->
            fail(Session, Caller, 0);
        Matches ->
            State = #{
                limit => Limit,
                formatter => Formatter,
                io => IO,
                owner => OwnerSpec,
                session => Session,
                count => 0
            },
            case trace_processes(State, Pids) of
                ok ->
                    trace:process(Session, self(), false, ?FLAGS),
                    Caller ! {self(), Matches},
                    loop(State);
                Error ->
                    fail(Session, Caller, Error)
            end
    end.

-spec fail(trace:session(), pid(), 0 | {error, cause()}) -> ok.
fail(Session, Caller, Reply) ->
    trace:session_destroy(Session),
    Caller ! {self(), Reply},
    ok.

-spec trace_processes(state(), processes()) -> ok | {error, cause()}.
trace_processes(State, Pid) when is_pid(Pid) -> trace_process(State, Pid);
trace_processes(#{session := Session}, Pids) when is_atom(Pids) ->
    trace:process(Session, Pids, true, ?FLAGS),
    ok;
trace_processes(State, Pids) ->
    case [Pid || Pid <- Pids, traced(State, Pid)] of
        [] -> {error, no_process};
        _ -> ok
    end.

% A process can exit at any time, so trace:process/4 is the only reliable check.
-spec trace_process(state(), pid()) -> ok | {error, unreachable()}.
trace_process(_State, Pid) when node(Pid) =/= node() -> {error, {remote, Pid}};
trace_process(#{session := Session}, Pid) ->
    try trace:process(Session, Pid, true, ?FLAGS) of
        _ -> ok
    catch
        error:badarg -> {error, {not_alive, Pid}}
    end.

% Prints a skip event for a process that cannot be traced.
-spec traced(state(), pid()) -> boolean().
traced(State, Pid) ->
    case trace_process(State, Pid) of
        ok ->
            true;
        {error, Unreachable} ->
            print(State, {skip, Unreachable, erlang:monotonic_time()}),
            false
    end.

-spec loop(state()) -> ok.
loop(#{limit := Limit, count := Count} = State) when Count >= Limit ->
    stop(State, {limit, Limit});
loop(#{count := Count, owner := {Kind, Owner}} = State) ->
    receive
        {'DOWN', _, process, Owner, _} ->
            stop(State, {exit, Kind, Owner});
        Event when element(1, Event) =:= trace_ts ->
            print(State, Event),
            loop(State#{count := Count + 1})
    end.

-spec stop(state(), stop_reason()) -> ok.
stop(#{session := Session} = State, Reason) ->
    trace:session_destroy(Session),
    print(State, {stop, Reason, erlang:monotonic_time()}).

% Prints the event's timestamp before the formatter output. A formatter crash
% stops the trace, as the formatter might fail on every event.
-spec print(state(), event()) -> ok.
print(#{io := IO, formatter := Formatter} = State, Event) ->
    try Formatter(Event) of
        Message -> io:put_chars(IO, [timestamp(time(Event)), $\s, Message, $\n])
    catch
        Class:Reason:Stack -> crash(State, Class, Reason, Stack)
    end.

-spec time(event()) -> time().
time({trace_ts, _Pid, call, _MFA, Time}) -> Time;
time({trace_ts, _Pid, _Tag, _MFA, _Result, Time}) -> Time;
time({skip, _Unreachable, Time}) -> Time;
time({stop, _Reason, Time}) -> Time.

-spec timestamp(time()) -> unicode:chardata().
timestamp(Time) ->
    Offset = Time + erlang:time_offset(),
    Micro = erlang:convert_time_unit(Offset, native, microsecond),
    {_, {H, M, S}} = calendar:system_time_to_local_time(Micro, microsecond),
    io_lib:format("~2..0B:~2..0B:~2..0B.~6..0B", [H, M, S, Micro rem 1000000]).

% The exception is printed in Erlang syntax, as the formatter cannot be trusted
% to print it. erlang:raise/3 only returns (badarg) for an invalid stacktrace.
-spec crash(state(), error | exit | throw, term(), erlang:stacktrace()) ->
    no_return().
crash(#{io := IO, session := Session}, Class, Reason, Stack) ->
    trace:session_destroy(Session),
    io:put_chars(IO, [
        timestamp(erlang:monotonic_time()),
        ~" Trace stopped: formatter crashed\n",
        erl_error:format_exception(Class, Reason, Stack),
        $\n
    ]),
    error(erlang:raise(Class, Reason, Stack)).

% The function becomes the top stack frame, so the Erlang shell prints
% "undefined function m:f/a" and Elixir raises UndefinedFunctionError.
% erlang:raise/3 only returns (badarg) for an invalid class or stacktrace.
-spec raise_undef(mfa()) -> no_return().
raise_undef({M, F, A}) -> error(erlang:raise(error, undef, [{M, F, A, []}])).
