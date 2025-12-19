# Repository Rules

Project-specific rules for the Probitas CLI repository.

## Pre-Completion Verification

BEFORE reporting task completion, run and ensure zero errors/warnings:

```bash
deno task verify
```

## Commit Conventions

This project uses [Conventional Commits](https://www.conventionalcommits.org/).

### Commit Types

| Commit Type  | Version Bump  | Example                                  |
| ------------ | ------------- | ---------------------------------------- |
| `feat:`      | minor (0.x.0) | `feat: add --parallel flag`              |
| `fix:`       | patch (0.0.x) | `fix: handle timeout errors`             |
| `perf:`      | patch (0.0.x) | `perf: optimize file discovery`          |
| `docs:`      | patch (0.0.x) | `docs: update installation instructions` |
| `refactor:`  | patch (0.0.x) | `refactor: simplify command parsing`     |
| `test:`      | patch (0.0.x) | `test: add config loading tests`         |
| `chore:`     | patch (0.0.x) | `chore: update dependencies`             |
| `BREAKING:!` | major (x.0.0) | `feat!: change exit code semantics`      |

### Important Notes

- This is a single-package repository, scopes are not required
- All conventional commit types trigger version bumps (including `docs:`)
- Version is managed via `.scripts/update_version.ts` from git tags
