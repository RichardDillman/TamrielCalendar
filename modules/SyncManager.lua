--[[
    SyncManager.lua
    Guild event synchronization using LibAddonMessage-2.0

    Handles:
    - Requesting events from guild members
    - Receiving and merging events
    - Broadcasting event changes
    - Rate limiting and message queuing
]]

local TC = TamrielCalendar
local DH = TC.DateHelpers
local EM = TC.EventManager

TC.SyncManager = {}
local SM = TC.SyncManager

-------------------------------------------------
-- Constants
-------------------------------------------------

local ADDON_PREFIX = "TAMC"  -- Tamriel Calendar
local MAX_EVENTS_PER_MESSAGE = 10
local MAX_TITLE_LENGTH = 100
local MAX_DESCRIPTION_LENGTH = 500

-- Message types
local MSG_TYPE = {
    REQUEST_EVENTS = "TAMC_REQUEST_EVENTS",
    PUSH_EVENT = "TAMC_PUSH_EVENT",
    BULK_EVENTS = "TAMC_BULK_EVENTS",
    DELETE_EVENT = "TAMC_DELETE_EVENT",
    SYNC_SETTINGS = "TAMC_SYNC_SETTINGS",
}

-------------------------------------------------
-- State
-------------------------------------------------

SM.initialized = false
SM.pendingRequests = {}     -- Track outstanding requests
SM.lastSyncTime = {}        -- Per-guild last sync timestamps
SM.messageQueue = {}        -- Outgoing message queue
SM.isSending = false        -- Rate limiter flag

-- Library references (populated on init)
SM.LAM2 = nil
SM.LibSerialize = nil
SM.LibDeflate = nil

-------------------------------------------------
-- Initialization
-------------------------------------------------

--- Initialize the sync manager
function SM:Initialize()
    if self.initialized then return end

    -- Track missing libraries for user notification
    local missingLibs = {}

    -- Check for required libraries
    self.LAM2 = LibAddonMessage2
    self.LibSerialize = LibSerialize
    self.LibDeflate = LibDeflate

    if not self.LAM2 then
        table.insert(missingLibs, "LibAddonMessage-2.0")
    end

    if not self.LibSerialize then
        table.insert(missingLibs, "LibSerialize")
    end

    if not self.LibDeflate then
        table.insert(missingLibs, "LibDeflate")
    end

    -- If any libraries are missing, notify user and disable sync
    if #missingLibs > 0 then
        SM.syncDisabled = true
        SM.missingLibraries = missingLibs
        TC:Debug("SyncManager: Missing libraries - " .. table.concat(missingLibs, ", "))
        -- Don't spam the user on every login, just log it
        return
    end

    -- Register message handler
    self.LAM2:RegisterAddonProtocol(ADDON_PREFIX, function(guildId, data, sender)
        self:OnMessageReceived(guildId, data, sender)
    end)

    self.initialized = true
    SM.syncDisabled = false
    TC:Debug("SyncManager: Initialized with LibAddonMessage2")
end

--- Check if guild sync is available
--- @return boolean available, string|nil reason
function SM:IsAvailable()
    if self.syncDisabled then
        local reason = "Guild sync requires: " .. table.concat(self.missingLibraries or {}, ", ")
        return false, reason
    end
    return self.initialized, nil
end

-------------------------------------------------
-- Message Serialization
-------------------------------------------------

--- Serialize a message for transmission
--- @param messageTable table The message to serialize
--- @return string|nil Encoded string or nil on error
function SM:SerializeMessage(messageTable)
    if not self.LibSerialize or not self.LibDeflate then
        return nil
    end

    -- Step 1: Serialize to string
    local serialized = self.LibSerialize:Serialize(messageTable)
    if not serialized then
        TC:Debug("SyncManager: Failed to serialize message")
        return nil
    end

    -- Step 2: Compress
    local compressed = self.LibDeflate:CompressDeflate(serialized)
    if not compressed then
        TC:Debug("SyncManager: Failed to compress message")
        return nil
    end

    -- Step 3: Encode for transmission
    local encoded = self.LibDeflate:EncodeForPrint(compressed)

    return encoded
