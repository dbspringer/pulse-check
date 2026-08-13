# PulseCheck — Agent Guidelines

This file provides guidance to AI coding assistants when working with code in this repository.

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

- **Bloodlust buffs**: 21 spell IDs covering Bloodlust, Heroism, Time Warp, Primal Rage, Fury of the Aspects, Harrier's Cry, and all drum variants (including Void-Touched Drums)
- **Sated debuffs**: 57723, 57724, 80354, 95809, 160455, 264689, 390435
- **Battle Res**: encounter charges via `C_Spell.GetSpellCharges(20484)`, with personal brez fallback for Druid (20484), DK (61999), Warlock (20707), Paladin (391054) via `C_Spell.GetSpellCooldown`

### 12.0 (Midnight) Aura API Considerations

Patch 12.0 introduced "secret values" that can restrict aura data on tainted execution paths. Primary detection uses `C_UnitAuras.GetPlayerAuraBySpellID(id)` with these fallback strategies:

- `C_Secrets.ShouldSpellAuraBeSecret(id)` to check if an aura is restricted at runtime
- `issecretvalue(value)` to check if a returned field is a secret value placeholder; `pcall(rawget, aura, field)` to safely access fields on potentially tainted aura objects
- Lightweight polling via `C_Timer.NewTicker` instead of `UNIT_AURA` event registration if taint is a concern
- **Sated-anchored lust detection** (primary; see the 12.1 section below)
- **Cast-based fallback** via `UNIT_SPELLCAST_SUCCEEDED`, for if the Sated family is ever re-classified as secret
- **Time-based expiration validation** for both lust and sated: when aura API returns nil during combat (due to taint), compare `GetTime()` against the previously saved expiration to distinguish real expiration from API failure
- **Instance-based polling**: `C_Timer.NewTicker` loops for lust (1s), bres (0.5s), and raid-sated (3s) start automatically inside instanced content and stop outside it

**Important:** `COMBAT_LOG_EVENT_UNFILTERED` is a **protected event** in 12.0 — addons cannot register for it without triggering `ADDON_ACTION_FORBIDDEN`. Do not use CLEU as a fallback detection path.

### 12.1 Aura API Split

Patch 12.1 divided the aura API into two tiers, and the split is the single most important constraint on this addon:

- **Lookup by spell ID or spell name — still allowed.** `C_UnitAuras.GetPlayerAuraBySpellID` keeps working while auras are secret; non-secret spells still return non-secret data. All personal lust/sated tracking runs through here.
- **Lookup by index, slot, or aura instance ID — hard Lua error.** `C_UnitAuras.GetAuraDataByIndex` (and the `C_TooltipInfo` equivalents) *raise* rather than returning nil or a secret when an addon calls them while auras are secret. A `pcall` around the field access is not enough — the call itself throws.

