# Contributing

Thanks for helping improve MacPad.

## Scope

MacPad is intended to stay close to Windows `notepad.exe`: fast, native, plain text, and lightweight. Extensions, themes, project models, and language-aware workflows are outside that focused scope.

## Before Opening a Pull Request

1. Check existing issues and discussions before starting overlapping work.
2. Fork the repository and create a focused branch from the latest `main`.
3. Keep changes focused and small.
4. Avoid private notes, local paths, generated build output, or credentials.
5. Add or update tests for behavior changes.
6. Run the repository checks:

```sh
./scripts/verify-public-repo.sh
swift test
./scripts/build-app.sh
```

## Pull Requests

Include:

- What changed
- Why it fits MacPad's focused plain-text scope
- How you verified it

Pull requests require review, passing CI, and resolved conversations before merge. GitHub may hold workflow runs from first-time contributors for maintainer approval; this is expected and does not block contribution.

Small tasks labeled [`good first issue`](https://github.com/anvilfilbert/MacPad/labels/good%20first%20issue) are intended as starting points for new contributors.

By contributing, you agree that your contribution is provided under this repository's GPL-3.0 license.
