# Messaging Protocol

Tamriel Calendar uses **LibAddonMessage-2.0** for guild event synchronization. All communication happens in-game through ESO's guild chat channel system.

## Overview

- **No external services** - All sync happens within ESO
- **Guild-scoped** - Messages only reach guild members with the addon
- **Rate-limited** - Respects ESO's message throttling
- **Compressed** - Uses LibSerialize + LibDeflate for efficiency

## Dependencies

```lua
-- Required libraries
local LAM2 = LibAddonMessage2
local LibSerialize = LibSerialize
local LibDeflate = LibDeflate
```

## Message Types

### TAMC_REQUEST_EVENTS

Request guild events from other online members.

**Direction:** Outgoing (broadcast to guild)

**Trigger:** User clicks "Refresh" button for a subscribed guild

**Payload:**
```lua
{
    type = "TAMC_REQUEST_EVENTS",
    guildId = 123456,
    since = 1733350000,     -- Only events updated after this timestamp
    requesterId = "@PlayerName",
}
```

**Response:** Recipients with events should send `TAMC_PUSH_EVENT` messages

---

### TAMC_PUSH_EVENT

Share a single event with guild members.

**Direction:** Outgoing (broadcast to guild) or Response to request

**Trigger:**
1. Response to `TAMC_REQUEST_EVENTS`
2. User creates/edits a guild event
3. User clicks "Share" on a personal event

**Payload:**
```lua
{
    type = "TAMC_PUSH_EVENT",
    guildId = 123456,
    event = {
        eventId = "PlayerName-1733356800-1234",
        title = "Veteran Trial Run",
        description = "Weekly vCR progression",
        startTime = 1733428800,
        endTime = 1733436000,
        category = "Raid",
        guildId = 123456,
        owner = "@PlayerName",
        version = 3,
        createdAt = 1733350000,
        updatedAt = 1733400000,
    },
}
```

---

### TAMC_DELETE_EVENT

Notify guild that an event has been deleted.

**Direction:** Outgoing (broadcast to guild)

**Trigger:** Event owner deletes a guild event

**Payload:**
```lua
{
    type = "TAMC_DELETE_EVENT",
    guildId = 123456,
    eventId = "PlayerName-1733356800-1234",
    deletedBy = "@PlayerName",
}
```

---

### TAMC_BULK_EVENTS

Send multiple events in a single message (response to REQUEST).

**Direction:** Response to `TAMC_REQUEST_EVENTS`

**Payload:**
```lua
{
    type = "TAMC_BULK_EVENTS",
    guildId = 123456,
    events = {
        { ... event 1 ... },
        { ... event 2 ... },
        -- max 10 events per message
    },
    hasMore = true,         -- More events to send
    page = 1,
}
```

## Message Flow

### Requesting Guild Events

```
┌─────────────┐                              ┌─────────────┐
│   Player A  │                              │   Player B  │
│  (Requester)│                              │  (Has Events)│
└──────┬──────┘                              └──────┬──────┘
       │                                            │
       │  TAMC_REQUEST_EVENTS (guildId=123)         │
       │ ─────────────────────────────────────────► │
       │                                            │
       │                                            │ (filters events
       │                                            │  for guild 123,
       │                                            │  today+future only)
       │                                            │
       │              TAMC_BULK_EVENTS              │
       │ ◄───────────────────────────────────────── │
       │                                            │
       │ (merge into local                          │
       │  savedVars.guildEvents)                    │
       │                                            │
```

### Publishing a New Event

```
┌─────────────┐                              ┌─────────────┐
│   Officer   │                              │ Guild Members│
│  (Publisher)│                              │  (Listeners) │
└──────┬──────┘                              └──────┬──────┘
       │                                            │
       │  TAMC_PUSH_EVENT (new event)               │
       │ ─────────────────────────────────────────► │
       │                                            │
       │                                            │ (each member
       │                                            │  merges event
       │                                            │  into local cache)
       │                                            │
```

## Serialization

Messages are serialized and compressed before transmission:

```lua
local function SerializeMessage(messageTable)
    -- Step 1: Serialize to string
    local serialized = LibSerialize:Serialize(messageTable)

    -- Step 2: Compress
    local compressed = LibDeflate:CompressDeflate(serialized)

    -- Step 3: Encode for transmission
    local encoded = LibDeflate:EncodeForPrint(compressed)

    return encoded
end

local function DeserializeMessage(encoded)
    -- Step 1: Decode
    local compressed = LibDeflate:DecodeForPrint(encoded)
    if not compressed then return nil end

    -- Step 2: Decompress
    local serialized = LibDeflate:DecompressDeflate(compressed)
    if not serialized then return nil end

    -- Step 3: Deserialize
    local success, messageTable = LibSerialize:Deserialize(serialized)
    if not success then return nil end

    return messageTable
end
```

