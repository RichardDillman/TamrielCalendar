--[[
    EventManager.lua
    CRUD operations for personal and guild events

    Handles:
    - Creating, updating, deleting events
    - Querying events by date range
    - Attendee management for guild events
    - Event validation
]]

local TC = TamrielCalendar
local DH = TC.DateHelpers

TC.EventManager = {}
local EM = TC.EventManager

-------------------------------------------------
-- Validation
-------------------------------------------------

--- Validate event data before create/update
--- @param eventData table Event data to validate
--- @return boolean, string|nil Success and error message
function EM:ValidateEvent(eventData)
    -- Required fields
    if not eventData.title or eventData.title == "" then
        return false, "Title is required"
    end

    if not eventData.startTime or type(eventData.startTime) ~= "number" then
        return false, "Start time is required"
    end

    if not eventData.endTime or type(eventData.endTime) ~= "number" then
        return false, "End time is required"
    end

    -- End time must be after start time
    if eventData.endTime <= eventData.startTime then
        return false, "End time must be after start time"
    end

    -- Category must be valid
    local validCategories = {
        Raid = true,
        Party = true,
        Training = true,
        Meeting = true,
        Personal = true,
    }
    if eventData.category and not validCategories[eventData.category] then
        return false, "Invalid category"
    end

    -- Max attendees must be non-negative
    if eventData.maxAttendees and eventData.maxAttendees < 0 then
        return false, "Max attendees cannot be negative"
    end

    return true, nil
end

-------------------------------------------------
-- Personal Events
-------------------------------------------------

--- Create a new personal event
--- @param eventData table Event data (title, description, startTime, endTime, category)
--- @return table|nil, string|nil Created event or nil, error message
function EM:CreatePersonalEvent(eventData)
    -- Validate
    local valid, err = self:ValidateEvent(eventData)
    if not valid then
        return nil, err
    end

    -- Generate event
    local event = {
        eventId = TC:GenerateEventId(),
        title = eventData.title,
        description = eventData.description or "",
        startTime = eventData.startTime,
        endTime = eventData.endTime,
        category = eventData.category or TC.CATEGORIES.PERSONAL,
        guildId = nil, -- Personal events have no guild
        createdBy = TC:GetAccountName(),
        version = 1,
        createdAt = GetTimeStamp(),
        updatedAt = GetTimeStamp(),
    }

    -- Store
    TC.savedVars.events[event.eventId] = event

    TC:Debug("Created personal event:", event.eventId, event.title)

    return event, nil
end

--- Update an existing personal event
--- @param eventId string Event ID
--- @param updates table Fields to update
--- @return table|nil, string|nil Updated event or nil, error message
function EM:UpdatePersonalEvent(eventId, updates)
    local event = TC.savedVars.events[eventId]
    if not event then
        return nil, "Event not found"
    end

    -- Check ownership
    if event.createdBy ~= TC:GetAccountName() then
        return nil, "Cannot edit events you didn't create"
    end

    -- Merge updates
    local updated = {}
    for k, v in pairs(event) do
        updated[k] = v
    end
    for k, v in pairs(updates) do
        if k ~= "eventId" and k ~= "createdBy" and k ~= "createdAt" and k ~= "guildId" then
            updated[k] = v
        end
    end

    -- Validate
    local valid, err = self:ValidateEvent(updated)
    if not valid then
        return nil, err
    end

    -- Update metadata
    updated.version = event.version + 1
    updated.updatedAt = GetTimeStamp()

    -- Store
    TC.savedVars.events[eventId] = updated

    TC:Debug("Updated personal event:", eventId)

    return updated, nil
end

--- Delete a personal event
--- @param eventId string Event ID
--- @return boolean, string|nil Success and error message
function EM:DeletePersonalEvent(eventId)
    local event = TC.savedVars.events[eventId]
    if not event then
        return false, "Event not found"
    end

    -- Check ownership
    if event.createdBy ~= TC:GetAccountName() then
        return false, "Cannot delete events you didn't create"
    end

    TC.savedVars.events[eventId] = nil

    TC:Debug("Deleted personal event:", eventId)

    return true, nil
end

--- Get a personal event by ID
--- @param eventId string Event ID
--- @return table|nil Event or nil
function EM:GetPersonalEvent(eventId)
    return TC.savedVars.events[eventId]
end

