# Math examples

## Days in month

```LUA
local function DaysInMonth(year, month)
    -- Month + 1, day 0 = last day of current month
    return os.date("*t", os.time({year = year, month = month + 1, day = 0})).day
end
```

## First weekday of month

```LUA
local function FirstWeekday(year, month)
    local t = os.date("*t", os.time({year = year, month = month, day = 1}))
    return t.wday  -- Sunday=1 in Lua
end
```

## Start of day

```LUA
local function StartOfDay(ts)
    local t = os.date("*t", ts)
    return os.time({year=t.year, month=t.month, day=t.day, hour=0})
end
```

## Start of week (assuming Monday)

```LUA
local function StartOfWeek(ts)
    local t = os.date("*t", ts)
    local wday = t.wday -- Lua: Sunday=1
    local offset = (wday == 1) and 6 or (wday - 2)
    return StartOfDay(ts - offset * 86400)
end
```

## Month navigation

```LUA
local function AddMonth(year, month, delta)
    month = month + delta
    while month > 12 do year = year + 1; month = month - 12 end
    while month < 1 do year = year - 1; month = month + 12 end
    return year, month
end
```
