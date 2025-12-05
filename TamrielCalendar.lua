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

--- Navigate to today
function TC:GoToToday()
    local t = os.date("*t", GetTimeStamp())
    self:GoToMonth(t.year, t.month)
    self.selectedDate = DH.GetTodayMidnight()
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

        local use24Hour = self:GetPreference("use24HourTime")

        if event then
            self.eventFormStartTime = event.startTime
            self.eventFormEndTime = event.endTime
        else
            -- Default to selected date at 7pm-9pm
            local baseDate = self.selectedDate or DH.GetTodayMidnight()
            self.eventFormStartTime = DH.SetTime(baseDate, 19, 0)
            self.eventFormEndTime = DH.SetTime(baseDate, 21, 0)
        end

        -- Update the time displays
        self:UpdateEventFormTimeDisplays()

        TamCalEventForm:SetHidden(false)
    end
end

--- Update the time displays in the event form
function TC:UpdateEventFormTimeDisplays()
    local use24Hour = self:GetPreference("use24HourTime")

    -- Start date display (just the date)
    local startDateDisplay = TamCalEventFormContentStartDateDisplay
    if startDateDisplay then
        startDateDisplay:SetText(DH.FormatDate(self.eventFormStartTime))
    end

    -- Start time display (just the time)
    local startTimeDisplay = TamCalEventFormContentStartTimeDisplay
    if startTimeDisplay then
        startTimeDisplay:SetText(DH.FormatTime(self.eventFormStartTime, use24Hour))
    end

    -- End date display
    local endDateDisplay = TamCalEventFormContentEndDateDisplay
    if endDateDisplay then
        endDateDisplay:SetText(DH.FormatDate(self.eventFormEndTime))
    end

    -- End time display
    local endTimeDisplay = TamCalEventFormContentEndTimeDisplay
    if endTimeDisplay then
        endTimeDisplay:SetText(DH.FormatTime(self.eventFormEndTime, use24Hour))
    end
end

--- Adjust start time by hours
--- @param delta number Hours to add (negative to subtract)
function TC:AdjustStartTime(delta)
    local newTime = self.eventFormStartTime + (delta * DH.SECONDS_PER_HOUR)
    self.eventFormStartTime = newTime

    -- If start time moved past end time, adjust end time
    if self.eventFormStartTime >= self.eventFormEndTime then
        self.eventFormEndTime = self.eventFormStartTime + DH.SECONDS_PER_HOUR
    end

    self:UpdateEventFormTimeDisplays()
end

--- Adjust end time by hours
--- @param delta number Hours to add (negative to subtract)
function TC:AdjustEndTime(delta)
    local newTime = self.eventFormEndTime + (delta * DH.SECONDS_PER_HOUR)

    -- Don't allow end time before start time
    if newTime > self.eventFormStartTime then
        self.eventFormEndTime = newTime
        self:UpdateEventFormTimeDisplays()
    end
end

--- Handle start hour decrease
function TC:OnStartHourDown()
    self:AdjustStartTime(-1)
    PlaySound(SOUNDS.POSITIVE_CLICK)
end

--- Handle start hour increase
function TC:OnStartHourUp()
    self:AdjustStartTime(1)
    PlaySound(SOUNDS.POSITIVE_CLICK)
end

--- Handle end hour decrease
function TC:OnEndHourDown()
    self:AdjustEndTime(-1)
    PlaySound(SOUNDS.POSITIVE_CLICK)
end

--- Handle end hour increase
function TC:OnEndHourUp()
    self:AdjustEndTime(1)
    PlaySound(SOUNDS.POSITIVE_CLICK)
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

-------------------------------------------------
-- Event Form Dropdowns
-------------------------------------------------

-- Category options
TC.CATEGORY_LIST = {"Personal", "Raid", "Party", "Training", "Meeting"}

-- Trial options (for Raid category)
TC.TRIAL_LIST = {
    "Any Trial",
    "Aetherian Archive",
    "Cloudrest",
    "Dreadsail Reef",
    "Hel Ra Citadel",
    "Kyne's Aegis",
    "Lucent Citadel",
    "Maw of Lorkhaj",
    "Rockgrove",
    "Sanctum Ophidia",
    "Sunspire",
    "Asylum Sanctorium",
    "Halls of Fabrication",
}

