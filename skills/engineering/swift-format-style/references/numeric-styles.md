# Numeric styles

`.number`, `.percent`, and `.currency` for `Int`, `Float`, `Double`, and
`Decimal`.

## Number

```swift
32.formatted()               // "32"
Double(100.0003).formatted() // "100.0003"
```

Compositing and direct initialisation:

```swift
Float(10).formatted(.number.scale(200.0).notation(.compactName)) // "2K"
IntegerFormatStyle<Int>().notation(.compactName).format(1_000)   // "1K"
Decimal.FormatStyle().scale(10).format(1)                        // "10"
```

### Rounding

| Rule | Behaviour |
| --- | --- |
| `.awayFromZero` | Magnitude ≥ source |
| `.down` | ≤ source |
| `.toNearestOrAwayFromZero` | Closest; ties favour greater magnitude |
| `.toNearestOrEven` | Closest; ties favour even |
| `.towardZero` | Magnitude ≤ source |
| `.up` | ≥ source |

```swift
Float(5.01).formatted(.number.rounded(rule: .awayFromZero, increment: 1))  // "6"
Float(5.01).formatted(.number.rounded(rule: .awayFromZero, increment: 10)) // "10"
Float(5.01).formatted(.number.rounded(rule: .down, increment: 1))          // "5"
```

### Sign

| Strategy | Behaviour |
| --- | --- |
| `.automatic` | Negative sign only |
| `.never` | No signs |
| `.always(includingZero:)` | Always show sign |

```swift
Float(1.90).formatted(.number.sign(strategy: .never))                     // "1.9"
Float(1.90).formatted(.number.sign(strategy: .always()))                  // "+1.9"
Float(0).formatted(.number.sign(strategy: .always(includingZero: true)))  // "+0"
```

### Decimal separator and grouping

```swift
Float(10).formatted(.number.decimalSeparator(strategy: .always)) // "10."
Float(1000).formatted(.number.grouping(.automatic))              // "1,000"
Float(1000).formatted(.number.grouping(.never))                  // "1000"
```

### Precision

```swift
// Significant digits
Decimal(10.1).formatted(.number.precision(.significantDigits(1)))       // "10"
Decimal(10.1).formatted(.number.precision(.significantDigits(1 ... 3))) // "10.1"

// Fraction length
Decimal(10.01).formatted(.number.precision(.fractionLength(1)))      // "10.0"
Decimal(10.111).formatted(.number.precision(.fractionLength(0...2))) // "10.11"

// Integer length
Decimal(10.111).formatted(.number.precision(.integerLength(1))) // "0.111"

// Combined
Decimal(10.111).formatted(.number.precision(.integerAndFractionLength(integer: 2, fraction: 1))) // "10.1"
```

### Notation and scale

```swift
Float(1_000).formatted(.number.notation(.compactName)) // "1K"
Float(1_000).formatted(.number.notation(.scientific))  // "1E3"
Float(10).formatted(.number.scale(1.5))                // "15"
Float(10).formatted(.number.scale(-2.0))               // "-20"
```

### Locale and number systems

```swift
Float(1_000).formatted(.number.grouping(.automatic).locale(Locale(identifier: "fr_FR"))) // "1 000"

// Alternate number systems via BCP-47 or ICU identifiers
123456.formatted(.number.locale(Locale(identifier: "en-u-nu-arab"))) // "١٢٣٬٤٥٦"
```

### Parsing

```swift
try? Int("120", format: .number)                       // 120
try? Int("1E5", format: .number.notation(.scientific)) // 100000
try? Decimal("1E5", format: .number.notation(.scientific)) // 100000
```

---

## Percent

Integer percentages are literal (`100` → "100%"); floating-point are
fractional (`1.0` → "100%").

```swift
0.1.formatted(.percent)                                         // "10%"
Float(0.26575).formatted(.percent.rounded(rule: .awayFromZero)) // "26.575%"
Float(1_000).formatted(.percent.notation(.compactName))         // "100K%"

try? Float("95%", format: .percent) // 0.95
```

---

## Currency

Always drive from `Decimal`. Requires an ISO 4217 code.

```swift
Decimal(9.99).formatted(.currency(code: "AUD"))                    // "$9.99"
Decimal.FormatStyle.Currency(code: "USD").scale(12).format(0.1)    // "$1.20"
```

### Rounding

```swift
Decimal(0.599).formatted(.currency(code: "GBP").rounded())                                 // "£0.60"
Decimal(5.01).formatted(.currency(code: "GBP").rounded(rule: .awayFromZero, increment: 1)) // "£6"
```

### Sign

Includes accounting variants on top of the number sign strategies:
`.accounting`, `.accountingAlways()`, `.accountingAlways(showZero:)`.

```swift
Decimal(7).formatted(.currency(code: "GBP").sign(strategy: .accountingAlways())) // "+£7.00"
Decimal(7).formatted(.currency(code: "GBP").sign(strategy: .always()))           // "+£7.00"
```

### Precision and presentation

```swift
Decimal(3_000.003).formatted(.currency(code: "GBP").precision(.fractionLength(4))) // "£3,000.0029"

Decimal(10).formatted(.currency(code: "GBP").presentation(.fullName)) // "10.00 British pounds"
Decimal(10).formatted(.currency(code: "GBP").presentation(.isoCode))  // "GBP 10.00"
Decimal(10).formatted(.currency(code: "GBP").presentation(.narrow))   // "£10.00"
```

### Locale and parsing

```swift
Decimal(10_000_000).formatted(.currency(code: "GBP").locale(Locale(identifier: "hi_IN")))
// "£1,00,00,000.00"

try Decimal("$3.14", format: .currency(code: "USD").locale(Locale(identifier: "en_US"))) // 3.14
```
</content>
