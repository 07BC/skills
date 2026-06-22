# Duration styles

`Duration` formatting requires iOS 16 / macOS 13. Two styles:
`TimeFormatStyle` (clock-like) and `UnitsFormatStyle` (named units).

## Time style

```swift
Duration.seconds(1_000).formatted()                                  // "0:16:40"
Duration.seconds(1_000).formatted(.time(pattern: .hourMinute))       // "0:17"
Duration.seconds(1_000).formatted(.time(pattern: .hourMinuteSecond)) // "0:16:40"
Duration.seconds(1_000).formatted(.time(pattern: .minuteSecond))     // "16:40"
```

Patterns take parameters for padding, fractional seconds, and rounding:

```swift
// hourMinute: padHourToLength, roundSeconds
Duration.seconds(1_000).formatted(.time(pattern: .hourMinute(padHourToLength: 3))) // "000:17"

// hourMinuteSecond / minuteSecond: pad…ToLength, fractionalSecondsLength, roundFractionalSeconds
Duration.seconds(1_000).formatted(
    .time(pattern: .hourMinuteSecond(padHourToLength: 3, fractionalSecondsLength: 3))
) // "000:16:40.000"
```

## Units style

```swift
Duration.seconds(100).formatted(.units()) // "1 min, 40 sec"
```

### Allowed units

`.nanoseconds`, `.microseconds`, `.milliseconds`, `.seconds`, `.minutes`,
`.hours`, `.days`, `.weeks`.

```swift
Duration.milliseconds(500).formatted(.units(allowed: [.milliseconds])) // "500 ms"
Duration.seconds(1_000_000.00123).formatted(
    .units(allowed: [.weeks, .days, .hours, .minutes, .seconds])
) // "1 wk, 4 days, 13 hr, 46 min, 40 sec"
```

### Width

| Value | Example |
| --- | --- |
| `.wide` | "1 minute, 40 seconds" |
| `.abbreviated` | "1 min, 40 sec" |
| `.condensedAbbreviated` | "1 min,40 sec" |
| `.narrow` | "1m 40s" |

### Other options

```swift
Duration.seconds(10_000).formatted(.units(maximumUnitCount: 2))           // "2 hr, 47 min"
Duration.seconds(100).formatted(.units(zeroValueUnits: .show(length: 1))) // "0 hr, 1 min, 40 sec"
Duration.seconds(1_000).formatted(.units(valueLength: 3))                 // "016 min, 040 sec"
Duration.seconds(10.0023).formatted(.units(fractionalPart: .show(length: 3, rounded: .up))) // "10.003 sec"
```
</content>
