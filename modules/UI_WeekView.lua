--[[
    UI_WeekView.lua
    Week view calendar rendering

    Displays a 7-day grid with:
    - Day header row (day name + date)
    - Hourly time rows (configurable range)
    - Event blocks positioned by time
    - Today column highlighting
]]

local TC = TamrielCalendar
local DH = TC.DateHelpers
local EM = TC.EventManager

TC.WeekView = {}
local WV = TC.WeekView

-------------------------------------------------
-- Constants
-------------------------------------------------

local DAYS_IN_WEEK = 7
local TIME_COLUMN_WIDTH = 50  -- Width of the time label column
local HOUR_ROW_HEIGHT = 30    -- Height of each hour row
local HEADER_HEIGHT = 32      -- Height of day header row

-- Colors (matching MonthView)
local COLORS = {
    -- Text
    bodyText = {232/255, 220/255, 200/255, 1},
    mutedText = {139/255, 115/255, 85/255, 1},
    headerGold = {212/255, 175/255, 55/255, 1},

    -- Borders
    borderNormal = {58/255, 53/255, 48/255, 1},
    borderHover = {107/255, 91/255, 69/255, 1},
    borderToday = {197/255, 165/255, 82/255, 1},

    -- Backgrounds
    cellBg = {30/255, 28/255, 25/255, 0.6},
    cellBgAlt = {35/255, 33/255, 30/255, 0.6},
    todayBg = {197/255, 165/255, 82/255, 0.1},
    headerBg = {40/255, 38/255, 35/255, 0.8},

    -- Category backgrounds
    categoryBg = {
        Raid = {74/255, 32/255, 32/255, 0.9},
        Party = {32/255, 58/255, 74/255, 0.9},
        Training = {32/255, 74/255, 40/255, 0.9},
        Meeting = {74/255, 64/255, 32/255, 0.9},
        Personal = {56/255, 32/255, 74/255, 0.9},
    },

    -- Category text
    categoryText = {
        Raid = {255/255, 153/255, 153/255, 1},
        Party = {153/255, 204/255, 255/255, 1},
        Training = {153/255, 255/255, 153/255, 1},
        Meeting = {255/255, 221/255, 153/255, 1},
        Personal = {204/255, 153/255, 255/255, 1},
    },
}

-------------------------------------------------
-- State
-------------------------------------------------

WV.dayHeaders = {}          -- 7 day header labels
WV.hourRows = {}            -- Hour row controls
WV.dayCells = {}            -- Grid of hour cells [hour][day]
WV.eventBlockPool = {}      -- Pool of event block controls
WV.activeBlocks = {}        -- Currently visible blocks
WV.initialized = false

-------------------------------------------------
-- Initialization
-------------------------------------------------

--- Helper to get or create a control
local function GetOrCreateControl(name, parent, controlType)
    local control = _G[name]
    if not control then
        control = CreateControl(name, parent, controlType)
    end
    return control
end

--- Initialize the week view UI
function WV:Initialize()
    if self.initialized then return end -- Prevent double init

    local weekView = TamCalWindowContentWeekView
    if not weekView then
        TC:Debug("WeekView: Cannot find TamCalWindowContentWeekView")
        return
    end

    self:CreateDayHeader()
    self:CreateHourGrid()
    self.initialized = true

    TC:Debug("WeekView: Initialized")
end

