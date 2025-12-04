# Raid Types & Modifiers

When creating an event with category "Raid", users can optionally specify a trial and difficulty modifier.

## Trials List

| Short | Full Name | DLC/Chapter |
|-------|-----------|-------------|
| AA | Aetherian Archive | Base Game |
| HRC | Hel Ra Citadel | Base Game |
| SO | Sanctum Ophidia | Base Game |
| MoL | Maw of Lorkhaj | Thieves Guild |
| HoF | Halls of Fabrication | Morrowind |
| AS | Asylum Sanctorium | Clockwork City |
| CR | Cloudrest | Summerset |
| SS | Sunspire | Elsweyr |
| KA | Kyne's Aegis | Greymoor |
| RG | Rockgrove | Blackwood |
| DSR | Dreadsail Reef | High Isle |
| SE | Sanity's Edge | Necrom |
| OC | Osseous Cage | Gold Road |
| LC | Lucent Citadel | Gold Road |

## Difficulty Modifiers

| Short | Full Name | Description |
|-------|-----------|-------------|
| N | Normal | Standard difficulty |
| Vet | Veteran | Increased difficulty, better loot |
| HM | Hard Mode | Veteran + all hard modes activated |
| SR | Speed Run | Timed completion challenge |
| ND | No Death | Zero deaths for achievement |

## Combined Display Format

When both trial and modifier are selected, display as:
- `vRG` = Veteran Rockgrove
- `vCR+0` or `CR HM` = Cloudrest Hard Mode
- `vSS SR` = Sunspire Speed Run
- `vKA ND` = Kyne's Aegis No Death

## Event Title Auto-Generation

If user selects a trial and modifier, suggest a title:

```lua
local function SuggestRaidTitle(trial, modifier)
    if not trial then return nil end

    local prefix = ""
    local suffix = ""

    if modifier == "Normal" then
        prefix = "n"
    elseif modifier == "Veteran" then
        prefix = "v"
    elseif modifier == "HM" then
        prefix = "v"
        suffix = " HM"
    elseif modifier == "SR" then
        prefix = "v"
        suffix = " Speed Run"
    elseif modifier == "ND" then
        prefix = "v"
        suffix = " No Death"
    end

    return prefix .. trial.short .. suffix
end

-- Examples:
-- SuggestRaidTitle(TRIALS.RG, "Veteran") → "vRG"
-- SuggestRaidTitle(TRIALS.CR, "HM") → "vCR HM"
-- SuggestRaidTitle(TRIALS.SS, "Normal") → "nSS"
```

## Data Model

```lua
-- Trial definitions
TamrielCalendar.TRIALS = {
    { id = "AA",  name = "Aetherian Archive" },
    { id = "HRC", name = "Hel Ra Citadel" },
    { id = "SO",  name = "Sanctum Ophidia" },
    { id = "MOL", name = "Maw of Lorkhaj" },
    { id = "HOF", name = "Halls of Fabrication" },
    { id = "AS",  name = "Asylum Sanctorium" },
    { id = "CR",  name = "Cloudrest" },
    { id = "SS",  name = "Sunspire" },
    { id = "KA",  name = "Kyne's Aegis" },
    { id = "RG",  name = "Rockgrove" },
    { id = "DSR", name = "Dreadsail Reef" },
    { id = "SE",  name = "Sanity's Edge" },
    { id = "OC",  name = "Osseous Cage" },
    { id = "LC",  name = "Lucent Citadel" },
}

-- Modifier definitions
TamrielCalendar.MODIFIERS = {
    { id = "N",   name = "Normal" },
    { id = "VET", name = "Veteran" },
    { id = "HM",  name = "Hard Mode" },
    { id = "SR",  name = "Speed Run" },
    { id = "ND",  name = "No Death" },
}
```

## Event Model Extension

When category is "Raid", additional optional fields:

```lua
{
    -- Standard event fields...
    category = "Raid",

    -- Raid-specific (optional)
    raidTrial = "RG",       -- Trial short code or nil
    raidModifier = "VET",   -- Modifier short code or nil
}
```

## UI: Create Event Dialog (Raid Category)

```
┌─────────────────────────────────────────────────────┐
│ Create Event                                        │
├─────────────────────────────────────────────────────┤
│ Title: [vRG Progression________________]            │
│                                                     │
│ Category: [▼ Raid                        ]          │
│                                                     │
│ ┌─ Trial (optional) ─────────────────────────────┐  │
│ │ [▼ Rockgrove                            ]      │  │
│ └────────────────────────────────────────────────┘  │
│                                                     │
│ ┌─ Difficulty (optional) ────────────────────────┐  │
│ │ ( ) Normal                                     │  │
│ │ (•) Veteran                                    │  │
│ │ ( ) Hard Mode                                  │  │
│ │ ( ) Speed Run                                  │  │
│ │ ( ) No Death                                   │  │
│ └────────────────────────────────────────────────┘  │
│                                                     │
│ Date: [Dec 6, 2025]  Time: [8:00 PM] - [11:00 PM]  │
│                                                     │
│ Description:                                        │
│ [Bring potions. Discord required.___________]      │
│ [__________________________________________ ]      │
│                                                     │
├─────────────────────────────────────────────────────┤
│              [Cancel]  [Create Event]               │
└─────────────────────────────────────────────────────┘
```

## UI: Event Display

When viewing a raid event with trial/modifier:

```
┌─────────────────────────────────────────────────────┐
│ vRG Progression                              [Edit] │
│ Rockgrove (Veteran)                                 │
│ Dec 6, 8:00 PM - 11:00 PM                          │
├─────────────────────────────────────────────────────┤
│ Tank (1/2):  @Player1                              │
│ Healer (2/2): @Player2, @Player3                   │
│ DPS (5/8):   @Player4, @Player5, @Player6...       │
├─────────────────────────────────────────────────────┤
│ [Sign Up]                                          │
└─────────────────────────────────────────────────────┘
```

## Filtering

In the calendar filter panel, allow filtering by:
- All Raids
- Specific trial (dropdown)
- Specific modifier (checkboxes)

## Future Considerations

### Dungeons (v1.1+)
Could add dungeon picker for 4-person content:
- Vet Dungeons (DLC)
- Arenas (vMA, vVH, vDSA, vBRP, vIA, etc.)

### Group Composition Templates (v1.2+)
Pre-set role requirements:
- Standard (2T/2H/8D)
- 3-Tank fights (3T/2H/7D)
- Portal groups, etc.

### Role Counts (v1.3+)
Show current/needed per role:
- Tank (1/2)
- Healer (2/2) ✓
- DPS (5/8)
