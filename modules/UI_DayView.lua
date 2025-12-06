--[[
    UI_DayView.lua
    Day view calendar rendering

    Displays a single day with:
    - Day header (weekday, date, month)
    - Hourly schedule (configurable range)
    - Event blocks positioned by time
    - Sidebar with selected event details
]]

local TC = TamrielCalendar
local DH = TC.DateHelpers
local EM = TC.EventManager

TC.DayView = {}
local DV = TC.DayView

-------------------------------------------------
-- Constants
-------------------------------------------------

local TIME_COLUMN_WIDTH = 60   -- Width of the time label column
local HOUR_ROW_HEIGHT = 38     -- Height of each hour row (per GUI spec)
local SIDEBAR_WIDTH = 190      -- Width of sidebar (per GUI spec)

-- Colors (matching WeekView/MonthView)
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
    cellBg = {30/255, 28/255, 25/255, 0.6},
    cellBgAlt = {35/255, 33/255, 30/255, 0.6},
    todayBg = {197/255, 165/255, 82/255, 0.1},
    selectedBg = {197/255, 165/255, 82/255, 0.15},
    sidebarBg = {26/255, 24/255, 21/255, 0.9},

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

    -- Category border
    categoryBorder = {
        Raid = {255/255, 102/255, 102/255, 1},
        Party = {102/255, 153/255, 255/255, 1},
        Training = {102/255, 255/255, 102/255, 1},
        Meeting = {255/255, 204/255, 102/255, 1},
        Personal = {153/255, 102/255, 255/255, 1},
    },
}

-------------------------------------------------
-- State
-------------------------------------------------

DV.hourRows = {}            -- Hour row controls
DV.eventBlockPool = {}      -- Pool of event block controls
DV.activeBlocks = {}        -- Currently visible blocks
DV.selectedEvent = nil      -- Currently selected event for sidebar
DV.initialized = false

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

--- Initialize the day view UI
function DV:Initialize()
    if self.initialized then return end -- Prevent double init

    local dayView = TamCalWindowContentDayView
    if not dayView then
        TC:Debug("DayView: Cannot find TamCalWindowContentDayView")
        return
    end

    self:CreateHourGrid()
    self:SetupSidebar()
    self.initialized = true

    TC:Debug("DayView: Initialized")
end

--- Create the hour grid
function DV:CreateHourGrid()
    local schedule = TamCalWindowContentDayViewSchedule
    if not schedule then return end

    local prefs = TC.savedVars and TC.savedVars.preferences or {}
    local hourRange = prefs.hourRange or {start = 17, stop = 24}
    local startHour = hourRange.start or 17
    local endHour = hourRange.stop or 24
    local use24Hour = prefs.use24HourTime

    local scheduleWidth = schedule:GetWidth()
    local eventAreaWidth = scheduleWidth - TIME_COLUMN_WIDTH

    for hour = startHour, endHour - 1 do
        local rowIndex = hour - startHour + 1
        local yOffset = (rowIndex - 1) * HOUR_ROW_HEIGHT

        -- Create hour row container
        local hourRowName = "TamCalDayHourRow" .. hour
        local hourRow = GetOrCreateControl(hourRowName, schedule, CT_CONTROL)
        hourRow:SetDimensions(scheduleWidth, HOUR_ROW_HEIGHT)
        hourRow:SetAnchor(TOPLEFT, schedule, TOPLEFT, 0, yOffset)

        -- Background for the entire row
        local rowBg = hourRow:GetNamedChild("RowBG") or CreateControl(hourRowName .. "RowBG", hourRow, CT_BACKDROP)
        rowBg:SetAnchorFill()
        local bgColor = (rowIndex % 2 == 0) and COLORS.cellBgAlt or COLORS.cellBg
        rowBg:SetCenterColor(unpack(bgColor))
        rowBg:SetEdgeColor(unpack(COLORS.borderNormal))
        rowBg:SetEdgeTexture("", 1, 1, 1, 0)

        -- Time label
        local timeLabel = hourRow:GetNamedChild("Time") or CreateControl(hourRowName .. "Time", hourRow, CT_LABEL)
        timeLabel:SetDimensions(TIME_COLUMN_WIDTH - 8, HOUR_ROW_HEIGHT)
        timeLabel:SetAnchor(TOPLEFT, hourRow, TOPLEFT, 4, 0)
        timeLabel:SetFont("ZoFontGameSmall")
        timeLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        timeLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
        timeLabel:SetColor(unpack(COLORS.mutedText))

        -- Format time label
        local timeText
        if use24Hour then
            timeText = string.format("%02d:00", hour)
        else
            local displayHour = hour % 12
            if displayHour == 0 then displayHour = 12 end
            local period = hour < 12 and "AM" or "PM"
            timeText = string.format("%d:00 %s", displayHour, period)
        end
        timeLabel:SetText(timeText)

        -- Event area (clickable)
        local eventArea = hourRow:GetNamedChild("Events") or CreateControl(hourRowName .. "Events", hourRow, CT_CONTROL)
        eventArea:SetDimensions(eventAreaWidth, HOUR_ROW_HEIGHT)
        eventArea:SetAnchor(TOPLEFT, hourRow, TOPLEFT, TIME_COLUMN_WIDTH, 0)

        -- Event area background
        local areaBg = eventArea:GetNamedChild("BG") or CreateControl(hourRowName .. "EventsBG", eventArea, CT_BACKDROP)
        areaBg:SetAnchorFill()
        areaBg:SetCenterColor(0, 0, 0, 0) -- Transparent
        areaBg:SetEdgeColor(unpack(COLORS.borderNormal))
        areaBg:SetEdgeTexture("", 1, 1, 1, 0)

        eventArea:SetMouseEnabled(true)
        eventArea:SetHandler("OnMouseUp", function(control, button)
            DV:OnHourCellClicked(control, button, hour)
        end)

        hourRow.timeLabel = timeLabel
        hourRow.eventArea = eventArea
        hourRow.bg = rowBg
        hourRow.areaBg = areaBg
        hourRow.hour = hour

        self.hourRows[hour] = hourRow
    end