--- Create the day header row (7 day columns)
function WV:CreateDayHeader()
    local header = TamCalWindowContentWeekViewHeader
    if not header then return end

    local headerWidth = header:GetWidth()
    local dayWidth = (headerWidth - TIME_COLUMN_WIDTH) / DAYS_IN_WEEK

    -- Create time column placeholder
    local timeHeader = GetOrCreateControl("TamCalWeekTimeHeader", header, CT_LABEL)
    timeHeader:SetDimensions(TIME_COLUMN_WIDTH, HEADER_HEIGHT)
    timeHeader:SetAnchor(TOPLEFT, header, TOPLEFT, 0, 0)
    timeHeader:SetText("")

    -- Create day headers
    for i = 1, DAYS_IN_WEEK do
        local dayHeaderName = "TamCalWeekDayHeader" .. i
        local dayHeader = GetOrCreateControl(dayHeaderName, header, CT_CONTROL)
        dayHeader:SetDimensions(dayWidth, HEADER_HEIGHT)
        dayHeader:SetAnchor(TOPLEFT, header, TOPLEFT, TIME_COLUMN_WIDTH + (i - 1) * dayWidth, 0)

        -- Background
        local bg = dayHeader:GetNamedChild("BG") or CreateControl(dayHeaderName .. "BG", dayHeader, CT_BACKDROP)
        bg:SetAnchorFill()
        bg:SetCenterColor(unpack(COLORS.headerBg))
        bg:SetEdgeColor(unpack(COLORS.borderNormal))
        bg:SetEdgeTexture("", 1, 1, 1, 0)

        -- Day name label (e.g., "Mon")
        local dayLabel = dayHeader:GetNamedChild("Day") or CreateControl(dayHeaderName .. "Day", dayHeader, CT_LABEL)
        dayLabel:SetFont("ZoFontGameSmall")
        dayLabel:SetAnchor(TOP, dayHeader, TOP, 0, 4)
        dayLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        dayLabel:SetColor(unpack(COLORS.mutedText))

        -- Date label (e.g., "Dec 4")
        local dateLabel = dayHeader:GetNamedChild("Date") or CreateControl(dayHeaderName .. "Date", dayHeader, CT_LABEL)
        dateLabel:SetFont("ZoFontGameSmall")
        dateLabel:SetAnchor(TOP, dayLabel, BOTTOM, 0, 2)
        dateLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        dateLabel:SetColor(unpack(COLORS.bodyText))

        dayHeader.bg = bg
        dayHeader.dayLabel = dayLabel
        dayHeader.dateLabel = dateLabel
        dayHeader.dayIndex = i

        self.dayHeaders[i] = dayHeader
    end
end

--- Create the hour grid
function WV:CreateHourGrid()
    local grid = TamCalWindowContentWeekViewGrid
    if not grid then return end

    local prefs = TC.savedVars and TC.savedVars.preferences or {}
    local hourRange = prefs.hourRange or {start = 17, stop = 24}
    local startHour = hourRange.start or 17
    local endHour = hourRange.stop or 24

    local gridWidth = grid:GetWidth()
    local dayWidth = (gridWidth - TIME_COLUMN_WIDTH) / DAYS_IN_WEEK

    self.dayCells = {}

    for hour = startHour, endHour - 1 do
        local rowIndex = hour - startHour + 1
        local yOffset = (rowIndex - 1) * HOUR_ROW_HEIGHT

        -- Create hour row container
        local hourRowName = "TamCalWeekHourRow" .. hour
        local hourRow = GetOrCreateControl(hourRowName, grid, CT_CONTROL)
        hourRow:SetDimensions(gridWidth, HOUR_ROW_HEIGHT)
        hourRow:SetAnchor(TOPLEFT, grid, TOPLEFT, 0, yOffset)

        -- Time label
        local timeLabel = hourRow:GetNamedChild("Time") or CreateControl(hourRowName .. "Time", hourRow, CT_LABEL)
        timeLabel:SetDimensions(TIME_COLUMN_WIDTH, HOUR_ROW_HEIGHT)
        timeLabel:SetAnchor(TOPLEFT, hourRow, TOPLEFT, 0, 0)
        timeLabel:SetFont("ZoFontGameSmall")
        timeLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        timeLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
        timeLabel:SetColor(unpack(COLORS.mutedText))

        -- Format time label
        local use24Hour = prefs.use24HourTime
        local timeText
        if use24Hour then
            timeText = string.format("%d:00", hour)
        else
            local displayHour = hour % 12
            if displayHour == 0 then displayHour = 12 end
            local period = hour < 12 and "AM" or "PM"
            timeText = string.format("%d %s", displayHour, period)
        end
        timeLabel:SetText(timeText)

        hourRow.timeLabel = timeLabel
        hourRow.hour = hour
        self.hourRows[hour] = hourRow

        -- Create day cells for this hour
        self.dayCells[hour] = {}

        for day = 1, DAYS_IN_WEEK do
            local cellName = "TamCalWeekCell" .. hour .. "_" .. day
            local cell = GetOrCreateControl(cellName, hourRow, CT_CONTROL)
            cell:SetDimensions(dayWidth, HOUR_ROW_HEIGHT)
            cell:SetAnchor(TOPLEFT, hourRow, TOPLEFT, TIME_COLUMN_WIDTH + (day - 1) * dayWidth, 0)

            -- Background
            local bg = cell:GetNamedChild("BG") or CreateControl(cellName .. "BG", cell, CT_BACKDROP)
            bg:SetAnchorFill()
            -- Alternating row colors
            local bgColor = (rowIndex % 2 == 0) and COLORS.cellBgAlt or COLORS.cellBg
            bg:SetCenterColor(unpack(bgColor))
            bg:SetEdgeColor(unpack(COLORS.borderNormal))
            bg:SetEdgeTexture("", 1, 1, 1, 0)

            cell.bg = bg
            cell.hour = hour
            cell.dayIndex = day
            cell.isToday = false

            -- Enable mouse for click-to-create
            cell:SetMouseEnabled(true)
            cell:SetHandler("OnMouseUp", function(control, button)
                WV:OnCellClicked(control, button)
            end)

            self.dayCells[hour][day] = cell
        end
    end
