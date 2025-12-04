--[[
    UI_MonthView.lua
    Month view calendar grid rendering

    Displays a 6-week grid (42 cells) with:
    - Weekday header row
    - Day cells with event pips
    - Today highlighting
    - Other-month dimming
]]

local TC = TamrielCalendar
local DH = TC.DateHelpers
local EM = TC.EventManager

TC.MonthView = {}
local MV = TC.MonthView

-------------------------------------------------
-- Constants
-------------------------------------------------

local GRID_ROWS = 6
local GRID_COLS = 7
local GRID_CELLS = GRID_ROWS * GRID_COLS -- 42

local MAX_PIPS_PER_CELL = 3 -- Show max 3 events per day cell

-- Colors (from GUI_SPEC.md)
local COLORS = {
    -- Text
    bodyText = {232/255, 220/255, 200/255, 1},
    mutedText = {139/255, 115/255, 85/255, 1},
    headerGold = {212/255, 175/255, 55/255, 1},

    -- Borders
    borderNormal = {58/255, 53/255, 48/255, 1},
    borderHover = {107/255, 91/255, 69/255, 1},
    borderToday = {197/255, 165/255, 82/255, 1},
    borderSelected = {212/255, 175/255, 55/255, 1},

    -- Backgrounds
    cellBg = {30/255, 28/255, 25/255, 0.8},
    cellBgHover = {40/255, 38/255, 35/255, 0.9},
    todayBg = {197/255, 165/255, 82/255, 0.15},

    -- Category backgrounds (dimmed for pips)
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

MV.dayCells = {}        -- Pool of 42 day cell controls
MV.weekdayLabels = {}   -- 7 weekday header labels
MV.eventPipPool = {}    -- Pool of event pip controls
MV.activePips = {}      -- Currently visible pips

-------------------------------------------------
-- Initialization
-------------------------------------------------

--- Initialize the month view UI
function MV:Initialize()
    local monthView = TamCalWindowContentMonthView
    if not monthView then
        TC:Debug("MonthView: Cannot find TamCalWindowContentMonthView")
        return
    end

    self:CreateWeekdayHeader()
    self:CreateDayCellPool()

    TC:Debug("MonthView: Initialized")
end

--- Create the weekday header labels
function MV:CreateWeekdayHeader()
    local header = TamCalWindowContentMonthViewWeekdayHeader
    if not header then return end

    local weekStartsMonday = TC:GetPreference("weekStartsMonday")
    local weekdays = weekStartsMonday
        and {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}
        or {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"}

    local cellWidth = header:GetWidth() / GRID_COLS

    for i = 1, GRID_COLS do
        local label = CreateControl("TamCalWeekdayLabel" .. i, header, CT_LABEL)

        label:SetDimensions(cellWidth, 24)
        label:SetAnchor(TOPLEFT, header, TOPLEFT, (i - 1) * cellWidth, 0)
        label:SetText(weekdays[i])
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetColor(unpack(COLORS.mutedText))
        label:SetFont("ZoFontGameSmall")
        label:SetMouseEnabled(false) -- Prevent click issues

        self.weekdayLabels[i] = label
    end
end

--- Create the pool of 42 day cells
function MV:CreateDayCellPool()
    local grid = TamCalWindowContentMonthViewGrid
    if not grid then return end

    local gridWidth = grid:GetWidth()
    local gridHeight = grid:GetHeight()
    local cellWidth = gridWidth / GRID_COLS
    local cellHeight = gridHeight / GRID_ROWS
    local gap = 2

    for i = 1, GRID_CELLS do
        local row = math.floor((i - 1) / GRID_COLS)
        local col = (i - 1) % GRID_COLS

        local cell = CreateControlFromVirtual(
            "TamCalDayCell" .. i,
            grid,
            "TamCal_DayCell_Template"
        )

        cell:SetDimensions(cellWidth - gap, cellHeight - gap)
        cell:SetAnchor(TOPLEFT, grid, TOPLEFT, col * cellWidth, row * cellHeight)

        -- Store cell metadata
        cell.cellIndex = i
        cell.dayData = nil
        cell.events = {}

        -- Get child controls
        cell.bg = cell:GetNamedChild("BG")
        cell.dayNum = cell:GetNamedChild("DayNum")
        cell.eventsContainer = cell:GetNamedChild("Events")

        -- Enable mouse
        cell:SetMouseEnabled(true)

        self.dayCells[i] = cell
    end
end

-------------------------------------------------
-- Rendering
-------------------------------------------------

--- Refresh the month view with current data
function MV:Refresh()
    if not TC.initialized then return end

    local year = TC.currentYear
    local month = TC.currentMonth
    local weekStartsMonday = TC:GetPreference("weekStartsMonday")

    -- Update period label
    self:UpdatePeriodLabel(year, month)

    -- Get grid data
    local gridData = DH.GetMonthGrid(year, month, weekStartsMonday)

    -- Get events for the visible range
    local firstCell = gridData[1]
    local lastCell = gridData[GRID_CELLS]
    local rangeStart = DH.MakeTimestamp(firstCell.year, firstCell.month, firstCell.day, 0, 0)
    local rangeEnd = DH.MakeTimestamp(lastCell.year, lastCell.month, lastCell.day, 23, 59)
    local events = EM:GetEventsForRange(rangeStart, rangeEnd)

    -- Group events by day
    local eventsByDay = self:GroupEventsByDay(events)

    -- Clear existing pips
    self:ClearEventPips()

    -- Update each cell
    local todayMidnight = DH.GetTodayMidnight()

    for i, dayData in ipairs(gridData) do
        local cell = self.dayCells[i]
        if cell then
            self:UpdateDayCell(cell, dayData, eventsByDay, todayMidnight)
        end
    end
end

--- Update the period label (e.g., "December 2025")
--- @param year number
--- @param month number
function MV:UpdatePeriodLabel(year, month)
    local label = TamCalWindowNavBarPeriodLabel
    if label then
        local monthName = DH.FormatMonth(month, false)
        label:SetText(string.format("%s %d", monthName, year))
    end
end

--- Group events by day (YYYYMMDD key)
--- @param events table Array of events
--- @return table Map of dayKey -> events
function MV:GroupEventsByDay(events)
    local byDay = {}

    for _, event in ipairs(events) do
        local year, month, day = DH.GetDate(event.startTime)
        local dayKey = string.format("%04d%02d%02d", year, month, day)

        if not byDay[dayKey] then
            byDay[dayKey] = {}
        end
        table.insert(byDay[dayKey], event)
    end

    return byDay
end

--- Update a single day cell
--- @param cell control The day cell control
--- @param dayData table {day, month, year, isCurrentMonth}
--- @param eventsByDay table Grouped events
--- @param todayMidnight number Today's midnight timestamp
function MV:UpdateDayCell(cell, dayData, eventsByDay, todayMidnight)
    -- Store data for click handlers
    cell.dayData = dayData
    cell.timestamp = DH.MakeTimestamp(dayData.year, dayData.month, dayData.day, 0, 0)

    -- Update day number
    cell.dayNum:SetText(tostring(dayData.day))

    -- Check states
    local isToday = cell.timestamp == todayMidnight
    local isSelected = TC.selectedDate and cell.timestamp == TC.selectedDate
    local isCurrentMonth = dayData.isCurrentMonth

    -- Apply styling
    self:StyleDayCell(cell, isToday, isSelected, isCurrentMonth)

    -- Get events for this day
    local dayKey = string.format("%04d%02d%02d", dayData.year, dayData.month, dayData.day)
    local dayEvents = eventsByDay[dayKey] or {}
    cell.events = dayEvents

    -- Render event pips
    self:RenderEventPips(cell, dayEvents)
end

--- Apply visual styling to a day cell
--- @param cell control The day cell
--- @param isToday boolean
--- @param isSelected boolean
--- @param isCurrentMonth boolean
function MV:StyleDayCell(cell, isToday, isSelected, isCurrentMonth)
    local bg = cell.bg
    local dayNum = cell.dayNum

    -- Background color
    if isToday then
        bg:SetCenterColor(unpack(COLORS.todayBg))
    else
        bg:SetCenterColor(unpack(COLORS.cellBg))
    end

    -- Border color
    if isSelected then
        bg:SetEdgeColor(unpack(COLORS.borderSelected))
    elseif isToday then
        bg:SetEdgeColor(unpack(COLORS.borderToday))
    else
        bg:SetEdgeColor(unpack(COLORS.borderNormal))
    end

    -- Text color and opacity
    if isCurrentMonth then
        dayNum:SetColor(unpack(COLORS.bodyText))
        cell:SetAlpha(1.0)
    else
        dayNum:SetColor(unpack(COLORS.mutedText))
        cell:SetAlpha(0.4)
    end

    -- Store state for hover effects
    cell.isToday = isToday
    cell.isSelected = isSelected
    cell.isCurrentMonth = isCurrentMonth
end

-------------------------------------------------
-- Event Pips
-------------------------------------------------

--- Get or create an event pip from the pool
--- @return control Event pip control
function MV:GetEventPip()
    -- Check pool for available pip
    for _, pip in ipairs(self.eventPipPool) do
        if pip:IsHidden() then
            pip:SetHidden(false)
            table.insert(self.activePips, pip)
            return pip
        end
    end

    -- Create new pip
    local pipIndex = #self.eventPipPool + 1
    local pip = CreateControlFromVirtual(
        "TamCalEventPip" .. pipIndex,
        GuiRoot,
        "TamCal_EventPip_Template"
    )

    pip:SetHidden(false)
    table.insert(self.eventPipPool, pip)
    table.insert(self.activePips, pip)

    return pip
end

--- Clear all visible event pips
function MV:ClearEventPips()
    for _, pip in ipairs(self.activePips) do
        pip:SetHidden(true)
        pip:ClearAnchors()
        pip:SetParent(GuiRoot)
    end
    self.activePips = {}
end

--- Render event pips in a day cell
--- @param cell control The day cell
--- @param events table Array of events for this day
function MV:RenderEventPips(cell, events)
    local container = cell.eventsContainer
    if not container then return end

    local pipHeight = 14
    local pipGap = 2
    local maxWidth = container:GetWidth()

    -- Limit to MAX_PIPS_PER_CELL
    local showCount = math.min(#events, MAX_PIPS_PER_CELL)
    local hasMore = #events > MAX_PIPS_PER_CELL

    for i = 1, showCount do
        local event = events[i]
        local pip = self:GetEventPip()

        -- Parent to container
        pip:SetParent(container)
        pip:ClearAnchors()
        pip:SetAnchor(TOPLEFT, container, TOPLEFT, 0, (i - 1) * (pipHeight + pipGap))
        pip:SetDimensions(maxWidth, pipHeight)

        -- Store event reference
        pip.event = event

        -- Get child controls
        local bg = pip:GetNamedChild("BG")
        local title = pip:GetNamedChild("Title")

        -- Apply category colors
        local category = event.category or "Personal"
        local bgColor = COLORS.categoryBg[category] or COLORS.categoryBg.Personal
        local textColor = COLORS.categoryText[category] or COLORS.categoryText.Personal

        if bg then
            bg:SetCenterColor(unpack(bgColor))
            bg:SetEdgeColor(textColor[1], textColor[2], textColor[3], 0.6)
        end

        if title then
            -- Truncate title to fit
            local displayTitle = event.title
            if #displayTitle > 12 then
                displayTitle = displayTitle:sub(1, 11) .. "..."
            end
            title:SetText(displayTitle)
            title:SetColor(unpack(textColor))
        end

        pip:SetMouseEnabled(true)
    end

    -- Show "+N more" indicator if needed
    if hasMore then
        local moreCount = #events - MAX_PIPS_PER_CELL
        -- Could add a "+N more" label here in future
    end
end

-------------------------------------------------
-- Event Handlers
-------------------------------------------------

--- Handle mouse enter on day cell
--- @param cell control The day cell
function TC:OnDayCellMouseEnter(cell)
    if not cell.isCurrentMonth then return end

    local bg = cell.bg
    if bg then
        bg:SetCenterColor(unpack(COLORS.cellBgHover))
        if not cell.isToday and not cell.isSelected then
            bg:SetEdgeColor(unpack(COLORS.borderHover))
        end
    end

    -- Show tooltip with event count
    local eventCount = #cell.events
    if eventCount > 0 then
        local tooltipText = string.format("%d event%s", eventCount, eventCount > 1 and "s" or "")
        ZO_Tooltips_ShowTextTooltip(cell, TOP, tooltipText)
    end
end

--- Handle mouse exit on day cell
--- @param cell control The day cell
function TC:OnDayCellMouseExit(cell)
    MV:StyleDayCell(cell, cell.isToday, cell.isSelected, cell.isCurrentMonth)
    ZO_Tooltips_HideTextTooltip()
end

--- Handle click on day cell
--- @param cell control The day cell
--- @param button number Mouse button
function TC:OnDayCellClicked(cell, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    if not cell.dayData then return end

    -- Select this date
    TC:SelectDate(cell.timestamp)

    -- If double-click or has events, could switch to day view
    -- For now, just select
    PlaySound(SOUNDS.POSITIVE_CLICK)
end

--- Handle mouse enter on event pip
--- @param pip control The event pip
function TC:OnEventPipMouseEnter(pip)
    if not pip.event then return end

    local event = pip.event
    local use24Hour = TC:GetPreference("use24HourTime")

    -- Build tooltip
    local lines = {
        event.title,
        DH.FormatDateTime(event.startTime, use24Hour),
    }

    if event.description and event.description ~= "" then
        table.insert(lines, "")
        table.insert(lines, event.description:sub(1, 50))
    end

    if event.guildId then
        local guildName = GetGuildName(event.guildId)
        if guildName and guildName ~= "" then
            table.insert(lines, "Guild: " .. guildName)
        end
    end

    ZO_Tooltips_ShowTextTooltip(pip, TOP, table.concat(lines, "\n"))
end

--- Handle mouse exit on event pip
--- @param pip control The event pip
function TC:OnEventPipMouseExit(pip)
    ZO_Tooltips_HideTextTooltip()
end

--- Handle click on event pip
--- @param pip control The event pip
--- @param button number Mouse button
function TC:OnEventPipClicked(pip, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    if not pip.event then return end

    -- Store selected event and switch to day view
    TC.selectedEvent = pip.event
    TC:SelectDate(pip.event.startTime)

    -- Could open event details or switch to day view
    PlaySound(SOUNDS.POSITIVE_CLICK)
end

-------------------------------------------------
-- Navigation Handlers
-------------------------------------------------

--- Handle prev button click
function TC:OnPrevClicked()
    if TC.currentView == TC.VIEW_MODES.MONTH then
        TC:PrevMonth()
    elseif TC.currentView == TC.VIEW_MODES.WEEK then
        -- Go back 1 week
        local weekStart = DH.StartOfWeek(TC.selectedDate or DH.GetNow())
        TC:SelectDate(weekStart - DH.SECONDS_PER_DAY * 7)
    elseif TC.currentView == TC.VIEW_MODES.DAY then
        -- Go back 1 day
        local current = TC.selectedDate or DH.GetTodayMidnight()
        TC:SelectDate(current - DH.SECONDS_PER_DAY)
    end
    PlaySound(SOUNDS.POSITIVE_CLICK)
end

--- Handle next button click
function TC:OnNextClicked()
    if TC.currentView == TC.VIEW_MODES.MONTH then
        TC:NextMonth()
    elseif TC.currentView == TC.VIEW_MODES.WEEK then
        -- Go forward 1 week
        local weekStart = DH.StartOfWeek(TC.selectedDate or DH.GetNow())
        TC:SelectDate(weekStart + DH.SECONDS_PER_DAY * 7)
    elseif TC.currentView == TC.VIEW_MODES.DAY then
        -- Go forward 1 day
        local current = TC.selectedDate or DH.GetTodayMidnight()
        TC:SelectDate(current + DH.SECONDS_PER_DAY)
    end
    PlaySound(SOUNDS.POSITIVE_CLICK)
end

-------------------------------------------------
-- View Management
-------------------------------------------------

--- Show the month view
function MV:Show()
    local monthView = TamCalWindowContentMonthView
    if monthView then
        monthView:SetHidden(false)
    end
end

--- Hide the month view
function MV:Hide()
    local monthView = TamCalWindowContentMonthView
    if monthView then
        monthView:SetHidden(true)
    end
end

-------------------------------------------------
-- Hook into main refresh
-------------------------------------------------

-- Override TC:RefreshView to call our refresh
local originalRefreshView = TC.RefreshView
function TC:RefreshView()
    if originalRefreshView then
        originalRefreshView(self)
    end

    -- Update view visibility
    local monthView = TamCalWindowContentMonthView
    local weekView = TamCalWindowContentWeekView
    local dayView = TamCalWindowContentDayView

    if self.currentView == self.VIEW_MODES.MONTH then
        if monthView then monthView:SetHidden(false) end
        if weekView then weekView:SetHidden(true) end
        if dayView then dayView:SetHidden(true) end
        MV:Refresh()
    elseif self.currentView == self.VIEW_MODES.WEEK then
        if monthView then monthView:SetHidden(true) end
        if weekView then weekView:SetHidden(false) end
        if dayView then dayView:SetHidden(true) end
        -- WeekView:Refresh() would go here
    elseif self.currentView == self.VIEW_MODES.DAY then
        if monthView then monthView:SetHidden(true) end
        if weekView then weekView:SetHidden(true) end
        if dayView then dayView:SetHidden(false) end
        -- DayView:Refresh() would go here
    end
end

-------------------------------------------------
-- Initialization Hook
-------------------------------------------------

-- Initialize when UI is ready
local function OnPlayerActivated()
    -- Delay to ensure XML is loaded
    zo_callLater(function()
        MV:Initialize()
        if TC.initialized and TamCalWindow then
            -- Restore window position
            local pos = TC:GetPreference("windowPosition")
            if pos then
                TamCalWindow:ClearAnchors()
                TamCalWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, pos.x, pos.y)
            end
        end
    end, 100)
end

EVENT_MANAGER:RegisterForEvent(TC.name .. "_MonthView", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
