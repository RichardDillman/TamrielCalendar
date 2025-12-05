--[[
    SettingsPanel.lua
    LibAddonMenu-2.0 settings panel for Tamriel Calendar

    Provides UI for configuring:
    - Display preferences (24h time, week start day)
    - Hour range for week/day views
    - Guild sync settings
    - Debug options
]]

local TC = TamrielCalendar
TC.SettingsPanel = {}
local SP = TC.SettingsPanel

-------------------------------------------------
-- Panel Data
-------------------------------------------------

local panelData = {
    type = "panel",
    name = "Tamriel Calendar",
    displayName = "|cD4AF37Tamriel Calendar|r",
    author = "@RichardDillman",
    version = TC.version or "0.1.0",
    slashCommand = "/tamcalsettings",
    registerForRefresh = true,
    registerForDefaults = true,
}

-------------------------------------------------
-- Default Values
-------------------------------------------------

local defaults = {
    use24HourTime = false,
    weekStartsMonday = true,
    hourRange = {start = 17, stop = 24},
    defaultView = "MONTH",
    showPastEvents = true,
    syncEnabled = true,
    debugMode = false,
}

-------------------------------------------------
-- Initialize Settings Panel
-------------------------------------------------

function SP:Initialize()
    local LAM = LibAddonMenu2
    if not LAM then
        TC:Debug("SettingsPanel: LibAddonMenu-2.0 not available")
        return
    end

    -- Create the panel
    TC.settingsPanel = LAM:RegisterAddonPanel("TamrielCalendarSettings", panelData)

    -- Get current savedVars or use defaults
    local sv = TC.savedVars and TC.savedVars.preferences or defaults

    -- Build the options
    local optionsData = {
        -- ============================================
        -- DISPLAY SETTINGS
        -- ============================================
        {
            type = "header",
            name = "|cD4AF37Display Settings|r",
        },
        {
            type = "checkbox",
            name = "Use 24-Hour Time",
            tooltip = "Display times in 24-hour format (e.g., 19:00 instead of 7:00 PM)",
            getFunc = function() return TC:GetPreference("use24HourTime") end,
            setFunc = function(value)
                TC:SetPreference("use24HourTime", value)
                TC:RefreshView()
            end,
            default = defaults.use24HourTime,
        },
        {
            type = "checkbox",
            name = "Week Starts on Monday",
            tooltip = "When enabled, weeks start on Monday. When disabled, weeks start on Sunday.",
            getFunc = function() return TC:GetPreference("weekStartsMonday") end,
            setFunc = function(value)
                TC:SetPreference("weekStartsMonday", value)
                TC:RefreshView()
            end,
            default = defaults.weekStartsMonday,
        },
        {
            type = "dropdown",
            name = "Default View",
            tooltip = "The view shown when opening the calendar",
            choices = {"Month", "Week", "Day"},
            choicesValues = {"MONTH", "WEEK", "DAY"},
            getFunc = function()
                return TC:GetPreference("defaultView") or "MONTH"
            end,
            setFunc = function(value)
                TC:SetPreference("defaultView", value)
            end,
            default = defaults.defaultView,
        },
        {
            type = "checkbox",
            name = "Show Past Events",
            tooltip = "Display events that have already occurred",
            getFunc = function() return TC:GetPreference("showPastEvents") end,
            setFunc = function(value)
                TC:SetPreference("showPastEvents", value)
                TC:RefreshView()
            end,
            default = defaults.showPastEvents,
        },

        -- ============================================
        -- HOUR RANGE SETTINGS
        -- ============================================
        {
            type = "header",
            name = "|cD4AF37Hour Range (Week/Day Views)|r",
        },
        {
            type = "slider",
            name = "Start Hour",
            tooltip = "First hour shown in week and day views",
            min = 0,
            max = 23,
            step = 1,
            getFunc = function()
                local range = TC:GetPreference("hourRange")
                return range and range.start or 17
            end,
            setFunc = function(value)
                local range = TC:GetPreference("hourRange") or {start = 17, stop = 24}
                range.start = value
                if range.start >= range.stop then
                    range.stop = math.min(24, range.start + 1)
                end
                TC:SetPreference("hourRange", range)
                -- Note: Requires reload to rebuild hour grid
            end,
            default = defaults.hourRange.start,
        },
        {
            type = "slider",
            name = "End Hour",
            tooltip = "Last hour shown in week and day views",
            min = 1,
            max = 24,
            step = 1,
            getFunc = function()
                local range = TC:GetPreference("hourRange")
                return range and range.stop or 24
            end,
            setFunc = function(value)
                local range = TC:GetPreference("hourRange") or {start = 17, stop = 24}
                range.stop = value
                if range.stop <= range.start then
                    range.start = math.max(0, range.stop - 1)
                end
                TC:SetPreference("hourRange", range)
                -- Note: Requires reload to rebuild hour grid
            end,
            default = defaults.hourRange.stop,
        },
        {
            type = "description",
            text = "|c888888Note: Hour range changes require /reloadui to take effect.|r",
        },

        -- ============================================
        -- GUILD SYNC SETTINGS
        -- ============================================
        {
            type = "header",
            name = "|cD4AF37Guild Sync|r",
        },
        {
            type = "checkbox",
            name = "Enable Guild Sync",
            tooltip = "Allow syncing events with guild members (requires LibAddonMessage-2.0, LibSerialize, LibDeflate)",
            getFunc = function() return TC:GetPreference("syncEnabled") end,
            setFunc = function(value)
                TC:SetPreference("syncEnabled", value)
            end,
            default = defaults.syncEnabled,
        },
        {
            type = "description",
            text = function()
                local SM = TC.SyncManager
                if SM then
                    local available, reason = SM:IsAvailable()
                    if available then
                        return "|c00FF00Guild sync is available and ready.|r"
                    else
                        return "|cFF6600" .. (reason or "Guild sync is not available.") .. "|r"
                    end
                end
                return "|c888888Guild sync status unknown.|r"
            end,
        },

        -- ============================================
        -- DEBUG SETTINGS
        -- ============================================
        {
            type = "header",
            name = "|cD4AF37Advanced|r",
        },
        {
            type = "checkbox",
            name = "Debug Mode",
            tooltip = "Enable debug messages in chat",
            getFunc = function() return TC:GetPreference("debugMode") end,
            setFunc = function(value)
                TC:SetPreference("debugMode", value)
            end,
            default = defaults.debugMode,
        },
        {
            type = "button",
            name = "Reset All Settings",
            tooltip = "Reset all settings to default values",
            func = function()
                for key, value in pairs(defaults) do
                    TC:SetPreference(key, value)
                end
                d("[TamCal] Settings reset to defaults")
            end,
            warning = "This will reset all Tamriel Calendar settings to their default values.",
        },
    }

    -- Register the options
    LAM:RegisterOptionControls("TamrielCalendarSettings", optionsData)

    TC:Debug("SettingsPanel: Initialized")
end

-------------------------------------------------
-- Initialization Hook
-------------------------------------------------

local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(TC.name .. "_SettingsPanel", EVENT_PLAYER_ACTIVATED)

    -- Initialize settings panel after a short delay
    zo_callLater(function()
        SP:Initialize()
    end, 300)
end

EVENT_MANAGER:RegisterForEvent(TC.name .. "_SettingsPanel", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
