---
description: Build, launch, and inspect the current iOS app on the booted simulator.
argument-hint: [optional: scheme / what to inspect]
---
Delegate to the `swift-debugger-agent` agent to build, launch, and inspect the current iOS app on the booted simulator: $ARGUMENTS

The agent owns simulator control via the XcodeBuildMCP server: it discovers the booted simulator, sets session defaults, builds and runs the current scheme, then inspects UI and captures logs. Have it report the launch state, any UI it inspected, and relevant log lines. If nothing specific is requested, it runs the base build → launch → describe-UI loop.
