# SavedVariables Schema

Tamriel Calendar uses ESO's SavedVariables system for all persistent storage. No external services or file I/O.

## File Location

```
Documents/Elder Scrolls Online/live/SavedVariables/TamrielCalendar.lua
```

## Complete Schema

```lua
TamrielCalendar_SV = {
    ["Default"] = {
        ["AccountWide"] = {
            version = 1,                        -- Schema version for migrations

            -------------------------------------------------
            -- PERSONAL EVENTS (never synced)
            -------------------------------------------------
            events = {
                ["<eventId>"] = {
                    eventId = "string",
                    title = "string",
                    description = "string",
                    startTime = number,             -- Unix timestamp
                    endTime = number,
                    category = "string",            -- Raid|Party|Training|Meeting|Personal
                    guildId = nil,                  -- Always nil for personal
                    createdBy = "@AccountName",
                    version = 1,
                    createdAt = number,
                    updatedAt = number,
                },
            },

            -------------------------------------------------
            -- GUILD EVENTS (cached from sync)
            -------------------------------------------------
            guildEvents = {
                [guildId] = {
                    lastSync = number,              -- When last synced
                    events = {
                        ["<eventId>"] = {
                            eventId = "string",
                            title = "string",
                            description = "string",
                            startTime = number,
                            endTime = number,
                            category = "string",    -- Raid|Party|Training|Meeting
                            guildId = number,
                            createdBy = "@AccountName",

                            -- Guild-specific fields
                            requiresApproval = false,   -- Auto-accept by default
                            maxAttendees = 0,           -- 0 = unlimited

                            -- Attendee list
                            attendees = {
                                ["@AccountName"] = {
                                    role = "Tank",      -- Tank|Healer|DPS
                                    status = "confirmed", -- confirmed|pending
                                    signedUpAt = number,
                                },
                            },

                            version = 1,
                            createdAt = number,
                            updatedAt = number,
                        },
                    },
                },
            },

            -------------------------------------------------
            -- GUILD SETTINGS (from guild master)
            -------------------------------------------------
            guildSettings = {
                [guildId] = {
                    enabled = true,                 -- Show calendar tab in guild panel
                    createPermission = 1,           -- GUILD_PERMISSION constant
                    editPermission = 1,             -- GUILD_PERMISSION constant
                    deletePermission = 1,           -- GUILD_PERMISSION constant
                    settingsVersion = 1,            -- For sync conflict resolution
                    lastModifiedBy = "@GuildMaster",
                    lastModifiedAt = number,
                },
            },

            -------------------------------------------------
            -- USER PREFERENCES
            -------------------------------------------------
            preferences = {
                -- Calendar display
                defaultView = "MONTH",              -- DAY|WEEK|MONTH
                use24HourTime = false,
                weekStartsMonday = false,

                -- Window state
                windowPosition = { x = 100, y = 100 },

                -- Week/Day view hour range
                hourRange = { start = 17, stop = 24 },

                -- Category filters
                categoryFilters = {
                    Raid = true,
                    Party = true,
                    Training = true,
                    Meeting = true,
                    Personal = true,
                },

                -- Event source filters
                showGuildEvents = true,
                showPersonalEvents = true,
            },

            -------------------------------------------------
            -- DEBUG
            -------------------------------------------------
            debugMode = false,
        },
    },
}
```

## Event Model

### Personal Event
```lua
{
    eventId = "RichardDillman-1733356800-4521",
    title = "Crafting Session",
    description = "Weekly writ grinding",
    startTime = 1733428800,         -- Dec 5, 2025 8:00 PM
    endTime = 1733436000,           -- Dec 5, 2025 10:00 PM
    category = "Personal",
    guildId = nil,                  -- Personal = no guild
    createdBy = "@RichardDillman",
    version = 1,
    createdAt = 1733350000,
    updatedAt = 1733350000,
}
```

### Guild Event
```lua
{
    eventId = "RichardDillman-1733356800-7892",
    title = "vRG Progression",
    description = "Bring potions and food. Discord required.",
    startTime = 1733518800,         -- Dec 6, 2025 8:00 PM EST
    endTime = 1733529600,           -- Dec 6, 2025 11:00 PM EST
    category = "Raid",
    guildId = 123456,
    createdBy = "@RichardDillman",

    -- Raid-specific fields (optional, only when category = "Raid")
    raidTrial = "RG",               -- Trial short code (see RaidTypes.md)
    raidModifier = "VET",           -- N|VET|HM|SR|ND

    requiresApproval = false,       -- Auto-accept (default)
    maxAttendees = 12,              -- Limit to 12 players

    attendees = {
        ["@RichardDillman"] = {
            role = "Tank",
            status = "confirmed",
            signedUpAt = 1733356900,
        },
        ["@Player2"] = {
            role = "Healer",
            status = "confirmed",
            signedUpAt = 1733357000,
        },
        ["@Player3"] = {
            role = "DPS",
            status = "pending",     -- Waiting for approval
            signedUpAt = 1733358000,
        },
    },

    version = 3,                    -- Edited twice since creation
    createdAt = 1733350000,
    updatedAt = 1733400000,
}
```