## Registration

```lua
local ADDON_PREFIX = "TAMC"  -- Tamriel Calendar

local function RegisterMessaging()
    LAM2:RegisterAddonProtocol(ADDON_PREFIX, function(guildId, data, sender)
        local message = DeserializeMessage(data)
        if not message then return end

        HandleIncomingMessage(guildId, message, sender)
    end)
end
```

## Sending Messages

```lua
local function SendToGuild(guildId, messageTable)
    local encoded = SerializeMessage(messageTable)

    -- LibAddonMessage handles rate limiting internally
    LAM2:SendGuildMessage(guildId, ADDON_PREFIX, encoded)
end
```

## Rate Limiting

ESO has strict rate limits on addon messages. LibAddonMessage-2.0 handles queuing internally, but we should still be mindful:

| Limit | Value |
|-------|-------|
| Messages per second | ~1-2 |
| Message size | ~1000 bytes |
| Burst capacity | ~5 messages |

### Best Practices

1. **Batch events** - Use `TAMC_BULK_EVENTS` instead of individual pushes
2. **Request sparingly** - Only sync on user action (Refresh button)
3. **Filter early** - Only sync today + future events
4. **Compress always** - LibDeflate significantly reduces payload size

## Conflict Resolution

When receiving an event that already exists locally:

```lua
local function MergeEvent(existingEvent, incomingEvent)
    -- Higher version wins
    if incomingEvent.version > existingEvent.version then
        return incomingEvent
    end

    -- Same version: more recent update wins
    if incomingEvent.version == existingEvent.version then
        if incomingEvent.updatedAt > existingEvent.updatedAt then
            return incomingEvent
        end
    end

    -- Keep existing
    return existingEvent
end
```

## Security Considerations

1. **Validate sender** - Only process messages from guild members
2. **Validate guildId** - Ensure message guildId matches actual source guild
3. **Sanitize content** - Strip potentially harmful characters from event text
4. **Size limits** - Reject events with excessively long titles/descriptions

```lua
local MAX_TITLE_LENGTH = 100
local MAX_DESCRIPTION_LENGTH = 500

local function ValidateEvent(event)
    if not event.eventId or not event.title then
        return false, "Missing required fields"
    end

    if #event.title > MAX_TITLE_LENGTH then
        return false, "Title too long"
    end

    if event.description and #event.description > MAX_DESCRIPTION_LENGTH then
        return false, "Description too long"
    end

    if event.startTime >= event.endTime then
        return false, "Invalid time range"
    end

    return true
end
```

## Officer-Only Publishing

For guilds that want to restrict event creation:

```lua
local function CanPublishToGuild(guildId)
    -- Check if player has officer-level permissions
    -- GUILD_PERMISSION_GUILD_KIOSK_BID is commonly used as "officer" check
    return DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_GUILD_KIOSK_BID)
end
```

This can be made configurable per-guild in settings.

## Error Handling

```lua
local function HandleIncomingMessage(guildId, message, sender)
    -- Validate message structure
    if type(message) ~= "table" or not message.type then
        return  -- Silently ignore malformed messages
    end

    -- Route by type
    if message.type == "TAMC_REQUEST_EVENTS" then
        HandleEventRequest(guildId, message, sender)
    elseif message.type == "TAMC_PUSH_EVENT" then
        HandlePushEvent(guildId, message, sender)
    elseif message.type == "TAMC_BULK_EVENTS" then
        HandleBulkEvents(guildId, message, sender)
    elseif message.type == "TAMC_DELETE_EVENT" then
        HandleDeleteEvent(guildId, message, sender)
    end
    -- Unknown types are silently ignored for forward compatibility
end
```

## Testing

To test messaging without affecting real guilds:

1. Create a test guild with alt accounts
2. Enable debug mode in settings
3. Use `/tamcal debug send` to trigger test messages
4. Check LibDebugLogger output for message flow

## Future Considerations

- **RSVP messages** (v1.1): `TAMC_RSVP` for attendance tracking
- **Event templates** (v1.3): `TAMC_SHARE_TEMPLATE` for sharing templates
- **Import codes** (v1.4): Generate shareable strings (not via messaging, via chat)
