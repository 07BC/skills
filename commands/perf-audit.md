---
description: Code-first SwiftUI performance audit with concrete fixes.
argument-hint: [view / module / file to audit]
---
Use the `swiftui-performance-audit` skill to review this SwiftUI code for performance issues and suggest concrete fixes: $ARGUMENTS

Classify the symptom, review against `code-smells.md` first, and only guide profiling if code review is inconclusive. For an actual runtime profile, hand off to the `ios-runtime-profiler` agent. Summarise causes, evidence, remediation, and validation using `report-template.md`. If no target is given, ask for the smallest useful slice (view, data flow, repro, deployment target).