end

--- Setup the sidebar for event details
function DV:SetupSidebar()
    local sidebar = TamCalWindowContentDayViewSidebar
    if not sidebar then return end

    local bg = sidebar:GetNamedChild("BG")
    if bg then
        bg:SetCenterColor(unpack(COLORS.sidebarBg))
        bg:SetEdgeColor(unpack(COLORS.borderNormal))
    end

    local title = sidebar:GetNamedChild("Title")
    if title then
        title:SetColor(unpack(COLORS.headerGold))
    end
end

-------------------------------------------------
-- Rendering
-------------------------------------------------

--- Refresh the day view with current data
function DV:Refresh()
    if not TC.initialized or not self.initialized then return end

    local selectedDate = TC.selectedDate or DH.GetTodayMidnight()
    local dayStart = DH.StartOfDay(selectedDate)
    local dayEnd = DH.EndOfDay(selectedDate)
    local todayMidnight = DH.GetTodayMidnight()
    local isToday = dayStart == todayMidnight

    -- Update header label
    self:UpdateDayHeader(dayStart, isToday)

    -- Update period label (single day)
    self:UpdatePeriodLabel(dayStart)

    -- Get events for the day
    local events = EM:GetEventsForDay(dayStart)

    -- Clear existing blocks
    self:ClearEventBlocks()

    -- Update hour row backgrounds
    self:UpdateHourBackgrounds(isToday)

    -- Render events
    self:RenderEvents(events, dayStart)

    -- Update sidebar with selected or first event
    self:UpdateSidebar()
end

--- Update the day header label
--- @param dayStart number Day start timestamp
--- @param isToday boolean Whether this is today
function DV:UpdateDayHeader(dayStart, isToday)
    local header = TamCalWindowContentDayViewDayHeader
    if not header then return end

    local t = os.date("*t", dayStart)
    local weekday = DH.FormatWeekday(dayStart, false) -- Full weekday name
    local text = string.format("%s, %s %d", weekday, DH.FormatMonth(t.month, false), t.day)

    if isToday then
        text = text .. " (Today)"
        header:SetColor(unpack(COLORS.headerGold))
    else
        header:SetColor(unpack(COLORS.bodyText))
    end

    header:SetText(text)
end

--- Update the period label for nav bar
--- @param dayStart number Day start timestamp
function DV:UpdatePeriodLabel(dayStart)
    local label = TamCalWindowNavBarPeriodLabel
    if not label then return end

    local t = os.date("*t", dayStart)
    local text = string.format("%s %d, %d", DH.FormatMonth(t.month, false), t.day, t.year)
    label:SetText(text)
