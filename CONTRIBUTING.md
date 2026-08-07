# Contributing

Thanks for helping improve MacPad.

## Scope

MacPad is intended to stay close to Windows `notepad.exe`: fast, native, plain text, and lightweight. Extensions, themes, project models, and language-aware workflows are outside that focused scope.

## Before Opening a Pull Request

1. Keep changes focused and small.
2. Avoid private notes, local paths, generated build output, or credentials.
3. Run the repository checks:

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

By contributing, you agree that your contribution is provided under this repository's GPL-3.0 license.
