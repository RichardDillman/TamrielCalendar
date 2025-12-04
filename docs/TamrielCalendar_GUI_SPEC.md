# Tamriel Calendar – GUI Specification

## Design System

### Colors (RGB values for Lua)
```
Header Gold:      212, 175, 55   (#D4AF37)
Body Text:        232, 220, 200  (#E8DCC8)
Muted Text:       139, 115, 85   (#8B7355)
Border Bronze:    139, 115, 85   (#8B7355)
Border Highlight: 197, 165, 82   (#C5A552)
Panel BG:         26, 24, 21     (#1A1815)
Cell BG:          30, 28, 25     (#1E1C19)
```

### Category Colors
| Category | BG RGB       | Text RGB        | Border RGB      |
|----------|--------------|-----------------|-----------------|
| Raid     | 74, 32, 32   | 255, 153, 153   | 255, 102, 102   |
| Party    | 32, 58, 74   | 153, 204, 255   | 102, 153, 255   |
| Training | 32, 74, 40   | 153, 255, 153   | 102, 255, 102   |
| Meeting  | 74, 64, 32   | 255, 221, 153   | 255, 204, 102   |
| Personal | 56, 32, 74   | 204, 153, 255   | 153, 102, 255   |

### Dimensions
```
Main Panel:       720w × 520h (resizable: false)
Header:           full-width × 44h
NavBar:           full-width × 38h
Month Cell:       ~92w × 52h (7 columns, 2px gap)
Week Hour Row:    30h
Day Hour Row:     38h
Event Pip:        full-cell-width × 14h
Sidebar:          190w
Guild Panel:      full-width × 60h
Action Bar:       full-width × 40h
```

---

## Control Hierarchy

```
TamCalWindow (TopLevelControl)
├── TamCalBG (Backdrop - ZO_DefaultBackdrop)
├── TamCalHeader (Control)
│   ├── TamCalTitle (Label)
│   └── TamCalClose (Button - ZO_CloseButton)
├── TamCalNavBar (Control)
│   ├── TamCalPrevBtn (Button)
│   ├── TamCalTodayBtn (Button)
│   ├── TamCalNextBtn (Button)
│   ├── TamCalPeriodLabel (Label)
│   └── TamCalViewToggles (Control)
│       ├── TamCalDayBtn (Button - ZO_TabButton)
│       ├── TamCalWeekBtn (Button - ZO_TabButton)
│       └── TamCalMonthBtn (Button - ZO_TabButton)
├── TamCalContent (Control)
│   ├── TamCalMonthView (Control)
│   │   ├── TamCalWeekdayHeader (Control) [7 Labels]
│   │   └── TamCalMonthGrid (Control) [42 DayCell controls]
│   ├── TamCalWeekView (Control)
│   │   ├── TamCalWeekHeader (Control) [8 cells: blank + 7 days]
│   │   └── TamCalWeekGrid (Control) [time labels + hour cells]
│   └── TamCalDayView (Control)
│       ├── TamCalDaySchedule (Control)
│       │   ├── TamCalDayHeader (Label)
│       │   └── TamCalHourRows (Control) [HourRow controls]
│       └── TamCalDaySidebar (Control)
│           ├── TamCalEventDetails (Control)
│           └── TamCalQuickActions (Control)
├── TamCalGuildPanel (Control)
│   ├── TamCalGuildHeader (Control)
│   │   ├── TamCalGuildTitle (Label)
│   │   └── TamCalSyncBtn (Button)
│   └── TamCalGuildList (Control) [GuildTag controls]
├── TamCalLegend (Control) [LegendItem controls]
└── TamCalActionBar (Control)
    ├── TamCalFilterBtn (Button)
    └── TamCalNewEventBtn (Button)
```

---

## Virtual Templates

