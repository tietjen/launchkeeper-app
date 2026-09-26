//
//  Updater.swift
//  LaunchKeeper — in-app updates via Sparkle (Phase 8).
//
//  The feed is the appcast.xml of the latest GitHub release; every DMG in
//  it carries an EdDSA signature that Sparkle checks against the public key
//  in Info.plist (SUPublicEDKey) before anything is installed. The update
//  replaces the whole bundle — the privileged helper inside it included;
//  launchd starts the new helper after the old one's idle exit, and the app
//  refuses to talk to a helper of another version until then.
//

import SwiftUI
import Sparkle

/// Owns Sparkle's updater for the app's lifetime.
///
/// Started only when the app runs from a bundle that names a feed — a
/// `swift run` build has neither, and Sparkle would complain on every launch.
@MainActor
final class Updater {
    /// Sparkle's standard controller (its own dialogs, scheduled checks).
    let controller: SPUStandardUpdaterController?

    init() {
        let configured = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") != nil
        controller = configured
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
    }

    /// The underlying updater, when running from a configured bundle.
    var updater: SPUUpdater? { controller?.updater }
}

/// Observes whether a check may start now (not while one is running).
@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    private var observation: NSKeyValueObservation?

    init(updater: SPUUpdater?) {
        // The value travels in the change record — the updater itself is
        // main-actor isolated and must not be read from the KVO closure.
        observation = updater?.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, change in
            let value = change.newValue ?? false
            Task { @MainActor in self?.canCheckForUpdates = value }
        }
    }
}

/// Menu item "Nach Updates suchen…" (in the app menu).
struct CheckForUpdatesView: View {
    @ObservedObject private var model: CheckForUpdatesViewModel
    private let updater: SPUUpdater?

    init(updater: SPUUpdater?) {
        self.updater = updater
        model = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Nach Updates suchen …") { updater?.checkForUpdates() }
            .disabled(updater == nil || !model.canCheckForUpdates)
    }
}

/// Settings section: automatic checks and the installed version.
struct UpdateSettingsSection: View {
    let updater: SPUUpdater?
    @State private var automatic = false

    var body: some View {
        Section("Updates") {
            LabeledContent("Version", value: Self.versionText)
            if let updater {
                Toggle("Automatisch nach Updates suchen", isOn: $automatic)
                    .onAppear { automatic = updater.automaticallyChecksForUpdates }
                    .onChange(of: automatic) { _, value in updater.automaticallyChecksForUpdates = value }
                Text("Updates werden vor der Installation gegen LaunchKeepers Signaturschlüssel geprüft. Das Hilfsprogramm kommt mit dem Update und startet nach einer Minute Leerlauf in der neuen Version.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Jetzt nach Updates suchen") { updater.checkForUpdates() }
            } else {
                Text("Updates sind nur in der installierten App verfügbar.").foregroundStyle(.secondary)
            }
        }
    }

    /// "0.1.0 (Build 42)" from the bundle.
    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (Build \(build))"
    }
}
