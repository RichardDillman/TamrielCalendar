# Folder Structure

```
ESO-Calendar/
│
├── TamrielCalendar.txt          # ESO addon manifest
├── TamrielCalendar.lua          # Main addon bootstrap
├── TamrielCalendar.xml          # UI control definitions
├── LICENSE                       # MIT License
├── README.md                     # Project overview
├── CONTRIBUTING.md               # Contribution guidelines
│
├── modules/
│   ├── DateHelpers.lua          # Date/time utility functions
│   ├── EventManager.lua         # Event CRUD and storage
│   ├── SyncManager.lua          # Guild sync via LibAddonMessage
│   ├── UI_DayView.lua           # Day view rendering
│   ├── UI_WeekView.lua          # Week view rendering
│   ├── UI_MonthView.lua         # Month grid rendering
│   ├── UI_Dialogs.lua           # Event create/edit dialogs
│   └── SettingsPanel.lua        # LibAddonMenu settings
│
├── SavedVariables/
│   └── TamrielCalendar_SV.lua   # Example SavedVariables (dev only)
│
├── docs/
│   ├── PRD.md                   # Product requirements
│   ├── Milestones.md            # Development roadmap
│   ├── DEVELOPMENT_PLAN.md      # Implementation guide
│   ├── FolderStructure.md       # This file
│   ├── SavedVariablesSchema.md  # Data storage schema
│   ├── MessagingProtocol.md     # Guild sync protocol
│   ├── CalendarMathExamples.md  # Date calculation examples
│   └── TamrielCalendar_GUI_SPEC.md  # UI specification
│
└── .github/
    └── ISSUE_TEMPLATE/
        ├── bug_report.md        # Bug report template
        ├── feature_request.md   # Feature request template
        └── task.md              # Development task template
```

## File Responsibilities

### Root Files

| File | Purpose |
|------|---------|
| `TamrielCalendar.txt` | ESO addon manifest - defines metadata, dependencies, and load order |
| `TamrielCalendar.lua` | Main entry point - initializes addon, registers events, loads modules |
| `TamrielCalendar.xml` | UI definitions - window structure, templates, virtual controls |

### Core Modules

| Module | Purpose |
|--------|---------|
| `DateHelpers.lua` | Pure functions for date math (days in month, week start, formatting) |
| `EventManager.lua` | Event CRUD operations, storage interface, purge logic |
| `SyncManager.lua` | LibAddonMessage integration, serialize/deserialize, conflict resolution |

### UI Modules

| Module | Purpose |
|--------|---------|
| `UI_DayView.lua` | 24-hour schedule display, event detail sidebar |
| `UI_WeekView.lua` | 7-day grid with hourly rows |
| `UI_MonthView.lua` | Calendar grid (6 weeks × 7 days), event pips |
| `UI_Dialogs.lua` | Event creation form, edit form, delete confirmation |
| `SettingsPanel.lua` | LibAddonMenu settings integration |

### Documentation

| Doc | Audience |
|-----|----------|
| `PRD.md` | Product requirements - what we're building |
| `Milestones.md` | Release roadmap - when features ship |
| `DEVELOPMENT_PLAN.md` | Implementation guide - how to build it |
| `SavedVariablesSchema.md` | Data format - how data is stored |
| `MessagingProtocol.md` | Sync protocol - how guild sharing works |
| `CalendarMathExamples.md` | Code snippets for date calculations |
| `TamrielCalendar_GUI_SPEC.md` | UI specification - colors, dimensions, hierarchy |

## Installation Path

When installed, the addon lives at:
```
Documents/Elder Scrolls Online/live/AddOns/TamrielCalendar/
```

## Dependencies (External)

These libraries are required and should be installed separately (not bundled):

| Library | Purpose | Required |
|---------|---------|----------|
| LibAddonMenu-2.0 | Settings panel | Yes |
| LibAddonMessage-2.0 | Guild messaging | Yes (for sync) |
| LibSerialize | Message encoding | Yes (for sync) |
| LibDeflate | Message compression | Yes (for sync) |
| LibDebugLogger | Debug output | Optional |

## Notes

1. The `SavedVariables/` folder is for development reference only - ESO manages the actual file
2. No external API integrations - all data stays in-game
3. Module load order matters - see TamrielCalendar.txt
