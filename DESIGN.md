# SeedPod — Design Document

> Solid 2026 Hackathon · ANU Software Innovation Institute · July 2026

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
| State management | Provider + ChangeNotifier | Matches solidui's patterns; no external state libs |
| Local persistence | SharedPreferences | Module toggle state only — fast, no auth required |
| POD server | pods.d01.solidcommunity.au | Hackathon-dedicated ANU server |

---

## Data Philosophy

### Where data lives

Every piece of user data is stored on the user's own Solid POD as an encrypted file. There is no SeedPod backend database. The app is a pure client.

```
POD root/
  seedpod/
    profile.json.enc.ttl        — baby profile (name, DOB, sex)
    log_{timestamp}.json.enc.ttl — one file per log entry
    childcare_list.json.enc.ttl  — waitlist tracker entries (array)
```

All files use solidpod's `encrypted: true` flag. The `.ttl` suffix is required by solidpod's encryption mechanism; the content is JSON wrapped in Turtle.

### Why one file per log entry

Log entries are immutable events (feeding at 14:32, nappy at 15:10). Storing each as a separate file avoids read-modify-write races and makes partial reads cheap. solidpod's `getResources()` lists all files; we filter by filename prefix `log_` to find log entries.

### Why SharedPreferences for module state

Module preferences (which modules are on/off) do not need to be synced between devices right now, and they need to be readable before the user logs in (so the login screen can show the right nav). SharedPreferences is the right tool. If cross-device sync becomes important later, this can migrate to a POD file.

---

## Module System

### Philosophy

A newborn needs Feeding, Sleep and Growth tracking. A 6-month-old also needs Food Introduction. A Canberra family with a newborn probably already has a childcare application submitted. The module system lets parents activate what is relevant now, without cluttering the UI with things they do not need yet.

**Key design rule: all modules are available from birth.** "Suggested from X months" is a display hint only — parents decide. This matters particularly for Childcare in Canberra, where waitlists often start before the baby is born.

### How it works

`ModulePrefs` (in `lib/models/module_prefs.dart`) holds a `Set<String>` of enabled module IDs. It is stored in SharedPreferences under the key `module_enabled`. The `AppState` provider loads this on startup and exposes a `toggleModule(id)` method.

Two categories of modules:

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

| Module | ID | Default | Suggested from | What it tracks |
|---|---|---|---|---|
| Nappy Log | `nappy` | **On** | Birth | Wet / Dirty / Both / Dry |
| Medication | `medication` | Off | Birth | Drug name, dose, schedule |
| Doctor Visits | `appointment` | Off | Birth | GP / Paed / Specialist / Dentist / Emergency; clinic name |
| Health & Symptoms | `health` | **On** | Birth | Symptom or condition description |

### Development (optional)

| Module | ID | Default | Suggested from | What it tracks |
|---|---|---|---|---|
| Food Introduction | `food` | Off | 4+ months | First foods and allergy reactions (None / Mild / Severe) |
| Development Checklist | `development` | Off | Birth | ASQ-based structured screening |
| Baby Teeth | `teeth` | Off | 4+ months | Tooth eruption by position |
| Sleep Training | `sleep_training` | Off | Birth | Method name and nightly notes |

### Life Admin (optional)

| Module | ID | Default | Suggested from | What it tracks |
|---|---|---|---|---|
| Childcare & Schools | `childcare` | **On** | Birth | Waitlist entries: centre, suburb, type, status, fee, desired start |
| Government Benefits | `benefits` | Off | Birth | CCS, FTB, Parenting Payment application status |
| Birth Admin | `birth_admin` | **On** | Birth | Checklist: birth certificate, Medicare, myGov, passport |
| Contacts & Carers | `contacts` | Off | Birth | Authorised carers, emergency contacts, healthcare providers |

### Memories (optional)

| Module | ID | Default | Suggested from | What it tracks |
|---|---|---|---|---|
| Memories & Journal | `memory` | Off | Birth | Free-form journal entries |
| Environment | `environment` | Off | Birth | Room temperature, humidity, air quality |

**Summary: 5 core + 14 optional. 4 optional modules are on by default (Nappy, Childcare, Health, Birth Admin).**

---

## Key Screens

### Home
Dashboard showing baby's name, age, POD server pill, quick-action chips (Growth / Sleep / Feeding / Milestone), and today's log entries as cards. Pull-to-refresh reloads from POD.

### Quick Log
Bottom sheet. Type grid filtered by enabled modules. Each type shows a purpose-built form (e.g. Feeding shows breast-side selector + duration; Nappy shows Wet/Dirty/Both/Dry chips; Food shows reaction severity). Saves as a new encrypted file on the POD.

### Timeline
Reverse-chronological list of all log entries across all types. Filtered by log type using a chip bar. Loads from POD on mount.

### Health
Three tabs:
- **Growth** — scatter plot with WHO P3/P50/P97 percentile bands. Uses `LayoutBuilder` to get real width before painting (fixed zero-width bug).
- **Vaccines** — ACT NIP 2025 schedule. Milestone cards with interactive checkboxes. Done state stored in SharedPreferences (`vax_M{mIdx}_V{vIdx}`). ACT-funded MenB flagged with orange chip.
- **Feeding** — last 10 feeding entries with side/duration for breast feeds.

### Childcare (when module is on)
Waitlist tracker. Add/edit/remove centres with: name, suburb, type (Long Day Care / Family Day Care / OSHC / Public / Catholic / Independent School), status (applied → waitlisted → offered → enrolled → declined), daily fee, waitlist position, desired start date, notes. Status badge uses colour coding. Saved as a JSON array to the POD.

### Modules
Toggle panel. Core modules shown as read-only chips. Optional modules listed by category with a Switch. Toggling immediately updates SharedPreferences and re-renders the Quick Log grid and nav.

### Share
Displays the user's WebID with a copy button. Collapsible 4-step explainer of Solid sharing. `GrantPermissionUi` widget handles the actual ACL grant — the user enters another person's WebID and selects which POD resources to share.

---

## Solid Sharing Model

SeedPod does not have a server to manage permissions. Sharing is done directly POD-to-POD via Solid ACL:

1. Parent copies their WebID (e.g. `https://pods.d01.solidcommunity.au/alice/profile/card#me`)
2. Parent opens Share screen and uses `GrantPermissionUi` to select resources and enter the carer's WebID
3. solidpod writes an ACL file on the parent's POD granting the carer read access
4. The carer opens SeedPod with their own login and navigates to the shared resource — they see the parent's data because the ACL permits it

No SeedPod account or invite system is needed. Access is controlled entirely by the data owner via their POD.

---

## Deployment

The app is a static Flutter Web build served from GitHub Pages:

- **URL**: https://yidingqiu.github.io/seedpod/
- **Client profile**: https://yidingqiu.github.io/seedpod/solid/client-profile.jsonld
- **Redirect handler**: https://yidingqiu.github.io/seedpod/solid/redirect.html
- **POD server**: https://pods.d01.solidcommunity.au (hackathon server)

Local `flutter run -d chrome` works for UI development but cannot complete Solid login (BroadcastChannel cross-origin constraint). Login testing requires the deployed GitHub Pages URL.

---

## What is not built yet

- Development Checklist screen (module exists, no dedicated screen — falls back to Quick Log note)
- Government Benefits screen (same)
- Birth Admin checklist screen (same)
- Contacts & Carers screen (same)
- Photo/media attachment (Quick Log has a Photo type stub)
- Cross-device module sync (currently SharedPreferences only)
- Push notifications or reminders