### DayCell Template
```xml
<Control name="TamCal_DayCell_Template" virtual="true">
  <Dimensions x="92" y="52"/>
  <Controls>
    <Backdrop name="$(parent)BG" inherits="ZO_ThinBackdrop">
      <AnchorFill/>
    </Backdrop>
    <Label name="$(parent)DayNum" font="ZO_FontGameSmall">
      <Anchor point="TOPLEFT" offsetX="4" offsetY="2"/>
    </Label>
    <Control name="$(parent)Events">
      <Anchor point="TOPLEFT" offsetY="16"/>
      <Anchor point="BOTTOMRIGHT"/>
      <!-- EventPips added dynamically -->
    </Control>
  </Controls>
</Control>
```

### EventPip Template
```xml
<Control name="TamCal_EventPip_Template" virtual="true">
  <Dimensions y="14"/>
  <Controls>
    <Backdrop name="$(parent)BG">
      <AnchorFill/>
      <Edge edgeSize="2"/>
    </Backdrop>
    <Label name="$(parent)Title" font="ZO_FontGameSmall">
      <Anchor point="LEFT" offsetX="4"/>
      <Anchor point="RIGHT" offsetX="-2"/>
    </Label>
  </Controls>
</Control>
```

### GuildTag Template
```xml
<Control name="TamCal_GuildTag_Template" virtual="true">
  <Dimensions y="22"/>
  <Controls>
    <Backdrop name="$(parent)BG" inherits="ZO_ThinBackdrop">
      <AnchorFill/>
    </Backdrop>
    <Label name="$(parent)Check" font="ZO_FontGameSmall" text="✓">
      <Anchor point="LEFT" offsetX="6"/>
    </Label>
    <Texture name="$(parent)ColorDot">
      <Dimensions x="8" y="8"/>
      <Anchor point="LEFT" offsetX="20"/>
    </Texture>
    <Label name="$(parent)Name" font="ZO_FontGameSmall">
      <Anchor point="LEFT" offsetX="32"/>
    </Label>
  </Controls>
</Control>
```

---

## Interaction States

### Button States
- Normal: border #6B5B45, text #C5A552
- Hover: border #C5A552, text #FFD700
- Pressed: bg darkens 10%
- Disabled: opacity 0.4

### DayCell States
- Normal: border #3A3530
- Hover: border #6B5B45, bg lightens
- Today: border #C5A552, bg rgba(197,165,82,0.1)
- Selected: border #D4AF37, inner glow
- OtherMonth: opacity 0.35

### View Toggle States
- Inactive: text #6B5B45, border #6B5B45
- Active: text #D4AF37, border #C5A552, bg slightly lighter

---

## Implementation Tasks

### Phase 1: Core Window
- [ ] Create TamrielCalendar.xml with main panel structure
- [ ] Create TamrielCalendar.lua with initialization
- [ ] Register slash command `/tamcal`
- [ ] Add keybind registration (toggle window)
- [ ] Implement close button handler
- [ ] Add window drag functionality
- [ ] Store window position in SavedVariables

### Phase 2: Navigation
- [ ] Implement view state machine (DAY/WEEK/MONTH)
- [ ] Create view toggle button handlers
- [ ] Implement prev/next navigation for each view
- [ ] Implement "Today" button (reset to current date)
- [ ] Update period label based on view + current date

### Phase 3: Month View
- [ ] Create weekday header row (Sun-Sat labels)
- [ ] Create DayCell pool (42 cells for 6-week grid)
- [ ] Implement month grid population from DateHelpers
- [ ] Apply "today" styling to current date
- [ ] Apply "other-month" styling to overflow days
- [ ] Implement day cell click → switch to Day view

### Phase 4: Week View
- [ ] Create week header row (blank + 7 day columns)
- [ ] Create time label column (configurable hour range)
- [ ] Create hour cell grid (7 cols × hour count)
- [ ] Apply "today" column highlighting
- [ ] Implement hour cell click → create event at time

### Phase 5: Day View
- [ ] Create hourly schedule list
- [ ] Create event detail sidebar
- [ ] Create quick action buttons (Edit, Copy)
- [ ] Implement event block click → show details
- [ ] Implement scroll for long schedules

