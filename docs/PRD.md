# Tamriel Calendar - Product Requirements Document

## Overview

Tamriel Calendar is an ESO addon providing:
1. **Personal Calendar** - Standalone calendar with Day/Week/Month views for personal events
2. **Guild Events** - Integrated into the Guild panel, allowing guild members to create, sign up for, and manage guild events

All data stays within ESO using SavedVariables and LibAddonMessage. No external services.

---

## Core Principles

1. **No external dependencies** - Everything stays in-game
2. **Guild-integrated** - Guild events accessed via Guild panel (like GuildEventsEnhanced)
3. **Permission-based** - Guild leaders control who can do what
4. **Simple roles** - Tank/Healer/DPS only (no overcomplicated categories)
5. **Auto-accept by default** - Events are open unless creator requires approval

---

## User Roles & Permissions

### Guild Owner/Leader

Can configure (per-guild):
- Which ESO permission level grants **Create Event** ability
- Which ESO permission level grants **Edit Event** ability
- Which ESO permission level grants **Delete Event** ability
- Whether to show calendar tab in guild info window

### Guild Member with Calendar Permissions

Based on guild leader configuration:
- Create guild events
- Edit guild events (own or all, based on config)
- Delete guild events (own or all, based on config)
- Accept/Kick members from events they created or administer

### Guild Member (Base)

- View guild events
- Subscribe/unsubscribe from guild event feed
- Join/Leave guild events (auto-accept or pending approval)
- See who's signed up and their roles

### Individual (Personal Calendar)

- Create/Edit/Delete personal events
- Share personal events via chat link (one-way, snapshot)
- Accept shared events from chat (creates local copy)
- Accept/Kick members from personal events they share

---

## Feature Specifications

### 1. Personal Calendar (Standalone Window)

**Access:** `/tamcal` slash command or keybind

**Views:**
- Day View - 24-hour timeline
- Week View - 7-day grid with hourly rows
- Month View - Calendar grid with event pips

**Personal Events:**
- Title, description, start/end time
- Category: Raid, Party, Training, Meeting, Personal
- Auto-cleanup of past events (before today midnight)

**Sharing (Personal → Others):**
- "Share" button creates clickable chat link
- Link contains event snapshot (title, time, description)
- Recipients with addon can click to add to their calendar
- Shared events do NOT sync updates (one-way copy)

---

### 2. Guild Events (Guild Panel Integration)

