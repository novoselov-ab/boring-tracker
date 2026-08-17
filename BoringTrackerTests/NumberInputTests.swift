import Foundation
import Testing
@testable import BoringTracker

@Suite("Number input")
struct NumberInputTests {

    let us = Locale(identifier: "en_US")
    let de = Locale(identifier: "de_DE")

    @Test("Plain numbers")
    func plainNumbers() {
        #expect(NumberInput.parse("250", locale: us) == 250)
        #expect(NumberInput.parse("78.4", locale: us) == 78.4)
        #expect(NumberInput.parse("0", locale: us) == 0)
        #expect(NumberInput.parse("-1.5", locale: us) == -1.5)
    }

    @Test("A grouping separator is not a decimal point")
    func groupingIsNotDecimal() {
        // The one that matters: getting this wrong turns a 1,250 kcal dinner
        // into 1.25 without anything looking wrong.
        #expect(NumberInput.parse("1,250", locale: us) == 1250)
        #expect(NumberInput.parse("1.250", locale: de) == 1250)
        #expect(NumberInput.parse("1,5", locale: de) == 1.5)
        #expect(NumberInput.parse("1 250,5", locale: de) == 1250.5)
    }

    @Test("Nothing to parse is nothing, not zero")
    func emptyIsNil() {
        #expect(NumberInput.parse("", locale: us) == nil)
        #expect(NumberInput.parse("   ", locale: us) == nil)
        #expect(NumberInput.parse(".", locale: us) == nil)
        #expect(NumberInput.parse("-", locale: us) == nil)
    }

    @Test("Half-typed input still reads as a number")
    func partialInput() {
        #expect(NumberInput.parse("78.", locale: us) == 78)
        #expect(NumberInput.parse(".5", locale: us) == 0.5)
        #expect(NumberInput.parse("5..5", locale: us) == 5.5)
    }

    @Test("The pad types what the region types")
    func padTypesLocaleSeparator() {
        #expect(NumberInput.appending("1", to: "", locale: us) == "1")
        #expect(NumberInput.appending("5", to: "12", locale: us) == "125")
        #expect(NumberInput.appending(".", to: "1", locale: us) == "1.")
        #expect(NumberInput.appending(",", to: "1", locale: de) == "1,")
    }

    @Test("Either separator key means this region's separator")
    func hardwareSeparatorIsTranslated() {
        // The one that matters, and it is the grouping test above seen from
        // the other side: a hardware keyboard sends the key that is physically
        // on it. Appended verbatim in de_DE, "1.5" reads back through `parse`
        // as grouped thousands — 15 — while the field on screen says 1.5.
        #expect(NumberInput.appending(".", to: "1", locale: de) == "1,")
        #expect(NumberInput.parse(NumberInput.appending(".", to: "1", locale: de) + "5",
                                  locale: de) == 1.5)
        #expect(NumberInput.appending(",", to: "1", locale: us) == "1.")
        #expect(NumberInput.parse(NumberInput.appending(",", to: "1", locale: us) + "5",
                                  locale: us) == 1.5)
    }

    @Test("A second separator is not typeable")
    func oneSeparatorOnly() {
        #expect(NumberInput.appending(".", to: "1.5", locale: us) == "1.5")
        #expect(NumberInput.appending(",", to: "1,5", locale: de) == "1,5")
        // Including when it arrives wearing the other region's character.
        #expect(NumberInput.appending(",", to: "1.5", locale: us) == "1.5")
        #expect(NumberInput.appending(".", to: "1,5", locale: de) == "1,5")
        // Still one field, one separator, whichever end it was typed from.
        #expect(NumberInput.appending(".", to: ".", locale: us) == ".")
    }

    @Test("A key that is not part of a number is ignored")
    func strayKeysAreDropped() {
        // A hardware keyboard can send anything, and what it types is shown to
        // the user — so a stray key must not be able to put a character on
        // screen that `parse` will silently drop later.
        for key in ["a", "-", " ", "٥", "12", ""] {
            #expect(NumberInput.appending(key, to: "78", locale: us) == "78",
                    "\(key) should not be typeable")
        }
    }

    @Test("Typing does not quietly fix what you typed")
    func padDoesNotNormalise() {
        // A lone separator stays nothing, so Log stays disabled — inserting a
        // leading zero here would turn an empty field into a logged 0.
        #expect(NumberInput.parse(NumberInput.appending(".", to: "", locale: us),
                                  locale: us) == nil)
        // Leading zeros behave exactly as they did through a text field.
        #expect(NumberInput.appending("7", to: "00", locale: us) == "007")
        #expect(NumberInput.parse("007", locale: us) == 7)
    }

    @Test("Formatted output reads back as the same number", arguments: [
        Locale(identifier: "en_US"), Locale(identifier: "de_DE"), Locale(identifier: "fr_FR"),
    ])
    func editTextRoundTrips(locale: Locale) {
        let tracker = Tracker(name: "Weight", decimals: 1)
        for value in [0.0, 5, 78.4, -12.5, 1_250, 99_999.9] {
            let typed = tracker.editText(value, locale: locale)
            #expect(NumberInput.parse(typed, locale: locale) == value,
                    "\(value) formatted as \(typed)")
        }
    }
}
