--[[
    DateHelpers.lua
    Pure date/time utility functions for Tamriel Calendar
    No external dependencies - uses only Lua os.date/os.time
]]

local TC = TamrielCalendar or {}
TamrielCalendar = TC

-- Set addon name early so all modules can use it for event registration
TC.name = TC.name or "TamrielCalendar"

TC.DateHelpers = {}
local DH = TC.DateHelpers

-- Constants
local SECONDS_PER_DAY = 86400
local SECONDS_PER_HOUR = 3600
local SECONDS_PER_MINUTE = 60

-- Month names for formatting
local MONTH_NAMES = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
}

local MONTH_NAMES_SHORT = {
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
}

local WEEKDAY_NAMES = {
    "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
}

local WEEKDAY_NAMES_SHORT = {
    "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
}

-------------------------------------------------
-- Core Date Math
-------------------------------------------------

--- Get the number of days in a given month
--- @param year number The year
--- @param month number The month (1-12)
--- @return number The number of days in the month
function DH.DaysInMonth(year, month)
    -- Month + 1, day 0 = last day of current month
    return os.date("*t", os.time({year = year, month = month + 1, day = 0})).day
end

--- Get the weekday of the first day of a month
--- @param year number The year
--- @param month number The month (1-12)
--- @return number Weekday (1=Sunday, 7=Saturday in Lua)
function DH.FirstWeekday(year, month)
    local t = os.date("*t", os.time({year = year, month = month, day = 1}))
    return t.wday
end

--- Get timestamp for start of day (midnight 00:00:00)
--- @param ts number Unix timestamp
--- @return number Timestamp at midnight of that day
function DH.StartOfDay(ts)
    local t = os.date("*t", ts)
    return os.time({year = t.year, month = t.month, day = t.day, hour = 0, min = 0, sec = 0})
end

--- Get timestamp for end of day (23:59:59)
--- @param ts number Unix timestamp
--- @return number Timestamp at end of that day
function DH.EndOfDay(ts)
    local t = os.date("*t", ts)
    return os.time({year = t.year, month = t.month, day = t.day, hour = 23, min = 59, sec = 59})
end

--- Get timestamp for start of week (Monday 00:00:00)
--- @param ts number Unix timestamp
--- @param mondayStart boolean If true, week starts Monday; if false, Sunday (default true)
--- @return number Timestamp at start of week
function DH.StartOfWeek(ts, mondayStart)
    if mondayStart == nil then mondayStart = true end

    local t = os.date("*t", ts)
    local wday = t.wday -- Lua: Sunday=1, Monday=2, ..., Saturday=7

    local offset
    if mondayStart then
        -- Monday start: Sunday needs to go back 6 days, Monday is 0
        offset = (wday == 1) and 6 or (wday - 2)
    else
        -- Sunday start: Sunday is 0
        offset = wday - 1
    end

    return DH.StartOfDay(ts - offset * SECONDS_PER_DAY)
end

--- Get timestamp for end of week (Sunday 23:59:59 or Saturday if Monday start)
--- @param ts number Unix timestamp
--- @param mondayStart boolean If true, week starts Monday; if false, Sunday (default true)
--- @return number Timestamp at end of week
function DH.EndOfWeek(ts, mondayStart)
    local startOfWeek = DH.StartOfWeek(ts, mondayStart)
    return DH.EndOfDay(startOfWeek + 6 * SECONDS_PER_DAY)
end

--- Navigate months forward or backward
--- @param year number Starting year
--- @param month number Starting month (1-12)
--- @param delta number Months to add (negative to subtract)
--- @return number, number New year and month
function DH.AddMonth(year, month, delta)
    month = month + delta
    while month > 12 do
        year = year + 1
        month = month - 12
    end
    while month < 1 do
        year = year - 1
        month = month + 12
    end
    return year, month
end

--- Get today's midnight timestamp
--- @return number Timestamp at midnight today
function DH.GetTodayMidnight()
    return DH.StartOfDay(GetTimeStamp())
end

