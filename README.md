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
iex(2)> Tap.call(String.trim(_, _), max: 4)
2
iex(3)> String.trim("test", "t")
"es"
11:51:36.370105 #PID<0.198.0> String.trim("test", "t")

11:51:36.377859 #PID<0.198.0> String.trim/2 --> "es"

iex(4)> String.trim("test", ?t)
11:51:44.140333 #PID<0.198.0> String.trim("test", 116)

11:51:44.140559 #PID<0.198.0> String.trim/2 ** (FunctionClauseError) no function clause matches

Recon tracer rate limit tripped.
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

Tap wraps the excellent [Recon](https://github.com/ferd/recon) library, adding
native Elixir formatting and macros for creating traces in an intuitive way.

## Releasing

Run `mise run release`. The task sets the next version in `mix.exs`,
regenerates `CHANGELOG.md`, and shows the new changelog section. After
confirmation, it commits the release and pushes it to `main`. The version is
computed from the commits since the last release. To override it, pass an
explicit version (e.g. `mise run release 1.0.0`).

CI publishes the package to Hex, tags the release, and creates a GitHub
release once lint and tests pass. CI publishes only when the release commit is
the head of `main`. If the release fails, push a fix and run the task again.
