--[[
    TamrielCalendar.lua
    Main addon bootstrap - initializes SavedVariables, registers events and slash commands

    This file runs after DateHelpers.lua and EventManager.lua are loaded.
]]

-- Addon namespace (already created by DateHelpers.lua)
local TC = TamrielCalendar
local DH = TC.DateHelpers

-------------------------------------------------
-- Addon Info
-------------------------------------------------

TC.name = "TamrielCalendar"
TC.version = "0.1.0"
TC.author = "@RichardDillman"
TC.savedVarsVersion = 1

-------------------------------------------------
-- Constants
-------------------------------------------------

TC.CATEGORIES = {
    RAID = "Raid",
    PARTY = "Party",
    TRAINING = "Training",
    MEETING = "Meeting",
    PERSONAL = "Personal",
}

TC.CATEGORY_COLORS = {
    Raid = {r = 1.0, g = 0.4, b = 0.4},      -- Red
    Party = {r = 0.4, g = 0.6, b = 1.0},     -- Blue
    Training = {r = 0.4, g = 1.0, b = 0.4},  -- Green
    Meeting = {r = 1.0, g = 0.8, b = 0.4},   -- Gold
    Personal = {r = 0.6, g = 0.4, b = 1.0},  -- Purple
}

TC.ROLES = {
    TANK = "Tank",
    HEALER = "Healer",
    DPS = "DPS",
}

TC.SIGNUP_STATUS = {
    CONFIRMED = "confirmed",
    PENDING = "pending",
}

TC.VIEW_MODES = {
    DAY = "DAY",
    WEEK = "WEEK",
    MONTH = "MONTH",
}

-- Trial definitions (for raid events)
TC.TRIALS = {
    { id = "AA",  name = "Aetherian Archive" },
    { id = "HRC", name = "Hel Ra Citadel" },
    { id = "SO",  name = "Sanctum Ophidia" },
    { id = "MOL", name = "Maw of Lorkhaj" },
    { id = "HOF", name = "Halls of Fabrication" },
    { id = "AS",  name = "Asylum Sanctorium" },
    { id = "CR",  name = "Cloudrest" },
    { id = "SS",  name = "Sunspire" },
    { id = "KA",  name = "Kyne's Aegis" },
    { id = "RG",  name = "Rockgrove" },
    { id = "DSR", name = "Dreadsail Reef" },
    { id = "SE",  name = "Sanity's Edge" },
    { id = "OC",  name = "Osseous Cage" },
    { id = "LC",  name = "Lucent Citadel" },
}

-- Difficulty modifiers
TC.MODIFIERS = {
    { id = "N",   name = "Normal",    prefix = "n" },
    { id = "VET", name = "Veteran",   prefix = "v" },
    { id = "HM",  name = "Hard Mode", prefix = "v", suffix = " HM" },
    { id = "SR",  name = "Speed Run", prefix = "v", suffix = " SR" },
    { id = "ND",  name = "No Death",  prefix = "v", suffix = " ND" },
}

-------------------------------------------------
-- SavedVariables Defaults
-------------------------------------------------

