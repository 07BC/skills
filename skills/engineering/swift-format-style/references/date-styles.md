# Date styles

Compositing, presets, ISO 8601, relative, verbatim, HTTP, interval, and
components.

## Compositing

Mix date components like building blocks. Symbol call order does not affect
output — the locale controls display order.

```swift
twosday.formatted(.dateTime.day())     // "22"
twosday.formatted(.dateTime.month())   // "Feb"
twosday.formatted(.dateTime.weekday()) // "Tue"

twosday.formatted(.dateTime.year().month().day().hour().minute())
// "Feb 22, 2022, 2:22 AM"
```

Component options:

```swift
.day(.twoDigits)                          // "22"
.month(.wide)                             // "February"
.month(.abbreviated)                      // "Feb"
.year(.twoDigits)                         // "22"
.hour(.defaultDigits(amPM: .wide))        // "2 AM"
.weekday(.wide)                           // "Tuesday"
.timeZone(.specificName(.long))           // "Mountain Standard Time"
.timeZone(.iso8601(.long))                // "-07:00"
```

## Presets

`DateStyle`: `.omitted`, `.numeric`, `.abbreviated`, `.long`, `.complete`.
`TimeStyle`: `.omitted`, `.shortened`, `.standard`, `.complete`.

```swift
twosday.formatted(date: .abbreviated, time: .omitted)  // "Feb 22, 2022"
twosday.formatted(date: .complete, time: .omitted)     // "Tuesday, February 22, 2022"
twosday.formatted(date: .omitted, time: .shortened)    // "2:22 AM"
twosday.formatted(date: .abbreviated, time: .shortened) // "Feb 22, 2022, 2:22 AM"
```

A `Date.FormatStyle` value can fix locale, calendar, and time zone for
reuse:

```swift
let style = Date.FormatStyle(
    date: .complete, time: .complete,
    locale: Locale(identifier: "fr_FR"),
    calendar: Calendar(identifier: .hebrew),
    timeZone: TimeZone(secondsFromGMT: 0)!
)
```

## ISO 8601

```swift
twosday.formatted(.iso8601) // "2022-02-22T09:22:22Z"

let iso = Date.ISO8601FormatStyle(
    includingFractionalSeconds: true,
    timeZone: TimeZone(secondsFromGMT: 0)!
)
iso.format(twosday) // "2022-02-22T09:22:22.000Z"
```

## Relative

`presentation`: `.numeric` ("1 day ago"), `.named` ("yesterday").
`unitsStyle`: `.abbreviated`, `.narrow`, `.spellOut`, `.wide`.

```swift
thePast.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)) // "2 wk. ago"
thePast.formatted(.relative(presentation: .named, unitsStyle: .wide))          // "2 weeks ago"
```

## Verbatim

For fixed, custom layouts (the replacement for `dateFormat`). Uses
type-safe interpolation rather than cryptic Unicode patterns.

```swift
twosday.formatted(
    .verbatim(
        "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits)",
        locale: .current, timeZone: .current, calendar: .current
    )
) // "2022-02-22"
```

**Pitfall — always pass a locale.** Omitting it defaults to `nil` and
garbles output (`.month(.abbreviated)` renders "M02" instead of "Feb").
Also note that an `.autoupdatingCurrent` locale overrides the `calendar`
parameter; pass an explicit `Locale` to honour a non-default calendar.

## HTTP

Fixed RFC 9110 format for HTTP headers — no customisation.

```swift
twosday.formatted(.http) // "Tue, 22 Feb 2022 09:22:22 GMT"
try? Date.HTTPFormatStyle().parse("Tue, 22 Feb 2022 09:22:22 GMT")
```

## Interval

Formats a date range as earliest–latest.

```swift
(date1..<date2).formatted(.interval)              // "12/31/69, 5:00 PM - 12/31/00, 5:47 PM"
(date1..<date2).formatted(.interval.year())       // "1969 - 2000"
(date1..<date2).formatted(.interval.month(.wide)) // "December 1969 - December 2000"
```

## Components

Formats the distance between two dates in plain language. Styles: `.wide`,
`.abbreviated`, `.condensedAbbreviated`, `.narrow`, `.spellOut`.

```swift
(date1..<date2).formatted(.components(style: .abbreviated, fields: [.year, .month, .week]))
// "21 yrs, 1 mth, 3 wks"
```

## Parsing

```swift
try? Date.FormatStyle()
    .day().month().year().hour().minute().second()
    .parse("Feb 22, 2022, 2:22:22 AM")
```
</content>
