import Foundation

/// Turning what someone typed on a number pad into a number.
///
/// Display goes the other way, through system formatters, so this has to accept
/// what those produce: the region's decimal separator, its grouping separator,
/// and its digits. Getting it wrong turns "1,250" into 1.25 for half the world,
/// which is a silent wrong number rather than an error anyone would notice.
enum NumberInput {

    static func parse(_ text: String, locale: Locale = .current) -> Double? {
        let decimalSeparator = (locale.decimalSeparator ?? ".").first
        var digits = ""
        var isNegative = false
        var seenSeparator = false

        for character in text {
            if character.isNumber, let digit = character.wholeNumberValue, (0...9).contains(digit) {
                digits.append(String(digit))  // also normalises non-ASCII digits
            } else if character == decimalSeparator, !seenSeparator {
                seenSeparator = true
                digits.append(".")
            } else if character == "-", digits.isEmpty, !isNegative {
                isNegative = true
            }
            // Everything else — grouping separators, spaces, currency symbols,
            // a second decimal point — is dropped rather than rejected.
        }

        guard digits.contains(where: \.isWholeNumber), let value = Double(digits) else {
            return nil
        }
        return isNegative ? -value : value
    }

    /// What one key adds to what has been typed so far.
    ///
    /// The pad is drawn by the app now (docs/TODO.md item 12), so the one
    /// editing rule a `UITextField` used to imply has to be written down. It
    /// lives here, next to `parse`, because it decides the text `parse` is
    /// handed and therefore the number that gets stored — a second parser, or
    /// a second idea of what the separator is, is exactly the split this file
    /// exists to prevent.
    ///
    /// Everything else is deliberately absent. No leading zero is inserted in
    /// front of a lone separator, so a field holding just `.` still parses to
    /// `nil` and Log stays disabled, and `007` is still whatever `parse` makes
    /// of it — the pad changed how the text is typed, not what it means.
    ///
    /// It accepts a key from anywhere, because a hardware keyboard can send
    /// anything and does not know what region the app is in.
    static func appending(_ key: String, to text: String, locale: Locale = .current) -> String {
        let separator = locale.decimalSeparator ?? "."
        // Both separator characters mean "decimal point" here, whichever one
        // this region prints. A hardware keyboard sends the key that is on it
        // — a numeric keypad's `.` in Berlin, a `,` on a French layout — and
        // appending that verbatim was a silently wrong number, not an error:
        // in de_DE, `1` `.` `5` displayed 1.5 while `parse` read the `.` as a
        // grouping separator and returned 15. Translated here rather than at
        // the key catcher, because this is the file that owns what a
        // separator is.
        if key == "." || key == "," || key == separator {
            // A second separator is dropped rather than inserted. `parse`
            // survives `5..5` and the tests pin that, but it survives it by
            // guessing; a field that displays it is showing something that is
            // not a number, and no key press should be able to produce one.
            return text.contains(separator) ? text : text + separator
        }
        // Anything that is not a digit is not part of a number. Silence is the
        // right answer for a stray key, and it keeps `parse`'s "drop what you
        // don't recognise" rule from ever being asked to guess.
        guard key.count == 1, key.allSatisfy(\.isASCII), key.allSatisfy(\.isNumber) else {
            return text
        }
        return text + key
    }
}