end

--- Update hour row backgrounds
--- @param isToday boolean Whether viewing today
function DV:UpdateHourBackgrounds(isToday)
    local prefs = TC.savedVars and TC.savedVars.preferences or {}
    local hourRange = prefs.hourRange or {start = 17, stop = 24}

    for hour = hourRange.start, hourRange.stop - 1 do
        local row = self.hourRows[hour]
        if row then
            local rowIndex = hour - hourRange.start + 1
            local baseBg = (rowIndex % 2 == 0) and COLORS.cellBgAlt or COLORS.cellBg

            if isToday then
                row.bg:SetCenterColor(COLORS.todayBg[1], COLORS.todayBg[2], COLORS.todayBg[3], 0.3)
            else
                row.bg:SetCenterColor(unpack(baseBg))
            end
        end
    end
end

-------------------------------------------------
-- Event Blocks
-------------------------------------------------

--- Get or create an event block from the pool
--- @return control Event block control
function DV:GetEventBlock()
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
        "TamCalDayEventBlock" .. blockIndex,
        GuiRoot,
        "TamCal_EventBlock_Template"
    )

    block:SetHidden(false)
    table.insert(self.eventBlockPool, block)
    table.insert(self.activeBlocks, block)

    return block
end

--- Clear all visible event blocks
function DV:ClearEventBlocks()
    for _, block in ipairs(self.activeBlocks) do
        block:SetHidden(true)
        block:ClearAnchors()
        block:SetParent(GuiRoot)
    end
    self.activeBlocks = {}
end

--- Render events in the schedule
--- @param events table Array of events
--- @param dayStart number Start of the day timestamp
function DV:RenderEvents(events, dayStart)
    local schedule = TamCalWindowContentDayViewSchedule
    if not schedule then return end

    local prefs = TC.savedVars and TC.savedVars.preferences or {}
    local hourRange = prefs.hourRange or {start = 17, stop = 24}
    local startHour = hourRange.start
    local endHour = hourRange.stop
    local use24Hour = prefs.use24HourTime

    local scheduleWidth = schedule:GetWidth()
    local eventAreaWidth = scheduleWidth - TIME_COLUMN_WIDTH

    -- Sort events by start time
    table.sort(events, function(a, b)
        return a.startTime < b.startTime
    end)

    -- Track overlapping events for column layout
    local columns = {}

    for _, event in ipairs(events) do
        local eventStartHour, eventStartMin = DH.GetTime(event.startTime)
        local eventEndHour, eventEndMin = DH.GetTime(event.endTime)

        -- Check if event is visible in the hour range
        if eventEndHour >= startHour and eventStartHour < endHour then
            -- Calculate column for overlapping events
            local column = self:FindAvailableColumn(columns, event)

            self:RenderEventBlock(event, column, eventAreaWidth, startHour, endHour, use24Hour, schedule)
        end
    end
end

--- Find an available column for an event (handles overlapping)
--- @param columns table Track of column usage
--- @param event table The event
--- @return number Column index (1-based)
function DV:FindAvailableColumn(columns, event)
    -- Simple approach: find first column where event doesn't overlap
    for colIndex, colEvents in ipairs(columns) do
        local canUse = true
        for _, otherEvent in ipairs(colEvents) do
            if self:EventsOverlap(event, otherEvent) then
                canUse = false
                break
            end
        end
        if canUse then
            table.insert(columns[colIndex], event)
            return colIndex
        end
    end

    -- Need new column
    local newColIndex = #columns + 1
    columns[newColIndex] = {event}
    return newColIndex
end

--- Check if two events overlap in time
--- @param event1 table First event
--- @param event2 table Second event
--- @return boolean True if overlapping
function DV:EventsOverlap(event1, event2)
    return event1.startTime < event2.endTime and event2.startTime < event1.endTime
end