--- Get current timestamp (wrapper for ESO API)
--- @return number Current Unix timestamp
function DH.GetNow()
    return GetTimeStamp()
end

-------------------------------------------------
-- Date Component Extraction
-------------------------------------------------

--- Extract date components from timestamp
--- @param ts number Unix timestamp
--- @return table Table with year, month, day, hour, min, sec, wday
function DH.GetComponents(ts)
    return os.date("*t", ts)
end

--- Get just the date portion (year, month, day)
--- @param ts number Unix timestamp
--- @return number, number, number year, month, day
function DH.GetDate(ts)
    local t = os.date("*t", ts)
    return t.year, t.month, t.day
end

--- Get just the time portion (hour, minute)
--- @param ts number Unix timestamp
--- @return number, number hour, minute
function DH.GetTime(ts)
    local t = os.date("*t", ts)
    return t.hour, t.min
end

-------------------------------------------------
-- Timestamp Construction
-------------------------------------------------

--- Create timestamp from date components
--- @param year number Year
--- @param month number Month (1-12)
--- @param day number Day (1-31)
--- @param hour number Hour (0-23), default 0
--- @param min number Minute (0-59), default 0
--- @return number Unix timestamp
function DH.MakeTimestamp(year, month, day, hour, min)
    return os.time({
        year = year,
        month = month,
        day = day,
        hour = hour or 0,
        min = min or 0,
        sec = 0
    })
end

--- Create timestamp from date and time offset
--- @param dateTs number Timestamp for the date (any time that day)
--- @param hour number Hour (0-23)
--- @param min number Minute (0-59)
--- @return number Unix timestamp
function DH.SetTime(dateTs, hour, min)
    local t = os.date("*t", dateTs)
    return os.time({
        year = t.year,
        month = t.month,
        day = t.day,
        hour = hour,
        min = min or 0,
        sec = 0
    })
end

-------------------------------------------------
-- Formatting Functions
-------------------------------------------------

--- Format date as "Dec 4, 2025"
--- @param ts number Unix timestamp
--- @return string Formatted date
function DH.FormatDate(ts)
    local t = os.date("*t", ts)
    return string.format("%s %d, %d", MONTH_NAMES_SHORT[t.month], t.day, t.year)
end

--- Format date as "December 4, 2025"
--- @param ts number Unix timestamp
--- @return string Formatted date (long form)
function DH.FormatDateLong(ts)
    local t = os.date("*t", ts)
    return string.format("%s %d, %d", MONTH_NAMES[t.month], t.day, t.year)
end

--- Format date as "12/4/2025" or "4/12/2025" depending on locale preference
--- @param ts number Unix timestamp
--- @param dayFirst boolean If true, format as DD/MM/YYYY
--- @return string Formatted date
function DH.FormatDateNumeric(ts, dayFirst)
    local t = os.date("*t", ts)
    if dayFirst then
        return string.format("%d/%d/%d", t.day, t.month, t.year)
    else
        return string.format("%d/%d/%d", t.month, t.day, t.year)
    end
end

--- Format time as "8:00 PM" or "20:00"
--- @param ts number Unix timestamp
--- @param use24Hour boolean If true, use 24-hour format
--- @return string Formatted time
function DH.FormatTime(ts, use24Hour)
    local t = os.date("*t", ts)

    if use24Hour then
        return string.format("%d:%02d", t.hour, t.min)
    else
        local hour = t.hour
        local period = "AM"

        if hour == 0 then
            hour = 12
        elseif hour == 12 then
            period = "PM"
        elseif hour > 12 then
            hour = hour - 12
            period = "PM"
        end

        return string.format("%d:%02d %s", hour, t.min, period)
    end
end

--- Format date and time as "Dec 4, 8:00 PM"
--- @param ts number Unix timestamp
--- @param use24Hour boolean If true, use 24-hour format
--- @return string Formatted date and time
function DH.FormatDateTime(ts, use24Hour)
    return DH.FormatDate(ts) .. ", " .. DH.FormatTime(ts, use24Hour)
end

