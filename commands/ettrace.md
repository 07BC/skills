---
description: Capture a focused iOS simulator ETTrace profile and find time-heavy stacks.
argument-hint: [the one flow to profile, with start/stop points]
---
Delegate to the `ios-runtime-diagnostics` subagent (ETTrace mode) to capture a focused iOS simulator ETTrace profile and identify time-heavy stacks for: $ARGUMENTS

The agent follows the `ios-ettrace-performance` skill: one user-visible flow per trace, UUID-matched dSYMs, preserve the processed flamegraph JSON immediately, analyse only that. `ettrace` needs a TTY, so it may ask you to run the capture step in a terminal. If no flow is given, ask for one with explicit start and stop points.
