//
//  ToolbarIcon.swift
//  LaunchKeeper — LaunchKeeper's own toolbar icons (Basic/Expert mode,
//  Apple entries hidden/shown).
//

import SwiftUI
import AppKit

/// The app's own toolbar icons, one per state of a toolbar toggle.
///
/// The icons are plain PNG resources (`Name.png`, `@2x`, `@3x`) instead of an
/// asset catalog, because `swift build` does not compile `.xcassets`.
/// `Bundle.image(forResource:)` combines the scale variants into one
/// multi-resolution `NSImage`, so the toolbar picks the sharp one.
enum ToolbarIcon: String, CaseIterable {
    /// Basic mode: short summary and next steps.
    case basicMode = "BasicMode"
    /// Expert mode: every detail.
    case expertMode = "ExpertMode"
    /// Apple-signed entries are hidden (the default).
    case appleSignedHidden = "AppleSignedHidden"
    /// Apple-signed entries are shown.
    case appleSignedShown = "AppleSignedShown"

    /// The icon for the detail mode that is active.
    static func mode(expert: Bool) -> ToolbarIcon { expert ? .expertMode : .basicMode }

    /// The icon for the Apple filter that is active.
    static func apple(hidden: Bool) -> ToolbarIcon { hidden ? .appleSignedHidden : .appleSignedShown }

    /// The icon as a SwiftUI image at toolbar size.
    ///
    /// Falls back to a comparable SF Symbol when the resource is missing
    /// (e.g. a broken bundle), so the toolbar never shows an empty button.
    var image: Image {
        guard let image = Bundle.module.image(forResource: rawValue) else {
            return Image(systemName: fallbackSymbol)
        }
        // The colours are part of the design: not a template image.
        image.isTemplate = false
        return Image(nsImage: image)
    }

    /// SF Symbol used when the PNG cannot be loaded.
    private var fallbackSymbol: String {
        switch self {
        case .basicMode: "list.bullet"
        case .expertMode: "list.bullet.rectangle"
        case .appleSignedHidden: "eye.slash"
        case .appleSignedShown: "eye"
        }
    }
}
