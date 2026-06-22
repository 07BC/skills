---
name: swift-format-style
description: 'Conceptual guidance and reference for formatting values for display in Swift with FormatStyle. Triggers when formatting a date, number, currency, measurement, duration, byte count, name, or list; when using .formatted() or FormatStyle; when choosing how to render a value in SwiftUI Text; or when replacing legacy DateFormatter, NumberFormatter, MeasurementFormatter, DateComponentsFormatter, or ByteCountFormatter.'
user-invocable: false
---
# Swift FormatStyle

## Overview

Reference for turning values into display strings using Foundation's
`FormatStyle` family and the `.formatted(...)` API. Covers numbers,
currency, dates, durations, measurements, byte counts, names, and lists,
plus SwiftUI integration. This is read-only conceptual guidance — it
explains what to use and why; it does not run a review workflow.

## Core Rules

1. **Prefer `.formatted(...)` / `FormatStyle` over legacy formatters.**
   Every `Formatter` subclass has a modern, value-type replacement (see
   table below). Avoid C-style `String(format:)` for numeric or time
   display — it is locale-blind and error-prone.
2. **In SwiftUI, prefer `Text(_:format:)` over interpolating a formatted
   string.** `Text(value, format: …)` formats at render time and respects
   the view's environment locale; `Text("\(value.formatted())")` captures
   the string eagerly and misses later locale or calendar changes.
3. **`FormatStyle` instances are value types** — they conform to `Codable`
   and `Hashable`. Build and reuse them as stored properties or `static`
   constants; do not hoard `Formatter` singletons for performance, and do
   not reach for `DispatchQueue` to format off the main thread (styles are
   thread-safe).
4. **Use `Decimal` for currency**, never `Double`/`Float` — binary
   floating point cannot represent decimal money exactly.
5. **Locale is automatic.** Styles use the user's current locale by
   default. Only call `.locale(_:)` when you need a *specific*, different
   locale. The one exception is `.verbatim(...)`, where you must pass a
   locale explicitly or output garbles (see `references/date-styles.md`).

## Legacy → Modern Replacements

| Legacy | Modern replacement |
| --- | --- |
| `NumberFormatter` | `.formatted(.number)` / `IntegerFormatStyle` / `FloatingPointFormatStyle` |
| `DateFormatter` | `.formatted(.dateTime)` / `Date.FormatStyle` / `.formatted(date:time:)` |
| `DateComponentsFormatter` | `Duration.formatted(.units(...))` / `.time(pattern:)` |
| `DateIntervalFormatter` | `.formatted(.interval)` / `Date.IntervalFormatStyle` |
| `MeasurementFormatter` | `.formatted(.measurement(...))` |
| `ByteCountFormatter` | `.formatted(.byteCount(style:))` |
| `PersonNameComponentsFormatter` | `.formatted(.name(style:))` |
| `RelativeDateTimeFormatter` | `.formatted(.relative(...))` |
| `String(format: "%.2f", x)` | `x.formatted(.number.precision(.fractionLength(2)))` |

## Availability

- `.formatted()` / `FormatStyle`, number, percent, currency, date, list,
  measurement, name, relative, and `Int64` byte-count styles — **iOS 15 /
  macOS 12**.
- `Duration` and its `.time(...)` / `.units(...)` styles, and
  `URL.FormatStyle` — **iOS 16 / macOS 13**.

Confirm the deployment target supports the style before adopting it.

## Quick Reference

### Numbers, percent, currency

```swift
1234.formatted()                                          // "1,234"
3.14159.formatted(.number.precision(.fractionLength(2)))  // "3.14"
0.1.formatted(.percent)                                   // "10%"
Float(1_000).formatted(.number.notation(.compactName))    // "1K"
Decimal(9.99).formatted(.currency(code: "AUD"))           // "$9.99"
```

Currency takes an ISO 4217 code and is best driven from `Decimal`.
See `references/numeric-styles.md` for rounding, sign, grouping,
precision, notation, scale, and parsing.

### Dates and times

```swift
date.formatted(date: .abbreviated, time: .shortened) // "Feb 22, 2022, 2:22 AM"
date.formatted(.dateTime.year().month().day())       // "Feb 22, 2022"
date.formatted(.iso8601)                             // "2022-02-22T09:22:22Z"
pastDate.formatted(.relative(presentation: .named))  // "yesterday"
(start..<end).formatted(.interval)                   // range across two dates
```

Symbol call order does not matter — the locale controls display order.
For fixed machine formats use `.iso8601`; for fixed *custom* layouts use
`.verbatim(...)` (type-safe interpolation, not a `dateFormat` string), and
always pass an explicit locale. See `references/date-styles.md`.

### Durations

```swift
Duration.seconds(1_000).formatted(.time(pattern: .minuteSecond)) // "16:40"
Duration.seconds(100).formatted(.units(width: .wide))            // "1 minute, 40 seconds"
Duration.seconds(10_000).formatted(.units(maximumUnitCount: 2))  // "2 hr, 47 min"
```

Use `.time(pattern:)` for clock-style output and `.units(...)` for named
units. Never hand-roll `minutes / 60` arithmetic with `String(format:)`.
See `references/duration-styles.md`.

### Measurements, byte counts, names, lists

```swift
Measurement(value: 190, unit: UnitLength.centimeters)
    .formatted(.measurement(width: .abbreviated, usage: .personHeight))   // locale-dependent

Int64(1_000_000_000_000).formatted(.byteCount(style: .file))              // "1 TB"

components.formatted(.name(style: .long))                                 // "Dr Elizabeth Jillian Smith Esq."

["a", "b", "c"].formatted(.list(type: .and))                              // "a, b, and c"
```

Measurement output is **non-deterministic across devices**: `.general`
usage converts to the device locale's preferred unit, so test with an
explicit locale (or use `.asProvided` to keep the supplied unit).
Custom units only display correctly with `.asProvided`.

### SwiftUI

```swift
// Correct — formats at render time, follows environment locale.
Text(price, format: .currency(code: "AUD"))
Text(date, format: .dateTime.hour().minute())
Text(progress, format: .percent)
Text(Duration.seconds(125), format: .time(pattern: .minuteSecond))

// Avoid — eager string, misses locale/calendar changes.
Text("\(price.formatted(.currency(code: "AUD")))")
```

## Custom Styles

Conform to `FormatStyle` for a bespoke conversion, and expose it via a
static member so it reads as `.myStyle` at the call site:

```swift
extension FormatStyle where Self == MyCustomStyle {
    static var myStyle: MyCustomStyle { .init() }
}

value.formatted(.myStyle)
```

Conform to `ParseableFormatStyle` to support parsing strings back into the
value. Built-in parseable styles include numbers, percentages, currencies,
dates (`Date.FormatStyle`, `Date.ISO8601FormatStyle`), person names, and
URLs.

## Reference Files

- **`references/numeric-styles.md`** — number, percent, and currency:
  rounding, sign, decimal separator, grouping, precision, notation, scale,
  locale/number systems, and parsing.
- **`references/date-styles.md`** — `Date.FormatStyle` compositing,
  presets, ISO 8601, relative, verbatim (with locale pitfalls), HTTP,
  interval, and components.
- **`references/duration-styles.md`** — `Duration.TimeFormatStyle` and
  `Duration.UnitsFormatStyle`: patterns, units, width, counts, and
  fractional seconds.
</content>
</invoke>