### Phase 6: Event Rendering
- [ ] Create EventPip object pool
- [ ] Implement category → color mapping
- [ ] Render event pips in month view cells
- [ ] Render event blocks in week view cells
- [ ] Render event blocks in day view rows
- [ ] Handle overlapping events (stack/truncate)
- [ ] Implement tooltip on hover

### Phase 7: Guild Panel
- [ ] Create guild tag pool (max 5 guilds)
- [ ] Populate from GetNumGuilds() / GetGuildName()
- [ ] Implement subscription toggle per guild
- [ ] Store subscriptions in SavedVariables
- [ ] Implement sync button → trigger SyncManager

### Phase 8: Action Bar
- [ ] Create Filter button → opens filter dropdown
- [ ] Create New Event button → opens event form
- [ ] Implement filter dropdown (category checkboxes)
- [ ] Create event form dialog (separate TopLevelControl)

### Phase 9: Event Form Dialog
- [ ] Create TamCalEventForm TopLevelControl
- [ ] Add title input (ZO_DefaultEditForBackdrop)
- [ ] Add description input (multiline)
- [ ] Add start date/time picker
- [ ] Add end date/time picker
- [ ] Add category dropdown
- [ ] Add guild selector (if officer+)
- [ ] Add Save/Cancel buttons
- [ ] Implement validation
- [ ] Wire to EventManager:Create/Update

### Phase 10: Polish
- [ ] Add corner ornament textures
- [ ] Implement smooth view transitions (optional)
- [ ] Add sound effects (button clicks, event create)
- [ ] Keyboard navigation (arrow keys in month view)
- [ ] Accessibility: ensure readable contrast ratios

---

## File Structure
```
TamrielCalendar/
├── TamrielCalendar.txt          # Addon manifest
├── TamrielCalendar.lua          # Main entry point
├── TamrielCalendar.xml          # UI definitions
├── Bindings.xml                 # Keybinds
├── libs/
│   ├── LibAddonMenu-2.0/
│   ├── LibSerialize/
│   └── LibDeflate/
├── modules/
│   ├── DateHelpers.lua
│   ├── EventManager.lua
│   ├── SyncManager.lua
│   └── UI/
│       ├── MainWindow.lua
│       ├── MonthView.lua
│       ├── WeekView.lua
│       ├── DayView.lua
│       ├── GuildPanel.lua
│       ├── EventForm.lua
│       └── Templates.xml
└── textures/
    └── (custom textures if needed)
```

---

## Key API References

### Time
- `GetTimeStamp()` → current Unix timestamp
- `GetDateStringFromTimestamp(ts)` → formatted string
- `os.date("*t", ts)` → Lua date table

### Guilds
- `GetNumGuilds()` → 0-5
- `GetGuildId(index)` → guildId
- `GetGuildName(guildId)` → string
- `DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_GUILD_KIOSK_BID)` → check officer-level

### UI
- `SCENE_MANAGER:RegisterTopLevel(control, false)`
- `ZO_Tooltips_ShowTextTooltip(control, position, text)`
- `PlaySound(SOUNDS.POSITIVE_CLICK)`

---

## Notes for Implementation

1. **Object Pooling**: Month view reuses 42 DayCell controls. Week view reuses hour cells. Don't create/destroy on view change.

2. **Event Pip Limit**: Show max 2-3 pips per day cell in month view. Add "+N more" indicator if overflow.

3. **Time Zone**: ESO uses server time. Use `GetTimeStamp()` consistently; don't mix with `os.time()`.

4. **Guild Sync Throttling**: LibAddonMessage has rate limits. Queue outgoing messages, respect backoff.

5. **SavedVariables Structure**:
```lua
TamCalSavedVars = {
  events = {},           -- personal events
  guildEvents = {},      -- cached guild events by guildId
  subscriptions = {},    -- guildId → boolean
  windowPosition = {},   -- x, y
  defaultView = "MONTH",
  hourRange = {start = 17, stop = 24},  -- 5 PM - midnight
}
```
