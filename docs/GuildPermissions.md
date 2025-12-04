# Guild Permissions System

Tamriel Calendar allows guild leaders to configure which ESO permission levels grant calendar abilities.

## ESO Permission Levels

ESO provides these guild permissions that we can map to calendar actions:

```lua
-- Commonly used for "officer" level checks
GUILD_PERMISSION_SET_MOTD              -- Can edit Message of the Day
GUILD_PERMISSION_NOTE_EDIT             -- Can edit member notes (public)
GUILD_PERMISSION_OFFICER_NOTE_EDIT     -- Can edit officer notes
GUILD_PERMISSION_PROMOTE               -- Can promote members
GUILD_PERMISSION_DEMOTE                -- Can demote members
GUILD_PERMISSION_INVITE                -- Can invite to guild
GUILD_PERMISSION_REMOVE                -- Can remove from guild
GUILD_PERMISSION_GUILD_KIOSK_BID       -- Can bid on guild traders

-- Less commonly used
GUILD_PERMISSION_BANK_DEPOSIT          -- Can deposit to guild bank
GUILD_PERMISSION_BANK_WITHDRAW         -- Can withdraw from guild bank
GUILD_PERMISSION_BANK_WITHDRAW_GOLD    -- Can withdraw gold
GUILD_PERMISSION_BANK_VIEW_GOLD        -- Can view bank gold
GUILD_PERMISSION_STORE_SELL            -- Can sell in guild store
GUILD_PERMISSION_CHAT                  -- Can use guild chat
GUILD_PERMISSION_CLAIM_AVA_RESOURCE    -- Can claim AvA resources
GUILD_PERMISSION_RELEASE_AVA_RESOURCE  -- Can release AvA resources
```

## Calendar Permission Mapping

Guild leaders can configure which ESO permission grants each calendar ability:

| Calendar Action | Default ESO Permission | Configurable |
|-----------------|----------------------|--------------|
| View Events | (All members) | No |
| Create Events | GUILD_PERMISSION_SET_MOTD | Yes |
| Edit Own Events | (Event creator) | No |
| Edit Any Event | GUILD_PERMISSION_SET_MOTD | Yes |
| Delete Own Events | (Event creator) | No |
| Delete Any Event | GUILD_PERMISSION_SET_MOTD | Yes |
| Manage Attendees | (Event creator OR Edit Any) | No |
| Configure Calendar | (Guild Master only) | No |

## Default Behavior

Out of the box, Tamriel Calendar uses `GUILD_PERMISSION_SET_MOTD` as the "calendar admin" permission. This matches GuildEventsEnhanced's behavior and is intuitive:

- If you can edit the MOTD, you're probably an officer
- Officers can create/edit/delete guild events
- Regular members can view and sign up

## Configuration UI

Guild masters see a "Calendar Settings" option in the addon settings:

```
┌─────────────────────────────────────────────────────┐
│ Calendar Settings for: [Guild Name]                 │
├─────────────────────────────────────────────────────┤
│                                                     │
│ Enable Calendar Tab: [✓]                            │
│                                                     │
│ Permission to CREATE events:                        │
│ [▼ Can Edit MOTD                              ]     │
│                                                     │
│ Permission to EDIT any event:                       │
│ [▼ Can Edit MOTD                              ]     │
│                                                     │
│ Permission to DELETE any event:                     │
│ [▼ Can Edit MOTD                              ]     │
│                                                     │
├─────────────────────────────────────────────────────┤
│ Note: Only the Guild Master can change these        │
│ settings. Changes sync to all guild members.        │
└─────────────────────────────────────────────────────┘
```

## Permission Check Implementation

