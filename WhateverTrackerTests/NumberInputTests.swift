import Foundation
import Testing
@testable import WhateverTracker

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
