# Changelog

All notable changes to the LaunchKeeper app are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The engine
underneath is [launchkeeper](https://github.com/tietjen/launchkeeper)
(`LaunchKeeperKit`); its changes are listed there.

## [0.1.0] — 2026-09-26

First public test release.

### Added
- Inventory of everything that starts automatically (LaunchAgents/Daemons,
  login items, extensions, helpers, cron, shell startup, network listeners,
  profiles …) with categories, search, badges and an Apple filter.
- Basic and expert detail view: what an entry is, whether it runs, who signed
  it, where it came from, what it really executes — and the next steps.
- Dedicated views: background items (as in System Settings), installer
  packages, leftovers of removed apps, the quarantine, the watch.
- Actions with a plan first and verification after: disable/enable, move
  leftovers and working launch plists into the quarantine, restore, uninstall
  packages — the same gate as the CLI, no bypass.
- Privileged helper (SMAppService) for administrator steps: Touch ID or
  password each time, only "operation + entry", never commands.
- Watch: file-system events and a periodic full check report new or changed
  entries as notifications; LaunchKeeper's own changes are labelled, not
  notified. Menu-bar item while watching, optional launch at login.
- "Copy hash for VirusTotal" for programs (no upload, no network).
- In-app updates via Sparkle (EdDSA-signed, notarized DMGs from GitHub).