--- Format time range as "8:00 PM - 11:00 PM"
--- @param startTs number Start timestamp
--- @param endTs number End timestamp
--- @param use24Hour boolean If true, use 24-hour format
--- @return string Formatted time range
function DH.FormatTimeRange(startTs, endTs, use24Hour)
    return DH.FormatTime(startTs, use24Hour) .. " - " .. DH.FormatTime(endTs, use24Hour)
end

--- Format weekday name
--- @param ts number Unix timestamp
--- @param short boolean If true, use short form (Mon vs Monday)
--- @return string Weekday name
function DH.FormatWeekday(ts, short)
    local t = os.date("*t", ts)
    if short then
        return WEEKDAY_NAMES_SHORT[t.wday]
    else
        return WEEKDAY_NAMES[t.wday]
    end
end

--- Format month name
--- @param month number Month (1-12)
--- @param short boolean If true, use short form (Dec vs December)
--- @return string Month name
function DH.FormatMonth(month, short)
    if short then
        return MONTH_NAMES_SHORT[month]
    else
        return MONTH_NAMES[month]
    end
end

--- Format relative time (e.g., "in 2 hours", "yesterday")
--- @param ts number Unix timestamp
--- @return string Relative time description
function DH.FormatRelative(ts)
    local now = DH.GetNow()
    local diff = ts - now
    local absDiff = math.abs(diff)
    local isPast = diff < 0

    -- Within the hour
    if absDiff < SECONDS_PER_HOUR then
        local mins = math.floor(absDiff / SECONDS_PER_MINUTE)
        if mins < 1 then
            return isPast and "just now" or "now"
        end
        local unit = mins == 1 and "minute" or "minutes"
        return isPast and string.format("%d %s ago", mins, unit) or string.format("in %d %s", mins, unit)
    end

    -- Within the day
    if absDiff < SECONDS_PER_DAY then
        local hours = math.floor(absDiff / SECONDS_PER_HOUR)
        local unit = hours == 1 and "hour" or "hours"
        return isPast and string.format("%d %s ago", hours, unit) or string.format("in %d %s", hours, unit)
    end

    -- Check for yesterday/today/tomorrow
    local todayStart = DH.GetTodayMidnight()
    local tsStart = DH.StartOfDay(ts)
    local dayDiff = math.floor((tsStart - todayStart) / SECONDS_PER_DAY)

    if dayDiff == 0 then
        return "today"
    elseif dayDiff == 1 then
        return "tomorrow"
    elseif dayDiff == -1 then
        return "yesterday"
    elseif dayDiff > 1 and dayDiff <= 7 then
        return string.format("in %d days", dayDiff)
    elseif dayDiff < -1 and dayDiff >= -7 then
        return string.format("%d days ago", -dayDiff)
    end

    -- Fall back to date
    return DH.FormatDate(ts)
end

-------------------------------------------------
-- Comparison Functions
-------------------------------------------------

--- Check if two timestamps are on the same day
--- @param ts1 number First timestamp
--- @param ts2 number Second timestamp
--- @return boolean True if same day
function DH.IsSameDay(ts1, ts2)
    return DH.StartOfDay(ts1) == DH.StartOfDay(ts2)
end

--- Check if timestamp is today
--- @param ts number Unix timestamp
--- @return boolean True if today
function DH.IsToday(ts)
    return DH.IsSameDay(ts, DH.GetNow())
end

--- Check if timestamp is in the past
--- @param ts number Unix timestamp
--- @return boolean True if before now
function DH.IsPast(ts)
    return ts < DH.GetNow()
end

--- Check if timestamp is in the future
--- @param ts number Unix timestamp
--- @return boolean True if after now
function DH.IsFuture(ts)
    return ts > DH.GetNow()
end

--- Check if event spans multiple days
--- @param startTs number Start timestamp
--- @param endTs number End timestamp
--- @return boolean True if spans multiple days
function DH.SpansMultipleDays(startTs, endTs)
    return not DH.IsSameDay(startTs, endTs)
end