--- Render a single event block
--- @param event table The event
--- @param column number Column for positioning (for overlaps)
--- @param totalWidth number Total width of event area
--- @param startHour number First visible hour
--- @param endHour number Last visible hour
--- @param use24Hour boolean Use 24-hour time format
--- @param schedule control The schedule container
function DV:RenderEventBlock(event, column, totalWidth, startHour, endHour, use24Hour, schedule)
    local eventStartHour, eventStartMin = DH.GetTime(event.startTime)
    local eventEndHour, eventEndMin = DH.GetTime(event.endTime)

    -- Clamp to visible range
    local displayStartHour = math.max(eventStartHour, startHour)
    local displayEndHour = math.min(eventEndHour, endHour)

    -- Calculate position
    local startMinutes = (displayStartHour - startHour) * 60 + (eventStartHour >= startHour and eventStartMin or 0)
    local endMinutes = (displayEndHour - startHour) * 60 + eventEndMin

    local yOffset = (startMinutes / 60) * HOUR_ROW_HEIGHT
    local height = ((endMinutes - startMinutes) / 60) * HOUR_ROW_HEIGHT
    height = math.max(height, 24) -- Minimum height

    -- Calculate horizontal position (for overlapping events)
    local maxColumns = 3 -- Support up to 3 overlapping events
    local colWidth = (totalWidth - 8) / math.min(column, maxColumns)
    local xOffset = TIME_COLUMN_WIDTH + 4 + (column - 1) * colWidth
    local width = colWidth - 4

    -- Create block
    local block = self:GetEventBlock()
    block:SetParent(schedule)
    block:ClearAnchors()
    block:SetAnchor(TOPLEFT, schedule, TOPLEFT, xOffset, yOffset)
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
    local borderColor = COLORS.categoryBorder[category] or COLORS.categoryBorder.Personal

    if bg then
        bg:SetCenterColor(unpack(bgColor))
        bg:SetEdgeColor(unpack(borderColor))
    end

    if titleLabel then
        local displayTitle = event.title
        -- Truncate based on width
        local maxChars = math.floor(width / 7)
        if #displayTitle > maxChars then
            displayTitle = displayTitle:sub(1, maxChars - 2) .. "..."
        end
        titleLabel:SetText(displayTitle)
        titleLabel:SetColor(unpack(textColor))
    end

    if timeLabel then
        timeLabel:SetText(DH.FormatTimeRange(event.startTime, event.endTime, use24Hour))
        timeLabel:SetColor(textColor[1], textColor[2], textColor[3], 0.7)
    end

    block:SetMouseEnabled(true)

    -- Highlight selected event
    if self.selectedEvent and self.selectedEvent.eventId == event.eventId then
        if bg then
            bg:SetEdgeColor(unpack(COLORS.borderSelected))
        end
    end
end

-------------------------------------------------
-- Sidebar
-------------------------------------------------

--- Update the sidebar with event details
function DV:UpdateSidebar()
    local details = TamCalWindowContentDayViewSidebarDetails
    if not details then return end

    -- Clear existing content
    local children = {details:GetChildren()}
    for _, child in ipairs(children) do
        child:SetHidden(true)
    end

    -- If we have a selected event or active events, show the first one
    local event = self.selectedEvent

    if not event and #self.activeBlocks > 0 then
        event = self.activeBlocks[1].event
    end

    if not event then
        self:ShowNoEventMessage(details)
        return
    end

    self:ShowEventDetails(details, event)
end

--- Show "no event selected" message
--- @param parent control Parent control
function DV:ShowNoEventMessage(parent)
    local label = parent:GetNamedChild("NoEventLabel")
    if not label then
        label = CreateControl("$(parent)NoEventLabel", parent, CT_LABEL)
        label:SetFont("ZoFontGameSmall")
        label:SetColor(unpack(COLORS.mutedText))
        label:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
        label:SetDimensionConstraints(0, 0, parent:GetWidth(), 0)
        label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end

    label:SetHidden(false)
    label:SetText("Click an event to view details.\n\nOr click an empty time slot to create a new event.")
end

