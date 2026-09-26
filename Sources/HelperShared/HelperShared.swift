//
//  HelperShared.swift
//  HelperShared — everything app and privileged helper must agree on:
//  identities, code-signing requirements, the authorization right, the XPC
//  interface and the request/response types.
//
//  Kept in one small module without dependencies so both sides compile the
//  exact same definitions.
//

import Foundation

// MARK: - Identities

/// Bundle ids, team and the requirements each side demands of the other.
public enum HelperIdentity {
    /// The app's bundle identifier.
    public static let appBundleID = "de.paranoidsecurity.LaunchKeeper"
    /// The helper's code-signing identifier; also its launchd label and Mach service name.
    public static let helperID = "de.paranoidsecurity.LaunchKeeper.Helper"
    /// The launchd plist inside the app bundle (`Contents/Library/LaunchDaemons/`).
    public static let daemonPlistName = helperID + ".plist"
    /// Apple Developer team that signs both.
    public static let teamID = "Y2LTPLFG6D"
    /// The helper protocol/build version. Compiled into both sides: the app
    /// compares it with what the running helper reports and asks for a
    /// restart of the helper when they differ.
    public static let version = "0.1.2"

    /// What the helper demands of a connecting client: the LaunchKeeper app,
    /// signed by this team with an Apple-issued (Developer ID) certificate.
    /// Any other process — even one running as the same user — is refused.
    public static let clientRequirement =
        "anchor apple generic and identifier \"\(appBundleID)\" and certificate leaf[subject.OU] = \"\(teamID)\""

    /// What the app demands of the service it connects to: the genuine helper.
    public static let helperRequirement =
        "anchor apple generic and identifier \"\(helperID)\" and certificate leaf[subject.OU] = \"\(teamID)\""
}

// MARK: - Authorization right

/// The authorization right every privileged action needs.
///
/// A custom right (rather than `system.privilege.admin`) so the macOS dialog
/// says what LaunchKeeper wants, and so the rule can be strict: admin
/// credentials (Touch ID or password), not shared with other processes, and
/// no grace period — every execution asks again.
public enum HelperRight {
    /// The right's name in the authorization database.
    public static let name = "de.paranoidsecurity.LaunchKeeper.modify"

    /// The prompt macOS shows in the authentication dialog.
    public static let prompt = "LaunchKeeper möchte einen Autostart-Eintrag auf Systemebene ändern."

    /// The rule, modelled on `authenticate-admin-nonshared` with timeout 0.
    public static var definition: [String: Any] {
        [
            "class": "user",
            "group": "admin",
            "authenticate-user": true,
            "shared": false,
            "session-owner": false,
            "allow-root": false,
            "timeout": 0,
            "tries": 3,
            "comment": "Used by LaunchKeeper to change system-level startup items through its privileged helper.",
        ]
    }
}

// MARK: - XPC interface

/// The helper's XPC interface. Payloads are JSON (`PrivilegedRequest` in,
/// `PrivilegedOutcome` out) so both sides decode strictly typed values
/// instead of trusting loose Objective-C objects.
@objc public protocol LaunchKeeperHelperXPC {
    /// Executes one privileged action.
    /// - Parameters:
    ///   - request: JSON of a `PrivilegedRequest`.
    ///   - authorization: `AuthorizationExternalForm` bytes of an (empty)
    ///     authorization of the client. The helper asks for `HelperRight.name`
    ///     on it with interaction allowed — macOS shows Touch ID / password
    ///     in the client's session. (Apple's EvenBetterAuthorizationSample
    ///     pattern: the check happens once, where the action happens.)
    ///   - reply: JSON of a `PrivilegedOutcome`.
    func perform(_ request: Data, authorization: Data, reply: @escaping @Sendable (Data) -> Void)

    /// The helper's version — the app compares it with its own build.
    func version(reply: @escaping @Sendable (String) -> Void)
}

// MARK: - Request / response

/// One privileged action, as the app asks for it. Never a command line:
/// the helper resolves the target itself and runs its own gate and engines.
public struct PrivilegedRequest: Codable, Equatable, Sendable {
    /// What to do.
    public enum Kind: String, Codable, Sendable {
        /// `disable` / `enable` / `remove` of one inventory entry, by stable key.
        case disable, enable, remove
        /// `remove --working` (kit 0.10): disable a working entry and move its plist into the quarantine.
        case removeWorking = "remove-working"
        /// Move a quarantine entry back.
        case restore
        /// Delete a quarantine entry for good.
        case purge
        /// Uninstall a package by exact receipt id.
        case uninstall
    }

    /// What to do.
    public var kind: Kind
    /// Entry key, quarantine name or package id — depending on `kind`.
    public var target: String

    /// Creates a request.
    public init(kind: Kind, target: String) {
        self.kind = kind
        self.target = target
    }

    /// Rejects targets no legitimate request would carry, before any engine
    /// sees them: empty, overlong, control characters, a leading dash.
    /// The engines validate again (gate, exact resolution); this is the
    /// helper's own first line.
    /// - Returns: `nil` when acceptable, else the reason.
    public func validationError() -> String? {
        if target.isEmpty { return "empty target" }
        if target.utf8.count > 1024 { return "target too long" }
        if target.hasPrefix("-") { return "target looks like an option" }
        if target.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
            return "control characters in target"
        }
        return nil
    }
}

/// The helper's answer — mirrors the engines' result.
public struct PrivilegedOutcome: Codable, Equatable, Sendable {
    /// `done`, `failed`, `refused` (as the engines report them) or `error` (the helper itself).
    public var state: String
    /// Detail for `failed` / `refused` / `error`.
    public var detail: String?
    /// The executed plan: display form and description per step.
    public var steps: [[String]]
    /// The engine's notes.
    public var messages: [String]
    /// How to undo.
    public var undo: String?

    /// Creates an outcome.
    public init(state: String, detail: String? = nil, steps: [[String]] = [], messages: [String] = [],
                undo: String? = nil) {
        self.state = state; self.detail = detail; self.steps = steps; self.messages = messages; self.undo = undo
    }

    /// An error the helper reports before any engine ran.
    public static func error(_ detail: String) -> PrivilegedOutcome {
        PrivilegedOutcome(state: "error", detail: detail)
    }
}
