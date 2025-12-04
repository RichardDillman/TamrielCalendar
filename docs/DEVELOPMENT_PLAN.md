# Tamriel Calendar - Development Plan

## Project Status Summary

**Current State:** Scaffold only - all module files are empty placeholders.

### Documentation Status
| Item | Status |
|------|--------|
| README.md | Complete |
| PRD.md | Complete (revised with guild integration) |
| Milestones.md | Complete |
| GUI_SPEC.md | Complete |
| GuildPermissions.md | Complete |
| SavedVariablesSchema.md | Complete |
| MessagingProtocol.md | Complete |
| CalendarMathExamples.md | Complete |

### Code Status
| File | Status |
|------|--------|
| All `.lua` files | Placeholder only |
| All `.xml` files | Placeholder only |

---

## Architecture Overview

### Two UI Entry Points

1. **Personal Calendar** (`/tamcal`) - Standalone window with Day/Week/Month views
2. **Guild Events Tab** - Integrated into ESO's Guild panel (like GuildEventsEnhanced)

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     SavedVariables                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ Personal     │  │ Guild Events │  │ Guild Settings   │  │
│  │ Events       │  │ (cached)     │  │ (permissions)    │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                  ▲                    ▲
         │                  │                    │
         ▼                  │                    │
┌─────────────────┐   ┌─────────────────────────────────────┐
│ EventManager    │   │ SyncManager (LibAddonMessage)       │
│ - CRUD          │   │ - REQUEST_EVENTS                    │
│ - Purge         │   │ - PUSH_EVENT / BULK_EVENTS          │
│ - Query         │   │ - GUILD_SETTINGS                    │
└─────────────────┘   └─────────────────────────────────────┘
         │                         ▲
         ▼                         │
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                             │
│  ┌──────────────────────┐  ┌──────────────────────────┐    │
│  │ Personal Calendar    │  │ Guild Events Tab         │    │
│  │ - Day/Week/Month     │  │ - Event list             │    │
│  │ - Event dialogs      │  │ - Sign-up dialogs        │    │
│  │ - Standalone window  │  │ - In Guild panel         │    │
│  └──────────────────────┘  └──────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## Development Phases

### Phase 1: Core Infrastructure (v0.1)

**Goal:** Addon loads, SavedVariables work, date math functional

#### 1.1 DateHelpers.lua
Pure functions, no dependencies:
```lua
-- Required functions
DaysInMonth(year, month)      -- Days in given month
FirstWeekday(year, month)     -- Sunday=1 weekday of month start
StartOfDay(timestamp)         -- Midnight of given day
StartOfWeek(timestamp)        -- Monday 00:00 of week
EndOfDay(timestamp)           -- 23:59:59 of given day
AddMonth(year, month, delta)  -- Navigate months
GetTodayMidnight()            -- Today at 00:00
FormatDate(ts, format)        -- "Dec 4, 2025"
FormatTime(ts)                -- "8:00 PM"
FormatDateTime(ts)            -- "Dec 4, 8:00 PM"
ParseTime(hour, minute)       -- Hour/min to timestamp offset
```

#### 1.2 TamrielCalendar.lua (Bootstrap)
```lua
-- On EVENT_ADD_ON_LOADED:
1. Initialize SavedVariables with defaults
2. Register slash command /tamcal
3. Initialize module tables
4. Register guild panel callbacks
5. Call PurgeOldEvents()
```

#### 1.3 SavedVariables Structure
```lua
TamrielCalendar_SV = {
    version = 1,

    -- Personal events
    events = {},

    -- Guild event cache
    guildEvents = {
        [guildId] = { events = {}, lastSync = timestamp },
    },

    -- Guild settings (from guild master)
    guildSettings = {
        [guildId] = {
            enabled = true,
            createPermission = GUILD_PERMISSION_SET_MOTD,
            editPermission = GUILD_PERMISSION_SET_MOTD,
            deletePermission = GUILD_PERMISSION_SET_MOTD,
            settingsVersion = 1,
        },
    },

    -- User preferences
    preferences = {
        defaultView = "MONTH",
        windowPosition = { x = 100, y = 100 },
        use24HourTime = false,
        weekStartsMonday = false,
    },
}
```

#### 1.4 Testing Checkpoint
- `/reloadui` produces no errors
- `/tamcal` prints "Tamriel Calendar loaded" (placeholder)
- SavedVariables file created on logout

---

### Phase 2: Personal Calendar UI (v0.2)

**Goal:** Standalone calendar window with personal events

#### 2.1 TamrielCalendar.xml
Main window structure:
```xml
TamCalWindow (TopLevelControl)
├── Background
├── Header (title + close button)
├── NavBar (prev/today/next + view toggles)
├── ContentArea
│   ├── MonthView
│   ├── WeekView
│   └── DayView
└── ActionBar (filter + new event)
```