end

-------------------------------------------------
-- Rendering
-------------------------------------------------

--- Refresh the week view with current data
function WV:Refresh()
    if not TC.initialized or not self.initialized then return end

    local selectedDate = TC.selectedDate or DH.GetTodayMidnight()
    local weekStartsMonday = TC:GetPreference("weekStartsMonday")

    -- Get days for this week
    local weekDays = DH.GetWeekDays(selectedDate, weekStartsMonday)
    local todayMidnight = DH.GetTodayMidnight()

    -- Update period label
    self:UpdatePeriodLabel(weekDays)

    -- Update day headers
    self:UpdateDayHeaders(weekDays, todayMidnight)

    -- Get events for the week
    local weekStart = weekDays[1]
    local weekEnd = DH.EndOfDay(weekDays[DAYS_IN_WEEK])
    local events = EM:GetEventsForRange(weekStart, weekEnd)

    -- Clear existing blocks
    self:ClearEventBlocks()

    -- Update cell backgrounds (today highlighting)
    self:UpdateCellBackgrounds(weekDays, todayMidnight)

    -- Render events
    self:RenderEvents(events, weekDays)
end

--- Update the period label (e.g., "Dec 1 - Dec 7, 2025")
--- @param weekDays table Array of 7 day timestamps
function WV:UpdatePeriodLabel(weekDays)
    local label = TamCalWindowNavBarPeriodLabel
    if not label then return end

    local firstDay = weekDays[1]
    local lastDay = weekDays[DAYS_IN_WEEK]

    local t1 = os.date("*t", firstDay)
    local t2 = os.date("*t", lastDay)

    local text
    if t1.year == t2.year and t1.month == t2.month then
        -- Same month: "Dec 1 - 7, 2025"
        text = string.format("%s %d - %d, %d",
            DH.FormatMonth(t1.month, true), t1.day, t2.day, t1.year)
    elseif t1.year == t2.year then
        -- Same year, different months: "Nov 28 - Dec 4, 2025"
        text = string.format("%s %d - %s %d, %d",
            DH.FormatMonth(t1.month, true), t1.day,
            DH.FormatMonth(t2.month, true), t2.day, t1.year)
    else
        -- Different years: "Dec 28, 2024 - Jan 3, 2025"
        text = string.format("%s %d, %d - %s %d, %d",
            DH.FormatMonth(t1.month, true), t1.day, t1.year,
            DH.FormatMonth(t2.month, true), t2.day, t2.year)
    end

    label:SetText(text)
