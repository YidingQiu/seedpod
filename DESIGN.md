# SeedPod — Design Document

> Solid 2026 Hackathon · ANU Software Innovation Institute · July 2026
> Last updated: Day 2 (2026-07-15)

---

## Concept

SeedPod is a **privacy-first baby lifecycle tracker** built on the Solid Protocol. All data belongs to the parent — stored encrypted on their personal Solid POD, not on any central server. The app covers the full early-life arc: from birth admin and feeding logs through childcare queues, school readiness and beyond.

The core insight is that parents accumulate fragmented records across apps, notebooks, and WhatsApp threads. SeedPod puts everything in one place, owned by the family, shareable on their terms.

---

## Technical Stack

| Layer | Choice | Reason |
|---|---|---|
| Language | Dart | Required by solidui/solidpod ecosystem |
| Framework | Flutter 3.44 (Web target) | Hackathon platform; Chrome demo |
| Solid library | solidpod 1.0.13 | POD read/write, auth, encryption |
| UI framework | solidui 1.0.18 | SolidScaffold, SolidLogin, nav patterns |
| State management | Provider + ChangeNotifier | Matches solidui patterns; no external state libs |
| Local persistence | SharedPreferences | Module toggles and vaccine checkbox state — fast, no auth required |
| POD server | pods.d01.solidcommunity.au | Hackathon-dedicated ANU server |
| CI/CD | GitHub Actions | Auto-build and deploy to GitHub Pages on every push to master |

---

## Data Philosophy

### Where data lives

Every piece of user data is stored on the user's own Solid POD as an encrypted file. There is no SeedPod backend database. The app is a pure client.

```
POD root/
  seedpod/
    data/
      babies.json.enc.ttl         — all baby profiles (JSON array)
      log_entries.json.enc.ttl    — all log entries (JSON array)
      childcare_list.json.enc.ttl — waitlist entries (JSON array)
```

All files use solidpod's `encrypted: true` flag. The `.enc.ttl` suffix is required by solidpod's encryption mechanism; the content is JSON wrapped in Turtle RDF.

Legacy paths (migration only, no longer written):
```
  seedpod/data/profile.json.enc.ttl  — original single-baby profile
```

### Why aggregated files, not one file per entry

Early in development we used one file per log entry and called `getResourcesInContainer()` to list them. This caused a critical bug: directory listing over HTTP to a Solid container fails silently under certain conditions (cross-origin timing, container not yet initialised), returning an empty list — which made all log entries appear to vanish on browser refresh.

The fix was to store all entries in a single well-known file and read it directly by filename. This is the same pattern solidpod uses for its own encryption key files. Read-modify-overwrite is atomic enough for single-user write patterns.

The same issue affected baby profiles when multi-baby support was added (using a `babies/` subdirectory with one file per baby). That was also fixed by switching to `babies.json.enc.ttl`.

**Rule: never use `getResourcesInContainer()` for app data. Always use a known filename.**

### Why SharedPreferences for module state

Module preferences (which modules are on/off) and vaccine checkbox state do not need to be synced between devices right now, and they need to be readable before the user logs in. SharedPreferences is the right tool. If cross-device sync becomes important later, this can migrate to a POD file.

---

## Multi-Baby Support

Each baby has a `BabyProfile` with a generated `id` (16-byte hex string). All profiles are stored as a JSON array in `babies.json.enc.ttl`.

```
BabyProfile {
  id:          String   // generated, e.g. "a3f8c2..."
  name:        String
  dateOfBirth: DateTime
  gender:      String?  // "Boy" | "Girl" | "Other"
  photoUrl:    String?  // reserved, not yet used
}
```

Each `LogEntry` carries a `babyId` field. When there is only one baby, legacy entries with `babyId: ""` are automatically assigned to that baby on first load (migration path in `PodService._assignLegacyLogsTo()`).

The home screen shows a baby selector dropdown. Switching babies filters the log display and quick-log target.

### Creating a new baby's Solid POD

When adding a new baby, the parent is prompted to create a dedicated Solid POD account for the baby before saving the profile. This uses `createAccountPopup()` from solidui, which calls the CSS v7 account management API (`createCssAccount`) — independent of the current login session, so no auth token is required.

The "Create Baby Profile" save button is gated: it remains disabled until `createAccountPopup` returns `true` (account created successfully). The baby's POD is a fully independent Solid account on `pods.d01.solidcommunity.au`.

