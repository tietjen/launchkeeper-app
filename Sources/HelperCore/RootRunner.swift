//
//  RootRunner.swift
//  HelperCore — runs the engines' commands inside the privileged helper.
//
//  The engines plan privileged steps as `/usr/bin/sudo <tool> …` (that is
//  how the CLI reaches root). The helper already runs as root: it executes
//  the tool directly — but only tools on a fixed list, resolved to fixed
//  absolute paths. Anything else is refused, whatever the plan says.
//

import Foundation
import LaunchKeeperKit

/// Executes planned commands as root, with `sudo` stripped and a tool allowlist.
public struct RootRunner: CommandRunner {
    /// Runs the resolved commands (tests inject a scripted runner).
    public let inner: CommandRunner

    /// The only tools a `sudo` step may name, and where they live.
    /// Mirrors what the engines plan: launchctl state changes, file moves and
    /// deletes, loginwindow defaults, receipts, checksums, the firewall.
    public static let allowedTools: [String: String] = [
        "launchctl": "/bin/launchctl", "/bin/launchctl": "/bin/launchctl",
        "rm": "/bin/rm", "/bin/rm": "/bin/rm",
        "cp": "/bin/cp", "/bin/cp": "/bin/cp",
        "/bin/mv": "/bin/mv", "/bin/mkdir": "/bin/mkdir",
        "defaults": "/usr/bin/defaults",
        "/usr/sbin/pkgutil": "/usr/sbin/pkgutil",
        "/usr/bin/cksum": "/usr/bin/cksum",
        "/usr/libexec/ApplicationFirewall/socketfilterfw": "/usr/libexec/ApplicationFirewall/socketfilterfw",
    ]

    /// Creates the runner.
    /// - Parameter inner: The runner that actually spawns processes.
    public init(inner: CommandRunner = SystemCommandRunner()) { self.inner = inner }

    /// Rewrites a planned command for execution as root.
    /// - Parameters:
    ///   - command: The planned executable.
    ///   - arguments: The planned arguments.
    /// - Returns: The command to run, `.skip` for sudo's own bookkeeping
    ///   (`sudo -v`), or `nil` when the step is not allowed.
    public static func resolve(command: String, arguments: [String]) -> Resolution? {
        guard command == "/usr/bin/sudo" else { return .run(command, arguments) }
        var args = arguments[...]
        if args == ["-v"] { return .skip }                   // refresh credentials: nothing to do as root
        if args.first == "-n" { args = args.dropFirst() }     // non-interactive flag
        guard let tool = args.first, let path = allowedTools[tool] else { return nil }
        return .run(path, Array(args.dropFirst()))
    }

    /// What `resolve` decided.
    public enum Resolution: Equatable {
        /// Run this executable with these arguments.
        case run(String, [String])
        /// Nothing to run; report success.
        case skip
    }

    public func run(command: String, arguments: [String], timeout: TimeInterval) -> CommandResult {
        switch Self.resolve(command: command, arguments: arguments) {
        case .run(let path, let args)?: return inner.run(command: path, arguments: args, timeout: timeout)
        case .skip?: return CommandResult(exitCode: 0, stdout: "", stderr: "")
        case nil:
            return CommandResult(exitCode: 126, stdout: "",
                                 stderr: "helper: \(arguments.first ?? command) is not on the helper's tool list")
        }
    }

    /// No terminal in a daemon: "interactive" steps run like any other.
    public func runInteractive(command: String, arguments: [String], timeout: TimeInterval) -> Int32 {
        run(command: command, arguments: arguments, timeout: timeout).exitCode
    }
}