end

--- Update day header labels
--- @param weekDays table Array of 7 day timestamps
--- @param todayMidnight number Today's midnight timestamp
function WV:UpdateDayHeaders(weekDays, todayMidnight)
    for i, dayTs in ipairs(weekDays) do
        local header = self.dayHeaders[i]
        if header then
            local isToday = DH.StartOfDay(dayTs) == todayMidnight

            -- Update labels
            header.dayLabel:SetText(DH.FormatWeekday(dayTs, true))
            header.dateLabel:SetText(DH.FormatDate(dayTs):gsub(", %d+$", "")) -- Remove year

            -- Apply today styling
            if isToday then
                header.bg:SetCenterColor(unpack(COLORS.todayBg))
                header.bg:SetEdgeColor(unpack(COLORS.borderToday))
                header.dateLabel:SetColor(unpack(COLORS.headerGold))
            else
                header.bg:SetCenterColor(unpack(COLORS.headerBg))
                header.bg:SetEdgeColor(unpack(COLORS.borderNormal))
                header.dateLabel:SetColor(unpack(COLORS.bodyText))
            end

            -- Store timestamp for event creation
            header.timestamp = dayTs
        end
    end
end

--- Update cell backgrounds for today highlighting
--- @param weekDays table Array of 7 day timestamps
--- @param todayMidnight number Today's midnight timestamp
function WV:UpdateCellBackgrounds(weekDays, todayMidnight)
    local prefs = TC.savedVars and TC.savedVars.preferences or {}
    local hourRange = prefs.hourRange or {start = 17, stop = 24}

    for hour = hourRange.start, hourRange.stop - 1 do
        local rowIndex = hour - hourRange.start + 1

        for day = 1, DAYS_IN_WEEK do
            local cell = self.dayCells[hour] and self.dayCells[hour][day]
            if cell then
                local dayTs = weekDays[day]
                local isToday = dayTs and DH.StartOfDay(dayTs) == todayMidnight

                cell.isToday = isToday
                cell.timestamp = dayTs and DH.SetTime(dayTs, hour, 0) or nil

                -- Apply background
                if isToday then
                    cell.bg:SetCenterColor(unpack(COLORS.todayBg))
                else
                    local bgColor = (rowIndex % 2 == 0) and COLORS.cellBgAlt or COLORS.cellBg
                    cell.bg:SetCenterColor(unpack(bgColor))
                end
            end
        end
    end
end

-------------------------------------------------
-- Event Blocks
-------------------------------------------------

--- Get or create an event block from the pool
--- @return control Event block control
function WV:GetEventBlock()
    -- Check pool for available block
    for _, block in ipairs(self.eventBlockPool) do
        if block:IsHidden() then
            block:SetHidden(false)
            table.insert(self.activeBlocks, block)
            return block
        end
    end

    -- Create new block
    local blockIndex = #self.eventBlockPool + 1
    local block = CreateControlFromVirtual(
        "TamCalWeekEventBlock" .. blockIndex,
        GuiRoot,
        "TamCal_EventBlock_Template"
    )

    block:SetHidden(false)
    table.insert(self.eventBlockPool, block)
    table.insert(self.activeBlocks, block)

    return block
end

--- Clear all visible event blocks
function WV:ClearEventBlocks()
    for _, block in ipairs(self.activeBlocks) do
        block:SetHidden(true)
        block:ClearAnchors()
        block:SetParent(GuiRoot)
    end
    self.activeBlocks = {}
end