#### 2.2 UI_MonthView.lua
- 42-cell grid (6 rows × 7 columns)
- Weekday header row
- Day number labels
- Event pip rendering (max 3 per cell)
- Today highlighting
- Click → switch to Day view

#### 2.3 UI_WeekView.lua
- 7-day columns with day headers
- Hourly row grid
- Event blocks positioned by time
- Today column highlighting

#### 2.4 UI_DayView.lua
- 24-hour timeline
- Event blocks with details
- Sidebar for selected event

#### 2.5 UI_Dialogs.lua
- Event creation form
- Event edit form
- Delete confirmation
- Date picker (month grid)
- Time picker (hour/minute dropdowns)

#### 2.6 EventManager.lua (Personal)
```lua
CreateEvent(data)           -- Validate & store
UpdateEvent(eventId, data)  -- Modify existing
DeleteEvent(eventId)        -- Remove
GetEvent(eventId)           -- Single event
GetEventsForDay(ts)         -- Day query
GetEventsForRange(start, end) -- Range query
PurgeOldEvents()            -- Delete before today
GenerateEventId()           -- Unique ID
```

#### 2.7 Testing Checkpoint
- Window opens/closes with `/tamcal`
- Can create personal event
- Event shows in all three views
- Event survives `/reloadui`
- Old events purged on load

---

### Phase 3: Guild Panel Integration (v0.3)

**Goal:** Guild events tab in Guild panel, basic sync

#### 3.1 Guild Panel Hook
```lua
-- Add tab to existing Guild panel
-- Similar to GuildEventsEnhanced approach:
1. Create fragment for events tab
2. Register with GUILD_SELECTOR callback
3. Hook into SCENE_MANAGER for guild scenes
```

#### 3.2 GuildEventsFragment.lua (New file)
```lua
-- Guild-specific event list UI
- Event cards with attendee counts
- Sign-up buttons
- Role indicators (Tank/Healer/DPS)
- Create button (if has permission)
- Refresh button
```

#### 3.3 SyncManager.lua
```lua
-- LibAddonMessage integration
RegisterProtocol()
SendRequest(guildId)           -- REQUEST_EVENTS
SendEvent(guildId, event)      -- PUSH_EVENT
SendBulkEvents(guildId, events) -- BULK_EVENTS
SendSettings(guildId, settings) -- GUILD_SETTINGS
HandleIncoming(guildId, data, sender)
SerializeMessage(data)
DeserializeMessage(encoded)
```

#### 3.4 Sign-up System
```lua
-- Event attendee management
SignUp(eventId, role)          -- Tank/Healer/DPS
Withdraw(eventId)              -- Leave event
GetAttendees(eventId)          -- List with roles
IsSignedUp(eventId)            -- Current player check
```

#### 3.5 Sync Triggers
```lua
-- Automatic sync on:
1. Guild panel opened (OnGuildSelected callback)
2. Guild switched (GUILD_SELECTOR.guildId changed)
3. Manual refresh button clicked

-- Broadcast on:
1. Event created
2. Event edited
3. Event deleted
4. Sign-up/withdraw
```

#### 3.6 Testing Checkpoint
- Guild tab appears in Guild panel
- Events display for selected guild
- Can sign up with role selection
- Two accounts see each other's events after refresh
- Events persist across sessions

---

### Phase 4: Permissions & Admin (v0.4)

**Goal:** Guild leaders can configure permissions, approval mode

#### 4.1 Permission Checking
```lua
CanCreateEvent(guildId)
CanEditEvent(guildId, event)
CanDeleteEvent(guildId, event)
CanManageAttendees(guildId, event)
CanConfigureCalendar(guildId)
IsGuildMaster(guildId)
```

#### 4.2 SettingsPanel.lua
```lua
-- LibAddonMenu-2.0 integration
- Personal preferences (default view, time format)
- Per-guild calendar settings (guild master only)
  - Enable/disable calendar tab
  - Permission dropdowns (create/edit/delete)
```

#### 4.3 Approval Mode
```lua
-- Event creation option:
requiresApproval = true/false (default false)

-- If true:
- Sign-ups go to "pending" status
- Event creator sees pending list
- Approve/Deny buttons for each
- On approve → status = "confirmed"
```

#### 4.4 Attendee Management
```lua
-- Event creator/admin can:
KickAttendee(eventId, accountName)
ApproveAttendee(eventId, accountName)
DenyAttendee(eventId, accountName)
```

#### 4.5 Testing Checkpoint
- Guild master can change permission settings
- Settings sync to other guild members
- Members without permission see disabled create button
- Event creator can kick attendees
- Approval mode works end-to-end

