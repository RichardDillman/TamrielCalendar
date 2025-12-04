# Tamriel Calendar

An in-game Elder Scrolls Online calendar addon with **Day, Week, and Month views**, **personal event management**, and **guild event synchronization**.

All sync occurs *inside* ESO using LibAddonMessage - **no external services, no companion apps**. Works on **PC and console**.

## Features

### Calendar Views
- **Day View** - 24-hour timeline showing today's events
- **Week View** - 7-day grid with hourly slots
- **Month View** - Classic calendar layout with navigation

### Personal Events
- Create, edit, and delete personal events
- Categories: Raid, Party, Training, Meeting, Personal
- Automatic cleanup of past events

### Guild Calendars
- Subscribe to guild event feeds
- Officers can publish events to guild members
- Manual refresh to pull latest events
- Events sync only to players with this addon installed

### Technical
- Uses LibAddonMessage-2.0 for guild communication
- LibSerialize + LibDeflate for efficient payloads
- Version-based conflict resolution
- Today-and-future filtering to minimize data

## Installation

1. Download from [ESOUI](https://esoui.com) or [GitHub Releases](https://github.com/RichardDillman/ESO-Calendar/releases)
2. Extract to `Documents/Elder Scrolls Online/live/AddOns/`
3. Install required libraries (see below)
4. Enable in-game via AddOns menu

### Required Libraries

Install these separately from ESOUI:
- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html)
- [LibAddonMessage-2.0](https://www.esoui.com/downloads/info2562-LibAddonMessage-2.0.html) (for guild sync)
- [LibSerialize](https://www.esoui.com/downloads/info2568-LibSerialize.html)
- [LibDeflate](https://www.esoui.com/downloads/info2569-LibDeflate.html)
- [LibDebugLogger](https://www.esoui.com/downloads/info2275-LibDebugLogger.html) (optional)

## Usage

- `/tamcal` - Toggle calendar window
- Click dates to navigate
- Use view tabs (Day/Week/Month) to switch views
- "Today" button returns to current date

## Development Status

| Component | Status |
|-----------|--------|
| Documentation | Complete |
| DateHelpers | Not started |
| EventManager | Not started |
| SyncManager | Not started |
| UI Views | Not started |
| Dialogs | Not started |
| Settings | Not started |

**Current Phase:** Pre-development (scaffold and docs complete)

See [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) for implementation details.

## Milestones

| Version | Focus |
|---------|-------|
| v0.1 | Core infrastructure - addon loads, SavedVariables work |
| v0.2 | Personal events - create/edit/delete |
| v0.3 | Guild sync - LibAddonMessage protocol |
| v0.4 | UI polish - all views functional |
| v0.5 | Console support - gamepad friendly |
| v1.0 | Public release |

See [docs/Milestones.md](docs/Milestones.md) for full roadmap.

## Documentation

| Document | Description |
|----------|-------------|
| [PRD.md](docs/PRD.md) | Product requirements |
| [Milestones.md](docs/Milestones.md) | Release roadmap |
| [DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) | Implementation guide |
| [SavedVariablesSchema.md](docs/SavedVariablesSchema.md) | Data storage format |
| [MessagingProtocol.md](docs/MessagingProtocol.md) | Guild sync protocol |
| [TamrielCalendar_GUI_SPEC.md](docs/TamrielCalendar_GUI_SPEC.md) | UI specification |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

- Follow ESO addon Lua conventions
- Avoid heavy per-frame operations
- Keep messaging payloads small
- Submit PRs against the `dev` branch

## License

MIT License - see [LICENSE](LICENSE)

## Credits

Architecture and development by [@RichardDillman](https://github.com/RichardDillman)
