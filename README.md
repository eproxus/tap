# Tap

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;*Because Erlang's tracing is awesome and
doing compile time debugging sucks!*

## Description

Tap enables tracing of Elixir and Erlang functions in a intuitive and safe way.

```
iex(1)> require Tap
nil
iex(2)> Tap.call(String.strip(_, _), max: 4)
2
iex(4)> String.strip("test", ?t)
"es"
21:52:36.972255 #PID<0.88.0> String.strip("test", 116)

21:52:36.972711 #PID<0.88.0> String.strip/2 --> "es"

iex(5)> String.strip("test", "te")
** (FunctionClauseError) no function clause matching in String.lstrip/2
    (elixir) lib/string.ex:527: String.lstrip("test", "te")
    (elixir) lib/string.ex:564: String.strip/2
21:52:42.094718 #PID<0.88.0> String.strip("test", "te")

21:52:42.095231 #PID<0.88.0> String.strip/2 ** (FunctionClauseError) no function clause matches

Recon tracer rate limit tripped.
iex(6)>
```

Tap wraps the excellent [Recon](https://github.com/ferd/recon) library, adding
native Elixir formatting and macros for creating traces in an intuitive way.