--- Show event details in sidebar
--- @param parent control Parent control
--- @param event table The event
function DV:ShowEventDetails(parent, event)
    local prefs = TC.savedVars and TC.savedVars.preferences or {}
    local use24Hour = prefs.use24HourTime

    local yOffset = 0
    local labelWidth = parent:GetWidth()

    -- Hide no event message if exists
    local noEventLabel = parent:GetNamedChild("NoEventLabel")
    if noEventLabel then
        noEventLabel:SetHidden(true)
    end

    -- Title
    local titleLabel = self:GetOrCreateLabel(parent, "Title", yOffset)
    titleLabel:SetFont("ZoFontWinH4")
    titleLabel:SetText(event.title)
    local category = event.category or "Personal"
    titleLabel:SetColor(unpack(COLORS.categoryText[category] or COLORS.categoryText.Personal))
    yOffset = yOffset + 28

    -- Time
    local timeLabel = self:GetOrCreateLabel(parent, "Time", yOffset)
    timeLabel:SetFont("ZoFontGameSmall")
    timeLabel:SetText(DH.FormatTimeRange(event.startTime, event.endTime, use24Hour))
    timeLabel:SetColor(unpack(COLORS.mutedText))
    yOffset = yOffset + 20

    -- Category
    local categoryLabel = self:GetOrCreateLabel(parent, "Category", yOffset)
    categoryLabel:SetFont("ZoFontGameSmall")
    categoryLabel:SetText("Category: " .. (event.category or "Personal"))
    categoryLabel:SetColor(unpack(COLORS.bodyText))
    yOffset = yOffset + 20

    -- Description
    if event.description and event.description ~= "" then
        yOffset = yOffset + 8
        local descLabel = self:GetOrCreateLabel(parent, "Desc", yOffset)
        descLabel:SetFont("ZoFontGameSmall")
        descLabel:SetText(event.description)
        descLabel:SetColor(unpack(COLORS.bodyText))
        descLabel:SetDimensionConstraints(0, 0, labelWidth, 100)
        descLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
        yOffset = yOffset + math.min(descLabel:GetTextHeight() + 4, 80)
    end

    -- Guild info (if guild event)
    if event.guildId then
        yOffset = yOffset + 12
        local guildName = GetGuildName(event.guildId)
        if guildName and guildName ~= "" then
            local guildLabel = self:GetOrCreateLabel(parent, "Guild", yOffset)
            guildLabel:SetFont("ZoFontGameSmall")
            guildLabel:SetText("Guild: " .. guildName)
            guildLabel:SetColor(unpack(COLORS.headerGold))
            yOffset = yOffset + 20
        end

        -- Attendee counts
        local counts = EM:GetAttendeeCounts(event)
        if counts.total > 0 then
            local attendeeLabel = self:GetOrCreateLabel(parent, "Attendees", yOffset)
            attendeeLabel:SetFont("ZoFontGameSmall")
            attendeeLabel:SetText(string.format(
                "Attendees: %d (T:%d H:%d D:%d)",
                counts.total, counts.Tank or 0, counts.Healer or 0, counts.DPS or 0
            ))
            attendeeLabel:SetColor(unpack(COLORS.bodyText))
            yOffset = yOffset + 20
        end
    end

    -- Action hint
    yOffset = yOffset + 16
    local hintLabel = self:GetOrCreateLabel(parent, "Hint", yOffset)
    hintLabel:SetFont("ZoFontGameSmall")
    if event.guildId then
        local isSignedUp = EM:IsSignedUp(event.guildId, event.eventId)
        if isSignedUp then
            hintLabel:SetText("You are signed up!")
            hintLabel:SetColor(0.5, 1, 0.5, 1)
        else
            hintLabel:SetText("Click event to sign up")
            hintLabel:SetColor(unpack(COLORS.mutedText))
        end
    else
        hintLabel:SetText("Click to edit")
        hintLabel:SetColor(unpack(COLORS.mutedText))
    end
end

--- Get or create a label in the sidebar
--- @param parent control Parent control
--- @param name string Label name suffix
--- @param yOffset number Vertical offset
--- @return control Label control
function DV:GetOrCreateLabel(parent, name, yOffset)
    local fullName = "Detail" .. name
    local label = parent:GetNamedChild(fullName)

    if not label then
        label = CreateControl("$(parent)" .. fullName, parent, CT_LABEL)
        label:SetDimensionConstraints(0, 0, parent:GetWidth(), 0)
    end

    label:SetHidden(false)
    label:ClearAnchors()
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, yOffset)

    return label
end

-------------------------------------------------
-- Event Handlers
-------------------------------------------------

--- Handle click on hour cell
--- @param control control The hour cell control
--- @param button number Mouse button
--- @param hour number The hour clicked
function DV:OnHourCellClicked(control, button, hour)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end

    local selectedDate = TC.selectedDate or DH.GetTodayMidnight()
    local clickTime = DH.SetTime(selectedDate, hour, 0)

    -- Open event form with this time
    TC.eventFormStartTime = clickTime
    TC.eventFormEndTime = clickTime + DH.SECONDS_PER_HOUR

    TC:ShowEventForm()
    PlaySound(SOUNDS.POSITIVE_CLICK)
