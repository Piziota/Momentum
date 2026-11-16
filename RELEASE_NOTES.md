Momentum is a native macOS personal manager for people running several things at
once — built around one problem: things get forgotten, and deadlines slip past.

## Install

1. Download `Momentum-1.0-macos.zip` below, unzip it, drag **Momentum.app** to
   your **Applications** folder.
2. Double-click it. macOS will say it *can't be opened because Apple cannot
   check it for malicious software* — click **Done**.
3. Open **System Settings → Privacy & Security**, scroll to **Security** at the
   bottom, and click **Open Anyway**.

That third step is a one-time thing. The app is signed, but not *notarized* —
notarization needs a paid Apple Developer account. Everything here is open
source if you would rather build it yourself: `./build.sh` needs only the
Command Line Tools and takes about a minute.

Universal binary — runs natively on both Apple Silicon and Intel.
Requires macOS 13 (Ventura) or later.

## What it does

- **Tasks that break into checkpoints**, with progress derived from what's
  actually done rather than a number you type
- **Four views over the same data** — today's list, a kanban board, a month
  calendar, and a Gantt timeline you can drag
- **Categories** — a project, something you're learning and a one-day event
  each behave differently
- **A Learning shelf** for topics and the links you collect under them
- **Pages, tags, custom fields and dependencies**
- **A menu bar counter**, so the number is visible without opening anything
- **Reminders** the evening before, the morning of, and an hour before a timed
  deadline
- **⌃⌥Space from any app** to capture in about two seconds — type
  `Data Viz exam on 20 Nov #uni !high` and it files itself, or pick the date
  and time from the capture box
- **Bright and dark themes**, or follow the system

## Your data

One JSON file in `~/Library/Application Support/Momentum/`. No account, no
cloud, no telemetry, nothing to sign up for. Deleting the app never touches it.

## Known limits

- Single user, single Mac — no sync and no sharing
- No recurring tasks yet
- Not notarized, hence the one-time step above
