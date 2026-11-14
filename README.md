# Momentum

A native macOS personal manager, built for one problem: *you forget things and miss deadlines
because you're running several projects at once.* Everything in it points at that.

Built with SwiftUI. No Xcode needed — it compiles with the Command Line Tools you already have.

## Build and run

```bash
./build.sh
```

That compiles the app, builds the icon, ad-hoc signs it, and installs it to
`/Applications/Momentum.app` — quitting and relaunching the running copy if there is one.
The install only happens when the compile succeeded, so a broken build can never replace a
working app. To build without touching the installed copy:

```bash
./build.sh --no-install
```

Add it to **System Settings → General → Login Items** so the menu bar counter and the global
capture hotkey are always available.

## What's in it

**Categories.** Every new task asks what it is, and the answer changes how it behaves:

| Category | Means | What it does |
|---|---|---|
| **Project** | Multi-step, over days | Gets a start and a due date, so it draws as a bar on the timeline |
| **Learning** | Ongoing, no deadline | Starts as in-progress, no deadline pressure |
| **Event** | Happens on one day | Date only, no span — a diamond milestone on the timeline |
| **Task** | A single thing to do | Plain, just a due date if you gave one |

The palette pre-selects a guess (a time of day → Event, "learn/read/course/study" → Learning,
a long estimate → Project); click another if it guessed wrong. Change it later from the inspector
or by right-clicking a task → Category.

**Structure**

- **Projects** → **Tasks** → **Checkpoints** (small steps, each with its own optional date)
- **Pages** attached to any task — Markdown, with live preview. For meeting notes, research, drafts.
- **Tags**, colour-coded and shared across projects
- **Custom fields** per project (text, number, link, date, dropdown). The sample *Job applications*
  project has Company / Job link / Salary / Stage — right-click a project to edit its fields.
- **Dependencies**: "this can't start until that's done". Cycles are rejected automatically.

**Four views over the same data** (switcher top right, or ⌥⌘L / ⌥⌘B / ⌥⌘K / ⌥⌘G)

| View | What it gives you |
|---|---|
| **List** | Today's hero screen: overdue, due today, checkpoints due, in progress, next 7 days. Elsewhere it groups by deadline horizon. |
| **Board** | Kanban by status. Drag cards between columns. |
| **Calendar** | Month grid. Drag a task to another day to reschedule it; the side panel shows that day and lets you add to it. |
| **Timeline** | Gantt. Bars fill with checkpoint progress, dependency arrows curve between tasks (red and dashed when a prerequisite finishes too late), dashed line for today. Drag a bar to move it, drag its edges to resize. Slider top left zooms. |

**The anti-forgetting machinery**

- **Menu bar counter** — overdue + due today, visible without opening the app. Click it for the list,
  tick things off, or quick-capture from there.
- **Notifications** — the evening before (19:00), the morning of (09:00), an hour before a timed
  deadline, plus checkpoint deadlines. A daily review nudge at 08:30.
  macOS will ask permission the first time; say yes or it can't remind you.
- **Global capture hotkey** — **⌃⌥Space** from *any* app, without switching to Momentum first.
  It brings the window forward with the capture box open and focused. Change it under
  **Momentum → Global Capture Hotkey** (⌃⌥Space, ⌃⌥N, ⌃⇧Space, ⌥Space, or Off); the choice is
  remembered. If another app already owns the combination, the menu says so — pick a different one.
  It uses Carbon hotkey registration, so it needs **no Accessibility permission**, but Momentum
  has to be running (hence the Login Items step above).
- **Quick capture inside the app** — ⌘N or ⌘⇧Space.

**Natural language in the quick-add box.** Type it as one line:

```
Send CV to Erste fri 5pm #jobs @finaustria !high ~2h
```

| Pattern | Meaning |
|---|---|
| `today` `tomorrow` `tonight` `eod` `eow` | relative dates |
| `mon`…`sun`, `next tue`, `next week` | weekdays |
| `in 3 days`, `in 2 weeks` | offsets |
| `12 dec`, `dec 12`, `12/06` | explicit dates |
| `5pm`, `17:30`, `noon` | times |
| `#tag` | tag (created if new) |
| `@project` | project, matched by prefix |
| `!high` `!med` `!low` (or `p1` `p2` `p3`) | priority |
| `~2h` `~90m` | time estimate |