```lua
local TC = TamrielCalendar

-- Check if current player can perform action
function TC:CanCreateEvent(guildId)
    local settings = self:GetGuildSettings(guildId)
    local permission = settings.createPermission or GUILD_PERMISSION_SET_MOTD
    return DoesPlayerHaveGuildPermission(guildId, permission)
end

function TC:CanEditEvent(guildId, event)
    -- Creator can always edit own events
    if event.createdBy == GetDisplayName() then
        return true
    end

    -- Check configured permission for editing any event
    local settings = self:GetGuildSettings(guildId)
    local permission = settings.editPermission or GUILD_PERMISSION_SET_MOTD
    return DoesPlayerHaveGuildPermission(guildId, permission)
end

function TC:CanDeleteEvent(guildId, event)
    -- Creator can always delete own events
    if event.createdBy == GetDisplayName() then
        return true
    end

    -- Check configured permission for deleting any event
    local settings = self:GetGuildSettings(guildId)
    local permission = settings.deletePermission or GUILD_PERMISSION_SET_MOTD
    return DoesPlayerHaveGuildPermission(guildId, permission)
end

function TC:CanManageAttendees(guildId, event)
    -- Creator can always manage their event
    if event.createdBy == GetDisplayName() then
        return true
    end

    -- Anyone who can edit the event can manage attendees
    return self:CanEditEvent(guildId, event)
end

function TC:CanConfigureCalendar(guildId)
    -- Only guild master can configure
    return IsPlayerGuildMaster(guildId)
end

function TC:IsGuildMaster(guildId)
    local playerIndex = GetPlayerGuildMemberIndex(guildId)
    local _, _, rankIndex = GetGuildMemberInfo(guildId, playerIndex)
    return rankIndex == 1  -- Rank 1 is always Guild Master
end
```

## Settings Storage

Guild settings are stored per-guild in SavedVariables:

```lua
TamrielCalendar_SV = {
    guildSettings = {
        [guildId] = {
            enabled = true,                              -- Show calendar tab
            createPermission = GUILD_PERMISSION_SET_MOTD,
            editPermission = GUILD_PERMISSION_SET_MOTD,
            deletePermission = GUILD_PERMISSION_SET_MOTD,
            lastModifiedBy = "@GuildMaster",
            lastModifiedAt = 1733356800,
            settingsVersion = 1,
        },
    },
}
```

## Settings Sync

When guild settings are changed:

1. Guild master modifies settings
2. Settings saved locally with new version
3. `TAMC_GUILD_SETTINGS` message broadcast to guild
4. Other members receive and apply settings
5. Settings cached locally for offline access

```lua
-- Message format
{
    type = "TAMC_GUILD_SETTINGS",
    guildId = 123456,
    settings = {
        enabled = true,
        createPermission = GUILD_PERMISSION_SET_MOTD,
        editPermission = GUILD_PERMISSION_SET_MOTD,
        deletePermission = GUILD_PERMISSION_SET_MOTD,
        settingsVersion = 2,
    },
    modifiedBy = "@GuildMaster",
    modifiedAt = 1733360400,
}
```

## Edge Cases

### New Guild Member
- Receives settings on first sync (when opening guild panel)
- Uses defaults until sync completes

### Guild Master Changes
- Old master loses configure ability immediately
- New master gains configure ability immediately
- Settings persist through master changes

### Permission Downgrade
- If a member loses the required permission (demoted), they immediately lose calendar abilities
- No cached "I used to be an officer" loophole

### Multiple Guilds
- Each guild has independent settings
- Player may be admin in one guild, regular member in another
- UI adapts per-guild based on permissions

## Security Notes

1. **Client-side checks are advisory** - A malicious client could bypass UI restrictions
2. **Server-side validation** - Other clients validate incoming messages against permissions
3. **Trust but verify** - Accept events from users who claim create permission, but verify on display
4. **Version conflicts** - Higher settings version wins, prevents rollback attacks

## Dropdown Options

The permission dropdown shows human-readable names:

```lua
local PERMISSION_OPTIONS = {
    { value = GUILD_PERMISSION_SET_MOTD, label = "Can Edit MOTD" },
    { value = GUILD_PERMISSION_OFFICER_NOTE_EDIT, label = "Can Edit Officer Notes" },
    { value = GUILD_PERMISSION_PROMOTE, label = "Can Promote Members" },
    { value = GUILD_PERMISSION_GUILD_KIOSK_BID, label = "Can Bid on Traders" },
    { value = GUILD_PERMISSION_INVITE, label = "Can Invite Members" },
    { value = GUILD_PERMISSION_NOTE_EDIT, label = "Can Edit Member Notes" },
}
```

Guild masters choose from this list for each action.
