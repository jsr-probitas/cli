# Development Patterns

Coding conventions and development practices for the Probitas CLI.

## Testing Strategy

**Unit Tests (`*_test.ts`)**

- Test in isolation without external dependencies
- Run with `deno task test`

**Test Utilities**

- Avoid testing internal details; focus on command input/output behavior

## Command Implementation Pattern

Commands follow a consistent pattern:

```typescript ignore
import { parseArgs } from "@std/cli";
import { configureLogging, getLogger, type LogLevel } from "@probitas/logger";
import { EXIT_CODE } from "../constants.ts";
import { findProbitasConfigFile, loadConfig } from "../config.ts";
import { readAsset } from "../utils.ts";

const logger = getLogger("probitas", "cli", "command-name");

export async function commandName(
  args: string[],
  cwd: string,
): Promise<number> {
  try {
    // 1. Parse arguments
    const parsed = parseArgs(args, {
      string: ["config", "option"],
      boolean: ["help", "quiet", "verbose", "debug"],
      alias: { h: "help", v: "verbose", q: "quiet", d: "debug" },
    });

    // 2. Show help if requested
    if (parsed.help) {
      const helpText = await readAsset("usage-command.txt");
      console.log(helpText);
      return EXIT_CODE.SUCCESS;
    }

    // 3. Configure logging
    const logLevel: LogLevel = parsed.debug
      ? "debug"
      : parsed.verbose
      ? "info"
      : parsed.quiet
      ? "fatal"
      : "warning";
    await configureLogging(logLevel);

    // 4. Load configuration (CLI flags override config file)
    const configPath = parsed.config ??
      await findProbitasConfigFile(cwd, { parentLookup: true });
    const config = configPath ? await loadConfig(configPath) : {};

    // 5. Execute command logic
    // ...

    return EXIT_CODE.SUCCESS;
  } catch (err: unknown) {
    logger.error("Unexpected error", { error: err });
    console.error(`Error: ${err instanceof Error ? err.message : String(err)}`);
    return EXIT_CODE.FAILURE;
  }
}
```

### Key Points

1. **Return exit codes** - Use `EXIT_CODE` constants from `constants.ts`
2. **Configuration precedence** - CLI flags > config file > defaults
3. **Log level flags** - `-d/--debug`, `-v/--verbose`, `-q/--quiet`
4. **Help from assets** - Store help text in `assets/usage-*.txt`
5. **Error handling** - Catch at top level, log with logger, return error code

## Worker Pool Architecture

The `run` command uses Web Workers for parallel scenario execution:

- `pool.ts` - Manages worker lifecycle and task distribution
- `protocol.ts` - Defines message types between main thread and workers
- `worker.ts` - Worker implementation that executes scenarios

Workers communicate results back via structured messages, allowing the main
thread to forward events to the Reporter.