The authoritative source for which tier an API sits in is Blizzard's generated metadata
([UnitAuraDocumentation.lua](https://raw.githubusercontent.com/Gethe/wow-ui-source/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua)), not the wiki prose:

| Flag | Meaning |
|---|---|
| `RequiresUnitAuraAccess = true` | **Errors** when called by an addon while auras are secret. `GetAuraDataByIndex`, `GetAuraDataBySlot`, `GetAuraDataByAuraInstanceID` |
| `SecretArguments = "AllowedWhenTainted"` | Callable from tainted code. `GetPlayerAuraBySpellID`, `GetUnitAuraBySpellID` |
| `RequiresNonSecretAura = true` | Returns usable data only for non-secret spells |

**Do not use index/slot/instanceID lookups at all.** `C_UnitAuras.GetUnitAuraBySpellID(unit, spellID)` reads auras on *other* units without any of that restriction, which is what `ScanRaidSated` uses. Cost is one call per spell ID per unit, so keep the ID list short and return on the first hit.

Keep a `pcall` on aura calls regardless: the never-secret classification is set per patch and has already changed twice (see below).

Also in 12.1: `UNIT_AURA` delivers a fully secret payload while auras are secret, and AuraData structs are always fully secret (the unit token argument stays readable). `getglobal`/`setglobal` are deprecated and `UIParentLoadAddOn` is now `LoadAddOnWithErrorHandling` — this addon uses none of them.

### Which Spells Are Secret

Secrecy is decided **per spell**, not globally: auras are secret by default during combat, encounters, M+ and PvP, but individual spells carry never-secret / always-secret flags that override the restriction. `C_Secrets.ShouldAurasBeSecret()` answers the global question and is therefore *too blunt* to gate a specific spell — it is true in every encounter, including for spells that remain perfectly readable.

Current state, and the reason for the addon's whole detection design:

- **Sated / Exhaustion (all seven IDs in `SATED_IDS`) — never-secret.** Readable throughout combat.
- **Bloodlust / Heroism / drums — secret.** Not readable during encounters.

That asymmetry is what makes sated the detection anchor. Sated is applied by the same effect that grants lust, to exactly the targets that receive it, so `sated present ⟺ the player got lust`, and the aura's real `duration`/`expirationTime` give the exact lust start:

```
lustStart = satedExpiration - satedDuration
```

**This list changes between patches.** 12.1 shipped by removing healer buffs and HoTs from the never-secret list, then Blizzard walked that back and added Sated. Probe with `C_Secrets.ShouldSpellAuraBeSecret(id)` at runtime rather than hardcoding assumptions, and keep the cast-based fallback alive.

### Secret Values Outside the Aura API

Cooldown structs can carry secrets too: `SpellChargeInfo` marks only `maxCharges` and `isActive` as `NeverSecret`, so `currentCharges`, `cooldownStartTime` and `cooldownDuration` may be secret values. These don't throw on read — they throw on the *comparison or arithmetic* that happens later, often in a different function, which makes the traceback point somewhere innocent.

The rule: **sanitize at the read site, never store a secret in `state`.** `SafeNumber()` returns nil for anything unusable, and `UpdateBresState` stages values in locals so a mid-read bail can't leave `state` half-written — it holds the previous reading instead. `RefreshBresIcon` and `BresOnUpdate` then rely on `state.bres*` always being plain numbers.

Assume any numeric API can go secret in a future patch: `GetHaste()` was fine in 12.0.0 and returned secrets by 12.0.5, which is what eventually killed the haste-delta detection path entirely.

Order matters in these helpers: call `issecretvalue(v)` *before* any comparison, including `v == nil` — comparing a secret is itself the error.

### Key WoW APIs

| API | Purpose |
|---|---|
| `C_UnitAuras.GetPlayerAuraBySpellID(id)` | Check for a specific aura by spell ID |
| `C_UnitAuras.GetUnitAuraBySpellID(unit, id)` | Check a specific aura on another unit (raid-sated scan). Callable while tainted; the only safe way to read other units' auras in 12.1 |
| `C_Spell.GetSpellCharges(id)` | Encounter brez charge info (charges, cooldown, max) |
| `C_Spell.GetSpellCooldown(id)` | Personal spell cooldown info (for brez fallback) |
| `IsPlayerSpell(id)` | Check if player knows a spell (brez class detection) |
| `C_Secrets.ShouldSpellAuraBeSecret(id)` | Check if a specific spell's aura data is protected (12.0+) |
| `C_Secrets.ShouldAurasBeSecret()` | Global check only — too blunt to gate a specific spell, since never-secret spells stay readable |
| `issecretvalue(value)` | Check if a returned value is a secret placeholder (12.0+) |
| `GetInstanceInfo()` | Returns instance type for visibility and polling decisions |
| `C_AddOns.GetAddOnMetadata(name, key)` | Read addon version from TOC for settings panel |
| `C_Timer.NewTicker(interval, fn)` | Polling loops (lust, bres, raid-sated, aura fallback) |

### Localization

All user-facing strings live in `Locales/enUS.lua` as a global `PC_L` table, aliased to `local L = PC_L` in `PulseCheck.lua`. To add a language, create `Locales/<locale>.lua` that conditionally overrides keys (e.g. `if GetLocale() ~= "deDE" then return end`), and add it to the TOC after `enUS.lua`. Not localized (intentionally): addon name, slash commands, sound names, color codes, saved variable keys.

### Frame Positioning

The main frame uses a CENTER anchor relative to UIParent's BOTTOMLEFT. `SetPoint` offsets are in the child frame's coordinate space (`GetCenter()` returns offset values directly). Position is snapped to a 10-pixel grid on drag release. Scale changes preserve visual center via offset adjustment: `new_offset = old_offset * old_scale / new_scale`.

### Do

- Keep the addon to `PulseCheck.lua` + locale files unless there is a strong reason to add more
- Use `C_Timer.NewTicker` for any timing-sensitive or polling-based logic (Blizzard frames may not be ready on event fire)
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
| `export.sh` | Package addon as a distributable zip |
| `AGENTS.md` | Project instructions for AI coding assistants |

## References

- [Warcraft Wiki (API docs)](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API)
- [Warcraft Wiki: Events](https://warcraft.wiki.gg/wiki/Events)
- [Blizzard FrameXML on GitHub](https://github.com/Gethe/wow-ui-source) — Gethe's mirror of retail FrameXML
- [Patch 12.0.0 API Changes](https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes)
