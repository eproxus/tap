# Tap

[![Hex.pm](https://img.shields.io/hexpm/v/tap.svg?style=flat-square)](https://hex.pm/packages/tap)
[![License](https://img.shields.io/hexpm/l/tap.svg?style=flat-square)](https://github.com/eproxus/tap/blob/main/LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/eproxus/tap/ci.yml?branch=main&style=flat-square)](https://github.com/eproxus/tap/actions/workflows/ci.yml)

> *Because Erlang's tracing is awesome and doing compile time debugging sucks!*

## Description

Tap enables tracing of Elixir and Erlang functions in a intuitive and safe way.

```elixir
iex(1)> require Tap
Tap
iex(2)> Tap.call(String.trim(_, _), limit: 4)
1
iex(3)> String.trim("test", "t")
"es"
14:23:22.863903 #PID<0.208.0> String.trim("test", "t")
14:23:22.889608 #PID<0.208.0> String.trim/2 --> "es"
iex(4)> String.trim("test", ?t)
14:23:25.876960 #PID<0.208.0> String.trim("test", 116)
14:23:25.877830 #PID<0.208.0> String.trim/2 ** (FunctionClauseError) no function clause matches
14:23:25.877912 Trace stopped: limit of 4 events reached
** (FunctionClauseError) no function clause matching in String.trim/2

    The following arguments were given to String.trim/2:

        # 1
        "test"

        # 2
        116

    Attempted function clauses (showing 1 out of 1):

        def trim(string, to_trim) when is_binary(string) and is_binary(to_trim)

    (elixir 1.20.4) lib/string.ex:1431: String.trim/2
    iex:4: (file)
iex(4)>
```

Each trace runs in its own OTP trace session, so concurrent traces do not
affect each other. A trace started at the shell prompt survives errors in the
shell and stops at its event limit or when the shell exits.

## Releasing

Run `mise run release` on a clean working copy of `origin/main`. The task first
shows the changelog section of the next release. After confirmation, it sets
the version in `src/tap.app.src`, regenerates `CHANGELOG.md`, commits the release, and
pushes it to `main`. The version is computed from the commits since the last
release. To override it, pass an explicit version (e.g. `mise run release
1.0.0`). To only show the changelog section, run `mise run release:preview`.

CI publishes the package to Hex, tags the release, and creates a GitHub
release once lint and tests pass. CI publishes only when the release commit is
the head of `main`. If the release fails, push a fix and run the task again.
