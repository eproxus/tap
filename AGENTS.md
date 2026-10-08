# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## `tap` Overview

Elixir tracing library. Wraps Recon's `:recon_trace`, adding native Elixir
formatting and macros for creating traces.

## Architecture

* `Tap` - the whole public API: the `Tap.call/2` macro, `Tap.calls/2`, and
  the trace event formatter `Tap.format/1`

## Build & Development Commands

```sh
mise run --output=keep-order verify  # Run all linting
mise run --output=keep-order test    # Run all tests
mise run format                      # Format all code
mise run docs                        # Generate documentation
mise run release:prepare [VERSION]   # Set the release version and changelog
```

## Coding Conventions

* Prefer exceptions over tagged return values. If the caller cannot meaningfully
  act on the return value at the call site, an exception should be used.
* Keep public functions at the top of the module
* Keep private functions below, sorted in the order of appearance in the module

## Commits and Releases

* Commit messages follow [Conventional Commits](https://www.conventionalcommits.org).
  `git-cliff` generates the changelog from them (see `cliff.toml`).
* To release, run `mise run release:prepare` and commit the result as
  `chore(release): <version>`. Pushing that commit to `main` publishes the
  version once CI passes.

## Changes

Before making changes:

* Run tests with `mise run --output=keep-order test` to establish a baseline

When making changes:

* When refactoring, check if multiple lines can be joined and still stay under
  the length limit. When in doubt, prefer longer lines over shorter lines, the
  formatter will split them

After every change:

* Format the code: `mise run format`
* Lint: `mise run --output=keep-order verify`
* Docs: `mise run docs`
* Test: `mise run --output=keep-order test`