end

--- Deserialize a received message
--- @param encoded string The encoded message
--- @return table|nil Message table or nil on error
function SM:DeserializeMessage(encoded)
    if not self.LibSerialize or not self.LibDeflate then
        return nil
    end

    -- Step 1: Decode
    local compressed = self.LibDeflate:DecodeForPrint(encoded)
    if not compressed then
        return nil
    end

    -- Step 2: Decompress
    local serialized = self.LibDeflate:DecompressDeflate(compressed)
    if not serialized then
        return nil
    end

    -- Step 3: Deserialize
    local success, messageTable = self.LibSerialize:Deserialize(serialized)
    if not success then
        return nil
    end

    return messageTable
end

-------------------------------------------------
-- Message Sending
-------------------------------------------------

--- Queue a message to send to a guild
--- @param guildId number Guild ID
--- @param messageTable table Message to send
function SM:QueueMessage(guildId, messageTable)
    local encoded = self:SerializeMessage(messageTable)
    if not encoded then return end

    table.insert(self.messageQueue, {
        guildId = guildId,
        data = encoded,
        timestamp = GetTimeStamp(),
    })

    self:ProcessQueue()
end

--- Process the outgoing message queue (rate limited)
function SM:ProcessQueue()
    if self.isSending or #self.messageQueue == 0 then
        return
    end

    self.isSending = true

    local message = table.remove(self.messageQueue, 1)

    if self.LAM2 then
        self.LAM2:SendGuildMessage(message.guildId, ADDON_PREFIX, message.data)
        TC:Debug("SyncManager: Sent message to guild " .. message.guildId)
    end

    -- Rate limit: wait before sending next message
    zo_callLater(function()
        self.isSending = false
        self:ProcessQueue()
    end, 500) -- 2 messages per second max
end

--- Send to all subscribed guilds
--- @param messageTable table Message to send
function SM:BroadcastToSubscribedGuilds(messageTable)
    if not TC.savedVars then return end

    local subscriptions = TC.savedVars.guildSubscriptions or {}

    for guildId, subscribed in pairs(subscriptions) do
        if subscribed then
            self:QueueMessage(guildId, messageTable)
        end
    end
end

-------------------------------------------------
-- Message Receiving
-------------------------------------------------

--- Handle incoming addon message
--- @param guildId number Source guild ID
--- @param data string Encoded message data
--- @param sender string Sender account name
function SM:OnMessageReceived(guildId, data, sender)
    -- Ignore our own messages
    local myAccountName = GetDisplayName()
    if sender == myAccountName then
        return
    end

    -- Deserialize
    local message = self:DeserializeMessage(data)
    if not message or type(message) ~= "table" or not message.type then
        return
    end

    TC:Debug("SyncManager: Received " .. message.type .. " from " .. sender)

    -- Route by type
    if message.type == MSG_TYPE.REQUEST_EVENTS then
        self:HandleEventRequest(guildId, message, sender)
    elseif message.type == MSG_TYPE.PUSH_EVENT then
        self:HandlePushEvent(guildId, message, sender)
    elseif message.type == MSG_TYPE.BULK_EVENTS then
        self:HandleBulkEvents(guildId, message, sender)
    elseif message.type == MSG_TYPE.DELETE_EVENT then
        self:HandleDeleteEvent(guildId, message, sender)
    elseif message.type == MSG_TYPE.SYNC_SETTINGS then
        self:HandleSyncSettings(guildId, message, sender)
    end
    -- Unknown types are silently ignored for forward compatibility
end

-------------------------------------------------
-- Request Events
-------------------------------------------------

