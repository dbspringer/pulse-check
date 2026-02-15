# PulseCheck Addon Design

Date: 2026-02-14

## Overview

PulseCheck is a single-file World of Warcraft addon (retail 12.0+, Midnight era) that displays two raid-critical cooldown indicators: battle resurrection charges and bloodlust/sated status. It replaces an existing WeakAura group ([wago.io/8HR8DtYrk](https://wago.io/8HR8DtYrk)) with a standalone addon that integrates with WoW's Edit Mode.

## Constraints

- Retail only (Interface 120001)
- Single file: `PulseCheck.lua`
- No external libraries
- All locals except saved variables and slash command globals
- New globals prefixed `PC_` if ever needed

## Data Layer

### Spell ID Tables

**Bloodlust buffs (20 IDs):** 2825, 32182, 80353, 90355, 178207, 230935, 256740, 160452, 275200, 272678, 204276, 146555, 309658, 292686, 264667, 390386, 381301, 441076, 444257, 466904

**Sated debuffs (5 IDs):** 57723, 57724, 80354, 264689, 390435

**Battle res:** Spell 20484

### State Model

```lua
local state = {
    lustActive       = false,   -- player has a bloodlust buff
    lustExpiration   = 0,       -- GetTime() when buff expires
    sated            = false,   -- player has a sated debuff
    satedExpiration  = 0,       -- GetTime() when debuff expires
    raidSated        = false,   -- any group member has sated (fallback indicator)
    bresCharges      = 0,       -- current battle res charges
    bresMaxCharges   = 0,
    bresCooldownStart    = 0,   -- next charge recharge start time
    bresCooldownDuration = 0,   -- seconds to recharge one charge
    bresActive       = false,   -- true when charge pool exists (encounter/M+)
}
```

### Detection Strategy

**Bloodlust (primary path):** Register `UNIT_AURA` filtered to `"player"`. On event, loop `C_UnitAuras.GetPlayerAuraBySpellID(id)` over both the bloodlust and sated ID tables. Update state.

**Bloodlust (fallback path):** On `PLAYER_ENTERING_WORLD`, check `C_Secrets.ShouldSpellAuraBeSecret()` for a sample bloodlust ID. If restricted, start `C_Timer.NewTicker(0.5, pollFn)` to poll the same aura queries. Stop the ticker when auras are no longer secret.

**Battle res:** `C_Spell.GetSpellCharges(20484)` returns a `SpellChargeInfo` table with `currentCharges`, `maxCharges`, `cooldownStartTime`, `cooldownDuration`, `chargeModRate`. Combat res spells are explicitly whitelisted in 12.0 — no fallback needed. Updated via `SPELL_UPDATE_CHARGES` event plus a light poll (0.5s ticker) during encounters.

**Raid sated scan (secondary indicator):** When the player has no personal sated debuff and is in an encounter, scan group members on a slow ticker (every 2–3 seconds). Use `C_UnitAuras.GetAuraDataByIndex(unitID, index, "HARMFUL")` on each unit, checking `auraData.spellId` against the sated ID set. Short-circuits on first match. Clears on `ENCOUNTER_END` or leaving group.

**Initial state:** Full state refresh on `PLAYER_ENTERING_WORLD` to catch auras already active on login/reload.

## UI Layer

### Frame Hierarchy

```
PulseCheckFrame (parent container — backdrop + border)
├── BresIcon (icon texture, cooldown model, text overlays)
│   ├── Icon texture (136080 — Rebirth)
│   ├── Cooldown model (swipe for charge recharge)
│   ├── ChargeText (top-right, charge count)
│   └── TimerText (bottom-center, cooldown remaining)
└── LustIcon (icon texture, cooldown model, text overlays, glow)
    ├── Icon texture (136012 — Bloodlust)
    ├── Cooldown model (swipe for lust/sated duration)
    ├── TimerText (bottom-center, remaining duration)
    └── Glow overlay (ActionButton_ShowOverlayGlow)
```

### Layout

Both icons are children of `PulseCheckFrame`. Default size 48px, scalable.

- Horizontal (default): lust icon offset 54px right of bres icon
- Vertical: lust icon offset 54px below bres icon

Configurable via settings.

### Visual States

#### Battle Res

| State | Appearance |
|---|---|
| Charges available, none recharging | Normal icon, charge count shown |
| Charges recharging | Cooldown swipe + timer text, charge count shown |
| Pool not active (solo / no encounter) | Desaturated |

#### Bloodlust

| State | Appearance |
|---|---|
| Ready | Normal icon, full color |
| Active (player has buff) | Glow overlay + duration timer |
| Sated (player has debuff) | Desaturated + lockout timer |
| Sated (raid — player missed lust) | Dimmed (reduced alpha ~50%), no timer |

### Edit Mode Integration

Register `PulseCheckFrame` with `EditModeManagerFrame` so it appears as a draggable element in WoW's Edit Mode UI. Delayed via `C_Timer.After(1, initEditMode)` to ensure the system frame is loaded. Position persisted to `PulseCheckDB.position`.

### Timer Text Updates

Cooldown swipe models handle their own animation. Text overlays (remaining seconds) use `OnUpdate` scripts on each icon, set only when a timer is active and cleared to `nil` when idle.

## Settings & Configuration

### Saved Variables

Single table `PulseCheckDB` declared in the TOC.

```lua
local DEFAULTS = {
    position    = nil,              -- set on first drag
    orientation = "horizontal",     -- or "vertical"
    scale       = 1.0,
    showAlways  = false,            -- false = party/raid/instance only
    sound = {
        lustActive = true,          -- sound when lust is gained
        lustReady  = true,          -- sound when sated expires
        bresUsed   = false,         -- sound when a charge is consumed
    },
}
```

Defaults merged on load so future settings additions get their default values without wiping existing config.

### Slash Commands

Registered as `/pulsecheck` and `/plc`.

| Command | Action |
|---|---|
| `/plc` | Open the options panel |
| `/plc lock` / `/plc unlock` | Toggle Edit Mode lock |
| `/plc orientation` | Toggle horizontal ↔ vertical |
| `/plc scale <number>` | Set icon scale (0.5–2.0) |
| `/plc sound lust on/off` | Toggle bloodlust sounds |
| `/plc sound bres on/off` | Toggle battle res sounds |
| `/plc show always/group` | Toggle visibility mode |
| `/plc reset` | Reset position and settings to defaults |

### Options Panel

Registered via `Settings.RegisterCanvasLayoutCategory`. Single flat layout, no tabs.

- Visibility — dropdown: "In groups only" / "Always"
- Orientation — dropdown: "Horizontal" / "Vertical"
- Scale — slider: 0.5 to 2.0, step 0.1
- Sound: Bloodlust active — checkbox (default on)
- Sound: Bloodlust ready — checkbox (default on)
- Sound: Battle res charge used — checkbox (default off)
- Reset to defaults — button

Changes apply immediately.

### Sounds

Built-in sounds via `PlaySound(soundKitID)`. Gated by `PulseCheckDB.sound.*` booleans.

- Lust active: alert tone (e.g. `SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING`)
- Lust ready: ready chime (e.g. `SOUNDKIT.READY_CHECK`)
- Bres charge consumed: subtle alert (e.g. `SOUNDKIT.MAP_PING`)

Exact sound kit IDs finalized during implementation.

## Event Flow & Lifecycle

### Events

| Event | Purpose |
|---|---|
| `ADDON_LOADED` | Init saved variables, build UI, register settings |
| `PLAYER_ENTERING_WORLD` | Full state refresh, evaluate visibility, check secret values |
| `UNIT_AURA` (filtered: `"player"`) | Bloodlust/sated detection (primary path) |
| `SPELL_UPDATE_CHARGES` | Battle res charge changes |
| `ENCOUNTER_START` | Mark bres pool active, start polling tickers |
| `ENCOUNTER_END` | Stop tickers, clear raid sated flag |
| `CHALLENGE_MODE_START` | Mark bres pool active for M+ |
| `GROUP_ROSTER_UPDATE` | Re-evaluate visibility |
| `ZONE_CHANGED_NEW_AREA` | Re-evaluate visibility |

### Startup Sequence

1. `ADDON_LOADED` for "PulseCheck" → merge saved variables with defaults, build frames, register options panel and slash commands
2. `C_Timer.After(1, fn)` → register with Edit Mode
3. `PLAYER_ENTERING_WORLD` → full state refresh, evaluate visibility, check `C_Secrets.ShouldSpellAuraBeSecret()` to decide if fallback polling is needed

### Update Flow

```
Event fires (UNIT_AURA / SPELL_UPDATE_CHARGES / ticker)
  → Update state table
  → Compare old vs new state
  → If changed:
      → Update icon visuals (saturation, glow, timer text, cooldown model)
      → Play sound if applicable and enabled
```

### Visibility

```lua
local function ShouldShow()
    if PulseCheckDB.showAlways then return true end
    return IsInGroup() or IsInInstance()
end
```

Evaluated on `GROUP_ROSTER_UPDATE`, `ZONE_CHANGED_NEW_AREA`, `PLAYER_ENTERING_WORLD`.

## File Structure

### PulseCheck.toc

```
## Interface: 120001
## Title: PulseCheck
## Notes: Battle res and bloodlust cooldown tracking
## Author: KidMoxie
## Version: 1.0.0
## SavedVariables: PulseCheckDB

PulseCheck.lua
```

### PulseCheck.lua — Section Order

1. Local constants — spell ID tables, defaults, sound kit IDs
2. State table
3. Utility functions — `ShouldShow()`, defaults merge, timer formatting
4. Detection functions — `UpdateBloodlustState()`, `UpdateBresState()`, `ScanRaidSated()`
5. UI construction — `CreateIcons()`, `CreateBackdrop()`, `SetupEditMode()`
6. UI update functions — `RefreshBresIcon()`, `RefreshLustIcon()`, `ShowHide()`
7. Settings panel — `BuildOptionsPanel()`, `RegisterSettings()`
8. Slash command handler
9. Event handler — `OnEvent` dispatch, event registration
10. Initialization — `ADDON_LOADED` handler, startup sequence

### Globals

Only what WoW requires: `PulseCheckDB` (saved variable), `SLASH_PULSECHECK1`, `SLASH_PULSECHECK2`, `SlashCmdList["PULSECHECK"]`.
