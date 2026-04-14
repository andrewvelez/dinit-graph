#! /usr/bin/env Bun
/**
 * This script acts as a convenience wrapper around the CLI build command
 */
const buildCmd = [
  "bun", "build",
  "--compile",        // Create a standalone executable
  "--minify",         // Minify the output
  "--sourcemap",      // Generate a sourcemap
  "./src/index.ts",   // Your CLI's entrypoint
  "--outfile", "./bin/my-cli"
].join(" ");

// Execute the build command
console.log(`Building: ${buildCmd}`);
const result = await Bun.spawn(buildCmd.split(" "), {
  stdio: ["inherit", "inherit", "inherit"],
});

if (result.exited === 0) {
  console.log("✅ Build successful!");
} else {
  console.error("❌ Build failed.");
  process.exit(result.exitCode);
}