#! /usr/bin/env Bun
/**
 * This script acts as a convenience wrapper around the CLI build command
 */
export { };

const buildCmd = [
  "bun", "build",
  "--compile",
  "--minify",
  "--sourcemap",
  "./src/dinit-graph-cli.ts",
  "--outfile", "./bin/dinit-graph"
].join(" ");

console.log(`Building: ${buildCmd}`);
const result = await Bun.spawn(buildCmd.split(" "), {
  stdio: ["inherit", "inherit", "inherit"],
});

if (await result.exited === 0) {
  console.log("✅ Build successful!");
} else {
  console.error("❌ Build failed.");
  process.exit(result.exitCode);
}