end

--- Handle mouse enter on event block (called from XML via main TC handlers)
function TC:OnDayEventBlockMouseEnter(block)
    DV:OnEventBlockMouseEnter(block)
end

--- Handle mouse exit on event block
function TC:OnDayEventBlockMouseExit(block)
    DV:OnEventBlockMouseExit(block)
end

--- Handle click on event block
function TC:OnDayEventBlockClicked(block, button)
    DV:OnEventBlockClicked(block, button)
end

--- Handle mouse enter on event block
--- @param block control The event block
function DV:OnEventBlockMouseEnter(block)
    if not block.event then return end

    local event = block.event
    local use24Hour = TC:GetPreference("use24HourTime")

    -- Highlight the block
    local bg = block:GetNamedChild("BG")
    if bg then
        bg:SetEdgeColor(unpack(COLORS.borderHover))
    end

    -- Build tooltip
    local lines = {
        event.title,
        DH.FormatTimeRange(event.startTime, event.endTime, use24Hour),
    }

    if event.description and event.description ~= "" then
        table.insert(lines, "")
        local desc = event.description
        if #desc > 80 then
            desc = desc:sub(1, 77) .. "..."
        end
        table.insert(lines, desc)
    end

    if event.guildId then
        local guildName = GetGuildName(event.guildId)
        if guildName and guildName ~= "" then
            table.insert(lines, "")
            table.insert(lines, "Guild: " .. guildName)
        end

        local counts = EM:GetAttendeeCounts(event)
        if counts.total > 0 then
            table.insert(lines, string.format("Attendees: %d", counts.total))
        end
    end

    ZO_Tooltips_ShowTextTooltip(block, RIGHT, table.concat(lines, "\n"))
end

--- Handle mouse exit on event block
--- @param block control The event block
function DV:OnEventBlockMouseExit(block)
    ZO_Tooltips_HideTextTooltip()

    -- Reset highlight
    local bg = block:GetNamedChild("BG")
    if bg and block.event then
        local category = block.event.category or "Personal"
        local borderColor = COLORS.categoryBorder[category] or COLORS.categoryBorder.Personal

        -- Check if this is the selected event
        if self.selectedEvent and self.selectedEvent.eventId == block.event.eventId then
            bg:SetEdgeColor(unpack(COLORS.borderSelected))
        else
            bg:SetEdgeColor(unpack(borderColor))
        end
    end
end

--- Handle click on event block
--- @param block control The event block
--- @param button number Mouse button
function DV:OnEventBlockClicked(block, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    if not block.event then return end

    local event = block.event

    -- Select this event for sidebar
    self.selectedEvent = event
    TC.selectedEvent = event

    -- Update sidebar
    self:UpdateSidebar()

    -- Refresh to update visual selection
    self:Refresh()

    -- If guild event and not signed up, show sign-up dialog
    if event.guildId then
        local isSignedUp = EM:IsSignedUp(event.guildId, event.eventId)
        if not isSignedUp then
            TC:ShowSignUpDialog(event)
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

--- Show the day view
function DV:Show()
    local dayView = TamCalWindowContentDayView
    if dayView then
        dayView:SetHidden(false)
    end
end

--- Hide the day view
function DV:Hide()
    local dayView = TamCalWindowContentDayView
    if dayView then
        dayView:SetHidden(true)
    end

    -- Clear selection when hiding
    self.selectedEvent = nil
end

-------------------------------------------------
-- Hook into RefreshView
-------------------------------------------------

-- Store original RefreshView to chain
local originalRefreshView = TC.RefreshView

function TC:RefreshView()
    -- Call original (which handles MonthView and WeekView)
    if originalRefreshView then
        originalRefreshView(self)
    end

    -- Handle DayView
    if self.currentView == self.VIEW_MODES.DAY then
        if DV.initialized then
            DV:Refresh()
        end
    end
end

-------------------------------------------------
-- Initialization Hook
-------------------------------------------------

-- Initialize when UI is ready
local function OnPlayerActivated()
    zo_callLater(function()
        DV:Initialize()
    end, 200) -- After MonthView and WeekView
end

EVENT_MANAGER:RegisterForEvent(TC.name .. "_DayView", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