--- Render events on the week grid
--- @param events table Array of events
--- @param weekDays table Array of 7 day timestamps
function WV:RenderEvents(events, weekDays)
    local grid = TamCalWindowContentWeekViewGrid
    if not grid then return end

    local prefs = TC.savedVars and TC.savedVars.preferences or {}
    local hourRange = prefs.hourRange or {start = 17, stop = 24}
    local startHour = hourRange.start
    local endHour = hourRange.stop

    local gridWidth = grid:GetWidth()
    local dayWidth = (gridWidth - TIME_COLUMN_WIDTH) / DAYS_IN_WEEK
    local use24Hour = prefs.use24HourTime

    -- Map weekDays to day index
    local dayMap = {}
    for i, dayTs in ipairs(weekDays) do
        local dayKey = DH.StartOfDay(dayTs)
        dayMap[dayKey] = i
    end

    -- Render each event
    for _, event in ipairs(events) do
        local eventDayKey = DH.StartOfDay(event.startTime)
        local dayIndex = dayMap[eventDayKey]

        if dayIndex then
            self:RenderEventBlock(event, dayIndex, dayWidth, startHour, endHour, use24Hour, grid)
        end
    end
end

--- Render a single event block
--- @param event table The event
--- @param dayIndex number Day column (1-7)
--- @param dayWidth number Width of each day column
--- @param startHour number First visible hour
--- @param endHour number Last visible hour
--- @param use24Hour boolean Use 24-hour time format
--- @param grid control The grid container
function WV:RenderEventBlock(event, dayIndex, dayWidth, startHour, endHour, use24Hour, grid)
    local eventStartHour, eventStartMin = DH.GetTime(event.startTime)
    local eventEndHour, eventEndMin = DH.GetTime(event.endTime)

    -- Check if event is visible in the hour range
    if eventEndHour < startHour or eventStartHour >= endHour then
        return -- Event is outside visible range
    end

    -- Clamp to visible range
    local displayStartHour = math.max(eventStartHour, startHour)
    local displayEndHour = math.min(eventEndHour, endHour)

    -- Calculate position
    local startMinutes = (displayStartHour - startHour) * 60 + (eventStartHour >= startHour and eventStartMin or 0)
    local endMinutes = (displayEndHour - startHour) * 60 + eventEndMin

    local yOffset = (startMinutes / 60) * HOUR_ROW_HEIGHT
    local height = ((endMinutes - startMinutes) / 60) * HOUR_ROW_HEIGHT
    height = math.max(height, 20) -- Minimum height

    local xOffset = TIME_COLUMN_WIDTH + (dayIndex - 1) * dayWidth + 2
    local width = dayWidth - 4

    -- Create block
    local block = self:GetEventBlock()
    block:SetParent(grid)
    block:ClearAnchors()
    block:SetAnchor(TOPLEFT, grid, TOPLEFT, xOffset, yOffset)
    block:SetDimensions(width, height)

    -- Store event reference
    block.event = event

    -- Get child controls
    local bg = block:GetNamedChild("BG")
    local titleLabel = block:GetNamedChild("Title")
    local timeLabel = block:GetNamedChild("Time")

    -- Apply category colors
    local category = event.category or "Personal"
    local bgColor = COLORS.categoryBg[category] or COLORS.categoryBg.Personal
    local textColor = COLORS.categoryText[category] or COLORS.categoryText.Personal

    if bg then
        bg:SetCenterColor(unpack(bgColor))
        bg:SetEdgeColor(textColor[1], textColor[2], textColor[3], 0.8)
    end

    if titleLabel then
        local displayTitle = event.title
        if #displayTitle > 20 then
            displayTitle = displayTitle:sub(1, 18) .. "..."
        end
        titleLabel:SetText(displayTitle)
        titleLabel:SetColor(unpack(textColor))
    end

    if timeLabel then
        timeLabel:SetText(DH.FormatTime(event.startTime, use24Hour))
        timeLabel:SetColor(textColor[1], textColor[2], textColor[3], 0.7)
    end

    block:SetMouseEnabled(true)
end

-------------------------------------------------
-- Event Handlers
-------------------------------------------------