--- Get all personal events
--- @return table Array of events
function EM:GetAllPersonalEvents()
    local events = {}
    for _, event in pairs(TC.savedVars.events) do
        table.insert(events, event)
    end
    return events
end

-------------------------------------------------
-- Guild Events
-------------------------------------------------

--- Get guild events cache for a guild
--- @param guildId number Guild ID
--- @return table Guild event cache {events = {}, lastSync = number}
local function GetGuildCache(guildId)
    if not TC.savedVars.guildEvents[guildId] then
        TC.savedVars.guildEvents[guildId] = {
            events = {},
            lastSync = 0,
        }
    end
    return TC.savedVars.guildEvents[guildId]
end

--- Create a new guild event
--- @param guildId number Guild ID
--- @param eventData table Event data
--- @return table|nil, string|nil Created event or nil, error message
function EM:CreateGuildEvent(guildId, eventData)
    -- Validate
    local valid, err = self:ValidateEvent(eventData)
    if not valid then
        return nil, err
    end

    -- Generate event
    local event = {
        eventId = TC:GenerateEventId(),
        title = eventData.title,
        description = eventData.description or "",
        startTime = eventData.startTime,
        endTime = eventData.endTime,
        category = eventData.category or TC.CATEGORIES.MEETING,
        guildId = guildId,
        createdBy = TC:GetAccountName(),

        -- Guild-specific fields
        requiresApproval = eventData.requiresApproval or false,
        maxAttendees = eventData.maxAttendees or 0,

        -- Raid-specific fields (optional)
        raidTrial = eventData.raidTrial,
        raidModifier = eventData.raidModifier,

        -- Attendees
        attendees = {},

        -- Metadata
        version = 1,
        createdAt = GetTimeStamp(),
        updatedAt = GetTimeStamp(),
    }

    -- Auto sign-up creator as first attendee (if they specified a role)
    if eventData.creatorRole then
        event.attendees[TC:GetAccountName()] = {
            role = eventData.creatorRole,
            status = TC.SIGNUP_STATUS.CONFIRMED,
            signedUpAt = GetTimeStamp(),
        }
    end

    -- Store
    local cache = GetGuildCache(guildId)
    cache.events[event.eventId] = event

    TC:Debug("Created guild event:", event.eventId, event.title, "for guild", guildId)

    -- Sync to guild
    local SM = TC.SyncManager
    if SM and SM.OnEventChanged then
        SM:OnEventChanged(event)
    end

    return event, nil
end

--- Update an existing guild event
--- @param guildId number Guild ID
--- @param eventId string Event ID
--- @param updates table Fields to update
--- @return table|nil, string|nil Updated event or nil, error message
function EM:UpdateGuildEvent(guildId, eventId, updates)
    local cache = GetGuildCache(guildId)
    local event = cache.events[eventId]

    if not event then
        return nil, "Event not found"
    end

    -- Merge updates (preserve certain fields)
    local updated = {}
    for k, v in pairs(event) do
        updated[k] = v
    end
    for k, v in pairs(updates) do
        if k ~= "eventId" and k ~= "createdBy" and k ~= "createdAt" and k ~= "guildId" and k ~= "attendees" then
            updated[k] = v
        end
    end

    -- Validate
    local valid, err = self:ValidateEvent(updated)
    if not valid then
        return nil, err
    end

    -- Update metadata
    updated.version = event.version + 1
    updated.updatedAt = GetTimeStamp()

    -- Store
    cache.events[eventId] = updated

    TC:Debug("Updated guild event:", eventId)

    -- Sync to guild
    local SM = TC.SyncManager
    if SM and SM.OnEventChanged then
        SM:OnEventChanged(updated)
    end

    return updated, nil
end

--- Delete a guild event
--- @param guildId number Guild ID
--- @param eventId string Event ID
--- @return boolean, string|nil Success and error message
function EM:DeleteGuildEvent(guildId, eventId)
    local cache = GetGuildCache(guildId)
    local event = cache.events[eventId]

    if not event then
        return false, "Event not found"
    end

    cache.events[eventId] = nil

    TC:Debug("Deleted guild event:", eventId)

    -- Sync deletion to guild
    local SM = TC.SyncManager
    if SM and SM.OnEventDeleted then
        SM:OnEventDeleted(guildId, eventId)
    end

    return true, nil
end

--- Get a guild event by ID
--- @param guildId number Guild ID
--- @param eventId string Event ID
--- @return table|nil Event or nil
function EM:GetGuildEvent(guildId, eventId)
    local cache = GetGuildCache(guildId)
    return cache.events[eventId]