local SV_DEFAULTS = {
    version = 1,

    -- Personal events (never synced)
    events = {},

    -- Guild events (cached from sync)
    guildEvents = {},

    -- Guild settings (from guild master)
    guildSettings = {},

    -- Guild subscriptions (which guilds to show events from)
    guildSubscriptions = {},

    -- User preferences
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

-------------------------------------------------
-- State
-------------------------------------------------

TC.savedVars = nil
TC.initialized = false
TC.currentView = nil
TC.currentYear = nil
TC.currentMonth = nil
TC.selectedDate = nil

-------------------------------------------------
-- Utility Functions
-------------------------------------------------

--- Deep copy a table
--- @param orig table Original table
--- @return table Copy of the table
local function DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[DeepCopy(k)] = DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

--- Debug logging
--- @param ... any Values to log
function TC:Debug(...)
    if self.savedVars and self.savedVars.debugMode then
        d("[TamCal]", ...)
    end
end

--- Get the current player's account name
--- @return string Account name with @ prefix
function TC:GetAccountName()
    return GetDisplayName()
end

--- Generate a unique event ID
--- @return string Unique event ID
function TC:GenerateEventId()
    local account = self:GetAccountName():gsub("@", "")
    local time = GetTimeStamp()
    local rand = math.random(1000, 9999)
    return string.format("%s-%d-%d", account, time, rand)
end

-------------------------------------------------
-- SavedVariables
-------------------------------------------------

--- Initialize or load SavedVariables
local function InitializeSavedVariables()
    -- Use ZO_SavedVars for account-wide storage
    TC.savedVars = ZO_SavedVars:NewAccountWide(
        "TamrielCalendar_SV",
        TC.savedVarsVersion,
        nil,
        DeepCopy(SV_DEFAULTS)
    )

    -- Run migrations if needed
    TC:MigrateSavedVars()

    TC:Debug("SavedVariables initialized")
end

--- Run any necessary migrations on SavedVariables
function TC:MigrateSavedVars()
    local sv = self.savedVars
    local version = sv.version or 0

    if version < 1 then
        -- Initial schema setup
        sv.version = 1
        sv.events = sv.events or {}
        sv.guildEvents = sv.guildEvents or {}
        sv.guildSettings = sv.guildSettings or {}
        sv.preferences = sv.preferences or DeepCopy(SV_DEFAULTS.preferences)
        self:Debug("Migrated to version 1")
    end

    -- Future migrations:
    -- if version < 2 then
    --     -- v2 migration logic
    --     sv.version = 2
    -- end
end

-------------------------------------------------
-- Event Purging
-------------------------------------------------

--- Purge events that ended before today
function TC:PurgeOldEvents()
    local todayMidnight = DH.GetTodayMidnight()
    local purgedCount = 0

    -- Purge personal events
    for eventId, event in pairs(self.savedVars.events) do
        if event.endTime < todayMidnight then
            self.savedVars.events[eventId] = nil
            purgedCount = purgedCount + 1
        end
    end

    -- Purge guild events
    for guildId, guildData in pairs(self.savedVars.guildEvents) do
        if guildData.events then
            for eventId, event in pairs(guildData.events) do
                if event.endTime < todayMidnight then
                    guildData.events[eventId] = nil
                    purgedCount = purgedCount + 1
                end
            end
        end
    end

    if purgedCount > 0 then
        self:Debug("Purged", purgedCount, "old events")
    end
end

-------------------------------------------------
-- Preferences
-------------------------------------------------

--- Get a preference value
--- @param key string Preference key
--- @return any Preference value
function TC:GetPreference(key)
    return self.savedVars.preferences[key]
end

--- Set a preference value
--- @param key string Preference key
--- @param value any Preference value
function TC:SetPreference(key, value)
    self.savedVars.preferences[key] = value
end

-------------------------------------------------
-- Category Colors
-------------------------------------------------

--- Get color for a category
--- @param category string Category name
--- @return table RGB color table {r, g, b}
function TC:GetCategoryColor(category)
    return self.CATEGORY_COLORS[category] or {r = 0.8, g = 0.8, b = 0.8}
end

--- Get color as hex string for a category
--- @param category string Category name
--- @return string Hex color string like "FF6666"
function TC:GetCategoryColorHex(category)
    local c = self:GetCategoryColor(category)
    return string.format("%02X%02X%02X", c.r * 255, c.g * 255, c.b * 255)
end

-------------------------------------------------
-- Trial Helpers
-------------------------------------------------

--- Get trial info by ID
--- @param trialId string Trial short code
--- @return table|nil Trial info {id, name}
function TC:GetTrialById(trialId)
    for _, trial in ipairs(self.TRIALS) do
        if trial.id == trialId then
            return trial
        end
    end
    return nil
end

--- Get modifier info by ID
--- @param modifierId string Modifier short code
--- @return table|nil Modifier info {id, name, prefix, suffix}
function TC:GetModifierById(modifierId)
    for _, mod in ipairs(self.MODIFIERS) do
        if mod.id == modifierId then
            return mod
        end
    end
    return nil
end

--- Suggest a raid title based on trial and modifier
--- @param trialId string Trial short code
--- @param modifierId string Modifier short code
--- @return string|nil Suggested title
function TC:SuggestRaidTitle(trialId, modifierId)
    local trial = self:GetTrialById(trialId)
    if not trial then return nil end

    local mod = self:GetModifierById(modifierId)
    if not mod then
        return trial.id
    end

    local title = (mod.prefix or "") .. trial.id .. (mod.suffix or "")
    return title
end

-------------------------------------------------
-- Slash Command
-------------------------------------------------

--- Handle /tamcal slash command
--- @param args string Command arguments
local function SlashCommandHandler(args)
    args = args:lower():gsub("^%s+", ""):gsub("%s+$", "")

    if args == "debug" then
        TC.savedVars.debugMode = not TC.savedVars.debugMode
        d("[TamCal] Debug mode:", TC.savedVars.debugMode and "ON" or "OFF")
    elseif args == "reset" then
        TC.savedVars.preferences.windowPosition = { x = 100, y = 100 }
        d("[TamCal] Window position reset")
    elseif args == "purge" then
        TC:PurgeOldEvents()
        d("[TamCal] Old events purged")
    elseif args == "help" or args == "?" then
        d("[TamCal] Commands:")
        d("  /tamcal - Open/close calendar")
        d("  /tamcal debug - Toggle debug mode")
        d("  /tamcal reset - Reset window position")
        d("  /tamcal purge - Manually purge old events")
    else
        -- Toggle calendar window
        TC:ToggleCalendar()
    end
end

-------------------------------------------------
-- Calendar Window Control
-------------------------------------------------

--- Toggle the calendar window visibility
function TC:ToggleCalendar()
    if TamCalWindow then
        TamCalWindow:SetHidden(not TamCalWindow:IsHidden())
        if not TamCalWindow:IsHidden() then
            self:RefreshView()
        end
    else
        d("[TamCal] Calendar window not initialized yet")
    end
end

--- Show the calendar window
function TC:ShowCalendar()
    if TamCalWindow then
        TamCalWindow:SetHidden(false)
        self:RefreshView()
    end
end

--- Hide the calendar window
function TC:HideCalendar()
    if TamCalWindow then
        TamCalWindow:SetHidden(true)
    end
end

--- Refresh the current view
function TC:RefreshView()
    -- This will be implemented by UI modules
    -- Placeholder for now
    self:Debug("RefreshView called")
end

-------------------------------------------------
-- View State Management
-------------------------------------------------

--- Set the current calendar view
--- @param viewMode string VIEW_MODES value
function TC:SetView(viewMode)
    self.currentView = viewMode
    self.savedVars.preferences.defaultView = viewMode
    self:RefreshView()
end

--- Navigate to a specific month
--- @param year number Year
--- @param month number Month (1-12)
function TC:GoToMonth(year, month)
    self.currentYear = year
    self.currentMonth = month
    self:RefreshView()
end

--- Navigate to the previous month
function TC:PrevMonth()
    local year, month = DH.AddMonth(self.currentYear, self.currentMonth, -1)
    self:GoToMonth(year, month)
end

--- Navigate to the next month
function TC:NextMonth()
    local year, month = DH.AddMonth(self.currentYear, self.currentMonth, 1)
    self:GoToMonth(year, month)
end

--- Navigate to today and switch to Day view
function TC:GoToToday()
    local t = os.date("*t", GetTimeStamp())
    self:GoToMonth(t.year, t.month)
    self.selectedDate = DH.GetTodayMidnight()
    self:SetView(self.VIEW_MODES.DAY)
end

--- Switch to Month view
function TC:OnMonthViewClicked()
    self:SetView(self.VIEW_MODES.MONTH)
    PlaySound(SOUNDS.POSITIVE_CLICK)
end

--- Select a specific date
--- @param timestamp number Unix timestamp for the date
function TC:SelectDate(timestamp)
    self.selectedDate = DH.StartOfDay(timestamp)
    self:RefreshView()
end

-------------------------------------------------
-- Window Position
-------------------------------------------------

--- Handle window move stop
--- @param control control The window control
function TC:OnWindowMoveStop(control)
    local x, y = control:GetScreenRect()
    self:SetPreference("windowPosition", {x = x, y = y})
    self:Debug("Window position saved:", x, y)
end

-------------------------------------------------
-- Dialog Handlers
-------------------------------------------------

--- Show the new event form
function TC:OnNewEventClicked()
    self:ShowEventForm()
end

--- Show the event form (create mode)
function TC:ShowEventForm(event)
    if TamCalEventForm then
        -- Set form title
        local title = TamCalEventFormHeaderTitle
        if title then
            title:SetText(event and "Edit Event" or "Create Event")
        end

        -- Store editing event (nil for create)
        self.editingEvent = event

        -- Set default values
        local contentTitle = TamCalEventFormContentTitleInput
        if contentTitle then
            contentTitle:SetText(event and event.title or "")
        end

        local contentDesc = TamCalEventFormContentDescInput
        if contentDesc then
            contentDesc:SetText(event and event.description or "")
        end

        -- Set time dropdown values
        if event then
            -- Convert event start time to 12-hour format
            local hour12, minute, ampm = self:TimestampTo12Hour(event.startTime)
            self:SetTimeDropdowns(hour12, minute, ampm)
            self.eventFormDate = DH.StartOfDay(event.startTime)
        else
            -- Default to 7:00 PM on selected date
            self:SetTimeDropdowns(7, 0, "PM")
            self.eventFormDate = self.selectedDate or DH.GetTodayMidnight()
        end

        TamCalEventForm:SetHidden(false)
    end
end

-------------------------------------------------
-- Time Dropdown State
-------------------------------------------------

TC.eventFormHour = 7      -- 1-12 for 12-hour format
TC.eventFormMinute = 0    -- 0, 15, 30, 45
TC.eventFormAmPm = "PM"   -- "AM" or "PM"

--- Initialize the time dropdowns in the event form
function TC:InitializeTimeDropdowns()
    -- Hour Dropdown (1-12)
    local hourDropdown = TamCalEventFormContentTimeRowHourDropdown
    if hourDropdown then
        local comboBox = ZO_ComboBox_ObjectFromContainer(hourDropdown)
        if not comboBox then
            comboBox = ZO_ComboBox:New(hourDropdown)
        end
        comboBox:SetSortsItems(false)
        comboBox:ClearItems()

        for h = 1, 12 do
            local hourStr = tostring(h)
            local entry = comboBox:CreateItemEntry(hourStr, function()
                TC.eventFormHour = h
            end)
            comboBox:AddItem(entry)
        end

        TC.hourComboBox = comboBox
    end

    -- Minute Dropdown (00, 15, 30, 45)
    local minuteDropdown = TamCalEventFormContentTimeRowMinuteDropdown
    if minuteDropdown then
        local comboBox = ZO_ComboBox_ObjectFromContainer(minuteDropdown)
        if not comboBox then
            comboBox = ZO_ComboBox:New(minuteDropdown)
        end
        comboBox:SetSortsItems(false)
        comboBox:ClearItems()

        for _, m in ipairs({0, 15, 30, 45}) do
            local minStr = string.format("%02d", m)
            local entry = comboBox:CreateItemEntry(minStr, function()
                TC.eventFormMinute = m
            end)
            comboBox:AddItem(entry)
        end

        TC.minuteComboBox = comboBox
    end

    -- AM/PM Dropdown
    local ampmDropdown = TamCalEventFormContentTimeRowAmPmDropdown
    if ampmDropdown then
        local comboBox = ZO_ComboBox_ObjectFromContainer(ampmDropdown)
        if not comboBox then
            comboBox = ZO_ComboBox:New(ampmDropdown)
        end
        comboBox:SetSortsItems(false)
        comboBox:ClearItems()

        for _, period in ipairs({"AM", "PM"}) do
            local entry = comboBox:CreateItemEntry(period, function()
                TC.eventFormAmPm = period
            end)
            comboBox:AddItem(entry)
        end

        TC.ampmComboBox = comboBox
    end
end

--- Set the time dropdowns to a specific time
--- @param hour number Hour (1-12)
--- @param minute number Minute (0, 15, 30, 45)
--- @param ampm string "AM" or "PM"
function TC:SetTimeDropdowns(hour, minute, ampm)
    self.eventFormHour = hour
    self.eventFormMinute = minute
    self.eventFormAmPm = ampm

    -- Select in hour dropdown
    if self.hourComboBox then
        local hourIndex = hour  -- hour 1 = index 1
        self.hourComboBox:SelectItemByIndex(hourIndex)
    end

    -- Select in minute dropdown
    if self.minuteComboBox then
        local minuteIndex = 1
        if minute == 15 then minuteIndex = 2
        elseif minute == 30 then minuteIndex = 3
        elseif minute == 45 then minuteIndex = 4
        end
        self.minuteComboBox:SelectItemByIndex(minuteIndex)
    end

    -- Select in AM/PM dropdown
    if self.ampmComboBox then
        local ampmIndex = (ampm == "AM") and 1 or 2
        self.ampmComboBox:SelectItemByIndex(ampmIndex)
    end
end

--- Convert dropdown selections to 24-hour time
--- @return number hour24 24-hour format hour (0-23)
--- @return number minute Minute value
function TC:GetTimeFromDropdowns()
    local hour12 = self.eventFormHour
    local minute = self.eventFormMinute
    local ampm = self.eventFormAmPm

    local hour24
    if ampm == "AM" then
        hour24 = (hour12 == 12) and 0 or hour12
    else -- PM
        hour24 = (hour12 == 12) and 12 or (hour12 + 12)
    end

    return hour24, minute
end

--- Convert a timestamp to 12-hour format for dropdowns
--- @param timestamp number Unix timestamp
--- @return number hour12 Hour 1-12
--- @return number minute Minute rounded to 15-min intervals
--- @return string ampm "AM" or "PM"
function TC:TimestampTo12Hour(timestamp)
    local t = os.date("*t", timestamp)
    local hour24 = t.hour
    local minute = t.min

    -- Round minute to nearest 15
    minute = math.floor((minute + 7) / 15) * 15
    if minute >= 60 then
        minute = 0
        hour24 = hour24 + 1
        if hour24 >= 24 then hour24 = 0 end
    end

    -- Convert to 12-hour
    local ampm = (hour24 < 12) and "AM" or "PM"
    local hour12 = hour24 % 12
    if hour12 == 0 then hour12 = 12 end

    return hour12, minute, ampm
end

--- Handle settings button click
function TC:OnSettingsClicked()
    -- Open LibAddonMenu settings if available
    local LAM = LibAddonMenu2
    if LAM then
        LAM:OpenToPanel(TC.settingsPanel)
    else
        d("[TamCal] Settings panel requires LibAddonMenu-2.0")
    end
end


--- Hide the event form
function TC:HideEventForm()
    if TamCalEventForm then
        TamCalEventForm:SetHidden(true)
        self.editingEvent = nil
    end
end

--- Handle event form save
function TC:OnEventFormSave()
    local titleInput = TamCalEventFormContentTitleInput
    local descInput = TamCalEventFormContentDescInput

    if not titleInput then return end

    local title = titleInput:GetText()
    if not title or title == "" then
        d("[TamCal] Title is required")
        return
    end

    -- Get time from dropdowns
    local hour24, minute = self:GetTimeFromDropdowns()
    local baseDate = self.eventFormDate or DH.GetTodayMidnight()
    local startTime = DH.SetTime(baseDate, hour24, minute)
    -- Default event duration: 2 hours
    local endTime = startTime + (2 * DH.SECONDS_PER_HOUR)

    local eventData = {
        title = title,
        description = descInput and descInput:GetText() or "",
        startTime = startTime,
        endTime = endTime,
        category = "Personal",  -- Simplified: all events are personal for now
    }

    local EM = TC.EventManager
    local success, err

    if self.editingEvent then
        success, err = EM:UpdatePersonalEvent(self.editingEvent.eventId, eventData)
    else
        success, err = EM:CreatePersonalEvent(eventData)
    end

    if success then
        self:HideEventForm()
        self:RefreshView()
        PlaySound(SOUNDS.POSITIVE_CLICK)
        d("[TamCal] Event saved")
    else
        d("[TamCal] Error:", err)
    end
end

--- Handle filter button click
function TC:OnFilterClicked()
    -- TODO: Implement filter dropdown
    d("[TamCal] Filter not yet implemented")
end

-------------------------------------------------
-- Sign-up Dialog
-------------------------------------------------

--- Show the sign-up dialog for a guild event
--- @param event table The guild event
function TC:ShowSignUpDialog(event)
    if not TamCalSignUpDialog then return end
    if not event or not event.guildId then return end

    self.signUpEvent = event

    local titleLabel = TamCalSignUpDialogEventTitle
    if titleLabel then
        titleLabel:SetText(event.title)
    end

    local timeLabel = TamCalSignUpDialogEventTime
    if timeLabel then
        local use24Hour = self:GetPreference("use24HourTime")
        timeLabel:SetText(DH.FormatDateTime(event.startTime, use24Hour))
    end

    TamCalSignUpDialog:SetHidden(false)
end

--- Hide the sign-up dialog
function TC:HideSignUpDialog()
    if TamCalSignUpDialog then
        TamCalSignUpDialog:SetHidden(true)
        self.signUpEvent = nil
    end
end

--- Handle role selection in sign-up dialog
--- @param role string The selected role
function TC:OnRoleSelected(role)
    if not self.signUpEvent then return end

    local EM = TC.EventManager
    local success, err = EM:SignUp(self.signUpEvent.guildId, self.signUpEvent.eventId, role)

    if success then
        self:HideSignUpDialog()
        self:RefreshView()
        PlaySound(SOUNDS.POSITIVE_CLICK)
        d("[TamCal] Signed up as " .. role)
    else
        d("[TamCal] Sign-up failed:", err)
    end
end

-------------------------------------------------
-- Placeholder Handlers (for XML callbacks)
-------------------------------------------------

--- Placeholder for event block mouse enter
function TC:OnEventBlockMouseEnter(block)
    -- Will be implemented by UI modules
end

--- Placeholder for event block mouse exit
function TC:OnEventBlockMouseExit(block)
    -- Will be implemented by UI modules
end

--- Placeholder for event block click
function TC:OnEventBlockClicked(block, button)
    -- Will be implemented by UI modules
end

--- Placeholder for guild tag click
function TC:OnGuildTagClicked(tag, button)
    -- Will be implemented by UI modules
end

-------------------------------------------------
-- Initialization
-------------------------------------------------

--- Main addon initialization
local function OnAddonLoaded(event, addonName)
    if addonName ~= TC.name then return end

    -- Unregister since we only need this once
    EVENT_MANAGER:UnregisterForEvent(TC.name, EVENT_ADD_ON_LOADED)

    -- Initialize SavedVariables
    InitializeSavedVariables()

    -- Set initial view state
    local t = os.date("*t", GetTimeStamp())
    TC.currentYear = t.year
    TC.currentMonth = t.month
    TC.currentView = TC.savedVars.preferences.defaultView or TC.VIEW_MODES.MONTH
    TC.selectedDate = DH.GetTodayMidnight()

    -- Purge old events
    TC:PurgeOldEvents()

    -- Register slash command
    SLASH_COMMANDS["/tamcal"] = SlashCommandHandler
    SLASH_COMMANDS["/tc"] = SlashCommandHandler

    -- Mark as initialized
    TC.initialized = true

    d(string.format("[TamCal] Tamriel Calendar v%s loaded. Type /tamcal to open.", TC.version))
end

--- Initialize UI elements after player activates (UI is ready)
local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(TC.name .. "_Main", EVENT_PLAYER_ACTIVATED)

    -- Initialize dropdowns after a short delay to ensure UI is ready
    zo_callLater(function()
        TC:InitializeTimeDropdowns()
    end, 250)
end

-- Register for addon loaded event
EVENT_MANAGER:RegisterForEvent(TC.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
EVENT_MANAGER:RegisterForEvent(TC.name .. "_Main", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
