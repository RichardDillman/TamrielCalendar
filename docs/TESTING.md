# Tamriel Calendar - Manual Testing Checklist

## Pre-Test Setup

1. **Install Required Libraries** (optional but recommended for full testing):
   - LibAddonMenu-2.0
   - LibAddonMessage-2.0
   - LibSerialize
   - LibDeflate
   - LibDebugLogger

2. **Enable Debug Mode**: Type `/tamcal debug` to enable debug messages

---

## v0.1 Core Infrastructure Tests

### Addon Loading
- [ ] Addon loads without Lua errors on login
- [ ] Chat message appears: "[TamCal] Tamriel Calendar v0.1.0 loaded"
- [ ] `/tamcal` command opens calendar window
- [ ] `/tc` command also works (shortcut)
- [ ] `/tamcal help` shows help text

### SavedVariables
- [ ] First launch creates TamrielCalendar_SV file
- [ ] Preferences persist across reloads
- [ ] Window position saves when moved

---

## v0.2 Personal Calendar Tests

### Calendar Window
- [ ] Window opens centered on screen
- [ ] Window is movable and remembers position
- [ ] Close button (X) works
- [ ] Escape key closes window (if hooked)

### Month View
- [ ] Displays current month by default
- [ ] Today is highlighted with gold border
- [ ] Weekday headers show correctly (Sun-Sat or Mon-Sun based on preference)
- [ ] Previous/Next buttons navigate months
- [ ] "Today" button returns to current month
- [ ] Day cells are clickable

### Week View
- [ ] D/W/M buttons switch views correctly
- [ ] Week view shows 7 day columns
- [ ] Hour grid displays correctly (5PM-12AM default range)
- [ ] Day headers show date and weekday
- [ ] Today column is highlighted
- [ ] Time labels show correctly (12h or 24h based on preference)
- [ ] Hour cells are clickable (opens event form)

### Day View
- [ ] Day view shows single day schedule
- [ ] Day header shows full date
- [ ] Sidebar shows "no event selected" initially
- [ ] Clicking hour slot opens event form
- [ ] Events appear as blocks on schedule

### Personal Event CRUD
- [ ] "+ New Event" button opens event form
- [ ] Event form shows title, description, date/time fields
- [ ] Can create personal event with title
- [ ] Event appears in calendar after save
- [ ] Event tooltip shows on hover
- [ ] Can click event to edit
- [ ] Can delete events
- [ ] Past events are auto-purged on login

### Date Navigation
- [ ] Left arrow moves to previous period
- [ ] Right arrow moves to next period
- [ ] Navigation works for Month/Week/Day views
- [ ] Period label updates correctly

---

## v0.3 Guild Integration Tests

### Guild Panel
- [ ] Guild panel shows at bottom of calendar window
- [ ] All player's guilds appear as tags
- [ ] Guild tags show correct names (truncated if long)
- [ ] Clicking guild tag toggles subscription
- [ ] Subscribed guilds show checkmark (X)
- [ ] Sync button is visible

### Guild Sync (requires LibAddonMessage + guild members online)
- [ ] Sync button triggers sync request
- [ ] Chat shows "Syncing X guild(s)..."
- [ ] If no guilds subscribed, shows "No guilds subscribed" message
- [ ] Received events appear after sync

### Sign-up Dialog
- [ ] Clicking guild event shows sign-up dialog
- [ ] Dialog shows event title and time
- [ ] Three role options: Tank, Healer, DPS
- [ ] Clicking role signs up and closes dialog
- [ ] Success message appears in chat
- [ ] Cannot sign up for same event twice

### Category Legend
- [ ] Legend shows at bottom of window
- [ ] Five categories displayed: Raid, Party, Training, Meeting, Personal
- [ ] Colors match event pip colors

---

## Visual/UI Tests

### Colors & Styling
- [ ] Gold header text (#D4AF37)
- [ ] Body text is readable (#E8DCC8)
- [ ] Muted text for secondary info (#8B7355)
- [ ] Event pips show category colors:
  - Raid = Red
  - Party = Blue
  - Training = Green
  - Meeting = Gold
  - Personal = Purple
- [ ] Hover effects work on interactive elements

### Tooltips
- [ ] Day cells show event count on hover
- [ ] Event pips show event details on hover
- [ ] Event blocks show full info on hover

### Responsiveness
- [ ] No flickering when switching views
- [ ] Smooth navigation between months
- [ ] Events render correctly after view switch

---

## Error Handling Tests

### Edge Cases
- [ ] Empty calendar (no events) displays correctly
- [ ] Many events on single day (shows max 3 pips + overflow)
- [ ] Long event titles truncate properly
- [ ] Events spanning midnight display in both days
- [ ] Year navigation works (December -> January)

### Missing Libraries
- [ ] Works without LibAddonMessage (sync disabled)
- [ ] Works without LibDebugLogger (debug output goes to chat)
- [ ] Appropriate messages shown when libs missing

---

## Debug Commands

```
/tamcal debug    - Toggle debug mode
/tamcal reset    - Reset window position
/tamcal purge    - Manually purge old events
/tamcal help     - Show command help
```

---

## Known Limitations (Expected Behavior)

1. Guild sync only works when guild members with addon are online
2. No real-time push - must open calendar to see updates
3. If offline for extended time, cached events may be stale
4. Sync requires LibAddonMessage-2.0, LibSerialize, and LibDeflate

---

## Bug Report Template

**Version**: 0.1.0
**API Version**: 101048

**Description**:

**Steps to Reproduce**:
1.
2.
3.

**Expected Behavior**:

**Actual Behavior**:

**Debug Output** (if available):
```
[paste debug messages here]
```

**Libraries Installed**:
- [ ] LibAddonMessage-2.0
- [ ] LibSerialize
- [ ] LibDeflate
- [ ] LibDebugLogger
- [ ] LibAddonMenu-2.0