-- Difficulty modifiers
TC.MODIFIER_LIST = {"Normal", "Veteran", "Veteran HM"}

--- Initialize the event form dropdowns
function TC:InitializeEventFormDropdowns()
    -- Category Dropdown
    local categoryDropdown = TamCalEventFormContentCategoryDropdown
    if categoryDropdown then
        local comboBox = ZO_ComboBox_ObjectFromContainer(categoryDropdown)
        if not comboBox then
            comboBox = ZO_ComboBox:New(categoryDropdown)
        end
        comboBox:SetSortsItems(false)
        comboBox:ClearItems()

        for _, category in ipairs(TC.CATEGORY_LIST) do
            local entry = comboBox:CreateItemEntry(category, function()
                TC.eventFormCategory = category
                TC:OnCategoryChanged(category)
            end)
            comboBox:AddItem(entry)
        end

        comboBox:SelectFirstItem()
        TC.categoryComboBox = comboBox
    end

    -- Trial Dropdown
    local trialDropdown = TamCalEventFormContentTrialDropdown
    if trialDropdown then
        local comboBox = ZO_ComboBox_ObjectFromContainer(trialDropdown)
        if not comboBox then
            comboBox = ZO_ComboBox:New(trialDropdown)
        end
        comboBox:SetSortsItems(false)
        comboBox:ClearItems()

        for _, trial in ipairs(TC.TRIAL_LIST) do
            local entry = comboBox:CreateItemEntry(trial, function()
                TC.eventFormTrial = trial
            end)
            comboBox:AddItem(entry)
        end

        comboBox:SelectFirstItem()
        TC.trialComboBox = comboBox
    end

    -- Modifier Dropdown
    local modifierDropdown = TamCalEventFormContentModifierDropdown
    if modifierDropdown then
        local comboBox = ZO_ComboBox_ObjectFromContainer(modifierDropdown)
        if not comboBox then
            comboBox = ZO_ComboBox:New(modifierDropdown)
        end
        comboBox:SetSortsItems(false)
        comboBox:ClearItems()

        for _, modifier in ipairs(TC.MODIFIER_LIST) do
            local entry = comboBox:CreateItemEntry(modifier, function()
                TC.eventFormModifier = modifier
            end)
            comboBox:AddItem(entry)
        end

        comboBox:SelectFirstItem()
        TC.modifierComboBox = comboBox
    end
end

--- Called when category changes to show/hide raid-specific fields
--- @param category string The selected category
function TC:OnCategoryChanged(category)
    local isRaid = (category == "Raid")

    -- Show/hide trial dropdown
    local trialLabel = TamCalEventFormContentTrialLabel
    local trialDropdown = TamCalEventFormContentTrialDropdown
    if trialLabel then trialLabel:SetHidden(not isRaid) end
    if trialDropdown then trialDropdown:SetHidden(not isRaid) end

    -- Show/hide modifier dropdown
    local modifierLabel = TamCalEventFormContentModifierLabel
    local modifierDropdown = TamCalEventFormContentModifierDropdown
    if modifierLabel then modifierLabel:SetHidden(not isRaid) end
    if modifierDropdown then modifierDropdown:SetHidden(not isRaid) end
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

    -- Get selected category (default to Personal)
    local category = self.eventFormCategory or "Personal"

    local eventData = {
        title = title,
        description = descInput and descInput:GetText() or "",
        startTime = self.eventFormStartTime,
        endTime = self.eventFormEndTime,
        category = category,
    }

    -- Add trial and modifier for Raid events
    if category == "Raid" then
        eventData.trial = self.eventFormTrial
        eventData.modifier = self.eventFormModifier
    end

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
        TC:InitializeEventFormDropdowns()
    end, 250)
end

-- Register for addon loaded event
EVENT_MANAGER:RegisterForEvent(TC.name, EVENT_ADD_ON_LOADED, OnAddonLoaded)
EVENT_MANAGER:RegisterForEvent(TC.name .. "_Main", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