end

--- Get all events for a guild
--- @param guildId number Guild ID
--- @return table Array of events
function EM:GetAllGuildEvents(guildId)
    local cache = GetGuildCache(guildId)
    local events = {}
    for _, event in pairs(cache.events) do
        table.insert(events, event)
    end
    return events
end

--- Merge received guild event into cache (for sync)
--- @param guildId number Guild ID
--- @param eventData table Event from another player
--- @return boolean Whether event was updated
function EM:MergeGuildEvent(guildId, eventData)
    local cache = GetGuildCache(guildId)
    local existing = cache.events[eventData.eventId]

    -- New event
    if not existing then
        cache.events[eventData.eventId] = eventData
        TC:Debug("Merged new guild event:", eventData.eventId)
        return true
    end

    -- Conflict resolution: higher version wins, or later updatedAt if versions equal
    if eventData.version > existing.version then
        cache.events[eventData.eventId] = eventData
        TC:Debug("Merged updated guild event:", eventData.eventId, "v" .. eventData.version)
        return true
    elseif eventData.version == existing.version and eventData.updatedAt > existing.updatedAt then
        cache.events[eventData.eventId] = eventData
        TC:Debug("Merged guild event (same version, later timestamp):", eventData.eventId)
        return true
    end

    return false
end

--- Mark a guild event as deleted (for sync)
--- @param guildId number Guild ID
--- @param eventId string Event ID
--- @param deletedVersion number Version when deleted
--- @return boolean Whether event was deleted
function EM:MarkGuildEventDeleted(guildId, eventId, deletedVersion)
    local cache = GetGuildCache(guildId)
    local existing = cache.events[eventId]

    if existing and deletedVersion >= existing.version then
        cache.events[eventId] = nil
        TC:Debug("Removed deleted guild event:", eventId)
        return true
    end

    return false
end

-------------------------------------------------
-- Attendee Management
-------------------------------------------------

--- Sign up for a guild event
--- @param guildId number Guild ID
--- @param eventId string Event ID
--- @param role string Role (Tank, Healer, DPS)
--- @return boolean, string|nil Success and error message
function EM:SignUp(guildId, eventId, role)
    local cache = GetGuildCache(guildId)
    local event = cache.events[eventId]

    if not event then
        return false, "Event not found"
    end

    -- Validate role
    if role ~= TC.ROLES.TANK and role ~= TC.ROLES.HEALER and role ~= TC.ROLES.DPS then
        return false, "Invalid role"
    end

    -- Check if already signed up
    local accountName = TC:GetAccountName()
    if event.attendees[accountName] then
        return false, "Already signed up"
    end

    -- Check max attendees
    if event.maxAttendees > 0 then
        local confirmedCount = 0
        for _, attendee in pairs(event.attendees) do
            if attendee.status == TC.SIGNUP_STATUS.CONFIRMED then
                confirmedCount = confirmedCount + 1
            end
        end
        if confirmedCount >= event.maxAttendees then
            return false, "Event is full"
        end
    end

    -- Determine status
    local status = event.requiresApproval and TC.SIGNUP_STATUS.PENDING or TC.SIGNUP_STATUS.CONFIRMED

    -- Add attendee
    event.attendees[accountName] = {
        role = role,
        status = status,
        signedUpAt = GetTimeStamp(),
    }

    event.version = event.version + 1
    event.updatedAt = GetTimeStamp()

    TC:Debug("Signed up for event:", eventId, "as", role, "status:", status)

    -- Sync to guild
    local SM = TC.SyncManager
    if SM and SM.OnEventChanged then
        SM:OnEventChanged(event)
    end

    return true, nil
end

--- Withdraw from a guild event
--- @param guildId number Guild ID
--- @param eventId string Event ID
--- @return boolean, string|nil Success and error message
function EM:Withdraw(guildId, eventId)
    local cache = GetGuildCache(guildId)
    local event = cache.events[eventId]

    if not event then
        return false, "Event not found"
    end

    local accountName = TC:GetAccountName()
    if not event.attendees[accountName] then
        return false, "Not signed up"
    end

    event.attendees[accountName] = nil
    event.version = event.version + 1
    event.updatedAt = GetTimeStamp()

    TC:Debug("Withdrew from event:", eventId)

    -- Sync to guild
    local SM = TC.SyncManager
    if SM and SM.OnEventChanged then
        SM:OnEventChanged(event)
    end

    return true, nil