When removing a baby, the confirmation dialog notes that the baby's Solid POD account is NOT deleted — only the profile and logs are removed from the parent's POD.

---

## Module System

### Philosophy

A newborn needs Feeding, Sleep and Growth tracking. A 6-month-old also needs Food Introduction. A Canberra family with a newborn probably already has a childcare application submitted. The module system lets parents activate what is relevant now, without cluttering the UI with things they do not need yet.

**Key design rule: all modules are available from birth.** "Suggested from X months" is a display hint only — parents decide. This matters particularly for Childcare in Canberra, where waitlists often start before the baby is born.

### How it works

`ModulePrefs` (in `lib/models/module_prefs.dart`) holds a `Set<String>` of enabled module IDs. It is stored in SharedPreferences under the key `module_enabled`. The `AppState` provider loads this on startup and exposes a `toggleModule(id)` method.

Two categories:

- **Core** — always enabled, cannot be toggled. Hardcoded in `_coreIds`.
- **Optional** — user-controlled. Persisted to SharedPreferences on every toggle.

```
isEnabled(id) = _coreIds.contains(id) || _enabled.contains(id)
```

### Effect on the UI

| Surface | Behaviour |
|---|---|
| Quick Log type grid | Only shows tiles for enabled modules |
| Sidebar nav | Childcare screen appears only when `childcare` module is on |
| Modules screen | Always visible; shows all optional modules grouped by category |

---

## Module Catalogue

### Core (always on)

| Module | ID | What it tracks |
|---|---|---|
| Feeding | `feeding` | Breast (side + duration), bottle, formula, solids |
| Sleep | `sleep` | Start/end times, session duration |
| Growth | `growth` | Weight (kg) and height (cm), plotted on WHO P3/P50/P97 bands |
| Vaccines | `vaccines` | ACT NIP 2025 schedule with interactive checkboxes; ACT-funded MenB flagged |
| Milestones | `milestone` | Named developmental moments |

### Daily Care (optional)

| Module | ID | Default | What it tracks |
|---|---|---|---|
| Nappy Log | `nappy` | **On** | Wet / Dirty / Both / Dry |
| Medication | `medication` | Off | Drug name, dose, schedule |
| Doctor Visits | `appointment` | Off | GP / Paed / Specialist / Dentist / Emergency; clinic name |
| Health & Symptoms | `health` | **On** | Symptom or condition description |

### Development (optional)

| Module | ID | Default | What it tracks |
|---|---|---|---|
| Food Introduction | `food` | Off | First foods and allergy reactions (None / Mild / Severe) |
| Development Checklist | `development` | Off | ASQ-based structured screening |
| Baby Teeth | `teeth` | Off | Tooth eruption by position |
| Sleep Training | `sleep_training` | Off | Method name and nightly notes |

### Life Admin (optional)

| Module | ID | Default | What it tracks |
|---|---|---|---|
| Childcare & Schools | `childcare` | **On** | Waitlist entries: centre, suburb, type, status, fee, desired start |
| Government Benefits | `benefits` | Off | CCS, FTB, Parenting Payment application status |
| Birth Admin | `birth_admin` | **On** | Checklist: birth certificate, Medicare, myGov, passport |
| Contacts & Carers | `contacts` | Off | Authorised carers, emergency contacts, healthcare providers |

### Memories (optional)

| Module | ID | Default | What it tracks |
|---|---|---|---|
| Memories & Journal | `memory` | Off | Free-form journal entries |
| Environment | `environment` | Off | Room temperature, humidity, air quality |

**Summary: 5 core + 14 optional. 4 optional modules are on by default (Nappy, Childcare, Health, Birth Admin).**

---

## Key Screens

### Home (current)

Baby selector dropdown + Add Baby button. Baby profile card (name, age, POD server pill). Quick-action chip grid (filtered by enabled modules). Today's log entries as scrollable cards with edit button. Pull-to-refresh reloads from POD.

### Home (planned — 24h Dashboard)

Replace "Today's Log" header section with a 24-hour summary dashboard:

- **Three stat cards**: total milk (ml), nappy count, total sleep (h) — all computed from log entries in the past 24 rolling hours
- **Feeding timeline bar**: hourly buckets across 24h rendered as a row of `Container` widgets, no chart package needed
- **Compact log list** below the cards (scrollable, keeps the detail)

This was proposed based on user feedback: parents want to see the baby's current status at a glance, not just a chronological list. The dashboard makes SeedPod more useful than a phone memo app. Implementation is pending mock data from the team.