The strip under the field shows what it understood before you hit Enter. It also works in the
checkpoint field, so "Proofread fri" dates the checkpoint.

## Keyboard

| | |
|---|---|
| **⌃⌥Space** | **Capture from any app** (system-wide) |
| ⌘N / ⌘⇧Space | New task / quick capture (inside the app) |
| ⌘1 ⌘2 ⌘3 | Today / Upcoming / All |
| ⌥⌘L ⌥⌘B ⌥⌘K ⌥⌘G | List / Board / Calendar / Timeline |
| ⌘⇧D | Show completed |
| ⌘↵ | Mark selected task done |
| ⌘⌫ | Delete selected task |
| Esc | Close the inspector |

## Your data

One JSON file, written atomically, no cloud, no account:

```
~/Library/Application Support/Momentum/store.json
```

**Momentum → Reveal Data File in Finder** opens it. Back it up by copying that file, or put the
folder in iCloud Drive / Dropbox if you want it on another Mac.

The app ships with sample data so the views aren't empty. **Momentum → Remove Sample Data**
wipes it when you're ready to use it for real.

## Layout

```
Sources/
  Model.swift          types: Project, Item, Checkpoint, Page, Tag, FieldDef
  Store.swift          AppStore: state, persistence, queries, mutations, sample data
  Theme.swift          colours (light + dark), fonts, motion, date formatting
  Components.swift     checkboxes, chips, pills, rings, bars, buttons, empty states
  TaskRow.swift        the main list row, with inline checkpoint expansion
  Sidebar.swift        navigation, projects, tags, project editor sheet
  TodayView.swift      the home screen
  MainContent.swift    top bar + grouped list
  BoardView.swift      kanban with drag and drop
  CalendarView.swift   month grid, day panel, drag to reschedule
  GanttView.swift      timeline: bars, dependencies, drag and resize
  DetailView.swift     the inspector: checkpoints, tags, fields, dependencies
  Pages.swift          page cards + Markdown renderer
  QuickAdd.swift       the capture palette
  NaturalLanguage.swift  the date/tag/priority parser
  Reminders.swift      notification scheduling
  GlobalHotkey.swift   system-wide capture hotkey (Carbon), window focusing
  App.swift            scenes, menu bar extra, menus and shortcuts
tools/MakeIcon.swift   draws the app icon at build time
build.sh               compiles, bundles, makes the icon, ad-hoc signs
```

## Notes and limits

- macOS 13+, builds for whichever architecture you're on.
- Ad-hoc signed, so it's yours alone — macOS may ask you to confirm the first launch
  (right-click → Open if it does).
- Storage is a JSON file. Fine for thousands of tasks; if it ever gets slow, the swap to SQLite
  only touches `Store.swift`.
- `MOMENTUM_ROUTE` / `MOMENTUM_MODE` / `MOMENTUM_SELECT` / `MOMENTUM_QUICKADD` environment
  variables pick the starting view, and `MOMENTUM_HOTKEY_TEST=1` prints whether the global
  hotkey registered — handy for testing.
- The global hotkey only works while the app is running; quitting it releases the combination.

## Worth adding next

1. EventKit, to show your Apple/Outlook calendar events next to your tasks.
2. Recurring tasks ("every Monday").
3. An iPhone companion — the model is plain Codable, so it would port cleanly.

## Working on it

```
~/projects/Momentum        the source, under git
/Applications/Momentum.app the app you actually run (installed by build.sh)
~/Library/Application Support/Momentum/store.json   your tasks
```

Your data lives outside both the source folder and the app bundle, so rebuilding, reinstalling
or deleting the app never touches it.

Normal loop: edit something in `Sources/`, run `./build.sh`, try it, then
`git add -A && git commit` when it's worth keeping. `git log` is your undo history; `build/` is
ignored because it's regenerated every time.