--- Request events from guild members
--- @param guildId number Guild ID to request from
function SM:RequestEvents(guildId)
    if not self.initialized then
        TC:Debug("SyncManager: Not initialized, cannot request events")
        return
    end

    local lastSync = self.lastSyncTime[guildId] or 0

    local message = {
        type = MSG_TYPE.REQUEST_EVENTS,
        guildId = guildId,
        since = lastSync,
        requesterId = GetDisplayName(),
    }

    self:QueueMessage(guildId, message)

    -- Track pending request
    self.pendingRequests[guildId] = GetTimeStamp()

    TC:Debug("SyncManager: Requested events from guild " .. guildId)
end

--- Handle incoming event request
--- @param guildId number Guild ID
--- @param message table Request message
--- @param sender string Sender account name
function SM:HandleEventRequest(guildId, message, sender)
    -- Get our guild events since the requested time
    local since = message.since or 0
    local events = self:GetGuildEventsToShare(guildId, since)

    if #events == 0 then
        return -- Nothing to share
    end

    -- Send in batches
    local page = 1
    for i = 1, #events, MAX_EVENTS_PER_MESSAGE do
        local batch = {}
        for j = i, math.min(i + MAX_EVENTS_PER_MESSAGE - 1, #events) do
            table.insert(batch, events[j])
        end

        local hasMore = (i + MAX_EVENTS_PER_MESSAGE - 1) < #events

        local response = {
            type = MSG_TYPE.BULK_EVENTS,
            guildId = guildId,
            events = batch,
            hasMore = hasMore,
            page = page,
        }

        self:QueueMessage(guildId, response)
        page = page + 1
    end

    TC:Debug("SyncManager: Sent " .. #events .. " events in " .. (page - 1) .. " messages")
end

--- Get guild events to share with others
--- @param guildId number Guild ID
--- @param since number Timestamp to filter by
--- @return table Array of events
function SM:GetGuildEventsToShare(guildId, since)
    if not TC.savedVars then return {} end

    local guildEvents = TC.savedVars.guildEvents or {}
    local guildCache = guildEvents[guildId]
    if not guildCache then return {} end

    -- EventManager stores events under guildEvents[guildId].events
    local events = guildCache.events or guildCache
    local result = {}

    local todayMidnight = DH.GetTodayMidnight()

    for eventId, event in pairs(events) do
        -- Only share future/today events that were updated since requested time
        if event.endTime >= todayMidnight then
            if event.updatedAt and event.updatedAt >= since then
                table.insert(result, event)
            elseif not event.updatedAt and event.createdAt and event.createdAt >= since then
                table.insert(result, event)
            end
        end
    end

    return result
end

-------------------------------------------------
-- Push Event
-------------------------------------------------

--- Push a single event to guild members
--- @param guildId number Guild ID
--- @param event table Event to push
function SM:PushEvent(guildId, event)
    if not self.initialized then return end

    -- Validate event
    local valid, err = self:ValidateEvent(event)
    if not valid then
        TC:Debug("SyncManager: Cannot push invalid event: " .. (err or "unknown"))
        return
    end

    local message = {
        type = MSG_TYPE.PUSH_EVENT,
        guildId = guildId,
        event = event,
    }

    self:QueueMessage(guildId, message)
    TC:Debug("SyncManager: Pushed event '" .. event.title .. "' to guild " .. guildId)
end

--- Handle incoming pushed event
--- @param guildId number Guild ID
--- @param message table Push message
--- @param sender string Sender account name
function SM:HandlePushEvent(guildId, message, sender)
    local event = message.event
    if not event then return end

    -- Validate
    local valid, err = self:ValidateEvent(event)
    if not valid then
        TC:Debug("SyncManager: Rejected invalid event from " .. sender .. ": " .. (err or "unknown"))
        return
    end

    -- Ensure guild ID matches
    event.guildId = guildId

    -- Merge into local storage
    self:MergeEvent(guildId, event)
end

-------------------------------------------------
-- Bulk Events
-------------------------------------------------

--- Handle incoming bulk events
--- @param guildId number Guild ID
--- @param message table Bulk message
--- @param sender string Sender account name
function SM:HandleBulkEvents(guildId, message, sender)
    local events = message.events
    if not events or type(events) ~= "table" then return end

    local merged = 0
    for _, event in ipairs(events) do
        local valid = self:ValidateEvent(event)
        if valid then
            event.guildId = guildId
            self:MergeEvent(guildId, event)
            merged = merged + 1
        end
    end

    TC:Debug("SyncManager: Merged " .. merged .. " events from " .. sender)

    -- Update last sync time
    self.lastSyncTime[guildId] = GetTimeStamp()

    -- Clear pending request
    self.pendingRequests[guildId] = nil

    -- Refresh UI if viewing guild events
    if TC.RefreshView then
        TC:RefreshView()
    end
end

-------------------------------------------------
-- Delete Event
-------------------------------------------------

--- Notify guild of deleted event
--- @param guildId number Guild ID
--- @param eventId string Event ID that was deleted
function SM:DeleteEvent(guildId, eventId)
    if not self.initialized then return end

    local message = {
        type = MSG_TYPE.DELETE_EVENT,
        guildId = guildId,
        eventId = eventId,
        deletedBy = GetDisplayName(),
    }

    self:QueueMessage(guildId, message)
    TC:Debug("SyncManager: Sent delete notification for event " .. eventId)
end

--- Handle incoming delete notification
--- @param guildId number Guild ID
--- @param message table Delete message
--- @param sender string Sender account name
function SM:HandleDeleteEvent(guildId, message, sender)
    local eventId = message.eventId
    if not eventId then return end

    -- Remove from local storage
    if TC.savedVars and TC.savedVars.guildEvents then
        local guildEvents = TC.savedVars.guildEvents[guildId]
        if guildEvents and guildEvents[eventId] then
            guildEvents[eventId] = nil
            TC:Debug("SyncManager: Deleted event " .. eventId .. " per " .. sender)

            -- Refresh UI
            if TC.RefreshView then
                TC:RefreshView()
            end
        end
    end
end

-------------------------------------------------
-- Settings Sync
-------------------------------------------------

--- Handle guild settings sync (for guild permissions)
--- @param guildId number Guild ID
--- @param message table Settings message
--- @param sender string Sender account name
function SM:HandleSyncSettings(guildId, message, sender)
    -- Only accept settings from guild master
    local guildMaster = GetGuildMasterDisplayName(guildId)
    if sender ~= guildMaster then
        TC:Debug("SyncManager: Rejected settings from non-master " .. sender)
        return
    end

    local settings = message.settings
    if not settings then return end

    -- Store guild settings
    if TC.savedVars then
        TC.savedVars.guildSettings = TC.savedVars.guildSettings or {}
        TC.savedVars.guildSettings[guildId] = settings
        TC:Debug("SyncManager: Updated settings for guild " .. guildId)
    end
end

--- Broadcast guild settings (guild master only)
--- @param guildId number Guild ID
--- @param settings table Settings to broadcast
function SM:BroadcastSettings(guildId, settings)
    if not self.initialized then return end

    local guildMaster = GetGuildMasterDisplayName(guildId)
    if GetDisplayName() ~= guildMaster then
        TC:Debug("SyncManager: Only guild master can broadcast settings")
        return
    end

    local message = {
        type = MSG_TYPE.SYNC_SETTINGS,
        guildId = guildId,
        settings = settings,
    }

    self:QueueMessage(guildId, message)
end

-------------------------------------------------
-- Event Merging
-------------------------------------------------

--- Merge an incoming event into local storage
--- @param guildId number Guild ID
--- @param incomingEvent table Event to merge
function SM:MergeEvent(guildId, incomingEvent)
    if not TC.savedVars then return end

    TC.savedVars.guildEvents = TC.savedVars.guildEvents or {}
    TC.savedVars.guildEvents[guildId] = TC.savedVars.guildEvents[guildId] or {}

    local events = TC.savedVars.guildEvents[guildId]
    local eventId = incomingEvent.eventId
    local existingEvent = events[eventId]

    if existingEvent then
        -- Conflict resolution: higher version wins
        if incomingEvent.version > (existingEvent.version or 0) then
            events[eventId] = incomingEvent
        elseif incomingEvent.version == (existingEvent.version or 0) then
            -- Same version: more recent update wins
            local incomingUpdated = incomingEvent.updatedAt or incomingEvent.createdAt or 0
            local existingUpdated = existingEvent.updatedAt or existingEvent.createdAt or 0
            if incomingUpdated > existingUpdated then
                events[eventId] = incomingEvent
            end
        end
        -- Otherwise keep existing
    else
        -- New event
        events[eventId] = incomingEvent
    end
end

-------------------------------------------------
-- Validation
-------------------------------------------------

--- Validate an event before sending/receiving
--- @param event table Event to validate
--- @return boolean, string|nil True if valid, error message otherwise
function SM:ValidateEvent(event)
    if not event then
        return false, "Event is nil"
    end

    if not event.eventId or type(event.eventId) ~= "string" then
        return false, "Missing or invalid eventId"
    end

    if not event.title or type(event.title) ~= "string" then
        return false, "Missing or invalid title"
    end

    if #event.title > MAX_TITLE_LENGTH then
        return false, "Title too long"
    end

    if event.description and #event.description > MAX_DESCRIPTION_LENGTH then
        return false, "Description too long"
    end

    if not event.startTime or type(event.startTime) ~= "number" then
        return false, "Missing or invalid startTime"
    end

    if not event.endTime or type(event.endTime) ~= "number" then
        return false, "Missing or invalid endTime"
    end

    if event.startTime >= event.endTime then
        return false, "Invalid time range"
    end

    return true
end

--- Sanitize event text fields
--- @param event table Event to sanitize
--- @return table Sanitized event
function SM:SanitizeEvent(event)
    local sanitized = {}

    for k, v in pairs(event) do
        sanitized[k] = v
    end

    -- Truncate long strings
    if sanitized.title and #sanitized.title > MAX_TITLE_LENGTH then
        sanitized.title = sanitized.title:sub(1, MAX_TITLE_LENGTH)
    end

    if sanitized.description and #sanitized.description > MAX_DESCRIPTION_LENGTH then
        sanitized.description = sanitized.description:sub(1, MAX_DESCRIPTION_LENGTH)
    end

    return sanitized
end

-------------------------------------------------
-- Public API
-------------------------------------------------

--- Check if sync is available
--- @return boolean True if sync is ready
function SM:IsAvailable()
    return self.initialized
end

--- Sync events for a specific guild
--- @param guildId number Guild ID
function SM:SyncGuild(guildId)
    if not self.initialized then
        d("[TamCal] Guild sync not available - missing libraries")
        return
    end

    self:RequestEvents(guildId)
    d("[TamCal] Syncing events for guild...")
end

--- Sync all subscribed guilds
function SM:SyncAllGuilds()
    if not self.initialized then return end

    if not TC.savedVars then return end

    local subscriptions = TC.savedVars.guildSubscriptions or {}

    for guildId, subscribed in pairs(subscriptions) do
        if subscribed then
            self:RequestEvents(guildId)
        end
    end
end

--- Called when a guild event is created or updated
--- @param event table The event
function SM:OnEventChanged(event)
    if not self.initialized then return end

    if event.guildId then
        self:PushEvent(event.guildId, event)
    end
end

--- Called when a guild event is deleted
--- @param guildId number Guild ID
--- @param eventId string Event ID
function SM:OnEventDeleted(guildId, eventId)
    if not self.initialized then return end

    self:DeleteEvent(guildId, eventId)
end

-------------------------------------------------
-- Hook into EventManager
-------------------------------------------------

-- These hooks are set up by EventManager when it loads

-------------------------------------------------
-- Initialization Hook
-------------------------------------------------

-- Initialize when addon loads
local function OnPlayerActivated()
    zo_callLater(function()
        SM:Initialize()
    end, 300) -- After UI modules
end

EVENT_MANAGER:RegisterForEvent(TC.name .. "_SyncManager", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