--- Handle click on hour cell
--- @param cell control The cell control
--- @param button number Mouse button
function WV:OnCellClicked(cell, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end

    if cell.timestamp then
        -- Select this time and open event form
        TC.selectedDate = DH.StartOfDay(cell.timestamp)
        TC.eventFormStartTime = cell.timestamp
        TC.eventFormEndTime = cell.timestamp + DH.SECONDS_PER_HOUR

        TC:ShowEventForm()
        PlaySound(SOUNDS.POSITIVE_CLICK)
    end
end

--- Handle mouse enter on event block (called from XML)
function TC:OnWeekEventBlockMouseEnter(block)
    WV:OnEventBlockMouseEnter(block)
end

--- Handle mouse exit on event block (called from XML)
function TC:OnWeekEventBlockMouseExit(block)
    WV:OnEventBlockMouseExit(block)
end

--- Handle click on event block (called from XML)
function TC:OnWeekEventBlockClicked(block, button)
    WV:OnEventBlockClicked(block, button)
end

--- Handle mouse enter on event block
--- @param block control The event block
function WV:OnEventBlockMouseEnter(block)
    if not block.event then return end

    local event = block.event
    local use24Hour = TC:GetPreference("use24HourTime")

    -- Build tooltip
    local lines = {
        event.title,
        DH.FormatTimeRange(event.startTime, event.endTime, use24Hour),
    }

    if event.description and event.description ~= "" then
        table.insert(lines, "")
        local desc = event.description
        if #desc > 60 then
            desc = desc:sub(1, 57) .. "..."
        end
        table.insert(lines, desc)
    end

    if event.guildId then
        local guildName = GetGuildName(event.guildId)
        if guildName and guildName ~= "" then
            table.insert(lines, "Guild: " .. guildName)
        end

        -- Show attendee count
        local counts = EM:GetAttendeeCounts(event)
        if counts.total > 0 then
            table.insert(lines, string.format("Attendees: %d", counts.total))
        end
    end

    ZO_Tooltips_ShowTextTooltip(block, TOP, table.concat(lines, "\n"))
end

--- Handle mouse exit on event block
--- @param block control The event block
function WV:OnEventBlockMouseExit(block)
    ZO_Tooltips_HideTextTooltip()
end

--- Handle click on event block
--- @param block control The event block
--- @param button number Mouse button
function WV:OnEventBlockClicked(block, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    if not block.event then return end

    local event = block.event

    -- Store selected event
    TC.selectedEvent = event

    -- If guild event, could open sign-up dialog
    if event.guildId then
        local isSignedUp = EM:IsSignedUp(event.guildId, event.eventId)
        if not isSignedUp then
            TC:ShowSignUpDialog(event)
        else
            -- Already signed up - could show details or withdraw option
            d("[TamCal] Already signed up for this event")
        end
    else
        -- Personal event - open edit form
        TC:ShowEventForm(event)
    end

    PlaySound(SOUNDS.POSITIVE_CLICK)
end

-------------------------------------------------
-- View Management
-------------------------------------------------

--- Show the week view
function WV:Show()
    local weekView = TamCalWindowContentWeekView
    if weekView then
        weekView:SetHidden(false)
    end
end

--- Hide the week view
function WV:Hide()
    local weekView = TamCalWindowContentWeekView
    if weekView then
        weekView:SetHidden(true)
    end
end

-------------------------------------------------
-- Hook into RefreshView
-------------------------------------------------

-- Store original RefreshView to chain
local originalRefreshView = TC.RefreshView

function TC:RefreshView()
    -- Call original (which handles MonthView)
    if originalRefreshView then
        originalRefreshView(self)
    end

    -- Handle WeekView
    if self.currentView == self.VIEW_MODES.WEEK then
        if WV.initialized then
            WV:Refresh()
        end
    end
end

-------------------------------------------------
-- Initialization Hook
-------------------------------------------------

-- Initialize when UI is ready
local function OnPlayerActivated()
    zo_callLater(function()
        WV:Initialize()
    end, 150) -- Slightly after MonthView
end

EVENT_MANAGER:RegisterForEvent(TC.name .. "_WeekView", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
