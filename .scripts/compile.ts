#!/usr/bin/env -S deno run -A
/**
 * Compile probitas CLI binary
 *
 * Usage:
 *   deno run -A .scripts/compile.ts [options]
 *
 * Options:
 *   --target <target>  Target platform (e.g., x86_64-unknown-linux-gnu)
 *   --output <path>    Output path (default: dist/probitas or dist/probitas.exe)
 *
 * Examples:
 *   deno run -A .scripts/compile.ts
 *   deno run -A .scripts/compile.ts --target aarch64-apple-darwin
 *   deno run -A .scripts/compile.ts --output ./my-probitas
 *
 * @module
 */

import { parseArgs } from "jsr:@std/cli@^1.0.24/parse-args";

const WINDOWS_TARGETS = [
  "x86_64-pc-windows-msvc",
];

interface CompileOptions {
  target?: string;
  output?: string;
}

function parseOptions(): CompileOptions {
  const args = parseArgs(Deno.args, {
    string: ["target", "output"],
    alias: {
      t: "target",
      o: "output",
    },
  });

  return {
    target: args.target,
    output: args.output,
  };
}

function getDefaultOutput(target?: string): string {
  const isWindows = target && WINDOWS_TARGETS.includes(target);
  return isWindows ? "dist/probitas.exe" : "dist/probitas";
}

async function compile(options: CompileOptions): Promise<void> {
  const output = options.output ?? getDefaultOutput(options.target);

  // Ensure output directory exists
  const outputDir = output.substring(0, output.lastIndexOf("/"));
  if (outputDir) {
    await Deno.mkdir(outputDir, { recursive: true });
  }

  const cmd = [
    "deno",
    "compile",
    "--allow-all",
    "--unstable-kv",
    "--lock",
    "./deno.lock",
    "--include=assets/",
    "--include=deno.json",
    "--output",
    output,
  ];

  if (options.target) {
    cmd.push("--target", options.target);
  }

  cmd.push("./mod.ts");

  console.log(`Compiling: ${cmd.join(" ")}`);

  const command = new Deno.Command(cmd[0], {
    args: cmd.slice(1),
    stdout: "inherit",
    stderr: "inherit",
  });

  const { code } = await command.output();

  if (code !== 0) {
    throw new Error(`Compilation failed with exit code ${code}`);
  }

  console.log(`\nCompiled successfully: ${output}`);
}

if (import.meta.main) {
  try {
    const options = parseOptions();
    await compile(options);
  } catch (error) {
    console.error(`Error: ${error instanceof Error ? error.message : error}`);
    Deno.exit(1);
  }
}