end

--- Kick an attendee from a guild event
--- @param guildId number Guild ID
--- @param eventId string Event ID
--- @param accountName string Account to kick
--- @return boolean, string|nil Success and error message
function EM:KickAttendee(guildId, eventId, accountName)
    local cache = GetGuildCache(guildId)
    local event = cache.events[eventId]

    if not event then
        return false, "Event not found"
    end

    if not event.attendees[accountName] then
        return false, "Attendee not found"
    end

    event.attendees[accountName] = nil
    event.version = event.version + 1
    event.updatedAt = GetTimeStamp()

    TC:Debug("Kicked attendee:", accountName, "from event:", eventId)

    -- Sync to guild
    local SM = TC.SyncManager
    if SM and SM.OnEventChanged then
        SM:OnEventChanged(event)
    end

    return true, nil
end

--- Approve a pending attendee
--- @param guildId number Guild ID
--- @param eventId string Event ID
--- @param accountName string Account to approve
--- @return boolean, string|nil Success and error message
function EM:ApproveAttendee(guildId, eventId, accountName)
    local cache = GetGuildCache(guildId)
    local event = cache.events[eventId]

    if not event then
        return false, "Event not found"
    end

    local attendee = event.attendees[accountName]
    if not attendee then
        return false, "Attendee not found"
    end

    if attendee.status ~= TC.SIGNUP_STATUS.PENDING then
        return false, "Attendee is not pending"
    end

    attendee.status = TC.SIGNUP_STATUS.CONFIRMED
    event.version = event.version + 1
    event.updatedAt = GetTimeStamp()

    TC:Debug("Approved attendee:", accountName, "for event:", eventId)

    -- Sync to guild
    local SM = TC.SyncManager
    if SM and SM.OnEventChanged then
        SM:OnEventChanged(event)
    end

    return true, nil
end

--- Deny a pending attendee
--- @param guildId number Guild ID
--- @param eventId string Event ID
--- @param accountName string Account to deny
--- @return boolean, string|nil Success and error message
function EM:DenyAttendee(guildId, eventId, accountName)
    -- Deny is effectively the same as kick
    return self:KickAttendee(guildId, eventId, accountName)
end

--- Check if current player is signed up for an event
--- @param guildId number Guild ID
--- @param eventId string Event ID
--- @return boolean, table|nil Is signed up, attendee info
function EM:IsSignedUp(guildId, eventId)
    local cache = GetGuildCache(guildId)
    local event = cache.events[eventId]

    if not event then
        return false, nil
    end

    local accountName = TC:GetAccountName()
    local attendee = event.attendees[accountName]

    return attendee ~= nil, attendee
end

--- Get attendee counts by role
--- @param event table Event with attendees
--- @return table Counts {Tank = n, Healer = n, DPS = n, total = n, pending = n}
function EM:GetAttendeeCounts(event)
    local counts = {
        Tank = 0,
        Healer = 0,
        DPS = 0,
        total = 0,
        pending = 0,
    }

    if not event.attendees then
        return counts
    end

    for _, attendee in pairs(event.attendees) do
        if attendee.status == TC.SIGNUP_STATUS.CONFIRMED then
            counts[attendee.role] = (counts[attendee.role] or 0) + 1
            counts.total = counts.total + 1
        elseif attendee.status == TC.SIGNUP_STATUS.PENDING then
            counts.pending = counts.pending + 1
        end
    end

    return counts
end

--- Get attendees list sorted by sign-up time
--- @param event table Event with attendees
--- @param statusFilter string|nil Filter by status (optional)
--- @return table Array of {accountName, role, status, signedUpAt}
function EM:GetAttendeeList(event, statusFilter)
    local list = {}

    if not event.attendees then
        return list
    end

    for accountName, attendee in pairs(event.attendees) do
        if not statusFilter or attendee.status == statusFilter then
            table.insert(list, {
                accountName = accountName,
                role = attendee.role,
                status = attendee.status,
                signedUpAt = attendee.signedUpAt,
            })
        end
    end

    -- Sort by sign-up time
    table.sort(list, function(a, b)
        return a.signedUpAt < b.signedUpAt
    end)

    return list
end

-------------------------------------------------
-- Query Functions
-------------------------------------------------

