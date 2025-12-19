# Source Structure

Source code organization for the Probitas CLI.

## Directory Layout

```
cli/
├── deno.json                    # Package configuration
├── mod.ts                       # Module entry point
├── assets/                      # Static assets (usage.txt, etc.)
├── .scripts/                    # Build/release scripts
└── src/
    ├── main.ts                  # CLI main entry point
    ├── config.ts                # Configuration file loading
    ├── constants.ts             # Exit codes and constants
    ├── types.ts                 # Type definitions
    ├── utils.ts                 # Utility functions
    └── commands/
        ├── mod.ts               # Command exports
        ├── list.ts              # `probitas list` command
        ├── run.ts               # `probitas run` command
        └── run/
            ├── pool.ts          # Worker pool management
            ├── protocol.ts      # Worker communication protocol
            └── worker.ts        # Worker implementation
```

## Dependencies

This CLI depends on the main Probitas packages from JSR:

- `@probitas/core` - Scenario loading and filtering
- `@probitas/discover` - File discovery
- `@probitas/runner` - Scenario execution engine
- `@probitas/reporter` - Output formatters
- `@probitas/logger` - Logging utilities
- `@probitas/probitas` - Primary library API