### Quick Log

Bottom sheet. Type grid filtered by enabled modules. Each type shows a purpose-built form:
- Feeding: breast-side selector + duration, or bottle amount + type
- Nappy: Wet/Dirty/Both/Dry chips
- Sleep: start/end time pickers
- Food: food name + reaction severity
- Medication: drug name + dose + unit
- (and all other log types)

Supports both create and edit mode. In edit mode, the sheet pre-populates from the existing `LogEntry` and calls `updateLog()` instead of `writeLogEntry()`.

### Timeline

Reverse-chronological list of all log entries. Filtered by log type using a chip bar. Tap any entry to edit via Quick Log sheet. Loads from `log_entries.json.enc.ttl` on mount.

### Health

Three tabs:
- **Growth** — scatter plot with WHO P3/P50/P97 percentile bands, using `LayoutBuilder` to get real width before painting
- **Vaccines** — ACT NIP 2025 schedule with interactive checkboxes; done state in SharedPreferences; ACT-funded MenB flagged with orange chip
- **Feeding** — last 10 feeding entries showing type, amount, duration

### Childcare (when module is on)

Waitlist tracker. Add/edit/remove centres with: name, suburb, type (Long Day Care / Family Day Care / OSHC / Public / Catholic / Independent School), status (applied → waitlisted → offered → enrolled → declined), daily fee, waitlist position, desired start date, notes. Status badge colour-coded. Saved as a JSON array to the POD.

### Modules

Toggle panel. Core modules shown as read-only chips. Optional modules listed by category with a Switch. Toggling immediately updates SharedPreferences and re-renders the Quick Log grid and nav.

### Share

Displays the user's WebID with a copy button. Collapsible 4-step explainer of Solid sharing. `GrantPermissionUi` widget handles ACL grants — the user enters another person's WebID and selects which POD resources to share.

---

## Import / Export

Log entries can be exported and imported via the home screen overflow menu (top-right `···`):

| Format | Export | Import |
|---|---|---|
| JSON | Full `LogEntry` array as JSON | Parse and merge with existing entries |
| CSV | Flat rows: id, babyId, type, timestamp, data fields | Parse and merge |

Export writes to the browser's download mechanism. Import reads from a file picker. Implemented in `lib/services/log_transfer.dart`.

---

## Solid Sharing Model

SeedPod does not have a server to manage permissions. Sharing is done directly POD-to-POD via Solid ACL:

1. Parent copies their WebID (e.g. `https://pods.d01.solidcommunity.au/alice/profile/card#me`)
2. Parent opens Share screen and uses `GrantPermissionUi` to select resources and enter the carer's WebID
3. solidpod writes an ACL file on the parent's POD granting the carer read access
4. The carer opens SeedPod with their own login and navigates to the shared resource

No SeedPod account or invite system is needed. Access is controlled entirely by the data owner.

---

## Deployment

The app is a static Flutter Web build served from GitHub Pages:

- **URL**: https://yidingqiu.github.io/seedpod/
- **Client profile**: https://yidingqiu.github.io/seedpod/solid/client-profile.jsonld
- **Redirect handler**: https://yidingqiu.github.io/seedpod/solid/redirect.html
- **POD server**: https://pods.d01.solidcommunity.au (hackathon server)

**Deployment is automatic.** A GitHub Actions workflow (`.github/workflows/deploy.yml`) builds on every push to master and commits the output to `docs/`. Contributors only need to push source code. Build time is approximately 3–4 minutes.

Local `flutter run -d chrome` works for UI development but cannot complete Solid login (BroadcastChannel cross-origin constraint). Login and POD read/write testing requires the deployed GitHub Pages URL.

---

## What is not built yet

| Feature | Notes |
|---|---|
| 24h dashboard | Designed (see Home planned section above); pending mock data |
| Development Checklist screen | Module exists; falls back to Quick Log note |
| Government Benefits screen | Module exists; no dedicated screen |
| Birth Admin checklist screen | Module exists; no dedicated screen |
| Contacts & Carers screen | Module exists; no dedicated screen |
| Photo/media attachment | `LogType.photo` stub exists in Quick Log |
| Cross-device module sync | Currently SharedPreferences (device-local) only |
| Push notifications / reminders | Out of scope for hackathon |
| Baby POD data writing | Baby POD is created but app writes to parent's POD only |
