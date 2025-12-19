# Design Philosophy

This document describes the design principles and architectural decisions for
the Probitas CLI.

## Overall Principles

1. **Thin CLI Layer** - CLI is a thin wrapper; business logic lives in library
   packages
2. **Configuration Precedence** - CLI flags override config file, which
   overrides defaults
3. **Worker-Based Parallelism** - Use Web Workers for process isolation
4. **Structured Messaging** - Type-safe protocol for worker communication

## Command Architecture

The CLI follows a dispatch pattern:

```
main.ts
├── parseArgs (global flags: --help, --version)
├── dispatch to command handler
│   ├── run command → runCommand()
│   └── list command → listCommand()
└── return exit code
```

### Command Handler Pattern

Each command:

1. Parses its own arguments
2. Loads configuration (with precedence: CLI > config > default)
3. Discovers and loads scenarios via library packages
4. Executes logic and returns exit code

Commands don't throw - they catch errors and return appropriate exit codes.

## Worker Pool Architecture

The `run` command uses Web Workers for parallel scenario execution:

```
Main Thread                          Worker Thread
┌─────────────────┐                  ┌─────────────────┐
│ runCommand()    │                  │ worker.ts       │
│                 │  WorkerInput     │                 │
│ WorkerPool ─────┼─────────────────►│ onmessage       │
│                 │                  │   ├─ load file  │
│                 │  WorkerOutput    │   ├─ run        │
│ Reporter ◄──────┼◄─────────────────│   └─ emit       │
│                 │                  │                 │
└─────────────────┘                  └─────────────────┘
```

### Why Workers?

- **Process Isolation**: Scenario execution errors don't crash the CLI
- **True Parallelism**: Utilize multiple CPU cores
- **Memory Isolation**: Each worker has its own heap

### Protocol Design

Worker messages use discriminated unions for type safety:

```typescript ignore
type WorkerOutput =
  | { type: "ready" }
  | { type: "result"; taskId: string; result: ScenarioResult }
  | { type: "error"; taskId: string; error: ErrorObject }
  | { type: "scenario_start"; taskId: string; scenario: ScenarioMetadata };
// ...
```

### Error Serialization

Errors cannot be directly passed between threads. The protocol serializes errors
to `ErrorObject` (from `@core/errorutil`) and deserializes on the main thread.

## Configuration Layer

Configuration loading follows a search hierarchy:

1. Explicit `--config` flag
2. `probitas.json` in current directory
3. `probitas.json` in parent directories (with `parentLookup: true`)

### Config Schema

```typescript ignore
interface Config {
  includes?: string[]; // Glob patterns for scenario files
  excludes?: string[]; // Glob patterns to exclude
  reporter?: string; // Reporter type (list, json)
  maxConcurrency?: number; // Max parallel scenarios
  maxFailures?: number; // Stop after N failures
  timeout?: string; // Scenario timeout (e.g., "30s")
  selectors?: string[]; // Default selectors
}
```

## Exit Code Semantics

Exit codes communicate status to shell scripts and CI:

| Code | Meaning     | Example                      |
| ---- | ----------- | ---------------------------- |
| 0    | Success     | All scenarios passed         |
| 1    | Failure     | One or more scenarios failed |
| 2    | Usage error | Invalid arguments            |
| 4    | Not found   | No scenarios matched         |

## Dependency on Probitas Library

The CLI is intentionally thin, delegating to library packages:

- `@probitas/discover` - File discovery
- `@probitas/core` - Scenario loading and filtering
- `@probitas/runner` - Scenario execution
- `@probitas/reporter` - Output formatting
- `@probitas/logger` - Structured logging

This separation allows:

- Independent versioning of CLI and library
- Library usage without CLI (programmatic API)
- CLI updates without library changes
