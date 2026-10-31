# Watch and notifications

*Deutsch: [Beobachtung und Mitteilungen](../../handbuch/07-beobachtung.md)*

The inventory shows what is there now. The **watch** tells you when that changes: when something
new wants to start automatically or an existing entry changes — for example because an installer
puts a service in place or an app sets itself up a background task.

The watch only reads. It prevents nothing, but reports what has happened; what you do then, you
decide in the entry's detail column.

## Turning it on

Two ways, both switch the same thing:

- In the sidebar under **Views**, click **Watch**, then flip the **Watch** switch at the top.
- In **Settings** (⌘,), section **Watch**: **Watch for new autostart entries**.

The watch is off by default. Once on, it stays on after a restart of the app as well. The first
time you turn it on, macOS asks whether LaunchKeeper may send notifications.

The **Notifications** switch next to it (in Settings: **Notify about new or changed entries**)
decides whether you get banners. Without it, the watch keeps collecting in its list.

## When it looks

| Trigger | What happens |
|---|---|
| An **autostart location is written** | LaunchKeeper waits for **5 seconds** of quiet (installers write in bursts) and then rescans |
| **Every ten minutes** | a full comparison — for whatever has no file that could be watched |
| **Every other scan** | ⌘R, ⇧⌘R, **Check now**, or the scan after an action are compared too — nothing is read twice |

Watched are the launch folders (`LaunchAgents`, `LaunchDaemons`), `/Library/PrivilegedHelperTools`,
`/Library/StartupItems`, `/Library/SystemExtensions`, the authorization plug-ins
(`/Library/Security/SecurityAgentPlugins`), `/etc/paths.d` and `/etc/manpaths.d`, the login
window settings (`com.apple.loginwindow.plist`), `/etc/crontab`, `/etc/rc.local`, the shell
startup files (`/etc/zshrc`, `/etc/profile`, `~/.zshrc`, `~/.zprofile`, and relatives), and the
top level of `/Applications` and `~/Applications`. Writes deep inside app bundles or in other
settings files trigger nothing.

If macOS cannot deliver the file events, only the ten-minute comparison runs; the status line
then says “every ten minutes only (file events unavailable)”.

### Background Task Management and Touch ID

Part of the inventory comes from macOS's **Background Task Management** (BTM for short: the login
items and “Allow in the Background”). Querying it fresh has a cost:

- **With the helper**, the helper reads it without asking. The ten-minute comparison then queries
  it fresh every time.
- **Without the helper**, macOS requires Touch ID or your password for every fresh query. That is
  why the ten-minute comparison then queries it fresh **at most every six hours** and otherwise
  compares against the state read last. A cancelled dialog counts as a query — otherwise it would
  come back every ten minutes.
- If the helper is set up but does not respond, LaunchKeeper takes the state read last instead of
  asking you — provided there already is one in this session; otherwise macOS asks. It then also
  waits six hours until the next attempt.

A scan triggered by a file change takes the last-read state of Background Task Management — a
cold query can take minutes. It reads the other sources fresh.

## What is reported — and what isn't

The first complete check after turning it on is the **baseline**; the status line then shows
“Active — watching N entries, last checked …”. Every further check is compared with the previous
one, entry by entry. Apple's entries and running network services are not part of this: a program
that is accepting connections right now is not a new autostart.

| Change | In the list | Notification |
|---|---|---|
| **New: …** | yes, orange | yes |
| **Changed: …** (with the fields that changed) | yes, blue | yes |
| **Removed: …** | yes, gray | no — what no longer starts is not a risk |
| own change, “by LaunchKeeper” | yes, gray | no |

**Own changes.** What LaunchKeeper changed itself at your click — a single action or a queue run —
appears in the list with “by LaunchKeeper” and is not reported. This also applies to differences
that show up up to **30 seconds** after the action ends: a scan that started before the action can
finish after it.

**Incomplete checks are not compared.** If a source did not respond — for example Background Task
Management after a timeout —, whole layers are missing. A comparison would then report nothing but
“Removed”. Instead the status line says “Last check incomplete, not compared: …”, and the baseline
stays as it was.