---

### Phase 5: Polish & Sharing (v0.5)

**Goal:** Chat sharing, UI polish, console support

#### 5.1 Chat Link Sharing
```lua
-- Personal events can be shared via chat
CreateShareLink(event)         -- Returns clickable link
HandleLinkClick(linkData)      -- Opens import dialog
ImportSharedEvent(eventData)   -- Adds to personal calendar
```

#### 5.2 UI Polish
- Category colors from GUI_SPEC.md
- Hover tooltips on events
- Button state animations
- Sound effects (click, create, delete)
- "Today" visual indicator

#### 5.3 Console/Gamepad Support
- Large touch targets
- Keyboard navigation (arrow keys in month grid)
- Gamepad button prompts
- No hover-dependent features

#### 5.4 Testing Checkpoint
- Chat links work between players
- UI looks correct on 720p/1080p
- Gamepad mode fully navigable
- No Lua errors in any flow

---

### Phase 6: Release (v1.0)

**Goal:** Public release on ESOUI

- [ ] CHANGELOG.md with version history
- [ ] Screenshots for ESOUI listing
- [ ] Test with 3+ real guilds
- [ ] Package as .zip
- [ ] Upload to ESOUI
- [ ] Create GitHub release
- [ ] Update README with ESOUI link

---

## File Implementation Order

```
1. DateHelpers.lua          -- Pure functions, test independently
2. TamrielCalendar.lua      -- Bootstrap, SavedVariables
3. EventManager.lua         -- CRUD for personal events
4. TamrielCalendar.xml      -- UI skeleton
5. UI_MonthView.lua         -- First visible calendar
6. UI_Dialogs.lua           -- Event forms
7. UI_WeekView.lua          -- Second view
8. UI_DayView.lua           -- Third view
9. GuildEventsFragment.lua  -- Guild panel tab (NEW)
10. SyncManager.lua         -- LibAddonMessage
11. SettingsPanel.lua       -- LibAddonMenu
```

---

## Module Responsibilities

| Module | Responsibility |
|--------|----------------|
| `DateHelpers.lua` | Pure date math, no side effects |
| `EventManager.lua` | Event CRUD, storage, queries |
| `SyncManager.lua` | LibAddonMessage, serialize/deserialize |
| `GuildEventsFragment.lua` | Guild panel UI, sign-ups |
| `UI_MonthView.lua` | Month grid rendering |
| `UI_WeekView.lua` | Week grid rendering |
| `UI_DayView.lua` | Day timeline rendering |
| `UI_Dialogs.lua` | Forms, confirmations, pickers |
| `SettingsPanel.lua` | LAM2 settings, guild config |

---

## Key ESO APIs

### Guild Integration
```lua
-- Hooking into guild panel
CALLBACK_MANAGER:RegisterCallback("OnGuildSelected", callback)
GUILD_SELECTOR.guildId              -- Current guild
GetNumGuilds()                      -- 0-5
GetGuildId(index)                   -- Guild ID from index
GetGuildName(guildId)               -- Display name

-- Permissions
DoesPlayerHaveGuildPermission(guildId, permission)
GetPlayerGuildMemberIndex(guildId)
GetGuildMemberInfo(guildId, memberIndex)
IsPlayerGuildMaster(guildId)        -- Doesn't exist, use rank check
```

### UI Fragments
```lua
-- Creating a guild panel tab (like GuildEventsEnhanced)
ZO_FadeSceneFragment:New(control)
GUILD_HOME_SCENE:AddFragment(fragment)
```

### Time
```lua
GetTimeStamp()                      -- Current Unix timestamp
os.date("*t", timestamp)            -- Lua date table
os.time({year, month, day, ...})    -- Components to timestamp
```

---

## Notes for Developers

1. **Guild panel integration is tricky** - Study GuildEventsEnhanced's `GuildEvents_Scene.lua` carefully
2. **Test with multiple accounts** - Sync bugs only appear with real guild members
3. **Rate limits matter** - LibAddonMessage has throttling, don't spam
4. **Version your data** - SavedVariables and events need version numbers for migrations
5. **Purge on load** - Always clean up old events before displaying

---

## Reference: GuildEventsEnhanced Patterns

The old addon provides useful patterns:

```lua
-- Registering guild callbacks
CALLBACK_MANAGER:RegisterCallback("OnGuildSelected", function()
    -- Refresh when guild changes
end)

-- Checking permissions
local memberIsAdmin = DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_SET_MOTD)

-- Getting member info
local name, note, rankIndex, playerStatus = GetGuildMemberInfo(guildId, memberIndex)

-- Player status values
-- 1 = Online, 2 = Away, 3 = DND, 4 = Offline
```

---

*Last updated: 2025-12-04*
