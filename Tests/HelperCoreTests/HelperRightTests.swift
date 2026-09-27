//
//  HelperRightTests.swift
//  HelperCoreTests — the authorization right carries its prompt per language.
//

import XCTest
import HelperShared

final class HelperRightTests: XCTestCase {
    func testPromptInEveryLanguageAndAFallback() {
        XCTAssertEqual(Set(HelperRight.prompts.keys), ["", "en", "de"])
        XCTAssertEqual(HelperRight.defaultPrompt, HelperRight.prompts["en"], "the fallback is English")
        // The rule itself carries the prompts — the helper has no localization bundle.
        XCTAssertEqual(HelperRight.definition["default-prompt"] as? [String: String], HelperRight.prompts)
        XCTAssertEqual(HelperRight.definition["timeout"] as? Int, 0, "every execution asks again")
    }
}