**Turning it off forgets the baseline.** If you turn the watch back on, the next complete check is
the new baseline — it does not report what happened in between.

## The list and the details

The **Watch** view lists the changes, newest at the top, at most 200. The number next to **Watch**
in the sidebar counts new and changed entries that did not come from LaunchKeeper itself. **Clear
list** clears the list; the log file (see below) stays.

Clicking a row shows on the right:

- **What** — **Category** (here as the core's raw value, for example `launch-items`), **Path**,
  **Identifier**, and for changes every field with its old and new value.
- **Noticed** — **When**, the **Trigger** (for example `fsevents: <path>` for a file change,
  `interval` for the ten-minute comparison, `manual rescan` for ⌘R), and the **Notification**
  line.
- **Show in inventory** — there you see what the entry is and what you can do. If it is gone, it
  says “The entry is not (or no longer) in the current inventory.”

### The “Notification” line

It only states what can be measured — what became of the notification for this entry:

| Text (examples) | Meaning |
|---|---|
| “none — LaunchKeeper made this change itself” | own change |
| “none — removals are only listed” | removal |
| “not sent: notifications are switched off in LaunchKeeper” | **Notifications** switch off |
| “not sent: macOS does not allow LaunchKeeper to notify (…)” | no permission in macOS |
| “refused by macOS: …” | macOS rejected the notification with an error |
| “handed to macOS at …; listed in the Notification Center.” | arrived |
| “handed to macOS at …; not in the Notification Center — already dismissed or held back by macOS.” | handed over, but not (or no longer) visible |
| “released for display at … (LaunchKeeper was in front; …)” | LaunchKeeper was in the foreground at the time |
| “shown and clicked at …” | you clicked it |
| “unknown (noticed before the app last started)” | from before the app last started |

Clicking a notification brings LaunchKeeper to the front and selects the entry — or, if it is gone,
the **Watch** view.

## Menu bar and launch at login

While the watch is running, there is an **eye in the menu bar**, even when no window is open. Its
menu shows “Watch active”, the last five third-party changes (a click opens the entry), **Open
LaunchKeeper**, **Turn off watch**, and **Quit LaunchKeeper**.

If you close the window, the app keeps watching. For it to do that after a restart of the Mac as
well, turn on **Launch at login** in Settings under **Watch**. LaunchKeeper then opens its window
at login; if you close it, the watch keeps running. If macOS requires approval, **Allow in System
Settings** appears.

## Checking notifications

If a notification is missing, the **Watch** section in Settings helps:

- **Notifications according to macOS** shows what macOS allows: “allowed”, “allowed, but without
  banners (style “None”)”, “not allowed”, or “not asked yet”. The line rereads the state when you
  come back from System Settings.
- **Send test notification** sends a notification “LaunchKeeper test” without anything having to
  change. Below it you see what became of it — the same texts as in the **Notification** line.
- **Ask for permission** appears as long as macOS has not asked yet.
- **Open notification settings** jumps to System Settings › Notifications › LaunchKeeper:
  permission, style, sound.

> **No banner although the notification was released?** While the screen is shared or mirrored —
> for example via Screen Sharing — macOS suppresses banners by default. Setting: System Settings ›
> Notifications › “When mirroring or sharing the display”. An active **Focus** also holds banners
> back. The notification is still listed in the Notification Center.

## The log shared with the command line

Every change the watch notices, LaunchKeeper appends as one JSON line to

```
~/Library/Logs/launchkeeper/watch.log
```

`launchkeeper watch` in Terminal ([chapter 10](10-command-line.md)) writes the same file, in the
same format. The app's own changes carry a marker there, so that they are recognized as “by
LaunchKeeper” even after a restart. At launch, the app reads the last 200 changes from this file
into its list — including those that `launchkeeper watch` recorded.

## Next

- [Chapter 8 — Quarantine and ways back](08-quarantine-and-undo.md)