--- Get events for a specific day (personal + guild)
--- @param timestamp number Any timestamp within the day
--- @param includeGuilds table|nil Array of guild IDs to include (nil = all)
--- @return table Array of events
function EM:GetEventsForDay(timestamp, includeGuilds)
    local dayStart = DH.StartOfDay(timestamp)
    local dayEnd = DH.EndOfDay(timestamp)

    return self:GetEventsForRange(dayStart, dayEnd, includeGuilds)
end

--- Get events for a date range
--- @param rangeStart number Start timestamp
--- @param rangeEnd number End timestamp
--- @param includeGuilds table|nil Array of guild IDs to include (nil = all)
--- @return table Array of events sorted by start time
function EM:GetEventsForRange(rangeStart, rangeEnd, includeGuilds)
    local events = {}
    local prefs = TC.savedVars.preferences

    -- Personal events
    if prefs.showPersonalEvents then
        for _, event in pairs(TC.savedVars.events) do
            if DH.RangesOverlap(event.startTime, event.endTime, rangeStart, rangeEnd) then
                if prefs.categoryFilters[event.category] ~= false then
                    table.insert(events, event)
                end
            end
        end
    end

    -- Guild events
    if prefs.showGuildEvents then
        local guilds = includeGuilds or {}

        -- If no specific guilds provided, get all cached guilds
        if #guilds == 0 then
            for guildId, _ in pairs(TC.savedVars.guildEvents) do
                table.insert(guilds, guildId)
            end
        end

        for _, guildId in ipairs(guilds) do
            local cache = TC.savedVars.guildEvents[guildId]
            if cache and cache.events then
                for _, event in pairs(cache.events) do
                    if DH.RangesOverlap(event.startTime, event.endTime, rangeStart, rangeEnd) then
                        if prefs.categoryFilters[event.category] ~= false then
                            table.insert(events, event)
                        end
                    end
                end
            end
        end
    end

    -- Sort by start time
    table.sort(events, function(a, b)
        return a.startTime < b.startTime
    end)

    return events
end

--- Get events for a specific month (for month view rendering)
--- @param year number Year
--- @param month number Month (1-12)
--- @param includeGuilds table|nil Array of guild IDs to include (nil = all)
--- @return table Array of events
function EM:GetEventsForMonth(year, month, includeGuilds)
    local monthStart = DH.MakeTimestamp(year, month, 1, 0, 0)
    local daysInMonth = DH.DaysInMonth(year, month)
    local monthEnd = DH.MakeTimestamp(year, month, daysInMonth, 23, 59)

    return self:GetEventsForRange(monthStart, monthEnd, includeGuilds)
end

--- Get upcoming events (next N days)
--- @param days number Number of days to look ahead
--- @param limit number|nil Maximum events to return
--- @param includeGuilds table|nil Array of guild IDs to include (nil = all)
--- @return table Array of events
function EM:GetUpcomingEvents(days, limit, includeGuilds)
    local now = GetTimeStamp()
    local rangeEnd = now + (days * DH.SECONDS_PER_DAY)

    local events = self:GetEventsForRange(now, rangeEnd, includeGuilds)

    if limit and #events > limit then
        local limited = {}
        for i = 1, limit do
            limited[i] = events[i]
        end
        return limited
    end

    return events
end

-------------------------------------------------
-- Event Helpers
-------------------------------------------------

--- Check if an event is a guild event
--- @param event table Event
--- @return boolean Is guild event
function EM:IsGuildEvent(event)
    return event.guildId ~= nil
end

--- Check if current player is the creator of an event
--- @param event table Event
--- @return boolean Is creator
function EM:IsEventCreator(event)
    return event.createdBy == TC:GetAccountName()
end

--- Get display title for a raid event (including trial info)
--- @param event table Event
--- @return string Display title
function EM:GetRaidDisplayTitle(event)
    if event.category ~= TC.CATEGORIES.RAID then
        return event.title
    end

    if event.raidTrial then
        local trial = TC:GetTrialById(event.raidTrial)
        local mod = TC:GetModifierById(event.raidModifier)

        if trial then
            local prefix = mod and mod.prefix or ""
            local suffix = mod and mod.suffix or ""
            local shortTitle = prefix .. trial.id .. suffix

            -- If title is just the auto-generated short form, show full name in parentheses
            if event.title == shortTitle then
                return string.format("%s (%s)", shortTitle, trial.name)
            end
        end
    end

    return event.title
end