## Guild Settings Model

```lua
{
    enabled = true,
    createPermission = GUILD_PERMISSION_SET_MOTD,    -- Who can create events
    editPermission = GUILD_PERMISSION_SET_MOTD,      -- Who can edit any event
    deletePermission = GUILD_PERMISSION_SET_MOTD,    -- Who can delete any event
    settingsVersion = 2,
    lastModifiedBy = "@GuildMaster",
    lastModifiedAt = 1733400000,
}
```

### Permission Constants

```lua
-- Common permission mappings
GUILD_PERMISSION_SET_MOTD = 1           -- "Can Edit MOTD" (officer-level)
GUILD_PERMISSION_NOTE_EDIT = ?          -- "Can Edit Member Notes"
GUILD_PERMISSION_OFFICER_NOTE_EDIT = ?  -- "Can Edit Officer Notes"
GUILD_PERMISSION_PROMOTE = ?            -- "Can Promote Members"
GUILD_PERMISSION_GUILD_KIOSK_BID = ?    -- "Can Bid on Traders"
```

## Event Categories

| Category | Usage | Color |
|----------|-------|-------|
| `Raid` | Trials, dungeons, group PvE | Red (#FF6666) |
| `Party` | Social events, celebrations | Blue (#6699FF) |
| `Training` | Learning sessions, workshops | Green (#66FF66) |
| `Meeting` | Guild meetings, officer calls | Gold (#FFCC66) |
| `Personal` | Private reminders (personal only) | Purple (#9966FF) |

## Raid Trials & Modifiers

When `category = "Raid"`, optional fields `raidTrial` and `raidModifier` are available.

See **[RaidTypes.md](RaidTypes.md)** for full list of trials and modifiers.

## Sign-up Roles

| Role | Icon | Usage |
|------|------|-------|
| `Tank` | Shield icon | Main tank, off-tank |
| `Healer` | Heart icon | Healers |
| `DPS` | Sword icon | Damage dealers (stam/mag) |

## Sign-up Status

| Status | Meaning |
|--------|---------|
| `confirmed` | Signed up and accepted |
| `pending` | Waiting for approval (when requiresApproval = true) |

## Event ID Generation

```lua
local function GenerateEventId()
    local account = GetDisplayName():gsub("@", "")
    local time = GetTimeStamp()
    local rand = math.random(1000, 9999)
    return string.format("%s-%d-%d", account, time, rand)
end
-- Example: "RichardDillman-1733356800-4521"
```

## Version Conflict Resolution

### Event Versions
1. On create: `version = 1`
2. On edit: `version = version + 1`
3. On sync: higher version wins
4. Equal versions: later `updatedAt` wins

### Settings Versions
1. Only guild master can increment
2. Higher `settingsVersion` wins
3. Prevents rollback from old cached settings

## Purge Logic

On addon load:

```lua
local function PurgeOldEvents()
    local todayMidnight = StartOfDay(GetTimeStamp())

    -- Purge personal events
    for eventId, event in pairs(savedVars.events) do
        if event.endTime < todayMidnight then
            savedVars.events[eventId] = nil
        end
    end

    -- Purge guild events
    for guildId, guildData in pairs(savedVars.guildEvents) do
        for eventId, event in pairs(guildData.events) do
            if event.endTime < todayMidnight then
                guildData.events[eventId] = nil
            end
        end
    end
end
```

## Defaults

```lua
local DEFAULTS = {
    version = 1,
    events = {},
    guildEvents = {},
    guildSettings = {},
    preferences = {
        defaultView = "MONTH",
        use24HourTime = false,
        weekStartsMonday = false,
        windowPosition = { x = 100, y = 100 },
        hourRange = { start = 17, stop = 24 },
        categoryFilters = {
            Raid = true,
            Party = true,
            Training = true,
            Meeting = true,
            Personal = true,
        },
        showGuildEvents = true,
        showPersonalEvents = true,
    },
    debugMode = false,
}
```

## Migration Strategy

```lua
local CURRENT_VERSION = 1

local function MigrateSavedVars(sv)
    local version = sv.version or 0

    if version < 1 then
        -- Initial schema setup
        sv.version = 1
        sv.events = sv.events or {}
        sv.guildEvents = sv.guildEvents or {}
        sv.guildSettings = sv.guildSettings or {}
        sv.preferences = sv.preferences or ZO_DeepTableCopy(DEFAULTS.preferences)
    end

    -- Future migrations:
    -- if version < 2 then
    --     -- v2 migration logic
    --     sv.version = 2
    -- end
end
```

## Size Considerations

ESO SavedVariables have practical size limits. To keep data manageable:

1. **Purge old events** - Delete events that have ended before today
2. **Limit attendee history** - Don't store withdrawn attendees
3. **Compact sync** - Only sync today+ events
4. **No media** - No images/icons stored, just references

## Privacy Notes

1. **Personal events never sync** - `guildId = nil` events stay local
2. **Guild events are guild-visible** - All members with addon can see
3. **Attendee names are public** - Within the guild context
4. **Settings are guild-wide** - But only master can change