**Access:** New tab in Guild panel (like GuildEventsEnhanced's quest icon)

**Sync Trigger:**
- On guild panel open
- On guild switch (selecting different guild)
- Manual "Refresh" button

**Guild Event Fields:**
- Title, description, start/end time
- Category: Raid, Party, Training, Meeting
- Created by (account name)
- Approval mode: Auto-accept (default) or Requires Approval
- Max attendees (optional, 0 = unlimited)

**Raid-Specific Fields (when category = Raid):**
- Trial picker (optional): AA, HRC, SO, MoL, HoF, AS, CR, SS, KA, RG, DSR, SE, OC, LC
- Difficulty modifier (optional): Normal, Veteran, Hard Mode, Speed Run, No Death
- Auto-suggests title based on selection (e.g., "vRG" for Veteran Rockgrove)

**Sign-up System:**
- Roles: Tank, Healer, DPS (simple)
- Sign-up status: Signed Up, Pending (if approval required)
- Show attendee list with roles and online status
- Event creator/admins can kick attendees

**Permission Mapping:**
Guild leaders configure which ESO permission grants calendar abilities:

| Calendar Action | Configurable ESO Permission |
|-----------------|---------------------------|
| Create Events | MOTD Edit / Member Note Edit / Promote / Custom rank |
| Edit Any Event | MOTD Edit / Promote / Custom rank |
| Delete Any Event | MOTD Edit / Promote / Custom rank |
| Manage Attendees | Event creator OR above permissions |

Default: MOTD Edit permission = full calendar admin (matches GuildEventsEnhanced)

---

### 3. Event Sign-up Flow

**Auto-Accept Mode (Default):**
1. Member clicks "Sign Up"
2. Selects role (Tank/Healer/DPS)
3. Immediately added to attendee list
4. Synced to other guild members on their next refresh

**Approval Required Mode:**
1. Member clicks "Sign Up"
2. Selects role
3. Status = "Pending"
4. Event creator sees pending requests
5. Creator approves/denies
6. On approval, member moves to attendee list

---

### 4. Data Storage

**Personal Events:** SavedVariables only (never synced)

**Guild Events:**
- Stored in SavedVariables as cache
- Synced via LibAddonMessage when guild panel opened
- Version-based conflict resolution (highest version wins)

**Guild Settings:**
- Permission mappings stored by guild leader
- Synced to guild members via LibAddonMessage
- Only guild master can modify

---

### 5. Sync Protocol

**On Guild Panel Open / Guild Switch:**
1. Send `TAMC_REQUEST_EVENTS` to guild channel
2. Members with addon respond with `TAMC_BULK_EVENTS`
3. Merge received events into local cache
4. Display merged results

**On Event Create/Edit/Delete:**
1. Save to local SavedVariables
2. Broadcast `TAMC_PUSH_EVENT` or `TAMC_DELETE_EVENT`
3. Other online members receive and merge

**Limitations (Accepted):**
- No real-time push (must open guild panel to see updates)
- If no one online has events, new member gets empty calendar
- Stale data possible if member hasn't synced recently

---

## UI Layout

### Personal Calendar Window
```
┌─────────────────────────────────────────────┐
│ Tamriel Calendar                        [X] │
├─────────────────────────────────────────────┤
│ [◄] [Today] [►]    December 2025   [D][W][M]│
├─────────────────────────────────────────────┤
│                                             │
│           Calendar Content Area             │
│         (Day/Week/Month views)              │
│                                             │
├─────────────────────────────────────────────┤
│ [Filter]                      [+ New Event] │
└─────────────────────────────────────────────┘
```

### Guild Events Tab (in Guild Panel)
```
┌─────────────────────────────────────────────┐
│ Guild Events              [↻ Refresh]       │
├─────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────┐ │
│ │ vRockgrove Prog                    [−]  │ │
│ │ Dec 6, 8:00 PM - 11:00 PM              │ │
│ │ Tank(1): @Player1                       │ │
│ │ Healer(2): @Player2, @Player3          │ │
│ │ DPS(5): @Player4, @Player5...          │ │
│ │ [Sign Up] [View Details]               │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ Guild Meeting                           │ │
│ │ Dec 4, 7:00 PM - 8:00 PM               │ │
│ │ Attending: 12                           │ │
│ │ [Sign Up] [View Details]               │ │
│ └─────────────────────────────────────────┘ │
├─────────────────────────────────────────────┤
│ [+ Create Event]  (if has permission)       │
└─────────────────────────────────────────────┘
```

### Sign-up Dialog
```
┌─────────────────────────────────────────────┐
│ Sign Up for Event                           │
├─────────────────────────────────────────────┤
│ vRockgrove Progression                      │
│ December 6, 8:00 PM                         │
├─────────────────────────────────────────────┤
│ Select your role:                           │
│                                             │
│ ( ) 🛡 Tank                                 │
│ ( ) 💚 Healer                               │
│ ( ) ⚔ DPS                                  │
│                                             │
├─────────────────────────────────────────────┤
│          [Cancel]  [Sign Up]                │
└─────────────────────────────────────────────┘
```

---

## Event Model

```lua
{
    eventId = "string",           -- Unique ID (accountName-timestamp-random)
    title = "string",
    description = "string",
    startTime = number,           -- Unix timestamp
    endTime = number,             -- Unix timestamp
    category = "string",          -- Raid/Party/Training/Meeting/Personal

    -- Guild event fields (nil for personal)
    guildId = number,
    createdBy = "string",         -- @AccountName
    requiresApproval = boolean,   -- false = auto-accept (default)
    maxAttendees = number,        -- 0 = unlimited

    -- Attendees (guild events)
    attendees = {
        ["@AccountName"] = {
            role = "Tank",        -- Tank/Healer/DPS
            status = "confirmed", -- confirmed/pending
            signedUpAt = number,
        },
    },

    -- Metadata
    version = number,             -- Increment on edit
    createdAt = number,
    updatedAt = number,
}
```

---

## Milestones (Revised)

### v0.1 - Core Infrastructure
- [x] DateHelpers complete
- [x] SavedVariables initialized
- [x] Slash command registered
- [ ] Addon loads without errors (needs testing in ESO)

### v0.2 - Personal Calendar
- [x] Event CRUD (EventManager.lua complete)
- [x] Auto-cleanup working
- [x] UI skeleton (TamrielCalendar.xml complete)
- [x] Month view rendering (UI_MonthView.lua complete)
- [x] Week view rendering (UI_WeekView.lua complete)
- [x] Day view rendering (UI_DayView.lua complete)

### v0.3 - Guild Panel Integration
- [x] Guild subscription panel in main window (UI_GuildPanel.lua complete)
- [x] Guild tags with subscribe toggles
- [x] Sign-up with roles (auto-accept only)
- [x] Basic sync on guild open (SyncManager.lua complete)

### v0.4 - Permissions & Admin
- [ ] Permission mapping UI for guild leaders
- [ ] Edit/Delete guild events
- [ ] Kick attendees
- [ ] Approval mode option

### v0.5 - Polish & Sharing
- [ ] Chat link sharing for personal events
- [ ] UI polish and category colors
- [ ] Console/gamepad support

### v1.0 - Release
- [ ] Full testing
- [ ] ESOUI publication

---

## Out of Scope (v1.0)

- Real-time push notifications
- Bench/Late/Tentative/Absence categories
- Recurring events
- Calendar export/import
- Discord integration
- External API connections
