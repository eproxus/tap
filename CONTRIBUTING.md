# Contributing to `tap`

1. [License](#license)
1. [Reporting a bug](#reporting-a-bug)
1. [Requesting or implementing a feature](#requesting-or-implementing-a-feature)
1. [Submitting your changes](#submitting-your-changes)
    1. [Code style](#code-style)
    1. [Committing your changes](#committing-your-changes)
    1. [Pull requests and branching](#pull-requests-and-branching)
    1. [Credits](#credits)

## License

`tap` is licensed under the [Apache License 2.0](LICENSE), for all code.

## Reporting a bug

`tap` is not perfect software and might have bugs.

Bugs can be reported via
[GitHub issues: bug report](https://github.com/eproxus/tap/issues/new?template=bug_report.md).

If your contribution is an actual bug fix, we ask you to include tests that, not
only show the issue is solved, but help prevent future regressions related to
it.

## Requesting or implementing a feature

Before requesting or implementing a new feature, do the following:

- search, in existing
  [issues](https://github.com/eproxus/tap/issues) (open or closed),
  whether the feature might already be in the works, or has already been
  rejected,
- make sure you're using the latest software release (or even the latest code,
  if you're going for _bleeding edge_).

If this is done, open up a
[GitHub issues: feature request](https://github.com/eproxus/tap/issues/new?template=feature_request.md).

## Submitting your changes

### Code style

- format the code with `mise run format` (`mix format`)
- make sure `mise run --output=keep-order verify` passes, including Credo in
  strict mode
- write small functions whenever possible, and use descriptive names for
  functions and variables
- comment tricky or non-obvious decisions made to explain their rationale

### Committing your changes

Merging to the `main` branch will usually be preceded by a squash.

While it's OK (and expected) your commit messages relate to why a given change
was made, be aware that the final commit (the merge one) will be the pull
request title. It must follow
[Conventional Commits](https://www.conventionalcommits.org), because the
changelog is generated from it. For `feat` changes, the body of the merge commit
is added to the changelog below the title. Write it for users of `tap`, e.g. by
explaining how to use the new feature.

### Pull requests and branching

All fixes to `tap` end up requiring a +1 from one or more of the project's
maintainers.

During the review process, you may be asked to correct or edit a few things
before a final rebase to merge things. Do send edits as individual commits to
allow for gradual and partial reviews to be done by reviewers.

### Credits

`tap` has been improved by
[many contributors](https://github.com/eproxus/tap/graphs/contributors)!