--- Check if timestamp falls within a range
--- @param ts number Timestamp to check
--- @param rangeStart number Range start
--- @param rangeEnd number Range end
--- @return boolean True if ts is within range (inclusive)
function DH.IsInRange(ts, rangeStart, rangeEnd)
    return ts >= rangeStart and ts <= rangeEnd
end

--- Check if two time ranges overlap
--- @param start1 number First range start
--- @param end1 number First range end
--- @param start2 number Second range start
--- @param end2 number Second range end
--- @return boolean True if ranges overlap
function DH.RangesOverlap(start1, end1, start2, end2)
    return start1 < end2 and end1 > start2
end

-------------------------------------------------
-- Calendar Grid Helpers
-------------------------------------------------

--- Get array of day numbers for a month grid (with leading/trailing days)
--- @param year number Year
--- @param month number Month (1-12)
--- @param mondayStart boolean If true, week starts Monday
--- @return table Array of {day, month, year, isCurrentMonth}
function DH.GetMonthGrid(year, month, mondayStart)
    if mondayStart == nil then mondayStart = true end

    local grid = {}
    local daysInMonth = DH.DaysInMonth(year, month)
    local firstWeekday = DH.FirstWeekday(year, month)

    -- Calculate leading days offset
    local leadingDays
    if mondayStart then
        -- Monday=0, Tuesday=1, ..., Sunday=6
        leadingDays = (firstWeekday == 1) and 6 or (firstWeekday - 2)
    else
        -- Sunday=0, Monday=1, ..., Saturday=6
        leadingDays = firstWeekday - 1
    end

    -- Previous month days
    local prevYear, prevMonth = DH.AddMonth(year, month, -1)
    local daysInPrevMonth = DH.DaysInMonth(prevYear, prevMonth)

    for i = leadingDays, 1, -1 do
        table.insert(grid, {
            day = daysInPrevMonth - i + 1,
            month = prevMonth,
            year = prevYear,
            isCurrentMonth = false
        })
    end

    -- Current month days
    for day = 1, daysInMonth do
        table.insert(grid, {
            day = day,
            month = month,
            year = year,
            isCurrentMonth = true
        })
    end

    -- Next month days (fill to 42 cells for 6 rows)
    local nextYear, nextMonth = DH.AddMonth(year, month, 1)
    local trailingDays = 42 - #grid

    for day = 1, trailingDays do
        table.insert(grid, {
            day = day,
            month = nextMonth,
            year = nextYear,
            isCurrentMonth = false
        })
    end

    return grid
end

--- Get array of days for a week view
--- @param ts number Any timestamp within the week
--- @param mondayStart boolean If true, week starts Monday
--- @return table Array of timestamps for each day of the week
function DH.GetWeekDays(ts, mondayStart)
    local weekStart = DH.StartOfWeek(ts, mondayStart)
    local days = {}

    for i = 0, 6 do
        table.insert(days, weekStart + i * SECONDS_PER_DAY)
    end

    return days
end

--- Get array of hour timestamps for a day
--- @param ts number Any timestamp within the day
--- @param startHour number First hour to include (default 0)
--- @param endHour number Last hour to include (default 23)
--- @return table Array of timestamps for each hour
function DH.GetDayHours(ts, startHour, endHour)
    startHour = startHour or 0
    endHour = endHour or 23

    local dayStart = DH.StartOfDay(ts)
    local hours = {}

    for hour = startHour, endHour do
        table.insert(hours, dayStart + hour * SECONDS_PER_HOUR)
    end

    return hours
end

-------------------------------------------------
-- Expose constants
-------------------------------------------------

DH.SECONDS_PER_DAY = SECONDS_PER_DAY
DH.SECONDS_PER_HOUR = SECONDS_PER_HOUR
DH.SECONDS_PER_MINUTE = SECONDS_PER_MINUTE
DH.MONTH_NAMES = MONTH_NAMES
DH.MONTH_NAMES_SHORT = MONTH_NAMES_SHORT
DH.WEEKDAY_NAMES = WEEKDAY_NAMES
DH.WEEKDAY_NAMES_SHORT = WEEKDAY_NAMES_SHORT
