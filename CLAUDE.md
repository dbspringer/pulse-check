# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Addon Does

PulseCheck is a World of Warcraft addon that tracks two raid-critical cooldowns:

1. **Battle Resurrection** — remaining charges and cooldown timer (spell 20484)
2. **Bloodlust / Heroism** — active buff detection across all sources, sated/lockout debuff tracking, and ready status

The scope is intentionally narrow: display raid cooldown state. It does not modify gameplay, automate casting, or interact with other addons.

### Display

The cooldown icons must be moveable and configurable via WoW's built-in Edit Mode UI (`EditModeManagerFrame`). Clicking the frame in Edit Mode opens an inline settings dialog (orientation, scale, visibility, sounds). Position is persisted in saved variables with snap-to-grid alignment.

## Architecture

Core logic in `PulseCheck.lua` with locale strings in `Locales/enUS.lua`. No libraries, no XML, no embeds.

### Constraints

- **Retail only** (Midnight era, Interface 120000+)
- Lua 5.1 (WoW's embedded runtime)
- No external libraries (Ace3, LibStub, etc.)
- Use `local` for all variables and functions except saved variables and slash command globals
- Prefix any new global names with `PC_` to avoid namespace collisions

### Spell ID Reference

See `bloodlust-detection-research.md` for the full spell ID tables and API research. Key sets:

- **Bloodlust buffs**: 20 spell IDs covering Bloodlust, Heroism, Time Warp, Primal Rage, Fury of the Aspects, all drum variants, and Harrier's Cry
- **Sated debuffs**: 57723, 57724, 80354, 264689, 390435
- **Battle Res**: encounter charges via `C_Spell.GetSpellCharges(20484)`, with personal brez fallback for Druid (20484), DK (61999), Warlock (20707), Paladin (391054) via `C_Spell.GetSpellCooldown`

### 12.0 (Midnight) Aura API Considerations

Patch 12.0 introduced "secret values" that can restrict aura data on tainted execution paths. Primary detection uses `C_UnitAuras.GetPlayerAuraBySpellID(id)` with these fallback strategies:

- `C_Secrets.ShouldSpellAuraBeSecret(id)` to check if an aura is restricted at runtime
- Lightweight polling via `C_Timer.NewTicker` instead of `UNIT_AURA` event registration if taint is a concern
- **Haste-delta fallback** for bloodlust: when the aura API is blocked, a >25% multiplicative haste spike (`currentHaste > lastHaste * 1.25`) infers lust activation with an assumed 40s duration
- **Time-based expiration validation** for both lust and sated: when aura API returns nil during combat (due to taint), compare `GetTime()` against the previously saved expiration to distinguish real expiration from API failure
- **Instance-based polling**: `C_Timer.NewTicker` loops for lust (1s), bres (0.5s), and raid-sated (3s) start automatically inside instanced content and stop outside it

**Important:** `COMBAT_LOG_EVENT_UNFILTERED` is a **protected event** in 12.0 — addons cannot register for it without triggering `ADDON_ACTION_FORBIDDEN`. Do not use CLEU as a fallback detection path.

### Key WoW APIs

| API | Purpose |
|---|---|
| `C_UnitAuras.GetPlayerAuraBySpellID(id)` | Check for a specific aura by spell ID |
| `C_Spell.GetSpellCharges(id)` | Encounter brez charge info (charges, cooldown, max) |
| `C_Spell.GetSpellCooldown(id)` | Personal spell cooldown info (for brez fallback) |
| `IsPlayerSpell(id)` | Check if player knows a spell (brez class detection) |
| `GetHaste()` | Player's current haste % (unrestricted by secret values) |
| `C_Secrets.ShouldSpellAuraBeSecret(id)` | Check if aura data is protected (12.0+) |
| `GetInstanceInfo()` | Returns instance type for visibility and polling decisions |
| `C_Timer.After(delay, fn)` | Delayed execution for frame initialization |
| `C_Timer.NewTicker(interval, fn)` | Polling loops (lust, bres, raid-sated, aura fallback) |

### Localization

All user-facing strings live in `Locales/enUS.lua` as a global `PC_L` table, aliased to `local L = PC_L` in `PulseCheck.lua`. To add a language, create `Locales/<locale>.lua` that conditionally overrides keys (e.g. `if GetLocale() ~= "deDE" then return end`), and add it to the TOC after `enUS.lua`. Not localized (intentionally): addon name, slash commands, sound names, color codes, saved variable keys.

### Frame Positioning

The main frame uses a CENTER anchor relative to UIParent's BOTTOMLEFT. `SetPoint` offsets are in the child frame's coordinate space (`GetCenter()` returns offset values directly). Position is snapped to a 10-pixel grid on drag release. Scale changes preserve visual center via offset adjustment: `new_offset = old_offset * old_scale / new_scale`.

### Do

- Keep the addon to `PulseCheck.lua` + locale files unless there is a strong reason to add more
- Use `C_Timer.After` for any timing-sensitive UI manipulation (Blizzard frames may not be ready on event fire)
- Test that aura spell IDs still resolve after WoW patches — these are the most fragile parts
- Update `## Interface:` in the TOC when targeting a new game build
- Bump `## Version:` in the TOC for every release

### Do Not

- Add features outside battle res / bloodlust tracking — scope is intentionally narrow
- Require or bundle external libraries
- Hook or replace Blizzard functions — read aura state directly, don't detour
- Register for `COMBAT_LOG_EVENT_UNFILTERED` — it is a protected event in 12.0 and will cause `ADDON_ACTION_FORBIDDEN`
- Add Classic/Era support without a separate TOC and gated code paths
- Commit AI-related files (CLAUDE.local.md, .claude/, etc.)

## File Map

| File | Role |
|---|---|
| `PulseCheck.toc` | Addon metadata, interface version, load order |
| `PulseCheck.lua` | All addon logic |
| `Locales/enUS.lua` | English locale strings (`PC_L` table) |
| `bloodlust-detection-research.md` | API research notes and spell ID reference |
| `CHANGELOG.md` | Version history |

## References

- [Warcraft Wiki (API docs)](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
- [Warcraft Wiki: Events](https://warcraft.wiki.gg/wiki/Events)
- [Blizzard FrameXML on GitHub](https://github.com/Gethe/wow-ui-source) — Gethe's mirror of retail FrameXML
- [Patch 12.0.0 API Changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes)
