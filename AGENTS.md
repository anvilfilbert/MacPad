# Agent Instructions — MacPad

## Role

Implement approved macOS MacPad work in this repository. Do not redefine MacPad
Mobile or Shared Services from a MacPad task.

## Required reading

Before changing code or architecture, read:

1. `PROJECT_CONTEXT.md`
2. `ROADMAP.md`
3. the relevant GitHub issue, specification, or implementation plan
4. `CONTRIBUTING.md` and repository verification scripts

For owner-authorized cross-project work, use the portfolio context supplied with
the task. External contributors are not required to access private coordination
material.

## Repository boundaries

- macOS source, tests, packaging, and releases belong here.
- Mobile source and widget behavior belong in `anvilfilbert/MacPad-Mobile`.
- Website, domain, VPS, Cloudflare, DNS, shared infrastructure, and shared
  contracts belong in `anvilfilbert/MacPad-SharedServices` after approval.
- Do not modify another repository unless the task explicitly names it and
  provides a cross-repository sequence.

## Safety

- Preserve unrelated branches and user work.
- Never delete or overwrite unrelated files, rewrite history, or force-push.
- Never commit secrets, credentials, certificates, profiles, signing data,
  personal account data, or workstation-local paths.
- Never perform production, DNS, Cloudflare, VPS, Apple-account, App Store
  Connect, pricing, upload, notarization, or publication actions without
  explicit owner approval for that action.
- Keep `implemented`, `merged`, `released`, and `verified` distinct.

## Verification

Use the repository’s existing build, test, privacy-scan, packaging, and release
verification commands that apply to the scoped change. Report exact commands,
results, unresolved limitations, and remaining owner gates in the pull request.
