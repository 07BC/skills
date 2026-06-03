---
description: Build, launch, and inspect the current iOS app on the booted simulator.
argument-hint: [optional: scheme / what to inspect]
---
Delegate to the `ios-runtime-diagnostics` subagent (debugger mode) to build, launch, and inspect the current iOS app on the booted simulator: $ARGUMENTS

The agent follows the `ios-debugger-agent` skill and requires the XcodeBuildMCP server. Have it report the launch state, any UI it inspected, and relevant log lines.
