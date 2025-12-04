# Tamriel Calendar – Development Milestones

Tamriel Calendar is developed in structured phases to ensure stability, ESO API compliance, and clean UX on both PC and console.
Each milestone represents a functional layer of the addon, from core architecture through public release.

---

## ⭐ Milestone v0.1 — Core Infrastructure Foundation

### Goals
- Addon loads without errors
- Basic file/folder structure in place
- SavedVariables schema defined and initialized
- Date/time helper functions implemented using `os.date()` and `os.time()`
- Event data structure defined (ID, title, times, category, version, guildId)
- Event purge logic implemented (keep today → future only)
- Logging hooks via LibDebugLogger (optional)

### Deliverables
- `/TamrielCalendar.lua` initialized
- `/modules/EventManager.lua` baseline
- `/modules/DateHelpers.lua` complete
- `/SavedVariables/TamrielCalendar_SV.lua` template
- `/docs/PRD.md` included

---

## ⭐ Milestone v0.2 — Personal Events (CRUD)

### Goals
- Users can create, edit, and delete personal events
- StartTime < EndTime validation
- UI dialogs for event creation/editing
- Day View can render events
- Event purge logic confirmed working in UI
- Slash commands for quick testing (e.g., `/tamcal add`)

### Deliverables
- `/modules/UI_Dialogs.lua`
- `/modules/UI_DayView.lua`
- Personal event storage working end-to-end
- Example personal events load & display

---

## ⭐ Milestone v0.3 — Guild Sync (LAM2 Protocol)

### Goals
- Guild subscription system added
- Refresh button implemented
- `TAMC_REQUEST_EVENTS` + `TAMC_PUSH_EVENT` implemented
- Event serialization via LibSerialize + LibDeflate
- Only today → future events synchronized
- Version-based conflict resolution (newest wins)
- Guild event rendering in Day & Week views

### Deliverables
- `/modules/SyncManager.lua` functional
- `/modules/SettingsPanel.lua` with guild dropdown + subscribe toggle
- Guild event round-trip from one player to another

---

## ⭐ Milestone v0.4 — Week & Month UI Rendering + UX Polish

### Goals
- Fully functional Week View UI
- Fully functional Month View UI
- Paging (previous/next week/month)
- Always reset to Today when calendar opens
- Hover tooltips for events
- Color-coded categories using LibMediaProvider
- Performance improvements for event rendering

### Deliverables
- `/modules/UI_WeekView.lua`
- `/modules/UI_MonthView.lua`
- Improving user flow

---

## ⭐ Milestone v0.5 — Console Compatibility

### Goals
- All UI layouts scale cleanly at 720p / 1080p
- Large hitboxes for gamepad support
- Replace hover-dependent interactions with button prompts
- Eliminate small text, unreadable labels, and mouse-specific UI
- Verify LAM2 message rate limits on console
- Performance test with large guild rosters

### Deliverables
- A single UI experience that works on:
  - PC Keyboard/Mouse
  - PC Gamepad Mode
  - Xbox
  - PlayStation

---

## ⭐ Milestone v0.6 — Beta Release Prep

### Goals
- Add README polish
- Add CHANGELOG.md
- Add CONTRIBUTING.md guidelines
- Add LICENSE (MIT recommended)
- Add GitHub issue templates
- Pre-release trailer screenshots (optional)
- Recruit test guilds on PC-NA and PC-EU

### Deliverables
- GitHub Release v0.6 tagged
- Distribute addon to test guilds manually

---

## ⭐ Milestone v1.0 — Public Release (ESOUI)

### Goals
- Stable event sync under load
- All UI views complete
- Dialogs feel polished and predictable
- Zero Lua errors under normal usage
- Upload to ESOUI with screenshots and description
- Announce release

### Deliverables
- `TamrielCalendar-v1.0.zip` published to:
  - ESOUI
  - GitHub Releases

---

## ⭐ Future Milestones (Post-Launch)

### v1.1 — RSVP System
- “Going / Maybe / Not Going”
- Sync via LAM2

### v1.2 — Multi-Guild Filters
- Select multiple subscribed guilds
- Unified event rendering

### v1.3 — Event Templates
- Quick-add templates like:
  - Trial (with role fields)
  - Guild Meeting
  - Crafting Party
  - PvP Night

### v1.4 — Export/Import Share Strings
- Share an event via chat or Discord
- Import with `/tamcal import <code>`

---

# End of File
