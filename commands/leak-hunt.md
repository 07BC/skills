---
description: Capture an iOS simulator memgraph, find retention paths, and verify a leak fix.
argument-hint: [the flow that should release objects]
---
Delegate to the `ios-runtime-profiler` subagent (memgraph mode) to capture an iOS simulator memgraph, identify retention paths, and verify leak fixes for: $ARGUMENTS

The agent follows the `ios-memgraph-leaks` skill: drive the exact flow, capture, summarise leaks, inspect ownership with `leaks --traceTree`, make the smallest patch, then recapture the same flow. It must prove the retention path disappears after the patch — never claim a fix from a smaller memgraph alone. If no flow is given, ask which one should release objects.
