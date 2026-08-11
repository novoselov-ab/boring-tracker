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
}
